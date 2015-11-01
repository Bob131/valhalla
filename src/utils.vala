extern int flock(int fd, int operation);
extern const int LOCK_SH;
extern const int LOCK_EX;
extern const int LOCK_UN;
extern const int LOCK_NB;

namespace utils {
    public errordomain WriteError {
        RESERVED_FILENAME
    }


    class Database : Object {
        private Sqlite.Database db;
        private Sqlite.Statement* stmt;

        construct {
            var db_name = "files";
            if (settings_section != "default")
                db_name += "_" + (!) settings_section;
            db_name += ".db";

            Sqlite.Database.open_v2(utils.config.path(db_name), out db);
            db.exec("""CREATE TABLE IF NOT EXISTS Files (
                        date STRING DEFAULT CURRENT_TIMESTAMP,
                        checksum STRING,
                        local_filename STRING,
                        remote_filename STRING UNIQUE NOT NULL ON CONFLICT FAIL);""");
        }

        public HashTable<string, string>[]? exec(string query, string?[] args = {})
            requires (db.prepare_v2(query, query.length, out stmt) == Sqlite.OK)
        {
            for (var i=0;i<args.length;i++) {
                stmt->bind_text(i+1, args[i]);
            }

            HashTable<string, string>[] r = {};
            var columns = stmt->column_count();
            while (stmt->step() == Sqlite.ROW) {
                var hs = new HashTable<string, string>(str_hash, str_equal);
                for (var i=0;i<columns;i++) {
                    if (stmt->column_text(i) != null && stmt->column_text(i) != "") {
                        hs.insert(stmt->column_name(i), (!) stmt->column_text(i));
                    }
                }
                r += hs;
            }

            delete stmt; // clean up for next run

            if (r.length == 0) {
                return null;
            }
            return r;
        }

        public bool contains(string needle) {
            var test = exec("SELECT * FROM Files WHERE remote_filename = $FN", {needle});
            if (test == null) {
                return false;
            }
            return true;
        }
    }


    class Mount : Object {
        public string location;
        private string unmount_cmd;
        private string lock_location;
        private int lock_fd;

        private void take_shared_flock() {
            if (flock(lock_fd, LOCK_SH) == -1) {
                stderr.printf(@"Fatal error acquiring mount lock: $(strerror(errno))");
                Posix.exit(1);
            }
        }

        construct {
            _mount_instantiated = true;

            this.unmount_cmd = settings.get_string("unmount-command");
            this.location = Path.build_filename(Environment.get_tmp_dir(), "valhalla_temp_mount");

            // set up mount lock
            this.lock_location = Path.build_filename(Environment.get_tmp_dir(), "valhalla_lock");
            this.lock_fd = Posix.open(lock_location, Posix.O_RDONLY|Posix.O_CREAT, 0600);

            // is the mount already set up?
            if (flock(lock_fd, LOCK_EX|LOCK_NB) == -1 && unmount_cmd != "") {
                // take lock anyway
                take_shared_flock();
                return;
            }

            // reset lock
            take_shared_flock();

            utils.ui.put_text("Mounting remote filesystem");

            bool waiting_on_cmd;
            Thread<void*> t;
            if (utils.ui.is_gtk()) {
                waiting_on_cmd = true;
                ThreadFunc<void*> pulse = () => {
                    while (waiting_on_cmd) {
                        utils.ui.put_text(null);
                        Thread.usleep(500000);
                    }
                };
                t = new Thread<void*>(null, pulse);
            }

            Posix.mkdir(location, 0700);
            var cmd = settings.get_string("mount-command").replace("$f", location);
            var p = new Subprocess.newv({"/bin/sh", "-c", cmd}, SubprocessFlags.INHERIT_FDS);
            p.wait();

            if (utils.ui.is_gtk()) {
                waiting_on_cmd = false;
                t.join();
            }

            utils.ui.put_text("Updating local file index ");
            Dir dir;
            try {
                dir = Dir.open(location);
            } catch (Error e) {
                return;
            }
            string? _name;
            string[] names = {};
            while ((_name = dir.read_name()) != null) {
                var full_path = Path.build_filename(location, _name);
                if (FileUtils.test(full_path, FileTest.IS_DIR|FileTest.IS_SYMLINK)) {
                    continue;
                }
                names += (!) _name;
            }
            for (var i=0;i<names.length;i++) {
                var name = names[i];
                if (!(database->contains(name))) {
                    string? cs = name.split(".")[0];
                    if (/[0-9a-f]{8}/.match((!) cs)) {
                        // assume it's one of our files and we know its checksum
                    } else {
                        // otherwise reset
                        cs = null;
                    }
                    if (settings.get_boolean("track-remote")) {
                        var full_path = Path.build_filename(location, name);
                        try {
                            cs = utils.files.get_checksum(File.new_for_path(full_path));
                        } catch (Error e) {
                            continue;
                        }
                    }
                    database->exec("INSERT INTO Files (checksum, remote_filename) VALUES ($cs, $rf)", {cs, name});
                    utils.ui.put_text(@"Updating local file index ($(i)/$(names.length))");
                }
            }
            foreach (var record in database->exec("SELECT * FROM Files")) {
                if (!(record.get("remote_filename") in names)) {
                    database->exec("DELETE FROM Files WHERE remote_filename = $FN", {record.get("remote_filename")});
                }
            }

            // clear line
            stderr.printf("%c[2K\r", 27);
        }

