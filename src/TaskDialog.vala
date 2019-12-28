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

namespace Yishu {
	public class TaskDialog : Gtk.Dialog {
		public Gtk.Entry entry;
		private Gtk.EntryCompletion completion;
		private Gtk.ListStore list_store;
		private Gtk.Grid bbox;
		
		public TaskDialog (Gtk.Window? parent) {
			Object (
			border_width: 6,
			deletable: false,
			resizable: false,
			title: _("New Task"),
			transient_for: parent,
			destroy_with_parent: true,
			window_position: Gtk.WindowPosition.CENTER_ON_PARENT
			);
		}
		
		construct {
			this.set_default_response(Gtk.ResponseType.ACCEPT);
			
			var task_label = new Granite.HeaderLabel (_("Task"));
			var prio_label = new Granite.HeaderLabel (_("Priority"));
			
			entry = new Gtk.Entry();
			entry.has_focus = true;
			entry.margin_start = 12;
			completion = new Gtk.EntryCompletion();
			
			list_store = new Gtk.ListStore(1, typeof(string));
			
			completion.set_model(list_store);
			completion.set_text_column(0);
			completion.match_selected.connect(on_match_selected);
			completion.set_match_func(match_func);
			
			entry.set_completion(completion);
			entry.activate.connect( () => {
				this.response(Gtk.ResponseType.ACCEPT);
			});
			
			bbox = new Gtk.Grid ();
			bbox.set_column_spacing (6);
			bbox.margin_start = 12;
			var button = new Button.with_label("A");
			var header_context = button.get_style_context ();
            header_context.add_class ("yi-button");
			bbox.add(button);
			button.clicked.connect(on_priority_button_clicked);
			var button2 = new Button.with_label("B");
			var header_context2 = button2.get_style_context ();
            header_context2.add_class ("yi-button");
			bbox.add(button2);
			button2.clicked.connect(on_priority_button_clicked);
			var button3 = new Button.with_label("C");
			var header_context3 = button3.get_style_context ();
            header_context3.add_class ("yi-button");
			bbox.add(button3);
			button3.clicked.connect(on_priority_button_clicked);
			var button4 = new Button.with_label("D");
			var header_context4 = button4.get_style_context ();
            header_context4.add_class ("yi-button");
			bbox.add(button4);
			button4.clicked.connect(on_priority_button_clicked);
			var button5 = new Button.with_label("E");
			var header_context5 = button5.get_style_context ();
            header_context5.add_class ("yi-button");
			bbox.add(button5);
			button5.clicked.connect(on_priority_button_clicked);
			var button6 = new Button.with_label("F");
			var header_context6 = button6.get_style_context ();
			bbox.add(button6);
			button6.clicked.connect(on_priority_button_clicked);
            header_context6.add_class ("yi-button");
			
			var task_help = new Gtk.Image.from_icon_name ("help-info-symbolic", Gtk.IconSize.BUTTON);
			task_help.halign = Gtk.Align.START;
			task_help.hexpand = true;
			task_help.tooltip_text = _("Adding YYYY-MM-DD after the priority and before the task will give a due date to the task.\nAdding + to a word will categorize the task.\nAdding @ to a word will specify the task's place.");
			
			var close_button = add_button (_("Cancel"), Gtk.ResponseType.CLOSE);
			this.add_button((_("OK")), Gtk.ResponseType.ACCEPT);
			((Gtk.Button) close_button).clicked.connect (() => destroy ());
			
			var main_grid = new Gtk.Grid();
			main_grid.margin = 6;
			main_grid.margin_top = 0;
			main_grid.row_spacing = 6;
			main_grid.column_spacing = 12;
			main_grid.attach (task_label, 0, 0, 1, 1);
			main_grid.attach (task_help, 1, 1, 1, 1);
			main_grid.attach (entry, 0, 1, 1, 1);
			main_grid.attach (prio_label, 0, 2, 1, 1);
			main_grid.attach (bbox, 0, 3, 1, 1);
			
			((Gtk.Container) get_content_area ()).add (main_grid);
		}
		
		private void on_priority_button_clicked (Button button) {
			try {
				Regex re = new Regex("(\\([A-Z]\\) )");
				string new_text = re.replace(this.entry.text, -1, 0, "", 0);
				this.entry.text = "(%s) %s".printf(button.label, new_text);
			}
			catch (Error e){
				warning(e.message);
			}
		}
		
		public void on_button_clicked(Button button){
			this.entry.set_text(
			this.entry.text + " " + button.label
			);
		}
		
		private bool on_match_selected(TreeModel model, TreeIter iter){
			string str;
			model.get(iter, 0, out str, -1);
			
			int pos = entry.cursor_position;
			var buf = entry.get_buffer();
			string text = buf.get_text();
			
			int start = pos;
			int end = pos;
			
			unichar c = 0;
			for (int i = 0; text.get_prev_char(ref start, out c); i++){
				string s = c.to_string();
				if (s == " "){
					start++;
					break;
				}
				else if (s == "+" || s == "@"){
					break;
				}
			}
			for (int i = 0; text.get_next_char(ref end, out c); i++){
				if (c.to_string() == " "){
					break;
				}
			}
			
			string new_str = text.splice(start, end, str);
			buf.set_text((uint8[])new_str.to_utf8());
			for (int i = 0; new_str.get_next_char(ref end, out c); i++){
				if (c.to_string() == " "){
					break;
				}
			}
			entry.set_position(end);
			
			return true;
		}
		
		public bool match_func (EntryCompletion completion, string key, TreeIter iter){
			try {
				MatchInfo mi;
				
				var re = new Regex("(@|\\+[A_Za-z0-9-_]*)(?!.* )");
				if (re.match(key, 0, out mi)){
					
					string str;
					list_store.get(iter, 0, out str, -1);
					
					var re2 = new Regex(Regex.escape_string(mi.fetch(0)));
					return re2.match(str.down());
				}
			}
			catch (Error e){
				warning("%s", e.message);
			}
			return false;
			
		}
	}
}
