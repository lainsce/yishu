/*
* Copyright (c) 2017 Lains
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*/
using Gtk;
using Yishu;

namespace Yishu {
	enum Columns {
		PRIORITY,
		MARKUP,
		TASK_OBJECT,
		VISIBLE,
		DONE,
		LINE_NR
	}

	public class Application : Gtk.Application {
		private TodoFile todo_file;
		private MainWindow window = null;
		private Gtk.Menu popup_menu;
		private Gtk.ListStore tasks_list_store;
		private TreeModelFilter tasks_model_filter;
		public TreeModelSort tasks_model_sort;
		public SearchEntry search_entry;
		public static Granite.Settings grsettings;
		public static GLib.Settings gsettings;

		/* Variables, Parameters and stuff */
		private Task trashed_task;
		public string current_filename = null;
		private string project_filter;
		private string context_filter;

		static construct {
			gsettings = new GLib.Settings ("com.github.lainsce.yishu");
		}

		construct {
			application_id = "com.github.lainsce.yishu";
			trashed_task = null;

			grsettings = Granite.Settings.get_default ();
		}

		public Application () {
			ApplicationFlags flags = ApplicationFlags.HANDLES_OPEN;
			set_flags(flags);

			var settings = AppSettings.get_default ();
			if (settings.todo_txt_file_path == null) {
				read_file(null);
			} else {
				settings.changed.connect (() => {
					read_file(settings.todo_txt_file_path);
				});
			}

			if (!settings.show_completed) {
				toggle_show_completed ();
			}
		}

		public override void activate(){
			window = new MainWindow(this);
			tasks_list_store = new Gtk.ListStore (6, typeof (string), typeof(string), typeof(GLib.Object), typeof(bool), typeof(bool), typeof(int));
			setup_model();
			window.tree_view.set_model(tasks_model_sort);
			setup_menus();
			search_entry = new SearchEntry (window.tree_view, tasks_model_sort);
			var search_context = search_entry.get_style_context ();
            search_context.add_class ("yi-searchbar");
			search_entry.placeholder_text = _("Search tasks…");
			window.titlebar.pack_start (search_entry);

			window.add_button.clicked.connect(add_task);
			window.tree_view.button_press_event.connect( (tv, event) => {
				if ((event.button == 3) && (event.type == Gdk.EventType.BUTTON_PRESS)){	// 3 = Right mouse button
					TreePath path;
					TreeIter iter;
					TreeViewColumn column;
					int cell_x;
					int cell_y;
					Task task;
					if (window.tree_view.get_path_at_pos((int)event.x, (int)event.y, out path, out column, out cell_x, out cell_y)){
						tasks_model_sort.get_iter_from_string(out iter,path.to_string());
						tasks_model_sort.get(iter, Columns.TASK_OBJECT, out task, -1);
						popup_menu.popup_at_pointer(event);
					}
				}
				return false;
			});
			window.tree_view.row_activated.connect(edit_task);
			window.cell_renderer_toggle.toggled.connect( (toggle, path) => {
				Task task;
				TreeIter iter;
				TreePath tree_path = new Gtk.TreePath.from_string(path);
				tasks_model_sort.get_iter(out iter, tree_path);
				tasks_model_sort.get(iter, Columns.TASK_OBJECT, out task, -1);
				task.done = (task.done ? false : true);
				task.to_model(tasks_list_store, task.iter);
				todo_file.lines[task.linenr - 1] = task.to_string();
				todo_file.write_file();
				toggle_show_completed();
			});

			window.delete_all_button.clicked.connect( (item) => {
				var dialog = new Granite.MessageDialog.with_image_from_icon_name (
					"Clear All Tasks?",
					"Clearing all tasks clears the app of tasks, and deletes your Todo.txt file.",
					"dialog-information",
					Gtk.ButtonsType.NONE
				);
				var clear_button = new Gtk.Button.with_label (_("Clear All"));
				clear_button.get_style_context ().add_class (Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);
				dialog.add_action_widget (clear_button, Gtk.ResponseType.OK);
	
				var cancel_button = new Gtk.Button.with_label (_("Cancel"));
				dialog.add_action_widget (cancel_button, Gtk.ResponseType.CANCEL);
				cancel_button.clicked.connect (() => { dialog.destroy (); });
				dialog.show_all ();
				dialog.transient_for = window;
				dialog.modal = true;
	
				dialog.run ();
	
				
				dialog.response.connect ((response_id) => {
					switch (response_id) {
						case Gtk.ResponseType.OK:
							delete_task ();
							window.sidebar.hide ();
							window.sidebar_no_tags.show ();
							dialog.close ();
							break;
						case Gtk.ResponseType.NO:
							dialog.close ();
							break;
						case Gtk.ResponseType.CANCEL:
						case Gtk.ResponseType.CLOSE:
						case Gtk.ResponseType.DELETE_EVENT:
							dialog.close ();
							return;
						default:
							assert_not_reached ();
					}
				});
			});

			window.sidebar.item_selected.connect( (item) => {

				string item_name = item.get_data("item-name");

				if (item_name == "clear"){
					context_filter = "";
					project_filter = "";
					tasks_model_filter.refilter();
				}
				else {
					item_name = item.parent.get_data("item-name");
					if (item_name == "contexts"){
						context_filter = "@"+item.name;
						project_filter = "";
						tasks_model_filter.refilter();
					}
					else if (item_name == "projects") {
						project_filter = "+"+item.name;
						context_filter = "";
						tasks_model_filter.refilter();
					}
				}
			});

			if (read_file(null)){
				window.normal_view.hide();
				window.swin.show();
				window.sidebar.show ();
                window.sidebar_no_tags.hide ();
			}
			else {
				window.normal_view.show();
				window.swin.hide();
				window.sidebar.hide ();
                window.sidebar_no_tags.show ();
			}

			tasks_model_filter.refilter();

			update_global_tags();
		}

