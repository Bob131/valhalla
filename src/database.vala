namespace Valhalla.Database {
    public class RemoteFile : Object {
        public Time? timestamp {set; get; default=null;}
        public string? crc32 {set; get; default=null;}
        public string? local_filename {set; get; default=null;}
        public string? file_type {set; get; default=null;}
        public uint64? file_size {set; get; default=null;}
        public string remote_path {set; get;}
        public string? module_name {set; get; default=null;}

        private Modules.BaseModule? _module;
        private bool _module_set = false;
        public Modules.BaseModule? module {get {
            if (!_module_set)
                _module = Modules.get_module(module_name);
            _module_set = true;
            return _module;
        }}

        private Database db;
        private int index;
        public RemoteFile? prev {get {
            var real_index = db.files.length - index - 1;
            if (real_index == 0)
                return null;
            return db.files[real_index-1];
        }}
        public RemoteFile? next {get {
            var real_index = db.files.length - index - 1;
            if (real_index == db.files.length-1)
                return null;
            return db.files[real_index+1];
        }}

        public signal void remove_from_database();

        public RemoteFile.build_from_statement(Database parent,
                                               Sqlite.Statement stmt,
                                               int index) {
            Object();
            this.db = parent;
            this.index = index;
            for (var i = 0; i < stmt.column_count(); i++) {
                var col = stmt.column_name(i);
                var val = stmt.column_text(i);
                if (val == null)
                    continue;
                if (col == "timestamp")
                    this.timestamp = Time.gm((time_t) uint64.parse(val));
                else if (col == "file_size")
                    this.file_size = uint64.parse(val);
                else
                    this[col] = val;
            }
        }
    }

    public class Database : Object {
        private Array<RemoteFile>? files_cache = null;
        public RemoteFile[] files {get{
            if (files_cache == null)
                query(false);
            return files_cache.data;
        }}

        private Sqlite.Database db;

        private string db_path {owned get {
            return Path.build_filename(Config.config_directory(), "files.db");
        }}

        public bool unique_url(string url) {
            Sqlite.Statement stmt;
            db.prepare_v2("SELECT * FROM Files WHERE remote_path = $remote_path"
                , -1, out stmt);
            stmt.bind_text(stmt.bind_parameter_index("$remote_path"), url);
            return stmt.step() == Sqlite.DONE;
        }

        public bool unique_hash(string crc32) {
            Sqlite.Statement stmt;
            db.prepare_v2("SELECT * FROM Files WHERE crc32 = $crc32", -1,
                out stmt);
            stmt.bind_text(stmt.bind_parameter_index("$crc32"), crc32);
            return stmt.step() == Sqlite.DONE;
        }

        public RemoteFile[] query(bool args = false, ...) {
            var files = new Array<RemoteFile>();
            Sqlite.Statement stmt;
            var sql = "SELECT * FROM Files";
            var col_args = new Gee.HashMap<string, string>();
            var va = va_list();
            while (args) {
                string? column = va.arg();
                if (column == null)
                    break;
                assert (!(@" $column " in sql));
                if ("WHERE" in sql)
                    sql += " AND ";
                else
                    sql += " WHERE ";
                sql += "%s = $%s".printf(column, column);
                col_args[column] = va.arg();
            }
            db.prepare_v2(sql, -1, out stmt);
            col_args.foreach((entry) => {
                stmt.bind_text(stmt.bind_parameter_index("$"+entry.key),
                    entry.value);
                return true;
            });
            for (var i = 0; stmt.step() == Sqlite.ROW; i++) {
                var file = new RemoteFile.build_from_statement(this, stmt, i);
                file.remove_from_database.connect(() => {delete_file(file);});
                files.prepend_val(file); // prepend so that they're sorted by
                                         // ascending age
            }
            if (!args)
                files_cache = files;
            return files.data;
        }

        public signal void committed();

        private void delete_file(RemoteFile file) {
            Thumbnailer.delete_thumbnail(file);
            Sqlite.Statement stmt;
            db.prepare_v2("DELETE FROM Files WHERE remote_path = $remote_path",
                -1, out stmt);
            stmt.bind_text(stmt.bind_parameter_index("$remote_path"),
                file.remote_path);
            assert (stmt.step() == Sqlite.DONE);
        }

        public void commit_transfer(Widgets.TransferWidget file) {
            Sqlite.Statement stmt;
            db.prepare_v2("""INSERT OR REPLACE INTO Files
                                (timestamp, crc32, local_filename, file_type,
                                 file_size, remote_path, module_name)
                             VALUES ($timestamp, $crc32, $local_filename,
                                     $file_type, $file_size, $remote_path,
                                     $module_name)""", -1, out stmt);
            stmt.bind_text(stmt.bind_parameter_index("$timestamp"),
                ((uint64) file.timestamp.mktime()).to_string());
            stmt.bind_text(stmt.bind_parameter_index("$crc32"), file.crc32);
            stmt.bind_text(stmt.bind_parameter_index("$local_filename"),
                file.local_filename);
            stmt.bind_text(stmt.bind_parameter_index("$file_type"),
                file.file_type);
            stmt.bind_text(stmt.bind_parameter_index("$file_size"),
                file.file_size.to_string());
            stmt.bind_text(stmt.bind_parameter_index("$remote_path"),
                file.remote_path);
            stmt.bind_text(stmt.bind_parameter_index("$module_name"),
                file.module_name);
            assert (stmt.step() == Sqlite.DONE);
        }

        construct {
            assert (Sqlite.Database.open(db_path, out db) == Sqlite.OK);
            db.exec("""CREATE TABLE IF NOT EXISTS Files (
                            timestamp STRING DEFAULT CURRENT_TIMESTAMP,
                            crc32 STRING,
                            local_filename STRING,
                            file_type STRING,
                            file_size STRING,
                            remote_path STRING UNIQUE NOT NULL ON CONFLICT FAIL,
                            module_name STRING);""");
            db.commit_hook(() => {
                files_cache = null;
                committed();
            });
        }
    }
}
