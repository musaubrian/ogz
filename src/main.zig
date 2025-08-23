const std = @import("std");
const Dgz = @import("Dgz.zig");
const Window = Dgz.Window;
const WindowFlags = Dgz.WindowFlags;
const Renderer = Dgz.Renderer;
const Color = Dgz.Color;
const Ui = Dgz.Ui;
const Texture = Dgz.Texture;

const width = 1080;
const height = 720;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    try Dgz.init(Dgz.Subsystem.VIDEO);
    defer Dgz.deinit();

    var window = try Window.create("OGZ", width, height, WindowFlags.RESIZABLE);
    defer window.destroy();

    var renderer = try Renderer.create(&window);
    defer renderer.destroy();

    var rect: Dgz.Rect = .{ .x = 40, .y = 400, .h = 100, .w = 100 };
    var circle: Dgz.Circle = .{ .x = 500, .y = 200, .radius = 50 };

    var dunno_texture = try Texture.create(&renderer, "/home/sminwn/Pictures/memes/dunno.png");
    defer dunno_texture.destroy();

    var font = try Texture.Font.init(&renderer, try Dgz.expandRelativePath(allocator, "./assets/fonts/RobotoCondensed-Medium.ttf"), 24);
    defer font.deinit();

    var progress_value: i32 = 0;
    var slider_value: i32 = 20;
    var slider_value1: i32 = 20;
    var event: Dgz.Event = undefined;

    mainLoop: while (true) {
        while (Dgz.pollEvents(&event)) {
            if (event.type == Dgz.QUIT or
                (event.type == Dgz.KEYDOWN and
                    Dgz.isCtrlQ(&event))) break :mainLoop;
        }

        var ui = Ui.init(allocator, &renderer, Dgz.getMouseState(), &font, null);
        defer ui.deinit();

        try renderer.setBgColor(Color.BLACK);
        try renderer.clear();

        try dunno_texture.render(100, 300);
        const window_dimensions = try window.getSize();

        try ui.drawFilledRect(rect, Color.BLUE);
        try ui.drawFilledCircle(circle, null);

        try ui.progress(10, 10, @divTrunc(window_dimensions.w, 3), progress_value);
        progress_value += 1; // test out the smoothness?

        try ui.slider("slider1", 10, 40, 300, &slider_value);
        try ui.slider("slider3", 10, 60, 200, &slider_value1);
        try ui.label("DEBUG TEST", 10, 90, null);

        if (try ui.button(
            "Yay",
            .{ .x = 200, .y = 200, .h = 40, .w = 200 },
            .{
                .active = Color.RED,
                .hover = Color.BLUE,
                .inactive = Color.LIGHT_GRAY,
            },
        )) {
            rect.w += 20;
            circle.radius += 10;
            slider_value += 2;
        }

        if (try ui.button(
            "No yay",
            .{ .x = 200, .y = 300, .h = 40, .w = 200 },
            .{
                .active = Color.DARK_GRAY,
                .hover = Color.WHITE,
                .inactive = Color.GREEN,
            },
        )) {
            rect.w -= 20;
            circle.radius -= 10;
            slider_value -= 2;
        }

        try renderer.render();
    }
}