		private void toggle_show_completed(){
			tasks_model_filter.refilter();
			update_global_tags();
		}

		private void setup_menus () {
			popup_menu = new Gtk.Menu();
			var accel_group_popup = new Gtk.AccelGroup();
			window.add_accel_group(accel_group_popup);
			popup_menu.set_accel_group(accel_group_popup);
			var edit_task_menu_item = new Gtk.MenuItem.with_label(_("Edit task"));
			var toggle_done_menu_item = new Gtk.MenuItem.with_label(_("Toggle done"));

			var priority_menu = new Gtk.Menu();

			var priority_menu_item = new Gtk.MenuItem.with_label(_("Priority"));
			priority_menu_item.set_submenu(priority_menu);

			var priority_none_menu_item = new Gtk.MenuItem.with_label(_("None"));
			priority_menu.append(priority_none_menu_item);
			priority_none_menu_item.add_accelerator("activate", accel_group_popup, Gdk.Key.BackSpace, Gdk.ModifierType.CONTROL_MASK, Gtk.AccelFlags.VISIBLE);
			priority_none_menu_item.activate.connect ( () => {
				Task task = get_selected_task ();
				if (task != null){
					task.priority = "";
					update_todo_file_after_task_edited (task);
				}
			});

			for (char prio = 'A'; prio <= 'F'; prio++){
				var priority_x_menu_item = new Gtk.MenuItem.with_label("%c".printf(prio));
				priority_x_menu_item.add_accelerator("activate", accel_group_popup, Gdk.Key.A + (prio - 'A'), Gdk.ModifierType.CONTROL_MASK, Gtk.AccelFlags.VISIBLE);
				priority_x_menu_item.activate.connect( (menu_item) => {

					Task task = get_selected_task();
					if (task != null){
						task.priority = menu_item.get_label ();
						update_todo_file_after_task_edited (task);
					}
				});
				priority_menu.append(priority_x_menu_item);
			}

			edit_task_menu_item.add_accelerator("activate", accel_group_popup, Gdk.Key.F2, 0, Gtk.AccelFlags.VISIBLE);
			toggle_done_menu_item.add_accelerator("activate", accel_group_popup, Gdk.Key.space, 0, Gtk.AccelFlags.VISIBLE);
			edit_task_menu_item.activate.connect(edit_task);
			toggle_done_menu_item.activate.connect(toggle_done);

			popup_menu.append(toggle_done_menu_item);
			popup_menu.append(priority_menu_item);
			popup_menu.append(edit_task_menu_item);

			popup_menu.show_all();
		}

