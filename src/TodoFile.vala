using Gee;

namespace Td {
	public class TodoFile : GLib.Object {

		private string path;
		private GLib.File file;
		public DataInputStream input_stream;
		public DataOutputStream ouput_stream;
		public ArrayList<string> lines;
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

				//monitor.cancel();

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
	}

}