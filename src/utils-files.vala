namespace utils.files {
    public string get_checksum(File file) throws Error {
        var stream = file.read();
        ulong adler = 1;
        int done;
        while (true) {
            uint8 buffer[1024];
            done = (int)stream.read(buffer);
            if (done == 0) {
                break;
            }
            adler = ZLib.Utility.adler32(adler, buffer[0:done]);
        }
        return "%08x".printf((uint) adler);
    }


    public File make_temp(owned string extension = "") {
        if (extension != "") {
            extension = "." + extension;
        }
        var now = Time.local(time_t());
        var filepath = now.format(settings.get_string("temp-names") + extension);
        filepath = @"$(Environment.get_tmp_dir())/$(filepath)";
        return File.new_for_path(filepath);
    }


    private HashTable<string, string>? _mimetypes;
    public string get_extension(File input) throws Error
        requires(input.get_path() != null)
    {
        if (_mimetypes == null) {
            _mimetypes = new HashTable<string, string>(str_hash, str_equal);
            string[] files = {"/etc/mime.types",
                                "/etc/httpd/mime.types"};
            foreach (var file in files) {
                var f = File.new_for_path(file);
                uint8[] data;
                string etag;
                try {
                    f.load_contents(null, out data, out etag);
                } catch (Error e) {
                    continue;
                }
                string contents = (string) data;
                foreach (var line in contents.split("\n")) {
                    if (!("\t" in line)) {
                        continue;
                    }
                    string mime, ext;
                    var d = line.split("\t");
                    mime = d[0];
                    ext = d[d.length-1].strip().split(" ")[0];
                    ((!) _mimetypes).insert(mime, @".$(ext)");
                }
            }
        }

        Regex[] txt_synonyms = {
            /^text\//,
            /[\/\+]xml/,
            /[\/\+]json/,
            /application\/javascript/,
            /message\/rfc822/
        };
        var magic = new LibMagic.Magic(
            LibMagic.Flags.SYMLINK|LibMagic.Flags.MIME_TYPE|LibMagic.Flags.ERROR);
        magic.load();
        var mime = (!) magic.file((!) input.get_path());
        foreach (var regex in txt_synonyms) {
            if (regex.match(mime)) {
                return ".txt";
            }
        }
        var r = ((!) _mimetypes).get(mime);
        return r;
    }
}
