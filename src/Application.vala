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

	/* Symbolic names for the columns in the
	   data model (ListStore)
	*/
	enum Columns {
		PRIORITY,
		MARKUP,
		TASK_OBJECT,
		VISIBLE,
		DONE,
		LINE_NR
	}

	/* Extend Granite.Application */

	public class Application : Granite.Application {
		/* File stuff */
		private TodoFile todo_file;

		/* Widgets */
		private MainWindow window;
		private Gtk.Menu popup_menu;

		/* Models and Lists */
		private Gtk.ListStore tasks_list_store;
		private TreeModelFilter tasks_model_filter;
		private TreeModelSort tasks_model_sort;

		private Task trashed_task;
		private string current_filename = null;

		construct {
			/* Set up the app */
      application_id = "com.github.lainsce.yishu";
      program_name = "Yishu";
      app_launcher = "com.github.lainsce.yishu.desktop";
      exec_name = "com.github.lainsce.yishu";

      var quit_action = new SimpleAction ("quit", null);
      add_action (quit_action);
      add_accelerator ("<Control>q", "app.quit", null);
      quit_action.activate.connect (() => {
          if (window != null) {
              window.destroy ();
          }
      });

		 	trashed_task = null;
		}

		public Application () {
			ApplicationFlags flags = ApplicationFlags.HANDLES_OPEN;
			set_flags(flags);

      var settings = AppSettings.get_default ();
      if (settings.todo_txt_file_path == null) {
        read_file(null);
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
			window.open_button.clicked.connect(open_file);
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

						popup_menu.popup(null, null, null, event.button, event.time);
					}
				}
				return false;
			});
			window.tree_view.row_activated.connect(edit_task);
			window.welcome.activated.connect((index) => {
				switch (index){
					case 0:
						select_file();
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
				task.to_model(tasks_list_store, null);
				todo_file.lines[task.linenr - 1] = task.to_string();
				todo_file.write_file();
				toggle_show_completed();
			});
			if (read_file(null)){
				window.welcome.hide();
				window.tree_view.show();
			}
			else {
				window.welcome.show();
				window.tree_view.hide();
			}
			tasks_model_filter.refilter();
		}

		protected override void open (File[] files, string hint){
			activate();
			foreach (File file in files){
				debug ("Opening file: %s\n", file.get_path());
				read_file(file.get_path());
			}
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

		/**
		 * reset
		 */
		private void reset(){
			tasks_list_store.clear();
		}

		/**
		 * setup_model
		 */
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

		private void open_file(){
			select_file();
		}

		private bool select_file(){
			var dialog = new FileChooserDialog(
				_("Select your todo.txt file"),
				this.window,
				Gtk.FileChooserAction.OPEN,
				"_Cancel", Gtk.ResponseType.CANCEL,
				"_Open", Gtk.ResponseType.ACCEPT
			);

			Gtk.FileFilter filter = new FileFilter();
			dialog.set_filter(filter);
			filter.add_pattern("*todo.txt");

			if (dialog.run() == Gtk.ResponseType.ACCEPT){

				read_file(dialog.get_filename());
				window.welcome.hide();
				window.tree_view.show();

			}
			dialog.destroy();
			return true;
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

				var info_bar = new Gtk.InfoBar.with_buttons("_Undo", Gtk.ResponseType.ACCEPT);
				info_bar.set_message_type(Gtk.MessageType.INFO);
				var content = info_bar.get_content_area();
				content.add(new Label(_("The task has been deleted")));
				info_bar.show_all();

				window.info_bar_box.foreach( (child) => {
					child.destroy();
				});

				window.info_bar_box.pack_start(info_bar, true, true, 0);
				info_bar.response.connect( () => {
					undelete();
					info_bar.destroy();
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

		/**
		 * read_file
		 */
		public bool read_file (string? filename) {
			reset();
      var settings = AppSettings.get_default ();

			if (filename != null){
				todo_file = new TodoFile(filename);
			}
			else {
				string DS = "%c".printf(GLib.Path.DIR_SEPARATOR);
				string[] paths = {
					settings.todo_txt_file_path,
					Environment.get_home_dir() + DS + "todo.txt",
					Environment.get_home_dir() + DS + "bin" + DS + "todo.txt" + DS + "todo.txt",
					Environment.get_home_dir() + DS + "Dropbox" + DS + "todo.txt",
					Environment.get_home_dir() + DS + "Dropbox" + DS + "todo" + DS + "todo.txt"
				};

				todo_file = null;
				foreach (string path in paths){

					var test_file = new TodoFile(path);
					if (test_file.exists()){
						todo_file = test_file;
						break;
					}
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

			try {
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
			}
			catch (Error e){
				warning("%s", e.message);
				return false;
			}
			return true;
		}

    public static int main(string[] args){
      Intl.setlocale (LocaleCategory.ALL, "");
      Intl.textdomain (Build.GETTEXT_PACKAGE);

    	var app = new Yishu.Application();
    	return app.run(args);
    }
	}
}
