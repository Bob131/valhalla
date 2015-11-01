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

namespace utils.screenshot {
    private class SelectionWindow : Gtk.Window {
        public SelectionWindow() {
            Object(type: Gtk.WindowType.POPUP);

            var screen = Gdk.Screen.get_default();

            if (screen != null) {
                var visual = ((!)screen).get_rgba_visual();

                if ((((!)screen).is_composited()) && (visual != null)) {
                    app_paintable = true;

                    set_visual((!)visual);
                }
            }

            move(-1, -1);
            resize(1, 1);

            // Realize after setting the visual, else we'll get an opaque window.
            visible = true;
        }


        public override bool draw(Cairo.Context cr) {
            if (app_paintable) {
                var style_context = get_style_context();

                cr.set_operator(Cairo.Operator.SOURCE);
                cr.set_source_rgba(0, 0, 0, 0);

                cr.paint();

                style_context.save();

                style_context.add_class(Gtk.STYLE_CLASS_RUBBERBAND);
                style_context.render_background(cr, 0, 0, get_allocated_width(), get_allocated_height());
                style_context.render_frame(cr, 0, 0, get_allocated_width(), get_allocated_height());

                style_context.restore();
            }

            return true;
        }
    }


    public Gdk.Pixbuf? take_interactive() {
        Gdk.Pixbuf? pixbuf = null;
        bool screenshot_taken = false;

        Gdk.Rectangle rectangle = Gdk.Rectangle();

        var selection_window = new SelectionWindow();

        bool selection_mode = false;

        selection_window.motion_notify_event.connect((event) => {
            if (!selection_mode) {
                return true;
            }

            var draw_rectangle = Gdk.Rectangle();

            draw_rectangle.x = int.min(rectangle.x, (int)event.x_root);
            draw_rectangle.y = int.min(rectangle.y, (int)event.y_root);
            draw_rectangle.width = (rectangle.x - (int)event.x_root).abs();
            draw_rectangle.height = (rectangle.y - (int)event.y_root).abs();

            if (!(draw_rectangle.width > 0) || !(draw_rectangle.height > 0)) {
                selection_window.move(-1, -1);
                selection_window.resize(1, 1);

                return true;
            }

            selection_window.move(draw_rectangle.x, draw_rectangle.y);
            selection_window.resize(draw_rectangle.width, draw_rectangle.height);

            return true;
        });

        selection_window.button_press_event.connect((event) => {
            if (selection_mode) {
                return true;
            }

            rectangle.x = (int)event.x_root;
            rectangle.y = (int)event.y_root;

            selection_mode = true;

            return true;
        });

        var display = Gdk.Display.get_default();
        if (display == null) {
            return null;
        }

        var device_manager = ((!)display).get_device_manager();
        if (device_manager == null) {
            return null;
        }

        var pointer = ((!)device_manager).get_client_pointer();

        var keyboard = pointer.get_associated_device();
        if (keyboard == null) {
            // Optional?
            return null;
        }

        var cursor = new Gdk.Cursor.for_display((!)display, Gdk.CursorType.CROSSHAIR);

        selection_window.button_release_event.connect((event) => {
            if (!selection_mode) {
                return true;
            }

            rectangle.x = int.min(rectangle.x, (int)event.x_root);
            rectangle.y = int.min(rectangle.y, (int)event.y_root);
            rectangle.width = (rectangle.x - (int)event.x_root).abs();
            rectangle.height = (rectangle.y - (int)event.y_root).abs();

            if ((rectangle.width == 0) || (rectangle.height == 0)) {
                pixbuf = utils.screenshot.take_window_at_point(rectangle.x, rectangle.y);

                screenshot_taken = true;
            }

            ((!)keyboard).ungrab(Gdk.CURRENT_TIME);
            pointer.ungrab(Gdk.CURRENT_TIME);

            selection_window.destroy();

            Timeout.add(200, () => {
                Gtk.main_quit();

                if (!screenshot_taken) {
                    pixbuf = utils.screenshot.take(rectangle);
                }

                return false;
            });

            return true;
        });

        selection_window.key_press_event.connect((event) => {
            if (event.keyval == Gdk.Key.Escape) {
                screenshot_taken = false;

                Gtk.main_quit();
            }

            return true;
        });

        var res = pointer.grab(selection_window.get_window(), Gdk.GrabOwnership.NONE, false, Gdk.EventMask.POINTER_MOTION_MASK | Gdk.EventMask.BUTTON_PRESS_MASK | Gdk.EventMask.BUTTON_RELEASE_MASK, cursor, Gdk.CURRENT_TIME);

        if (res != Gdk.GrabStatus.SUCCESS) {
            screenshot_taken = false;
        }

        res = ((!)keyboard).grab(selection_window.get_window(), Gdk.GrabOwnership.NONE, false, Gdk.EventMask.KEY_PRESS_MASK | Gdk.EventMask.KEY_RELEASE_MASK, null, Gdk.CURRENT_TIME);

        if (res != Gdk.GrabStatus.SUCCESS) {
            screenshot_taken = false;
        }

        Gtk.main();

        return pixbuf;
    }

    public async Gdk.Pixbuf? take_interactive_async() {
        return take_interactive();
    }


    public Gdk.Pixbuf? take_window_at_point(int x, int y) {
        var default_screen = Gdk.Screen.get_default();
        if (default_screen == null) {
            return null;
        }

        var window_stack = ((!)default_screen).get_window_stack();
        if (window_stack == null) {
            return null;
        }

        unowned List<weak Gdk.Window> _window_stack = (!)window_stack;
        _window_stack.reverse();

        foreach (var window in _window_stack) {
            var window_rectangle = Gdk.Rectangle();

            window.get_root_origin(out window_rectangle.x, out window_rectangle.y);

            window_rectangle.width = window.get_width();
            window_rectangle.height = window.get_height();

            var point_rectangle = Gdk.Rectangle();

            point_rectangle.x = x;
            point_rectangle.y = y;
            point_rectangle.width = 1;
            point_rectangle.height = 1;

            if (window_rectangle.intersect(point_rectangle, null)) {
                return Gdk.pixbuf_get_from_window(window, 0, 0, window_rectangle.width, window_rectangle.height);
            }
        }

        return null;
    }


    public Gdk.Pixbuf? take(Gdk.Rectangle? area_rectangle = null) {
        var root_window = Gdk.get_default_root_window();

        if (area_rectangle == null) {
            return Gdk.pixbuf_get_from_window(root_window, 0, 0, root_window.get_width(), root_window.get_height());
        } else {
            return Gdk.pixbuf_get_from_window(root_window, ((!)area_rectangle).x, ((!)area_rectangle).y, ((!)area_rectangle).width, ((!)area_rectangle).height);
        }
    }
}