        ~Mount() {
            // attempt to acquire exclusive lock
            if (flock(lock_fd, LOCK_EX|LOCK_NB) == 0 && unmount_cmd != "") {
                // unmount and clean up
                new Subprocess.newv({"/bin/sh", "-c", unmount_cmd.replace("$f", location)},
                        SubprocessFlags.INHERIT_FDS).wait();
                Posix.rmdir(location);

                // release lock
                flock(lock_fd, LOCK_UN);
                Posix.close(lock_fd);
            } else {
                // release lock without delete
                flock(lock_fd, LOCK_UN);
            }
        }
    }


    public string? checksum_from_arg(owned string arg) {
        var file = File.new_for_commandline_arg(arg);
        try {
            arg = utils.files.get_checksum(file);
        } catch (Error e) {}
        if (arg.length == 8 || (arg.length == 10 && arg[0:2] == "0x")) {
            if (arg.length == 10) {
                arg = arg[2:arg.length];
            }
            return arg;
        }
        return null;
    }


    public void delete_file(string filename) {
        if (!_mount_instantiated) {
            mount = new Mount();
        }
        database->exec("DELETE FROM Files WHERE remote_filename = $FN", {filename});
        File.new_for_path(Path.build_filename(mount->location, filename)).delete();
    }


    public string? upload_file(File file) throws WriteError
        requires(file.get_basename() != null)
    {
        string cs;
        try {
            cs = utils.files.get_checksum(file);
        } catch (Error e) {
            return null;
        }
        var dest_filename = settings.get_string("naming-scheme").replace("$c", cs);
        dest_filename = dest_filename.replace("$f", (!) file.get_basename());
        dest_filename = dest_filename.replace("$e", utils.files.get_extension(file));
        dest_filename = Time.gm(time_t()).format(dest_filename);

        mount = new Mount();

        if (!utils.ui.is_gtk()) {
            HashTable<string, string>[]? results;
            bool? all_go_for_launch = null;
            // check for duplicates
            if ((results = database->exec("SELECT * FROM Files WHERE checksum = $CS", {cs})) != null) {
                all_go_for_launch = utils.ui.overwrite_prompt("Duplicate file detected!", results, "Continue?");
            }
            // check for collisions
            if ((results = database->exec("SELECT * FROM Files WHERE remote_filename = $RF", {dest_filename})) != null &&
                    all_go_for_launch == null) {
                all_go_for_launch = utils.ui.overwrite_prompt("Filename collision detected!", results, "Overwrite?");
            }
            if (all_go_for_launch == false) {
                return null;
            }
        }

        utils.ui.BaseProgress meter;
        if (utils.ui.is_gtk()) {
            meter = new utils.ui.gtk_progress();
        } else {
            meter = new utils.ui.progress((!) file.get_basename());
        }
        meter.update();
        file.copy(File.new_for_path(Path.build_filename(mount->location, dest_filename)),
                FileCopyFlags.OVERWRITE|FileCopyFlags.NOFOLLOW_SYMLINKS, null, (current, total) => {
            meter.update(current, total);
        });
        FileUtils.chmod(Path.build_filename(mount->location, dest_filename), 0644);
        meter.clear();

        database->exec("DELETE FROM Files WHERE remote_filename = $FN", {dest_filename});
        database->exec("""INSERT INTO Files (checksum, local_filename, remote_filename)
                            VALUES ($cs, $lf, $rf);""", {cs, file.get_basename(), dest_filename});

        var url = settings.get_string("serve-url");
        if (url[url.length] != '/') {
            url += "/";
        }
        return @"$(url)$(dest_filename)";
    }


    public async string? upload_file_async(File file) {
        string? output = null;
        SourceFunc cb = upload_file_async.callback;
        ThreadFunc<void*> run = () => {
            output = upload_file(file);
            Idle.add((owned) cb);
            return null;
        };
        new Thread<void*>(null, run);
        yield;
        return output;
    }
}