		private void update_todo_file_after_task_edited (Task task){
			if (task != null){
				tasks_model_filter.refilter ();
				todo_file.lines[task.linenr - 1] = task.to_string ();
				task.to_model(tasks_list_store, task.iter);
				todo_file.write_file();
			}
		}

		private void reset(){
			tasks_list_store.clear();
		}

		private void setup_model(){
			tasks_model_filter = new TreeModelFilter(tasks_list_store, null);
			tasks_model_sort = new Gtk.TreeModelSort.with_model(tasks_model_filter);
			tasks_model_sort.set_sort_func( Columns.PRIORITY, (model, iter_a, iter_b) => {
				string prio_a;
				string prio_b;
				model.get(iter_a, Columns.PRIORITY, out prio_a, -1);
				model.get(iter_b, Columns.PRIORITY, out prio_b, -1);

				if (prio_a == "" && prio_b != ""){
					return 1;
				}
				if (prio_a != "" && prio_b == ""){
					return -1;
				}
				return (prio_a < prio_b ? -1 : 1);
			});
			tasks_model_sort.set_sort_column_id(Columns.PRIORITY, Gtk.SortType.ASCENDING);
		}

		private void update_global_tags(){
			var projects = new List<string>();
			var contexts = new List<string>();
			var selected_item = window.sidebar.selected;

			window.projects_category.clear();
			window.contexts_category.clear();

			tasks_list_store.foreach( (model, path, iter) => {
				Task task;
				model.get(iter, Columns.TASK_OBJECT, out task, -1);

				if (task.done){
				    window.sidebar.visible = false;
					return false;
				} else {
					window.sidebar.visible = true;
				}

				foreach (string context in task.contexts ){
					var ctx = context.splice(0, 1);
					if(!is_in_list(contexts, ctx)){
						contexts.append(ctx);
					}
				}
				foreach (string project in task.projects){
					var prj = project.splice(0, 1);
					if(!is_in_list(projects, prj)){
						projects.append(prj);
					}
				}

				return false;

			});

			foreach (string context in contexts){
				var item = new Granite.Widgets.SourceList.Item(context);
				int count = 0;
				tasks_list_store.foreach( (model, path, iter) => {
					Task task;
					model.get(iter, Columns.TASK_OBJECT, out task, -1);
					if (task.done){
						count--;
					}
					if (is_in_list(task.contexts, "@"+context)){
						count++;
					}
					return false;
				});
				if (count > 0) {
					item.badge = "%u".printf(count);
				} else {
					item.badge = "0";
				}
				window.contexts_category.add(item);
			}
			foreach (string project in projects){
				var item = new Granite.Widgets.SourceList.Item(project);
				int count = 0;
				tasks_list_store.foreach( (model, path, iter) => {
					Task task;
					model.get(iter, Columns.TASK_OBJECT, out task,-1);
					if (task.done){
						count--;
					}
					if (is_in_list(task.projects, "+"+project)){
						count++;
					}
					return false;
				});
				if (count > 0){
					item.badge = "%u".printf(count);
				} else {
					item.badge = "0";
				}
				window.projects_category.add(item);
			}


			if (selected_item != null) {

				bool flag = false;
				foreach (Granite.Widgets.SourceList.Item item in window.projects_category.children){
					if (item.name == selected_item.name){
						flag = true;
						window.sidebar.selected = item;
						break;
					}
				}
				if (!flag){
					foreach (Granite.Widgets.SourceList.Item item in window.contexts_category.children){
						if (item.name == selected_item.name){
							flag = true;
							window.sidebar.selected = item;
							break;
						}
					}
				}
			}
		}

		private bool is_in_list(List<string> list, string item){
			foreach (string i in list){
				if (i == item){
					return true;
				}
			}
			return false;
		}

		private Task get_selected_task(){
			TreeIter iter;
			TreeModel model;
			Task task = null;
			var sel = window.tree_view.get_selection();
			if (sel.get_selected(out model, out iter)){
				model.get(iter, Columns.TASK_OBJECT, out task, -1);
			}
			return task;
		}

		private TaskDialog add_edit_dialog () {
			var dialog = new TaskDialog(window);

			return dialog;
		}

