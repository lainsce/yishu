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

	public class Task : GLib.Object {

		public string priority;
		public string date;
		public string completed_date;
		public string due_date;
		public List<string> projects;
		public List<string> contexts;
		public string text;
		public bool done;

		public TreeIter iter;
		public int linenr;

		construct {
			done = false;
			date = null;
			completed_date = "";
			due_date = "";
			text = "";
			priority = "";
			projects = new List<string>();
			contexts = new List<string>();
		}

		public bool parse_from_string(string s){

			MatchInfo mi;
			string match;
			string match1;
			string str = s;

			projects = new List<string>();
			contexts = new List<string>();

			try {
				var re = new Regex("@[a-zA-Z0-9-_]+");
				while (re.match(str, 0, out mi)){
					match = mi.fetch(0);
					if (match != null){
						contexts.append(match.strip());
						uint start = str.index_of(match);
						str = str.splice(start, start + match.length);
					}
				}
				re = new Regex("\\+[a-zA-Z0-9-_]+");
				while (re.match(str, 0, out mi)){
					match = mi.fetch(0);
					if (match != null){
						projects.append(match.strip());
						uint start = str.index_of(match);
						str = str.splice(start, start + match.length);
					}
				}
				re = new Regex ("^(x )?(\\(([A-Z])\\))?");
				if (re.match(str, 0, out mi)){

					match1 = mi.fetch(1);
					match = mi.fetch(3);
					if (match != null){
						priority = match;
						uint start = str.index_of(match);
						str = str.splice(start-1, start + match.length + 2);
					}

					if (match1 != null && match1 == "x "){
						done = true;
						str = str.splice(0, 2);
					}
				}

				re = new Regex ("[0-9]{4}-[0-9]{2}-[0-9]{2}");
				var n = 0;
				var dates = new List<string>();
				while (re.match(str, 0, out mi)){
					match = mi.fetch(0);
					if (match != null && n < 2){
						dates.append(match);
						uint start = str.index_of(match);
						str = str.splice(start, start+11);
					}
					if (++n == 2){
						break;
					}
				}
				uint length = dates.length();
				switch (length){
					case 1:
						date = dates.nth_data(0);
						break;
					case 2:
						date = dates.nth_data(1);
						completed_date = dates.nth_data(0);
						break;
					default:
						break;
				}

				text = str.strip();
				return (text.length > 0);
			}
			catch (Error e){
				warning("%s", e.message);
				return false;
			}
		}

		public string to_string(){
			string str = "";
			if (this.done){
				str += "x ";
			}
			if (this.priority != null && this.priority.length > 0){
				str += "(%s)".printf(this.priority);
				str += " ";
			}
			if (this.date != null) {
				str += this.date;
				str += " ";
			}
			str += this.text;
			str += " ";
			foreach (string project in this.projects){
				str += project;
				str += " ";
			}
			foreach (string context in this.contexts){
				str += context;
				str += " ";
			}
			return str;
		}

		public void to_model(Gtk.ListStore model, Gtk.TreeIter? iter){

			model.set(
				iter,
				Columns.PRIORITY, this.priority,
				Columns.MARKUP, this.to_markup(),
				Columns.TASK_OBJECT, this,
				Columns.VISIBLE, true,
				Columns.DONE, this.done,
				Columns.LINE_NR, this.linenr
			);

			if (iter != null){
				this.iter = iter;
			}
			else {
				iter = this.iter;
			}
		}

		public string to_markup() {

			string ctx = "";
			foreach (string context in this.contexts){
				ctx += context;
				ctx += " ";
			}
			string prj = "";
			foreach (string project in this.projects){
				prj += project;
				prj += " ";
			}

			string markup = GLib.Markup.printf_escaped(
				"<span size=\"xx-large\" weight=\"light\">%s</span>\t<small><i>%s %s</i></small>\n<small><i><span foreground=\"#555\">%s</span></i></small>",
				this.text,
				prj,
				ctx,
				nice_date(this.date, 0)
			);

			if (this.done)
				markup = "<s>" + markup + "</s>";


			return markup;
		}

		/**
		 * nice_date
		 *
		 * returns a nicely formatted string, telling how many days have passed
		 * since the date_string (Y-m-d), e.g. returns "17 days ago"
		 * If the date is more than max days ago, it will return a locale formatted
		 * string of the date
		 *
		 * @param date_string string 		The Y-m-d formatted date to be processed
		 * @param max_days int optional		If date is more than max_days old, the
		 *									date will be returned as locale formatted
		 *									date string (default=30, pass <= 0 for default)
		 * @return string 					The formatted date as string
		 */
		public string nice_date(string? date_string, int max_days){

			if (date_string == null) {
				return "";
			}

			if (max_days <= 0){
				max_days = 30;
			}

			try {
				MatchInfo match_info;
				var re = new Regex("([0-9]{4})-([0-9]{2})-([0-9]{2})");
				if (re.match(date_string, 0, out match_info)){

					DateYear year =	(DateYear)int.parse(match_info.fetch(1));
					DateMonth month = (DateMonth)int.parse(match_info.fetch(2));
					DateDay day = (DateDay)int.parse(match_info.fetch(3));

					Date d = Date();
					d.set_year(year);
					d.set_month(month);
					d.set_day(day);

					time_t t_now;
					time_t(out t_now);
					Date now = Date();
					now.set_time_t(t_now);

					int diff = d.days_between(now);
					if (diff < max_days){
						string s = "";
						switch (diff){
							case 0:
								s = _("Today");
								break;
							case 1:
								s = _("Yesterday");
								break;
							default:
								s = "%u %s".printf(diff, _("days ago"));
								break;
						}
						return s;
					}
					else {
						char buf[100];
						d.strftime(buf, "%x");
						return (string)buf;
					}
				}
			}
			catch (Error e){
				warning (e.message);
			}
			return date_string;
		}

	}
}
