/* The MIT License (MIT)

Copyright (c) 2015 Ernestas Kulik

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE. */

// adapted from https://git.gnome.org/browse/gnome-screenshot/tree/src/screenshot-area-selection.c

// TODO: give window focus before capture
namespace Valhalla.Screenshot {
    private delegate void Func();


    private class SelectionWindow : Gtk.Window {
        public SelectionWindow() {
            Object(type: Gtk.WindowType.POPUP);
            var screen = Gdk.Screen.get_default();
            if (screen != null) {
                var visual = ((!) screen).get_rgba_visual();
                if (((!) screen).is_composited() && visual != null) {
                    this.app_paintable = true;
                    this.set_visual(visual);
                }
            }
            this.move(-1, -1);
            this.resize(1, 1);
            // Realize after setting the visual, else we'll get an opaque window
            this.visible = true;
        }


        public override bool draw(Cairo.Context cr) {
            if (this.app_paintable) {
                var style_context = get_style_context();
                style_context.add_class(Gtk.STYLE_CLASS_RUBBERBAND);
                style_context.render_background(cr, 0, 0,
                    this.get_allocated_width(), this.get_allocated_height());
                style_context.render_frame(cr, 0, 0, this.get_allocated_width(),
                    this.get_allocated_height());
            }
            return true;
        }
    }


    public Gdk.Pixbuf? take(Gdk.Rectangle area_rectangle) {
        var root_window = Gdk.get_default_root_window();
        return Gdk.pixbuf_get_from_window(root_window, area_rectangle.x,
            area_rectangle.y, area_rectangle.width, area_rectangle.height);
    }


    public Gdk.Pixbuf? take_window_at_point(int x, int y) {
        var screen = Gdk.Screen.get_default();
        if (screen == null)
            return null;
        var window_stack = ((!) screen).get_window_stack();
        if (window_stack == null)
            return null;

        unowned List<weak Gdk.Window> _window_stack = (!) window_stack;
        _window_stack.reverse();

        foreach (var window in _window_stack) {
            Gdk.Rectangle window_rectangle;
            window.get_frame_extents(out window_rectangle);

            var point_rectangle = Gdk.Rectangle();
            point_rectangle.x = x;
            point_rectangle.y = y;
            point_rectangle.width = 1;
            point_rectangle.height = 1;

            if (window_rectangle.intersect(point_rectangle, null))
                if (((!) screen).is_composited())
                    return take(window_rectangle);
                else
                    return Gdk.pixbuf_get_from_window(window, 0, 0,
                        window_rectangle.width, window_rectangle.height);
        }

        return null;
    }

    public async Gdk.Pixbuf? take_interactive() {
        Gdk.Rectangle rectangle = Gdk.Rectangle();
        var selection_window = new SelectionWindow();
        bool selection_mode = false;

        selection_window.button_press_event.connect((event) => {
            if (selection_mode)
                return true;
            rectangle.x = (int)event.x_root;
            rectangle.y = (int)event.y_root;
            selection_mode = true;
            return true;
        });

        selection_window.motion_notify_event.connect((event) => {
            if (!selection_mode)
                return true;

            var draw_rectangle = Gdk.Rectangle();
            draw_rectangle.x = int.min(rectangle.x, (int)event.x_root);
            draw_rectangle.y = int.min(rectangle.y, (int)event.y_root);
            draw_rectangle.width = (rectangle.x - (int)event.x_root).abs();
            draw_rectangle.height = (rectangle.y - (int)event.y_root).abs();

            if (!(draw_rectangle.width > 0) || !(draw_rectangle.height > 0)) {
                selection_window.move(-1, -1);
                selection_window.resize(1, 1);
            } else {
                selection_window.move(draw_rectangle.x, draw_rectangle.y);
                selection_window.resize(draw_rectangle.width,
                    draw_rectangle.height);
            }

            return true;
        });

        var _display = Gdk.Display.get_default();
        if (_display == null)
            return null;
        var display = (!) _display;
        var seat = display.get_default_seat();

        Func clean_up = () => {
            seat.ungrab();
            selection_window.destroy();
        };

        Gdk.Pixbuf? pixbuf = null;

        // set to null to squash 'unassigned local var' error; in reality this
        // should always be callable
        SourceFunc? return_pixbuf = null;
        SourceFunc? timeout = null;
        selection_window.destroy.connect_after(() => {
            Idle.add((!) ((owned) timeout ?? (owned) return_pixbuf));
        });

        selection_window.button_release_event.connect((event) => {
            if (!selection_mode)
                return true;

            rectangle.x = int.min(rectangle.x, (int)event.x_root);
            rectangle.y = int.min(rectangle.y, (int)event.y_root);
            rectangle.width = (rectangle.x - (int)event.x_root).abs();
            rectangle.height = (rectangle.y - (int)event.y_root).abs();

            if ((rectangle.width < 5) || (rectangle.height < 5))
                pixbuf = take_window_at_point(rectangle.x, rectangle.y);
            else
                timeout = () => {
                    // let selection_window finish destruction so we don't
                    // capture it
                    Timeout.add(200, () => {
                        pixbuf = take(rectangle);
                        Idle.add((!)(owned) return_pixbuf);
                        return false;
                    });
                    return false;
                };

            clean_up();

            return true;
        });

        selection_window.key_press_event.connect((event) => {
            if (event.keyval == Gdk.Key.Escape) {
                clean_up();
            }
            return true;
        });

        var res = seat.grab((!) selection_window.get_window(),
            Gdk.SeatCapabilities.ALL, true,
            new Gdk.Cursor.for_display(display, Gdk.CursorType.CROSSHAIR),
            null, null);
        assert (res == Gdk.GrabStatus.SUCCESS);

        return_pixbuf = take_interactive.callback;
        yield;

        return pixbuf;
    }

    public Gdk.Pixbuf scale_for_preview(Gdk.Pixbuf input, Gdk.Screen screen) {
        Gdk.Rectangle screen_size;
        screen.get_monitor_geometry(screen.get_monitor_at_window(
            (!) screen.get_active_window()), out screen_size);

        var x = input.width;
        var y = input.height;
        var preview_too_large = true;
        while (preview_too_large)
            for (var i = 0; i < 2; i++) {
                if (x / (float) screen_size.width > 0.75 ||
                        y / (float) screen_size.height > 0.75) {
                    x = (int) Math.floor(x*0.75);
                    y = (int) Math.floor(y*0.75);
                } else
                    preview_too_large = false;
            }

        return input.scale_simple(x, y, Gdk.InterpType.BILINEAR);
    }
}
