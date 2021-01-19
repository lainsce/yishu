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

namespace Yishu {
	public class MainWindow : Hdy.Window {
	    public Gtk.Application app { get; construct; }
		public Gtk.Box info_bar_box;
		public Hdy.HeaderBar titlebar;
		public Hdy.HeaderBar fauxtitlebar;
		public Hdy.Leaflet leaflet;
		public Gtk.Button delete_all_button;
		public Gtk.Button add_button;
		public Gtk.ScrolledWindow swin;
		public Granite.Widgets.Welcome welcome;
		public Granite.Widgets.Welcome no_file;
		public Gtk.Stack sidebar_stack;
		public Gtk.Label sidebar_no_tags;
		public Gtk.TreeView tree_view;
		public Gtk.TreeView tv;
		public Gtk.Grid normal_view;
		public Gtk.CellRendererToggle cell_renderer_toggle;
		public Gtk.Stack stack;
		public Granite.Widgets.SourceList sidebar;
		public Granite.Widgets.SourceList.ExpandableItem projects_category;
        public Granite.Widgets.SourceList.ExpandableItem contexts_category;
        public Widgets.Preferences preferences_dialog;

        public MainWindow (Gtk.Application application) {
            GLib.Object (
                         application: application,
                         app: application,
                         icon_name: "com.github.lainsce.yishu",
                         height_request: 300,
                         width_request: 500,
                         title: N_("Yishu")
            );

            if (Yishu.Application.grsettings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK) {
                Yishu.Application.gsettings.set_boolean("dark-mode", true);
            } else if (Yishu.Application.grsettings.prefers_color_scheme == Granite.Settings.ColorScheme.NO_PREFERENCE) {
                Yishu.Application.gsettings.set_boolean("dark-mode", false);
            }

            Yishu.Application.grsettings.notify["prefers-color-scheme"].connect (() => {
                if (Yishu.Application.grsettings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK) {
                    Yishu.Application.gsettings.set_boolean("dark-mode", true);
                } else if (Yishu.Application.grsettings.prefers_color_scheme == Granite.Settings.ColorScheme.NO_PREFERENCE) {
                    Yishu.Application.gsettings.set_boolean("dark-mode", false);
                }
            });

            if (Yishu.Application.gsettings.get_boolean("dark-mode")) {
                Gtk.Settings.get_default ().gtk_application_prefer_dark_theme = true;
                titlebar.get_style_context ().add_class ("yi-titlebar-dark");
                tv.get_style_context ().add_class ("yi-tv-dark");
                swin.get_style_context ().add_class ("yi-tv-dark");
                stack.get_style_context ().add_class ("yi-stack-dark");
            } else {
                Gtk.Settings.get_default ().gtk_application_prefer_dark_theme = false;
                titlebar.get_style_context ().remove_class ("yi-titlebar-dark");
                tv.get_style_context ().remove_class ("yi-tv-dark");
                swin.get_style_context ().remove_class ("yi-tv-dark");
                stack.get_style_context ().remove_class ("yi-stack-dark");
            }

            Yishu.Application.gsettings.changed.connect (() => {
                if (Yishu.Application.gsettings.get_boolean("dark-mode")) {
                    Gtk.Settings.get_default ().gtk_application_prefer_dark_theme = true;
                    titlebar.get_style_context ().add_class ("yi-titlebar-dark");
                    tv.get_style_context ().add_class ("yi-tv-dark");
                    swin.get_style_context ().add_class ("yi-tv-dark");
                    stack.get_style_context ().add_class ("yi-stack-dark");
                } else {
                    Gtk.Settings.get_default ().gtk_application_prefer_dark_theme = false;
                    titlebar.get_style_context ().remove_class ("yi-titlebar-dark");
                    tv.get_style_context ().remove_class ("yi-tv-dark");
                    swin.get_style_context ().remove_class ("yi-tv-dark");
                    stack.get_style_context ().remove_class ("yi-stack-dark");
                }
            });
        }

