private const string[] mimetype_locations = {
    "/etc/mime.types",
    "/etc/apache2/mime.types"
};

namespace Valhalla {
    namespace Data {
        public errordomain Error {
            TRANSFER_CANCELLED, INVALID_REMOTE_PATH;
        }

        public abstract class BaseFile : Object {
            public abstract Time? timestamp {protected set; get;}
            public abstract string? crc32 {protected set; get;}
            public abstract string file_type {protected set; get;}
            public abstract string remote_path {get;}
        }

        // timestamp & crc32 guaranteed to be non-null
        public interface TransferFile : BaseFile {
            public abstract string file_name {protected set; get;}
            public abstract uint8[] file_contents {protected set; get;}

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

        public interface Transfer : Object {
            public abstract TransferFile file {protected set; get;}
            public abstract Cancellable cancellable {protected set; get;}

            // must be called from the module, sets the URL from which the
            // uploaded file can be found        //
            // modules should return on error
            public abstract void set_remote_path(string path) throws Error;
            public abstract signal void progress(uint64 bytes_uploaded);
            // must be called from module to commit the file to the database
            public abstract signal void completed();

        }
    }

    namespace Preferences {
        public interface Preference : Object {
            public virtual string? pretty_name {get {return null;}}
            public virtual string? help_text {get {return null;}}
            public virtual string? @default {get {return null;}}

            // returns null if pref has not been set and no default is provided
            public abstract string? @value {set; get;}
        }

        public interface Context : Object {
            public abstract void register_preference(Type type);
            public abstract Preference @get(Type type);
        }
    }

    namespace Modules {
        public errordomain Error {
            GENERIC_ERROR, NOT_IMPLEMENTED;
        }

        [CCode (has_target = false)]
        public delegate Type ModuleRegistrar();
        [CCode (has_target = false)]
        public delegate Type[] PrefRegistrar();

        public interface BaseModule : Object {
            public abstract string pretty_name {get;}
            public abstract string description {get;}

            public virtual bool implements_delete {get {return false;}}
            public virtual async void @delete(string remote_path) throws Error {
                throw new Error.NOT_IMPLEMENTED("Delete not implmented");
            }

            public abstract async void upload(Data.Transfer t) throws Error;
        }
    }
}
