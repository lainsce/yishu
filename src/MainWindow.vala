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
	public class MainWindow : Gtk.Window {
		public Gtk.Box info_bar_box;
		public Gtk.HeaderBar toolbar;
		public Gtk.Button open_button;
		public Gtk.Button add_button;
		public Granite.Widgets.Welcome welcome;
		public Granite.Widgets.Welcome no_file;
		public Gtk.TreeView tree_view;
		public Gtk.CellRendererToggle cell_renderer_toggle;

		public const string ACTION_PREFIX = "win.";
		public const string ACTION_PREFS = "action_prefs";
		public SimpleActionGroup actions { get; construct; }
        public static Gee.MultiMap<string, string> action_accelerators = new Gee.HashMultiMap<string, string> ();

        private const GLib.ActionEntry[] action_entries = {
            { ACTION_PREFS,              action_prefs     }
        };

        public MainWindow (Gtk.Application application) {
            GLib.Object (application: application,
            icon_name: "com.github.lainsce.yishu",
            height_request: 600,
            width_request: 500,
            title: N_("Yishu"));
        }

        construct {
            key_press_event.connect ((e) => {
                uint keycode = e.hardware_keycode;
                if ((e.state & Gdk.ModifierType.CONTROL_MASK) != 0) {
                    if (match_keycode (Gdk.Key.q, keycode)) {
                        this.destroy ();
                    }
                }
                return false;
            });

            var provider = new Gtk.CssProvider ();
            provider.load_from_resource ("/com/github/lainsce/yishu/stylesheet.css");
            Gtk.StyleContext.add_provider_for_screen (Gdk.Screen.get_default (), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

			actions = new SimpleActionGroup ();
            actions.add_action_entries (action_entries, this);
            insert_action_group ("win", actions);

            var settings = AppSettings.get_default ();
            int x = settings.window_x;
            int y = settings.window_y;
            int w = settings.saved_state_width;
            int h = settings.saved_state_height;

            if (x != -1 && y != -1) {
                move (x, y);
            }

            if (w != -1 && h != -1) {
                resize (w, h);
            }

			var vbox = new Box(Gtk.Orientation.VERTICAL, 0);
			var stack = new Stack();
			var swin = new ScrolledWindow(null, null);

			welcome = new Granite.Widgets.Welcome(_("No Todo.txt File Open"), _("Open a todo.txt file to start adding tasks"));
            welcome.append("appointment-new", _("Add task"), _("Create a new todo.txt file with this task in your Home folder"));
			welcome.append("help-contents", _("What is a todo.txt file?"), _("Learn more about todo.txt files"));
			no_file = new Granite.Widgets.Welcome(_("No Todo.txt File Found"), _("Add tasks to start this todo.txt file"));

			/* Create toolbar */
			toolbar = new HeaderBar();
            this.set_titlebar(toolbar);
            toolbar.set_show_close_button (true);
            toolbar.has_subtitle = false;
            var header_context = toolbar.get_style_context ();
            header_context.add_class ("yi-titlebar");

			add_button = new Gtk.Button ();
            add_button.set_image (new Gtk.Image.from_icon_name ("appointment-new", Gtk.IconSize.LARGE_TOOLBAR));
            add_button.has_tooltip = true;
            add_button.tooltip_text = (_("Add task…"));

			var prefs_button = new Gtk.ModelButton ();
            prefs_button.action_name = ACTION_PREFIX + ACTION_PREFS;
			prefs_button.text = (_("Preferences"));

			var menu_grid = new Gtk.Grid ();
            menu_grid.margin = 6;
            menu_grid.row_spacing = 6;
            menu_grid.column_spacing = 12;
            menu_grid.orientation = Gtk.Orientation.VERTICAL;
            menu_grid.add (prefs_button);
            menu_grid.show_all ();

            var menu = new Gtk.Popover (null);
            menu.add (menu_grid);

            var menu_button = new Gtk.MenuButton ();
            menu_button.set_image (new Gtk.Image.from_icon_name ("open-menu", Gtk.IconSize.LARGE_TOOLBAR));
            menu_button.has_tooltip = true;
            menu_button.tooltip_text = (_("Settings"));
			menu_button.popover = menu;

			toolbar.pack_start (add_button);
			toolbar.pack_end (menu_button);

			tree_view = setup_tree_view();
			swin.add(tree_view);
			stack.add(welcome);
			stack.add(swin);

			info_bar_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
			vbox.pack_start(info_bar_box, false, false, 0);
			vbox.pack_start(stack, true, true, 0);
			add(vbox);

			show_all();
		}

		private void action_prefs () {
            debug ("Prefs button pressed.");
			var preferences_dialog = new Widgets.Preferences (this);
			preferences_dialog.show_all ();
        }

        public override bool delete_event (Gdk.EventAny event) {
            int x, y;
            int w, h;
            var settings = AppSettings.get_default ();

            get_position (out x, out y);
            get_size(out w, out h);

            settings.window_x = x;
            settings.window_y = y;
            settings.saved_state_width = w;
            settings.saved_state_height = h;
            return false;
        }

#if VALA_0_42
        protected bool match_keycode (uint keyval, uint code) {
#else
        protected bool match_keycode (int keyval, uint code) {
#endif
            Gdk.KeymapKey [] keys;
            Gdk.Keymap keymap = Gdk.Keymap.get_for_display (Gdk.Display.get_default ());
            if (keymap.get_entries_for_keyval (keyval, out keys)) {
                foreach (var key in keys) {
                    if (code == key.keycode)
                        return true;
                    }
                }

            return false;
        }

		private TreeView setup_tree_view(){
			TreeView tv = new TreeView();
			TreeViewColumn col;

			col = new TreeViewColumn.with_attributes(_("Priority"), new Granite.Widgets.CellRendererBadge(), "text", Columns.PRIORITY);
			col.set_sort_column_id(Columns.PRIORITY);
			col.resizable = true;
			tv.append_column(col);

			col = new TreeViewColumn.with_attributes(_("Task"), new CellRendererText(), "markup", Columns.MARKUP);
			col.set_sort_column_id(Columns.MARKUP);
			col.resizable = true;
            col.expand = true;
			tv.append_column(col);

			cell_renderer_toggle = new CellRendererToggle();
			col = new TreeViewColumn.with_attributes(_("Done"), cell_renderer_toggle, "active", Columns.DONE);
			col.set_sort_column_id(Columns.DONE);
			col.resizable = true;
			tv.append_column(col);

			return tv;
		}
	}
}
