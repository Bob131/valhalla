abstract class Valhalla.RemoteFile : Object, File {
    public Time timestamp {set; get;}
    public string crc32 {set; get;}
    public string file_type {set; get; default="application/octet-stream";}

    public string display_name {set; get;}

    public string remote_path {set; get;}

    public uint64? file_size {set; get;}
    public string? module_name {set; get;}
}

class RemoteFile : Valhalla.RemoteFile {
    public Valhalla.Uploader? module {owned get {
        if (module_name == null)
            return null;
        return get_app().loader[(!) module_name];
    }}

    Database db;
    public int index;

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

    public RemoteFile.build_from_statement(
        Database parent,
        Sqlite.Statement stmt,
        int index)
    {
        db = parent;
        this.index = index;

        for (var i = 0; i < stmt.column_count(); i++) {
            var col = stmt.column_name(i);
            var val = stmt.column_text(i);

            if (val == null)
                continue;

            if (col == "timestamp")
                this.timestamp = Time.gm((time_t) uint64.parse((!) val));
            else if (col == "file_size")
                this.file_size = uint64.parse((!) val);
            else if (col == "remote_path")
                this.remote_path = (!) val;
            else
                this[col] = (!) val;
        }
    }
}

class Database : Object {
    Array<RemoteFile>? files_cache = null;
    public RemoteFile[] files {get {
        if (files_cache == null)
            query(false);
        return ((!) files_cache).data;
    }}

    Sqlite.Database db;

    string db_path {owned get {
        return Path.build_filename(config_directory(), "files.db");
    }}

    public bool unique_hash(string crc32) {
        Sqlite.Statement stmt;
        db.prepare_v2("SELECT * FROM Files WHERE crc32 = $crc32", -1, out stmt);
        stmt.bind_text(stmt.bind_parameter_index("$crc32"), crc32);
        return stmt.step() == Sqlite.DONE;
    }

    public RemoteFile[] query(bool args = false, ...) {
        var sql = "SELECT * FROM Files";
        var col_args = new Gee.HashMap<string, string>();
        var va = va_list();

        while (args) {
            string? _col = va.arg();
            if (_col == null)
                break;
            var column = (!) _col;
            assert (!(@" $column " in sql));
            if ("WHERE" in sql)
                sql += " AND ";
            else
                sql += " WHERE ";
            sql += "%s = $%s".printf(column, column);
            col_args[column] = va.arg();
        }

        var files = new Array<RemoteFile>();
        Sqlite.Statement stmt;

        db.prepare_v2(sql, -1, out stmt);
        col_args.foreach((entry) => {
            stmt.bind_text(stmt.bind_parameter_index("$"+entry.key),
                entry.value);
            return true;
        });

        for (var i = 0; stmt.step() == Sqlite.ROW; i++) {
            var file = new RemoteFile.build_from_statement(this, stmt, i);
            file.remove_from_database.connect(() => @delete(file));
            // prepend to sort by ascending age
            files.prepend_val(file);
        }

        if (!args)
            files_cache = files;

        return files.data;
    }

    public signal void committed();

    void @delete(RemoteFile file) {
        get_app().thumbnailer.delete_thumbnail(file);

        Sqlite.Statement stmt;
        db.prepare_v2("DELETE FROM Files WHERE remote_path = $remote_path", -1,
            out stmt);
        stmt.bind_text(stmt.bind_parameter_index("$remote_path"),
            file.remote_path);
        assert (stmt.step() == Sqlite.DONE);
    }

    public void commit(Valhalla.RemoteFile file) {
        string[] fields = {
            "file_type",
            "display_name",
            "remote_path",
            "timestamp",
            "crc32"
        };

        if (file.file_size != null)
            fields += "file_size";
        if (file.module_name != null)
            fields += "module_name";

        var sql = "INSERT OR REPLACE INTO Files (%s) VALUES (%s)".printf(
            string.joinv(",", (string?[]) fields),
            "$%s".printf(string.joinv(",$", (string?[]) fields)));

        Sqlite.Statement stmt;
        db.prepare_v2(sql, -1, out stmt);

        stmt.bind_text(stmt.bind_parameter_index("$file_type"), file.file_type);
        stmt.bind_text(stmt.bind_parameter_index("$display_name"),
            file.display_name);
        stmt.bind_text(stmt.bind_parameter_index("$remote_path"),
            file.remote_path);

        if ("timestamp" in fields)
            stmt.bind_text(stmt.bind_parameter_index("$timestamp"),
                ((uint64) ((!) file.timestamp).mktime()).to_string());

        if ("crc32" in fields)
            stmt.bind_text(stmt.bind_parameter_index("$crc32"), file.crc32);

        if ("file_size" in fields)
            stmt.bind_text(stmt.bind_parameter_index("$file_size"),
                ((!) file.file_size).to_string());

        if ("module_name" in fields)
            stmt.bind_text(stmt.bind_parameter_index("$module_name"),
                file.module_name);

        assert (stmt.step() == Sqlite.DONE);
    }

    construct {
        assert (Sqlite.Database.open(db_path, out db) == Sqlite.OK);
        db.exec("""CREATE TABLE IF NOT EXISTS Files (
                        timestamp STRING DEFAULT CURRENT_TIMESTAMP,
                        crc32 STRING,
                        display_name STRING,
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
