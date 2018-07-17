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
            
            var header = new Granite.HeaderLabel (_("Todo.txt Preferences"));
            var label = new SettingsLabel (_("Default Location:"));
            list_place = new Gtk.ComboBoxText();
            list_place.hexpand = true;
            list_place.append_text("Home Folder");
            list_place.append_text("Dropbox Folder");
            list_place.append_text("Nextcloud Folder");
            list_place.append_text("ownCloud Folder");
            list_place.append_text("Other Clients Folder");
            
            string DS = "%c".printf(GLib.Path.DIR_SEPARATOR);
            
            if (settings.todo_txt_file_path == Environment.get_home_dir() + DS + "todo.txt") {
                list_place.set_active(0);
                list_place.sensitive = true;
                debug ("Set as Home");
            } else if (settings.todo_txt_file_path == Environment.get_home_dir() + DS + "Dropbox" + DS + "todo.txt") {
                list_place.set_active(1);
                list_place.sensitive = true;
                debug ("Set as Dropbox");
            } else if (settings.todo_txt_file_path == Environment.get_home_dir() + DS + "Nextcloud" + DS + "Todo" + DS + "todo.txt") {
                list_place.set_active(2);
                list_place.sensitive = true;
                debug ("Set as Nextcloud");
            } else if (settings.todo_txt_file_path == Environment.get_home_dir() + DS + "ownCloud" + DS + "Todo" + DS + "todo.txt") {
                list_place.set_active(3);
                list_place.sensitive = true;
                debug ("Set as ownCloud");
            } else if (settings.todo_txt_file_path == Environment.get_home_dir() + DS + "bin" + DS + "todo.txt" + DS + "todo.txt") {
                list_place.set_active(4);
                list_place.sensitive = true;
                debug ("Set as Other");
            } else {
                list_place.sensitive = false;
            }
            
            list_place.changed.connect (() => {
                if (list_place.get_active_text () == "Home Folder") {
                    settings.todo_txt_file_path = Environment.get_home_dir() + DS + "todo.txt";
                    list_place.sensitive = true;
                } else if (list_place.get_active_text () == "Dropbox Folder") {
                    settings.todo_txt_file_path = Environment.get_home_dir() + DS + "Dropbox" + DS + "todo.txt";
                    list_place.sensitive = true;
                } else if (list_place.get_active_text () == "Nextcloud Folder") {
                    settings.todo_txt_file_path = Environment.get_home_dir() + DS + "Nextcloud" + DS + "Todo" + DS + "todo.txt";
                    list_place.sensitive = true;
                } else if (list_place.get_active_text () == "ownCloud Folder") {
                    settings.todo_txt_file_path = Environment.get_home_dir() + DS + "ownCloud" + DS + "Todo" + DS + "todo.txt";
                    list_place.sensitive = true;
                } else if (list_place.get_active_text () == "Other Clients Folder") {
                    settings.todo_txt_file_path = Environment.get_home_dir() + DS + "bin" + DS + "todo.txt" + DS + "todo.txt";
                    list_place.sensitive = true;
                } else {
                    list_place.sensitive = false;
                }
            });
            
            var label_c = new SettingsLabel (_("Custom Location:"));
            var switch_c = new SettingsSwitch ("custom-file-enable");
            var chooser = new Gtk.FileChooserButton ("Open your file", Gtk.FileChooserAction.OPEN);
            chooser.hexpand = true;
            
            var custom_help = new Gtk.Image.from_icon_name ("help-info-symbolic", Gtk.IconSize.BUTTON);
            custom_help.halign = Gtk.Align.START;
            custom_help.hexpand = true;
            custom_help.tooltip_text = _("Enabling custom locations will have you save your file\nin other places not recognized by other clients.");
            
            var filter = new Gtk.FileFilter ();
            chooser.set_filter (filter);
            filter.add_mime_type ("todo.txt");
            
            chooser.selection_changed.connect (() => {
                string uris = chooser.get_filename ();
                settings.todo_txt_file_path = uris;
            });
            
            switch_c.notify["active"].connect (() => {
                if (settings.custom_file_enable == true) {
                    chooser.sensitive = true;
                    switch_c.active = true;
                } else {
                    chooser.sensitive = false;
                    switch_c.active = false;
                }
            });
            
            if (settings.custom_file_enable == true) {
                chooser.sensitive = true;
                switch_c.active = true;
            } else {
                chooser.sensitive = false;
                switch_c.active = false;
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
            main_grid.attach (list_place, 1, 2, 3, 1);
            main_grid.attach (label_c, 0, 3, 1, 1);
            main_grid.attach (hbox, 1, 3, 3, 1);
            main_grid.attach (custom_help, 4, 3, 1, 1);
            
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
