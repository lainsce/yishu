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
		private MainWindow window;
		private Gtk.Menu popup_menu;
		private Gtk.ListStore tasks_list_store;
		private TreeModelFilter tasks_model_filter;
		private TreeModelSort tasks_model_sort;

		private Task trashed_task;
		public string current_filename = null;

		construct {
			application_id = "com.github.lainsce.yishu";
			trashed_task = null;
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
            var settings = AppSettings.get_default ();
			tasks_list_store = new Gtk.ListStore (6, typeof (string), typeof(string), typeof(GLib.Object), typeof(bool), typeof(bool), typeof(int));
			setup_model();
			window.tree_view.set_model(tasks_model_sort);
			setup_menus();
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
			window.welcome.activated.connect((index) => {
				switch (index){
					case 0:
					add_task();
					break;
					case 1:
					Granite.Services.System.open_uri("http://todotxt.com");
					break;
				}
			});
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

            if (read_file(settings.todo_txt_file_path)) {
                window.welcome.hide();
                window.tree_view.show();
            } else if (settings.todo_txt_file_path == "" && read_file(null)) {
                window.welcome.show();
                window.tree_view.hide();
            }

            settings.changed.connect (() => {
    			if (read_file(settings.todo_txt_file_path)) {
    				window.welcome.hide();
    				window.tree_view.show();
    			} else if (settings.todo_txt_file_path == "" && read_file(null)) {
    				window.welcome.show();
    				window.tree_view.hide();
    			}
            });
			tasks_model_filter.refilter();
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
			var delete_task_menu_item = new Gtk.MenuItem.with_label(_("Delete task"));
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
			delete_task_menu_item.add_accelerator("activate", accel_group_popup, Gdk.Key.Delete, 0, Gtk.AccelFlags.VISIBLE);
			toggle_done_menu_item.add_accelerator("activate", accel_group_popup, Gdk.Key.space, 0, Gtk.AccelFlags.VISIBLE);
			edit_task_menu_item.activate.connect(edit_task);
			delete_task_menu_item.activate.connect(delete_task);
			toggle_done_menu_item.activate.connect(toggle_done);

			popup_menu.append(toggle_done_menu_item);
			popup_menu.append(priority_menu_item);
			popup_menu.append(edit_task_menu_item);
			popup_menu.append(delete_task_menu_item);

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
			var settings = AppSettings.get_default ();
			bool show_completed = settings.show_completed;

			tasks_list_store.foreach( (model, path, iter) => {
				Task task;
				model.get(iter, Columns.TASK_OBJECT, out task, -1);

				if (!show_completed && task.done){
					return false;
				}

				return false;

			});
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

				window.welcome.hide();
				window.tree_view.show();

				break;
				default:
				break;
			}
			dialog.destroy();
		}

		private void delete_task () {
			Task task = get_selected_task ();
			if (task != null) {
				trashed_task = task;
				todo_file.lines.remove_at (task.linenr -1);
				todo_file.write_file ();
				tasks_list_store.remove(ref task.iter);

				var infobar = new Gtk.InfoBar ();
            	var infobar_label = new Gtk.Label ("The task has been deleted");
				infobar.get_content_area ().add (infobar_label);
				infobar.add_button("_Undo", Gtk.ResponseType.ACCEPT);
            	infobar.show_close_button = false;
            	infobar.message_type = Gtk.MessageType.INFO;
				infobar.show_all();

				window.info_bar_box.foreach( (child) => {
					child.destroy();
				});

				window.info_bar_box.pack_start(infobar, true, true, 0);
				infobar.response.connect( () => {
					undelete();
					infobar.destroy();
				});

				update_global_tags();
			}
		}

		private void undelete () {
			if (trashed_task != null){
				debug ("Restoring task: " + trashed_task.text + " at line nr. " + "%u".printf(trashed_task.linenr));

				todo_file.lines.insert(trashed_task.linenr - 1, trashed_task.to_string());
				todo_file.write_file();
				TreeIter iter;
				tasks_list_store.append(out iter);
				trashed_task.to_model(tasks_list_store, iter);
				tasks_model_filter.refilter();

				trashed_task = null;
			}
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
