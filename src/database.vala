namespace Valhalla.Database {
    public class RemoteFile : Object {
        public Time timestamp {set; get;}
        public string crc32 {set; get;}
        public string local_filename {set; get;}
        public string file_type {set; get;}
        public string remote_path {set; get;}
        public string module_name {set; get;}

        private Modules.BaseModule? _module;
        private bool _module_set = false;
        public Modules.BaseModule? module {get {
            if (!_module_set)
                _module = Modules.get_module(module_name);
            _module_set = true;
            return _module;
        }}

        public signal void remove_from_database();
    }

    public class Database : Object {
        private Sqlite.Database db;

        private string db_path {owned get {
            return Path.build_filename(Config.config_directory(), "files.db");
        }}

        public signal void committed();

        private void delete_file(RemoteFile file) {
            Thumbnailer.delete_thumbnail(file);
            Sqlite.Statement stmt;
            db.prepare_v2("DELETE FROM Files WHERE remote_path = $remote_path", -1, out stmt);
            stmt.bind_text(stmt.bind_parameter_index("$remote_path"), file.remote_path);
            assert (stmt.step() == Sqlite.DONE);
        }

        private RemoteFile? build_file(Sqlite.Statement stmt) {
            RemoteFile? result = null;
            for (var i = 0; i < stmt.column_count(); i++) {
                var col = stmt.column_name(i);
                var val = stmt.column_text(i);
                if (val == null)
                    continue;
                if (result == null)
                    result = new RemoteFile();
                if (col == "timestamp")
                    result.timestamp = Time.gm((time_t) uint64.parse(val));
                else
                    result[col] = val;
            }
            if (result != null)
                result.remove_from_database.connect(() => {
                    delete_file(result);
                });
            return result;
        }

        public bool unique_url(string url) {
            Sqlite.Statement stmt;
            db.prepare_v2("SELECT * FROM Files WHERE remote_path = $remote_path", -1, out stmt);
            stmt.bind_text(stmt.bind_parameter_index("$remote_path"), url);
            stmt.step();
            return build_file(stmt) == null;
        }

        public bool unique_hash(string crc32) {
            Sqlite.Statement stmt;
            db.prepare_v2("SELECT * FROM Files WHERE crc32 = $crc32", -1, out stmt);
            stmt.bind_text(stmt.bind_parameter_index("$crc32"), crc32);
            stmt.step();
            return build_file(stmt) == null;
        }

        public RemoteFile[] get_files() {
            RemoteFile[] files = {};
            Sqlite.Statement stmt;
            db.prepare_v2("SELECT * FROM Files", -1, out stmt);
            while (stmt.step() == Sqlite.ROW) {
                var file = build_file(stmt);
                if (file != null)
                    files += file;
            }
            return files;
        }

        public void commit_transfer(Widgets.TransferWidget file) {
            Sqlite.Statement stmt;
            db.prepare_v2("""INSERT OR REPLACE INTO Files
                                (timestamp, crc32, local_filename, file_type,
                                 remote_path, module_name)
                             VALUES ($timestamp, $crc32, $local_filename, $file_type,
                                     $remote_path, $module_name)""", -1, out stmt);
            stmt.bind_text(stmt.bind_parameter_index("$timestamp"),
                ((uint64) file.timestamp.mktime()).to_string());
            stmt.bind_text(stmt.bind_parameter_index("$crc32"), file.crc32);
            stmt.bind_text(stmt.bind_parameter_index("$local_filename"), file.local_filename);
            stmt.bind_text(stmt.bind_parameter_index("$file_type"), file.file_type);
            stmt.bind_text(stmt.bind_parameter_index("$remote_path"), file.remote_path);
            stmt.bind_text(stmt.bind_parameter_index("$module_name"), file.module_name);
            assert (stmt.step() == Sqlite.DONE);
        }

        construct {
            assert (Sqlite.Database.open(db_path, out db) == Sqlite.OK);
            db.exec("""CREATE TABLE IF NOT EXISTS Files (
                            timestamp STRING DEFAULT CURRENT_TIMESTAMP,
                            crc32 STRING,
                            local_filename STRING,
                            file_type STRING,
                            remote_path STRING UNIQUE NOT NULL ON CONFLICT FAIL,
                            module_name STRING);""");
            db.commit_hook(() => {
                committed();
            });
        }
    }
}