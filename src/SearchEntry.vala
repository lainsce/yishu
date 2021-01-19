/*
* Copyright (c) 2018 Lains
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
*
* Co-authored by Stanisław <stanislaw.dac@gmail.com>
*/
using Gtk;
using Yishu;
namespace Yishu {
    public class SearchEntry : Gtk.SearchEntry {
        public Gtk.TreeModelFilter filter_model { get; private set; }
        private Gtk.TreeView process_view;

        public SearchEntry (Gtk.TreeView process_view, Gtk.TreeModel model) {
            this.process_view = process_view;
            filter_model = new Gtk.TreeModelFilter (model, null);
            connect_signal ();
            filter_model.set_visible_func(filter_func);
            process_view.set_model (filter_model);

            var sort_model = new Gtk.TreeModelSort.with_model (filter_model);
            process_view.set_model (sort_model);

            var settings = AppSettings.get_default ();
            if (settings.save_search) {
                this.text = settings.saved_search_string;
            } else {
                this.text = "";
            }

            this.show_all ();
        }

        private void connect_signal () {
            this.search_changed.connect (() => {
                if (this.is_focus) {
                    process_view.collapse_all ();
                }

                filter_model.refilter ();

                this.grab_focus ();

                if (this.text != "") {
                    this.insert_at_cursor ("");
                }
            });
        }

        private bool filter_func (Gtk.TreeModel model, Gtk.TreeIter iter) {
            string name_haystack;
            bool found = false;
            var needle = this.text;

            if ( needle.length == 0 ) {
                return true;
            }

            model.get( iter, Columns.MARKUP, out name_haystack, -1 );

            // sometimes name_haystack is null
            if (name_haystack != null) {
                bool name_found = name_haystack.casefold().contains(needle.casefold()) || false;
                found = name_found;
            }


            Gtk.TreeIter child_iter;
            bool child_found = false;

            if (model.iter_children (out child_iter, iter)) {
                do {
                    child_found = filter_func (model, child_iter);
                } while (model.iter_next (ref child_iter) && !child_found);
            }

            if (child_found && needle.length > 0) {
                process_view.expand_all ();
            }

            return found || child_found;
        }

        // reset filter, grab focus and insert the character
        public void activate_entry (string search_text = "") {
            this.text = "";
            this.search_changed ();
            this.insert_at_cursor (search_text);
        }

    }
}
