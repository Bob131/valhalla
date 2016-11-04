private const string[] mimetype_locations = {
    "/etc/mime.types",
    "/etc/apache2/mime.types"
};

namespace Valhalla {
    public errordomain TransferError {
        TRANSFER_CANCELLED;
    }

    public interface File : Object {
        public abstract Time timestamp {set; get;}
        public abstract string crc32 {set; get;}
        public abstract string file_type {set; get;}
        public abstract string remote_path {set; get;}

        public string guess_extension() {
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
            return "";
        }
    }

    public interface LocalFile : File {
        public abstract GLib.File file {set; get;}

        public string file_name {get {
            var path = file.get_path();
            return_if_fail(path != null);
            return (!) path;
        }}

        public new string guess_extension() {
            var ret = ((File) this).guess_extension();
            if (ret.length == 0 && "." in file_name)
                return "." + file_name.reverse().split(".")[0].reverse();
            return ret;
        }
    }

    public interface Transfer : Object {
        public abstract LocalFile file {protected set; get;}
        public abstract Cancellable cancellable {protected set; get;}
        public abstract uint64 bytes_uploaded {set; get;}

        public signal void completed();

    }

    public interface Preference : Object {
        public virtual string? pretty_name {get {return null;}}
        public virtual string? help_text {get {return null;}}
        public virtual string? @default {get {return null;}}

        // returns null if pref has not been set and no default is provided
        public abstract string? @value {set; get;}
    }

    public abstract class Uploader : Object {
        public abstract string pretty_name {get;}
        public abstract string description {get;}

        public abstract async void upload(Transfer t) throws Error;

        private Gee.HashSet<Preference> _prefs =
            new Gee.HashSet<Preference>();
        public Gee.Set<Preference> preferences {owned get {
            return _prefs.read_only_view;
        }}
        protected Preference register_preference(Type type) {
            assert (type.is_a(typeof(Preference)));
            var pref = (Preference) Object.new(type);
            _prefs.add(pref);
            return pref;
        }
    }

    public interface Deleter : Uploader {
        public abstract async void @delete(File file) throws Error;
    }
}