        construct {
            Hdy.init ();
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

			stack = new Gtk.Stack ();
			stack.transition_type = Gtk.StackTransitionType.SLIDE_LEFT_RIGHT;
			swin = new Gtk.ScrolledWindow(null, null);
			swin.get_style_context ().add_class ("yi-tv");

			/* Create titlebar */
			titlebar = new Hdy.HeaderBar();
            titlebar.set_show_close_button (true);
            titlebar.has_subtitle = false;
            var header_context = titlebar.get_style_context ();
            header_context.add_class ("yi-titlebar");
            titlebar.has_subtitle = false;
            titlebar.title = "Yishu";
            titlebar.hexpand = true;
            titlebar.set_size_request (-1,38);

            fauxtitlebar = new Hdy.HeaderBar();
            fauxtitlebar.set_show_close_button (true);
            fauxtitlebar.has_subtitle = false;
            fauxtitlebar.get_style_context ().add_class ("yi-side-titlebar");
            fauxtitlebar.set_size_request (193,38);

			add_button = new Gtk.Button ();
            add_button.set_image (new Gtk.Image.from_icon_name ("appointment-new-symbolic", Gtk.IconSize.SMALL_TOOLBAR));
            add_button.has_tooltip = true;
            add_button.tooltip_text = (_("Add task…"));
            add_button.visible = true;

            delete_all_button = new Gtk.Button ();
            delete_all_button.set_image (new Gtk.Image.from_icon_name ("edit-clear-all-symbolic", Gtk.IconSize.SMALL_TOOLBAR));
            delete_all_button.has_tooltip = true;
            delete_all_button.tooltip_text = (_("Clear all tasks"));
            delete_all_button.get_style_context ().add_class ("destructive-button");

            var menu_button = new Gtk.Button ();
            menu_button.set_image (new Gtk.Image.from_icon_name ("open-menu-symbolic", Gtk.IconSize.SMALL_TOOLBAR));
            menu_button.has_tooltip = true;
            menu_button.tooltip_text = (_("Settings"));

            menu_button.clicked.connect (() => {
                debug ("Prefs button pressed.");
                preferences_dialog = new Widgets.Preferences (this);
                preferences_dialog.show_all ();

                if (preferences_dialog != null) {
                    preferences_dialog.present ();
                }
            });

			titlebar.pack_end (menu_button);
			titlebar.pack_end (delete_all_button);
			titlebar.pack_end (add_button);

            var normal_icon = new Gtk.Image.from_icon_name ("appointment-new-symbolic", Gtk.IconSize.DND);
            var normal_label = new Gtk.Label (_("Start by adding some tasks…"));
            normal_label.halign = Gtk.Align.START;
            var normal_label_context = normal_label.get_style_context ();
            normal_label_context.add_class (Granite.STYLE_CLASS_H2_LABEL);
            normal_label_context.add_class (Gtk.STYLE_CLASS_DIM_LABEL);
            // Take care to use "\n" where the sentence should break to a new line.
            var normal_label2 = new Gtk.Label (_("You can configure which Todo.txt file to use in Settings,\nthe default is on Home."));
            normal_label2.halign = Gtk.Align.START;
            var normal_label2_context = normal_label2.get_style_context ();
            normal_label2_context.add_class (Granite.STYLE_CLASS_H4_LABEL);
            normal_label2_context.add_class (Gtk.STYLE_CLASS_DIM_LABEL);

            var normal_label_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
            normal_label_box.add (normal_label);
            normal_label_box.add (normal_label2);

            normal_view = new Gtk.Grid ();
            normal_view.column_spacing = 12;
            normal_view.row_spacing = 24;
            normal_view.expand = true;
            normal_view.halign = normal_view.valign = Gtk.Align.CENTER;
            normal_view.attach (normal_icon,0,0,1,1);
            normal_view.attach (normal_label_box,1,0,1,1);

			tree_view = setup_tree_view();
			swin.add(tree_view);
			stack.add(normal_view);
            stack.add(swin);
            stack.get_style_context ().add_class ("yi-stack");

            var vbox = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
			info_bar_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
			vbox.pack_start (info_bar_box, false, false, 0);
			vbox.pack_start (stack, true, true, 0);

			/* Create sidebar */
			sidebar = new Granite.Widgets.SourceList();
            sidebar.hexpand = false;
            sidebar.margin_top = 4;
			sidebar.margin_start = sidebar.margin_end = 8;
            projects_category = new Granite.Widgets.SourceList.ExpandableItem ("");
            projects_category.markup = _("CATEGORIES");
            contexts_category = new Granite.Widgets.SourceList.ExpandableItem ("");
            contexts_category.markup = _("LOCATIONS");
			projects_category.set_data("item-name", "projects");
			contexts_category.set_data("item-name", "contexts");
			sidebar.root.add(projects_category);
			sidebar.root.add(contexts_category);
			sidebar.root.expand_all();

			sidebar_no_tags = new Gtk.Label (_("No Tags…"));
			sidebar_no_tags.halign = Gtk.Align.CENTER;
			sidebar_no_tags.vexpand = true;
            var sidebar_no_tags_context = sidebar_no_tags.get_style_context ();
            sidebar_no_tags_context.add_class (Granite.STYLE_CLASS_H2_LABEL);
            sidebar_no_tags_context.add_class (Gtk.STYLE_CLASS_DIM_LABEL);
            sidebar_no_tags.margin = 12;
            sidebar_no_tags.show_all ();

            var sidebar_header = new Gtk.Label("");
            sidebar_header.get_style_context ().add_class (Granite.STYLE_CLASS_H4_LABEL);
            sidebar_header.halign = Gtk.Align.START;
            sidebar_header.margin_start = 9;
            sidebar_header.margin_top = 6;
            sidebar_header.set_markup (_("TAGS"));

            var sgrid = new Gtk.Grid ();
			sgrid.get_style_context ().add_class ("yi-column");
            sgrid.attach (fauxtitlebar, 0, 0, 1, 1);
            sgrid.attach (sidebar_header, 0, 1, 1, 1);
            sgrid.attach (sidebar, 0, 2, 1, 1);
            sgrid.attach (sidebar_no_tags, 0, 2, 1, 1);

            sgrid.show_all ();

            var grid = new Gtk.Grid ();
            grid.attach (titlebar, 1, 0, 1, 1);
            grid.attach (vbox, 1, 1, 1, 1);
            grid.show_all ();

            update ();

            leaflet = new Hdy.Leaflet ();
            leaflet.add (sgrid);
            leaflet.add (grid);
            leaflet.transition_type = Hdy.LeafletTransitionType.UNDER;
            leaflet.show_all ();
            leaflet.can_swipe_back = true;
            leaflet.set_visible_child (grid);

            leaflet.notify["folded"].connect (() => {
                update ();
            });

            this.add (leaflet);

			show_all();
		}