		private void toggle_done () {
			Task task = get_selected_task ();
			if (task != null) {

				task.done = !task.done;
				task.to_model(tasks_list_store, task.iter);
				tasks_model_filter.refilter();
				todo_file.lines[task.linenr - 1] = task.to_string();
				todo_file.write_file();

				update_global_tags();
			}
		}

		private void edit_task () {
			TreeIter iter;
			TreeModel model;
			Task task;
			var sel = window.tree_view.get_selection();
			if (!sel.get_selected(out model, out iter)){
				return;
			}
			model.get(iter, Columns.TASK_OBJECT, out task, -1);

			if (task != null){

				var dialog = add_edit_dialog();

				dialog.entry.set_text(task.to_string());

				dialog.show_all();
				int response = dialog.run();
				switch (response){
					case Gtk.ResponseType.ACCEPT:
					task.parse_from_string(dialog.entry.get_text());
					task.to_model(tasks_list_store, task.iter);
					tasks_model_filter.refilter();
					todo_file.lines[task.linenr - 1] = task.to_string();
					todo_file.write_file();
					break;
					default:
					break;
				}
				update_global_tags();
				dialog.destroy();

				sel.select_iter(iter);
			}
		}

		private void add_task (){
			var dialog = add_edit_dialog();
			dialog.show_all ();

			var settings = AppSettings.get_default ();
			string file_path_txt = settings.todo_txt_file_path;

			int response = dialog.run ();
			switch (response){
				case Gtk.ResponseType.ACCEPT:

				string str = dialog.entry.get_text();
				Task task = new Task();

				if (task.parse_from_string(str)){
					Date d = Date();
					var output = new char[100];
					d.set_time_t(time_t(null));
					d.strftime(output, "%Y-%m-%d");
					task.date = (string)output;

					read_file (file_path_txt);
					todo_file.lines.add(task.to_string());

					TreeIter iter, fiter, siter;

					tasks_list_store.append(out iter);
					task.to_model(tasks_list_store, iter);

					if (todo_file.write_file()){
						task.linenr = todo_file.n_lines;
						task.to_model(tasks_list_store, iter);
					}
					else {
						warning ("Failed to write file");
					}

					update_global_tags();

					tasks_model_filter.convert_child_iter_to_iter(out fiter, iter);
					tasks_model_sort.convert_child_iter_to_iter(out siter, fiter);

					window.tree_view.get_selection().select_iter(siter);
				}

				window.normal_view.hide();
				window.swin.show();

				break;
				default:
				break;
			}
			dialog.destroy();
		}

		private void delete_task () {
			show_delete_dialog ();
		}

		private void show_delete_dialog () {
			tasks_list_store.clear();
			todo_file.delete_file();
			update_global_tags();
			window.normal_view.show();
			window.swin.hide();
		}

		public bool read_file (string? filename) {
			reset();
			var settings = AppSettings.get_default ();

			if (filename != null){
				todo_file = new TodoFile(filename);
			}
			else {
				todo_file = null;
				var test_file = new TodoFile(settings.todo_txt_file_path);
				if (test_file.exists()){
					todo_file = test_file;
				}
			}

			if (todo_file == null){
				return false;
			}

			this.current_filename = filename;

			todo_file.monitor.changed.connect( (file, other_file, event) => {

				if (event == FileMonitorEvent.CHANGES_DONE_HINT){
					var info_bar = new Gtk.InfoBar.with_buttons("_OK", Gtk.ResponseType.ACCEPT);
					info_bar.set_message_type(Gtk.MessageType.WARNING);
					var content = info_bar.get_content_area();
					content.add(new Label(_("The todo.txt file has been modified and been re-read")));
					info_bar.show_all();
					window.info_bar_box.foreach( (widget) => {
						widget.destroy();
					});
					window.info_bar_box.pack_start(info_bar, true, true, 0);
					info_bar.response.connect( () => {
						info_bar.destroy();
					});
					read_file(null);
				}
			});

			int n = todo_file.read_file();
			for (int i = 0; i < n; i++){
				var task = new Task();
				if (task.parse_from_string(todo_file.lines[i])){
					TreeIter iter;
					tasks_list_store.append(out iter);
					task.linenr = i+1;
					task.to_model(tasks_list_store, iter);
				}
			}
			update_global_tags();
			return true;
		}

		public static int main(string[] args){
			var app = new Yishu.Application();
			return app.run(args);
		}
	}
}
