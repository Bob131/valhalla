// changes between file list and file details
class ListDetailStack : Gtk.Stack {
    public FileList list {private set; get;}
    public DetailsStack details {private set; get;}

    public void file_activated(RemoteFile file) {
        this.set_visible_child_full("details",
            Gtk.StackTransitionType.SLIDE_LEFT);
        details.display_file(file);
    }

    public void display_list() {
        this.set_visible_child_full("list",
            Gtk.StackTransitionType.SLIDE_RIGHT);
    }

    construct {
        list = new FileList();
        details = new DetailsStack();

        this.add_named(list, "list");
        this.add_named(details, "details");

        this.visible_child = list;
        this.show_all();

        get_app().database.committed.connect(() => {
            display_list();
            Timeout.add(this.transition_duration, () => {
                foreach (var child in details.get_children())
                    child.destroy();
                return false;
            });
        });
    }
}
