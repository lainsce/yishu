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
using Gee;

namespace Yishu {
	public class TodoFile : GLib.Object {
		public string path;
		private GLib.File file;
		public DataInputStream input_stream;
		public DataOutputStream ouput_stream;
		public Gee.ArrayList<string> lines;
		public FileMonitor monitor;
		public int n_lines;

		public TodoFile (string path) {
			this.path = path;
			this.file = File.new_for_path(path);
			lines = new ArrayList<string> ();
			try {
				monitor = this.file.monitor(FileMonitorFlags.NONE, null);
			}
			catch (Error e){
				warning ("%s\n", e.message);
			}
		}

		public bool exists(){
			try {
				var stream = file.read();
				stream.close();
			}
			catch (Error e){
				return false;
			}
			return true;
		}

		public int read_file(){
			lines.clear();
			n_lines = 0;

			try {
				var input_stream = new DataInputStream(file.read());
				string line;
				while ((line = input_stream.read_line()) != null){
					lines.add(line);
					n_lines++;
				}
				input_stream.close();
			}
			catch (Error e){
				warning ("%s\n", e.message);
				return -1;
			}
			return n_lines;
		}

		public bool write_file(){
			try {
				n_lines = 0;
				var iostream = file.replace_readwrite(null, false, FileCreateFlags.NONE);
				var output_stream = new DataOutputStream(iostream.output_stream);
				foreach (string line in lines){
					output_stream.put_string(line + "\n");
					n_lines++;
				}
				output_stream.close();
				monitor = this.file.monitor(FileMonitorFlags.NONE, null);
			}
			catch (Error e){
				warning ("%s\n", e.message);
				return false;
			}
			return true;
		}

		public void delete_file () {
			try {
				if (exists () == true)
					file.delete ();
			} catch (Error e){
				warning ("%s\n", e.message);
			}
		}
	}

}
