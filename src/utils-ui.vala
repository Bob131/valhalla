namespace utils.ui {
    public bool is_gtk() {
        return Application.get_default() is Gtk.Application;
    }


    public string prompt(string text, string? default_value = null) {
        var resp = Readline.readline(text);
        if (resp == "" || resp == null) {
            if (default_value == null) {
                return prompt(text);
            } else {
                return (!) default_value;
            }
        }
        return (!) resp;
    }


    public bool confirm(string que = "Are you sure?", bool default_answer = false) { // true for yes, false for no
        string def;
        string text;
        if (default_answer) {
            def = "y";
            text = "%s [Y/n]: ".printf(que);
        } else {
            def = "n";
            text = "%s [y/N]: ".printf(que);
        }
        var resp = prompt(text, def).down();
        if (resp == "y" || resp == "yes") {
            return true;
        } else {
            return false;
        }
    }


    // TODO: Remove potential null-dereference
    private Gtk.ProgressBar get_progressbar()
        requires (is_gtk())
    {
        var app = (!) (Application.get_default() as Gtk.Application);
        var notebook = (!) (app.active_window.get_child() as Gtk.Notebook);
        var box = (!) (notebook.get_nth_page(1) as Gtk.Box);
        return (!) (box.get_children().nth_data(0) as Gtk.ProgressBar);
    }


    public void put_text(string? text) {
        if (is_gtk()) {
            var pg = get_progressbar();
            if (text != null) {
                pg.text = (!) text;
            }
            pg.pulse();
        } else {
            if (text != null) {
                stderr.printf(@"$((!) text)\r");
            }
        }
    }


    abstract class BaseProgress {
        public abstract void update(int64 current = 0, int64 total = 1);
        public abstract void clear();
    }


    class gtk_progress : BaseProgress {
        private Gtk.ProgressBar progress;

        public gtk_progress() {
            this.progress = get_progressbar();
        }

        public override void update(int64 current = 0, int64 total = 1) {
            double percent = current/(float)total;
            this.progress.set_fraction(percent);
            this.progress.text = @"$(Math.floor(percent*100))%";
        }

        public override void clear() {
            this.progress.set_fraction(1);
            this.progress.text = "Complete!";
        }
    }


    class progress : BaseProgress {
        private int screen_width;
        private string filename;
        extern int get_width();


        public progress(string name) {
            filename = pad(name, 35, 2);
            screen_width = get_width();
        }

        private string truncate(owned string input, int max_length, bool ellipse = true) {
            if (ellipse) {
                var true_max = max_length - 3;
                if (true_max < 1) {
                    true_max = max_length;
                }

                if (input.length > true_max) {
                    input = input[0:true_max] + "...";
                }
            } else {
                if (input.length > max_length) {
                    input = input[0:max_length];
                }
            }

            return input;
        }

        private string pad(string input, int length, int alt_pad_length = 0, bool justify_left = true, bool ellipse = true) {
            var formatted = truncate(input, length - alt_pad_length, ellipse);

            var alt_padding = "";
            while (alt_padding.length < alt_pad_length) {
                alt_padding += " ";
            }
            if (justify_left) {
                formatted = alt_padding + formatted;
            } else {
                formatted += alt_padding;
            }

            if (formatted.length < length) {
                if (justify_left) {
                    while (formatted.length < length) {
                        formatted += " ";
                    }
                } else {
                    while (formatted.length < length) {
                        formatted = " " + formatted;
                    }
                }
            }

            return formatted;
        }

        public override void update(int64 current = 0, int64 total = 1) {
            if (isatty()) {
                double percent = Math.floor(current/(float)total*100);
                if (percent > 100) {
                    percent = 100;
                }

                // the figure 50 is to allow for the following:
                // - 4 characters of padding between elements
                // - the header and footer of the percentage bar (ie [])
                // - 4 characters for a 3 digit percentage and the % sign
                // - 35 character filename + 5 char spacing
                float percent_bar_width = screen_width - 50;

                string percent_bar;
                string percent_string = percent.to_string();

                string percent_bar_completed = "";
                var percent_bar_completed_width = Math.floor(percent * percent_bar_width / 100);

                for (var i = 0; i<percent_bar_completed_width; i++) {
                    percent_bar_completed += "=";
                }

                string percent_bar_padding = "";
                if (percent_bar_completed_width != percent_bar_width) {
                    percent_bar_padding = ">";
                }
                for (var i = 0; i<(percent_bar_width - percent_bar_completed_width - 1); i++) {
                    percent_bar_padding += " ";
                }

                percent_bar = percent_bar_completed + percent_bar_padding;

                while (percent_string.length < 3) {
                    percent_string = " " + percent_string;
                }
                percent_string += "%";

                percent_bar = "[" + percent_bar + "]";

                stderr.printf(@" $(percent_bar) $(percent_string) $(filename)\r");
            }
        }

        public override void clear() {
            string whitespace = "";
            while (whitespace.length < screen_width) {
                whitespace += " ";
            }
            stderr.printf(@"$(whitespace)\r");
        }
    }


    public bool isatty() {
        return Posix.isatty(stdin.fileno());
    }


    public bool overwrite_prompt(string message, HashTable<string, string>[] data, string? prompt = null) {
        stderr.printf(@"$(message)\n");

        int max_width = 0;
        string output = "";
        data[0].foreach((_key, val) => {
            var key = _key.replace("_", " ");
            key = "%s%s".printf(key.up(1), key.slice(1, key.length));
            var tabs = "\t";
            if (key.length < 15) {
                tabs += "\t";
            }
            if (key.length < 7) {
                tabs += "\t";
            }
            var line = "%s:%s%s\n".printf(key, tabs, val);
            int this_width;
            if ((this_width = line.replace("\t", "        ").length) > max_width) {
                max_width = this_width;
            }
            output += line;
        });

        var stiples = "";
        while (stiples.length < max_width) {
            stiples += "-";
        }

        stderr.printf(@"$(stiples)\n");
        stdout.printf(output);
        stderr.printf(@"$(stiples)\n");
        if (data.length > 1) {
            stderr.printf(@"[$(data.length-1) additional results omitted]\n");
        }

        if (prompt != null) {
            return confirm((!) prompt);
        }
        return true; // the TRUE-ly superior choice c:
    }
}
