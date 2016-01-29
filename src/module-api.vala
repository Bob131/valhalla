private const string[] mimetype_locations = {"/etc/mime.types", "/etc/apache2/mime.types"};

namespace Valhalla {
    public errordomain Error {
        MODULE_ERROR, CANCELLED, INVALID_REMOTE_PATH, NOT_IMPLEMENTED;
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
        // don't try to catch errors from this function; it's mainly for signalling
        // the upload() invoker
        public abstract void set_remote_path(string path) throws Error;
        public abstract signal void progress(uint64 bytes_uploaded);
        // must be called from module to commit the file to the database
        public abstract signal void completed();

        public virtual string guess_extension() {
            if (file_type.has_prefix("text/"))
                return ".txt";
            var mimetypes = "";
            foreach (var path in mimetype_locations) {
                string tmp;
                FileUtils.get_contents("/etc/mime.types", out tmp);
                mimetypes += tmp;
            }
            foreach (var line in mimetypes.split("\n"))
                if (line.has_prefix(file_type)) {
                    var cols = line.split(" ", 1);
                    if (cols.length < 2)
                        break;
                    return @".$(cols[1].strip())";
                }
            return "." + file_name.reverse().split(".")[0].reverse();
        }

        // created for the convinience of derivative implmentations;
        // module writers should ignore this
        protected virtual void init_for_path(string path) {
            var file = File.new_for_path(path);
            uint8[] tmp;
            file.load_contents(null, out tmp, null);

            file_contents = tmp;
            timestamp = Time.gm(time_t());
            file_name = Path.get_basename(path);
            file_type = ContentType.guess(path, tmp, null);
            cancellable = new Cancellable();
        }
    }

    namespace Config {
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
            public abstract void write(string val);
        }
    }

    namespace Modules {
        public extern const string MODULEDIR;

        [CCode (has_target = false)]
        public delegate Type ModuleRegistrar();

        public interface BaseModule : Object {
            public abstract string name {get;}
            public abstract string pretty_name {get;}
            public abstract string description {get;}
            public abstract Config.Settings settings {set; get;}

            public virtual bool implements_delete {get {return false;}}
            public virtual async void @delete(string remote_path) throws Valhalla.Error {
                throw new Valhalla.Error.NOT_IMPLEMENTED("Delete not implmented");
            }

            public abstract Config.Preference[] build_panel();
            public abstract async void upload(Transfer t) throws Error;
        }
    }
}