		public void reset(){
			projects_category.clear();
			contexts_category.clear();
		}

		private void update () {
            if (leaflet != null && leaflet.get_folded ()) {
                // On Mobile size, so.... have to have no buttons anywhere.
                fauxtitlebar.set_decoration_layout (":");
                titlebar.set_decoration_layout (":");
            } else {
                // Else you're on Desktop size, so business as usual.
                fauxtitlebar.set_decoration_layout ("close:");
                titlebar.set_decoration_layout (":maximize");
            }
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

		private Gtk.TreeView setup_tree_view(){
			tv = new Gtk.TreeView();
			tv.headers_visible = false;
			tv.vexpand = true;
			Gtk.TreeViewColumn col;

			col = new Gtk.TreeViewColumn.with_attributes(_("Priority"), new Granite.Widgets.CellRendererBadge(), "text", Columns.PRIORITY);
			col.set_sort_column_id(Columns.PRIORITY);
			col.resizable = true;
			tv.append_column(col);

			col = new Gtk.TreeViewColumn.with_attributes(_("Task"), new Gtk.CellRendererText(), "markup", Columns.MARKUP);
			col.set_sort_column_id(Columns.MARKUP);
			col.resizable = true;
            col.expand = true;
			tv.append_column(col);

			cell_renderer_toggle = new Gtk.CellRendererToggle();
			col = new Gtk.TreeViewColumn.with_attributes(_("Done"), cell_renderer_toggle, "active", Columns.DONE);
			col.set_sort_column_id(Columns.DONE);
			col.resizable = true;
			tv.append_column(col);

			return tv;
		}
	}
}
