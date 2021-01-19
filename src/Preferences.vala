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
namespace Yishu.Widgets {
    public class Preferences : Gtk.Dialog {
        public Gtk.ComboBoxText list_place;

        public Preferences (Gtk.Window? parent) {
            Object (
                border_width: 6,
                deletable: false,
                resizable: false,
                title: _("Preferences"),
                transient_for: parent,
                destroy_with_parent: true,
                window_position: Gtk.WindowPosition.CENTER_ON_PARENT
            );
        }

        construct {
            var settings = AppSettings.get_default ();

            var header = new Granite.HeaderLabel (_("Interface"));
            var label = new SettingsLabel (_("Save searches:"));
            var switch_b = new SettingsSwitch ("save-search");

            var header2 = new Granite.HeaderLabel (_("Todo.txt Preferences"));
            var label2 = new SettingsLabel (_("Default Location:"));
            list_place = new Gtk.ComboBoxText();
            list_place.hexpand = true;
            list_place.append_text(_("Home Folder"));
            list_place.append_text(_("Dropbox Folder"));
            list_place.append_text(_("Nextcloud Folder"));
            list_place.append_text(_("ownCloud Folder"));
            list_place.append_text(_("Other Clients Folder"));

            string homedir = GLib.Environment.get_home_dir ();
            string home = homedir + "/todo.txt";
            string db = homedir + "/Dropbox/todo.txt";
            string nc = homedir + "/Nextcloud/todo.txt";
            string oc = homedir + "/ownCloud/todo.txt";
            string other = homedir + "/bin/todo.txt/todo.txt";
            string file_used = settings.todo_txt_file_path;

            if (file_used == home) {
                list_place.set_active(0);
                debug ("Set as Home");
            } else if (file_used == db) {
                list_place.set_active(1);
                debug ("Set as Dropbox");
            } else if (file_used == nc) {
                list_place.set_active(2);
                debug ("Set as Nextcloud");
            } else if (file_used == oc) {
                list_place.set_active(3);
                debug ("Set as ownCloud");
            } else if (file_used == other) {
                list_place.set_active(4);
                debug ("Set as Other");
            } else {
                settings.custom_file_enable = true;
                list_place.set_active(0);
                list_place.sensitive = false;
                label2.sensitive = false;
                debug ("Set as custom");
            }

            list_place.changed.connect (() => {
                switch (list_place.get_active ()) {
                    case 0:
                        settings.todo_txt_file_path = home;
                        list_place.sensitive = true;
                        break;
                    case 1:
                        settings.todo_txt_file_path = db;
                        list_place.sensitive = true;
                        break;
                    case 2:
                        settings.todo_txt_file_path = nc;
                        list_place.sensitive = true;
                        break;
                    case 3:
                        settings.todo_txt_file_path = oc;
                        list_place.sensitive = true;
                        break;
                    case 4:
                        settings.todo_txt_file_path = other;
                        list_place.sensitive = true;
                        break;
                    default:
                        settings.todo_txt_file_path = home;
                        list_place.sensitive = true;
                        break;
                }
            });

            var label_c = new SettingsLabel (_("Custom Location:"));
            var switch_c = new SettingsSwitch ("custom-file-enable");
            var chooser = new Gtk.FileChooserButton (_("Open your file"), Gtk.FileChooserAction.OPEN);
            chooser.hexpand = true;

            var custom_help = new Gtk.Image.from_icon_name ("dialog-information-symbolic", Gtk.IconSize.BUTTON);
            custom_help.halign = Gtk.Align.START;
            custom_help.hexpand = true;
            custom_help.tooltip_text = _("Enabling custom locations will have you save your file\nin other places not recognized by other clients.");

            var filter = new Gtk.FileFilter ();
            chooser.set_filter (filter);
            filter.add_mime_type ("todo.txt");

            chooser.selection_changed.connect (() => {
                string uri = chooser.get_filename ();
                settings.todo_txt_file_path = uri;
            });

            if (settings.custom_file_enable == true) {
                    chooser.sensitive = true;
                    switch_c.active = true;
                    list_place.sensitive = false;
                    label2.sensitive = false;
            } else {
                    chooser.sensitive = false;
                    switch_c.active = false;
                    list_place.sensitive = true;
                    label2.sensitive = true;
                    list_place.set_active(0);
                    settings.todo_txt_file_path = home;
            }

            switch_c.notify["active"].connect (() => {
                if (settings.custom_file_enable == true) {
                    chooser.sensitive = true;
                    switch_c.active = true;
                    list_place.sensitive = false;
                    label2.sensitive = false;
                } else {
                    chooser.sensitive = false;
                    switch_c.active = false;
                    list_place.sensitive = true;
                    label2.sensitive = true;
                    list_place.set_active(0);
                    settings.todo_txt_file_path = home;
                }
            });

            if (settings.custom_file_enable == true) {
                chooser.sensitive = true;
                switch_c.active = true;
                list_place.sensitive = false;
                label2.sensitive = false;
            } else {
                chooser.sensitive = false;
                switch_c.active = false;
                list_place.sensitive = true;
                label2.sensitive = true;
            }

            var hbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
            hbox.pack_start (switch_c, false, true, 0);
            hbox.pack_start (chooser, false, true, 0);

            var main_grid = new Gtk.Grid ();
            main_grid.margin = 6;
            main_grid.row_spacing = 6;
            main_grid.column_spacing = 12;
            main_grid.attach (header, 0, 1, 1, 1);
            main_grid.attach (label, 0, 2, 1, 1);
            main_grid.attach (switch_b, 1, 2, 1, 1);
            main_grid.attach (header2, 0, 3, 1, 1);
            main_grid.attach (label2, 0, 4, 1, 1);
            main_grid.attach (list_place, 1, 4, 3, 1);
            main_grid.attach (label_c, 0, 5, 1, 1);
            main_grid.attach (hbox, 1, 5, 3, 1);
            main_grid.attach (custom_help, 4, 5, 1, 1);

            var content = this.get_content_area () as Gtk.Box;
            content.margin = 6;
            content.margin_top = 0;
            content.add (main_grid);

            var close_button = this.add_button (_("Close"), Gtk.ResponseType.CLOSE);
            ((Gtk.Button) close_button).clicked.connect (() => destroy ());
        }

        private class SettingsLabel : Gtk.Label {
            public SettingsLabel (string text) {
                label = text;
                halign = Gtk.Align.END;
                margin_start = 12;
            }
        }

        private class SettingsSwitch : Gtk.Switch {
            public SettingsSwitch (string setting) {
                var main_settings = AppSettings.get_default ();
                halign = Gtk.Align.START;
                main_settings.schema.bind (setting, this, "active", SettingsBindFlags.DEFAULT);
            }
        }
    }
}
