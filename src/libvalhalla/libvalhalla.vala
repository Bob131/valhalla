private const string[] mimetype_locations = {
    "/etc/mime.types",
    "/etc/apache2/mime.types"
};

namespace Valhalla {
    public errordomain Error {
        CONFIG_ERROR, MODULE_ERROR, CANCELLED, INVALID_REMOTE_PATH,
        NOT_IMPLEMENTED;
    }

    public interface Transfer : Object {
        public abstract Time timestamp {protected set; get;}
        public abstract string crc32 {protected set; get;}
        public abstract string file_name {protected set; get;}
        public abstract uint8[] file_contents {protected set; get;}
        public abstract string file_type {protected set; get;}

        public abstract Cancellable cancellable {protected set; get;}

        // must be called from the module, sets the URL from which the uploaded
        // file can be found        //
        // don't try to catch errors from this function; it's mainly for
        // signalling the upload() invoker
        public abstract void set_remote_path(string path) throws Error;
        public abstract signal void progress(uint64 bytes_uploaded);
        // must be called from module to commit the file to the database
        public abstract signal void completed();

        public virtual string guess_extension() {
            if (file_type.has_prefix("text/"))
                return ".txt";
            var mimetypes = new string[] {};
            foreach (var path in mimetype_locations) {
                string tmp;
                try {
                    FileUtils.get_contents(path, out tmp);
                } catch (FileError e) {
                    continue;
                }
                foreach (var line in tmp.split("\n"))
                    mimetypes += line;
            }
            foreach (var line in mimetypes)
                if (line.has_prefix(file_type)) {
                    var cols = Regex.split_simple("\\s+", line);
                    if (cols.length < 2)
                        break;
                    return @".$(cols[1])";
                }
            if ("." in file_name)
                return "." + file_name.reverse().split(".")[0].reverse();
            return "";
        }
    }

    namespace Config {
        public errordomain Error {
            KEY_NOT_SET;
        }

        public interface Settings : Object {
            public abstract string? @get(string key);
        }

        public interface Preference : Gtk.Widget {
            public abstract string key {get;}
            public virtual string? @default {get {return null;}}
            public virtual string? label {get {return null;}}
            public virtual string? help {get {return null;}}

            public signal void change_notify();

            public abstract string read();
            public abstract void write(string? val);
        }
    }

    namespace Modules {
        private extern const string MODULEDIR;
        public string[] get_paths() {
            return {
                Path.build_filename(Environment.get_user_data_dir(),
                    "valhalla"),
                MODULEDIR
            };
        }

        [CCode (has_target = false)]
        public delegate Type[] ModuleRegistrar();

        public interface BaseModule : Object {
            public abstract string name {get;}
            public abstract string pretty_name {get;}
            public abstract string description {get;}
            public abstract Config.Settings settings {set; get;}

            public virtual bool implements_delete {get {return false;}}
            public virtual async void @delete(string remote_path)
                    throws Valhalla.Error {
                throw new Valhalla.Error.NOT_IMPLEMENTED(
                    "Delete not implmented");
            }

            public abstract Config.Preference[] build_panel();
            public abstract async void upload(Transfer t) throws Error;
        }
    }
}
