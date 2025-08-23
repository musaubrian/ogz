const std = @import("std");
const c = @cImport({
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_main.h");
    @cInclude("SDL3_image/SDL_image.h");
    @cInclude("SDL3_ttf/SDL_ttf.h");
});

const Dgz = @This();

pub const Subsystem = struct {
    pub const VIDEO = c.SDL_INIT_VIDEO;
    pub const AUDIO = c.SDL_INIT_AUDIO;
};

pub const WindowFlags = struct {
    pub const RESIZABLE = c.SDL_WINDOW_RESIZABLE;
    pub const BORDERLESS = c.SDL_WINDOW_BORDERLESS;
};

// Re-Exports
pub const Event = c.SDL_Event;
pub const sdl = c;

pub const QUIT = c.SDL_EVENT_QUIT;
pub const KEYDOWN = c.SDL_EVENT_KEY_DOWN;
pub const KEYUP = c.SDL_EVENT_KEY_UP;

pub fn init(subSystems: u32) !void {
    if (subSystems & Subsystem.VIDEO != 0) std.log.debug("Initializing video", .{});
    if (subSystems & Subsystem.AUDIO != 0) std.log.debug("Initializing audio", .{});

    if (!c.SDL_Init(subSystems)) {
        std.log.debug("Failed to initialize: {s}", .{c.SDL_GetError()});
        return error.InitFailed;
    }

    if (!c.TTF_Init()) {
        std.log.debug("Failed to initialize font", .{});
        return error.TTFInitFailed;
    }

    std.log.debug("Subsystems initialized", .{});
}

pub fn deinit() void {
    c.TTF_Quit();
    c.SDL_Quit();
    std.log.debug("De-initializing", .{});
}

pub fn pollEvents(event: *Event) bool {
    return c.SDL_PollEvent(@ptrCast(event));
}

pub fn isCtrlQ(e: *Event) bool {
    return e.key.key == c.SDLK_Q and (e.key.mod & c.SDL_KMOD_CTRL) != 0;
}

pub fn expandRelativePath(allocator: std.mem.Allocator, relative_path: []const u8) ![]const u8 {
    var real_path: []const u8 = undefined;

    if (relative_path.len > 0 and relative_path[0] == '~') {
        const home = try std.process.getEnvVarOwned(allocator, "HOME");
        defer allocator.free(home);
        real_path = try std.fs.path.join(allocator, &.{ home, relative_path[1..] });
    } else if (std.fs.path.isAbsolute(relative_path)) {
        real_path = try allocator.dupe(u8, relative_path);
    } else {
        const cwd = try std.fs.cwd().realpathAlloc(allocator, ".");
        defer allocator.free(cwd);
        real_path = try std.fs.path.join(allocator, &.{ cwd, relative_path });
    }

    return real_path;
}
// Window related stuff

pub const Window = struct {
    handle: ?*c.SDL_Window,

    pub fn create(title: []const u8, w: u32, h: u32, flags: u64) !Window {
        const window = c.SDL_CreateWindow(title.ptr, @intCast(w), @intCast(h), flags);
        if (window == null) {
            std.log.err("Failed to create window: {s}", .{c.SDL_GetError()});
            return error.WindowCreateFailed;
        }

        std.log.debug("Created Window", .{});
        return Window{ .handle = window };
    }

    pub fn destroy(self: *Window) void {
        c.SDL_DestroyWindow(self.handle);
        self.handle = null;
        std.log.debug("Destroyed Window", .{});
    }

    pub fn getSize(self: *Window) !struct { w: i32, h: i32 } {
        var w: c_int = undefined;
        var h: c_int = undefined;

        if (!c.SDL_GetWindowSize(self.handle, &w, &h)) {
            std.log.err("Failed to get window size: {s}", .{c.SDL_GetError()});
            return error.GetWindowSizeFailed;
        }
        return .{ .w = @intCast(w), .h = @intCast(h) };
    }
};

// Renderer
pub const Renderer = struct {
    handle: ?*c.SDL_Renderer,

    pub fn create(window: *Window) !Renderer {
        if (window.handle == null) {
            std.log.err("Cannot create renderer: window handle is null", .{});
            return error.RendererCreateFailed;
        }
        const r = c.SDL_CreateRenderer(window.handle, null);
        if (r == null) {
            std.log.err("Failed to create renderer", .{});
            return error.RendererCreateFailed;
        }

        if (!c.SDL_SetRenderVSync(r, 1)) {
            std.log.warn("VSync not supported, welp frame rate: {s}", .{c.SDL_GetError()});
        } else {
            std.log.debug("VSync enabled", .{});
        }

        std.log.debug("Created renderer", .{});
        return Renderer{ .handle = r };
    }

    pub fn clear(self: *Renderer) !void {
        if (!c.SDL_RenderClear(self.handle)) return error.RendererClearFailed;
    }

    pub fn render(self: *Renderer) !void {
        if (!c.SDL_RenderPresent(self.handle)) return error.RenderFailed;
    }

    pub fn destroy(self: *Renderer) void {
        c.SDL_DestroyRenderer(self.handle);
        self.handle = null;
        std.log.debug("Renderer destroyed", .{});
    }

    pub fn setColor(self: *Renderer, color: Color) !void {
        if (!c.SDL_SetRenderDrawColor(self.handle, color.r, color.g, color.b, color.a)) {
            return error.SetColorFailed;
        }
    }

    pub fn setBgColor(self: *Renderer, color: Color) !void {
        try self.setColor(color);
    }
};

pub const Circle = struct { x: i32, y: i32, radius: i32 };
pub const Rect = struct { x: i32, y: i32, w: i32, h: i32 };
fn toSDLRect(r: Rect) c.SDL_FRect {
    return c.SDL_FRect{
        .x = @floatFromInt(r.x),
        .y = @floatFromInt(r.y),
        .w = @floatFromInt(r.w),
        .h = @floatFromInt(r.h),
    };
}

pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8 = 255,

    // some debug colors
    pub const RED = Color{ .r = 255, .g = 0, .b = 0 };
    pub const DARK_RED = Color{ .r = 180, .g = 0, .b = 0 };
    pub const GREEN = Color{ .r = 0, .g = 255, .b = 0 };
    pub const BLUE = Color{ .r = 0, .g = 0, .b = 255 };
    pub const WHITE = Color{ .r = 255, .g = 255, .b = 255 };
    pub const BLACK = Color{ .r = 0, .g = 0, .b = 0 };
    pub const LIGHT_GRAY = Color{ .r = 200, .g = 200, .b = 200 };
    pub const DARK_GRAY = Color{ .r = 80, .g = 80, .b = 80 };
};

pub fn toSDLColor(color: Color) c.SDL_Color {
    return c.SDL_Color{
        .r = color.r,
        .g = color.g,
        .b = color.b,
        .a = color.a,
    };
}

pub const Texture = struct {
    renderer: *Renderer,
    handle: [*c]c.SDL_Texture,

    pub fn create(renderer: *Renderer, path: []const u8) !Texture {
        const loadedSurface = c.IMG_Load(path.ptr);
        defer c.SDL_DestroySurface(loadedSurface);

        if (loadedSurface == null) return error.LoadingImageFailed;
        const texture = c.SDL_CreateTextureFromSurface(renderer.handle, loadedSurface);
        if (texture == null) return error.CreatingTextureFailed;
        return Texture{
            .renderer = renderer,
            .handle = texture,
        };
    }

    pub fn destroy(self: *Texture) void {
        c.SDL_DestroyTexture(self.handle);
        self.handle = null;
    }

    pub fn render(self: *Texture, x: i32, y: i32, w: i32, h: i32) !void {
        if (self.handle == null) return error.RenderTextureFailed;

        // TODO:: (8b5e6d191cc0) find a way to scale up/down
        const container: Rect = .{
            .h = h,
            .w = w,
            .x = x,
            .y = y,
        };

        if (!c.SDL_RenderTexture(self.renderer.handle, self.handle, null, &toSDLRect(container))) return error.RenderTextureFailed;
    }

    pub const Font = struct {
        handle: *c.TTF_Font,
        texture: [*c]c.SDL_Texture = undefined,
        renderer: *Renderer,

        pub fn init(renderer: *Renderer, path: []const u8, size: ?f32) !Font {
            const f = c.TTF_OpenFont(path.ptr, size orelse 10.0);
            if (f == null) return error.FontInitializationFailed;

            return Font{
                .handle = f.?,
                .renderer = renderer,
            };
        }

        pub fn deinit(self: *Font) void {
            c.SDL_DestroyTexture(self.texture);
            c.TTF_CloseFont(self.handle);
        }

        pub fn renderText(self: *Font, text: []const u8, x: i32, y: i32, color: ?Color) !struct { w: i32, h: i32 } {
            const text_surface = c.TTF_RenderText_Blended(
                self.handle,
                text.ptr,
                0,
                toSDLColor(color orelse Color.BLUE),
            );
            if (text_surface == null) return error.TextSurfaceCreationFailed;
            defer c.SDL_DestroySurface(text_surface);
            const w = text_surface.*.w;
            const h = text_surface.*.h;

            self.texture = c.SDL_CreateTextureFromSurface(self.renderer.handle, text_surface);
            if (!c.SDL_RenderTexture(
                self.renderer.handle,
                self.texture,
                null,
                &.{
                    .h = @floatFromInt(h),
                    .w = @floatFromInt(w),
                    .x = @floatFromInt(x),
                    .y = @floatFromInt(y),
                },
            )) return error.RenderTextFailed;

            return .{ .w = @intCast(w), .h = @intCast(h) };
        }
    };
};

var prev_mouse_state: ?MouseState = null;

pub const MouseState = struct {
    x: f32,
    y: f32,
    left_pressed: bool,
    left_just_pressed: bool,
    left_released: bool,

    is_dragging: bool = false,
    drag_start_x: f32,
    drag_start_y: f32,
    drag_delta_x: f32,
    drag_delta_y: f32,
};

pub fn getMouseState() MouseState {
    var x: f32 = undefined;
    var y: f32 = undefined;
    const mouse_buttons = c.SDL_GetMouseState(&x, &y);

    const currently_pressed = (mouse_buttons & c.SDL_BUTTON_LMASK) != 0;
    const was_pressed = if (prev_mouse_state) |prev| prev.left_pressed else false;

    var is_dragging = false;
    var drag_start_x: f32 = 0;
    var drag_start_y: f32 = 0;
    var drag_delta_x: f32 = 0;
    var drag_delta_y: f32 = 0;

    if (prev_mouse_state) |prev| {
        if (prev.left_just_pressed) {
            drag_start_x = x;
            drag_start_y = y;
        } else if (prev.is_dragging or (currently_pressed and (x != prev.x or y != prev.y))) {
            is_dragging = currently_pressed;
            drag_start_x = prev.drag_start_x;
            drag_start_y = prev.drag_start_y;
            drag_delta_x = x - drag_start_x;
            drag_delta_y = y - drag_start_y;
        }
    }

    const current_state = MouseState{
        .x = x,
        .y = y,
        .left_pressed = currently_pressed,
        .left_just_pressed = currently_pressed and !was_pressed,
        .left_released = !currently_pressed and was_pressed,
        .is_dragging = is_dragging,
        .drag_delta_x = drag_delta_x,
        .drag_delta_y = drag_delta_y,
        .drag_start_x = drag_start_x,
        .drag_start_y = drag_start_y,
    };

    prev_mouse_state = current_state;

    return current_state;
}

pub const UiState = struct {
    hot_id: ?u64 = null, // Widget currently under mouse (hovered)
    active_id: ?u64 = null, // Widget currently being interacted with (pressed)
};
var ui_state: UiState = .{};

// Common UI related stuff
pub const Ui = struct {
    mouse_state: MouseState,
    renderer: *Renderer,
    font: *Texture.Font,

    theme: Theme,
    allocator: std.mem.Allocator,

    circle_points_buffer: std.ArrayList(Point),
    filled_circle_rect_buffer: std.ArrayList(c.SDL_FRect),

    const Theme = struct {
        progress_colors: ProgressColors,
        slider_colors: ProgressColors,
        slider_height: i32,
        progress_height: i32,
    };

    const ProgressColors = struct {
        handle: ?Color,
        foreground: Color,
        track: Color,
    };

    const BtnColors = struct {
        inactive: Color,
        hover: Color,
        active: Color,
        label: Color,
    };

    const ButtonState = enum { inactive, hovered, clicked };
    const Point = c.SDL_FPoint;

    fn defaultTheme() Theme {
        return Theme{
            .progress_colors = .{ .foreground = Color.RED, .track = Color.DARK_GRAY, .handle = null },
            .slider_colors = .{ .foreground = Color.DARK_RED, .track = Color.DARK_GRAY, .handle = Color.RED },
            .slider_height = 8,
            .progress_height = 8,
        };
    }

    pub fn init(
        alloc: std.mem.Allocator,
        renderer: *Renderer,
        mouse_state: MouseState,
        font: *Texture.Font,
        theme: ?Theme,
    ) Ui {
        return Ui{
            .allocator = alloc,
            .mouse_state = mouse_state,
            .renderer = renderer,
            .font = font,
            .theme = theme orelse defaultTheme(),
            .circle_points_buffer = std.ArrayList(Point).init(alloc),
            .filled_circle_rect_buffer = std.ArrayList(c.SDL_FRect).init(alloc),
        };
    }

    pub fn deinit(self: *Ui) void {
        self.circle_points_buffer.deinit();
        self.filled_circle_rect_buffer.deinit();
    }

    pub fn drawFilledRect(self: *Ui, r: Rect, color: Color) !void {
        try self.renderer.setColor(color);
        const rect = toSDLRect(r);
        if (!c.SDL_RenderFillRect(self.renderer.handle, &rect)) return error.DrawRectFailed;
    }

    pub fn drawPoint(self: *Ui, x: f32, y: f32, color: Color) !void {
        try self.renderer.setColor(color);
        if (!c.SDL_RenderPoint(self.renderer.handle, x, y)) return error.DrawPointFailed;
    }

    pub fn drawPoints(self: *Ui, points: []Point, color: Color) !void {
        try self.renderer.setColor(color);
        if (!c.SDL_RenderPoints(self.renderer.handle, @ptrCast(points), @intCast(points.len))) return error.DrawPointsFailed;
    }

    pub fn drawCircle(self: *Ui, circle: Circle, color: ?Color) !void {
        const circle_color = color orelse Color.WHITE;

        var offset_x: i32 = 0;
        var offset_y = circle.radius;
        var d = 1 - circle.radius;
        self.circle_points_buffer.clearRetainingCapacity();

        while (offset_y >= offset_x) {
            try self.circle_points_buffer.append(.{ .x = @floatFromInt(circle.x + offset_x), .y = @floatFromInt(circle.y + offset_y) });
            try self.circle_points_buffer.append(.{ .x = @floatFromInt(circle.x - offset_x), .y = @floatFromInt(circle.y + offset_y) });
            try self.circle_points_buffer.append(.{ .x = @floatFromInt(circle.x + offset_x), .y = @floatFromInt(circle.y - offset_y) });
            try self.circle_points_buffer.append(.{ .x = @floatFromInt(circle.x - offset_x), .y = @floatFromInt(circle.y - offset_y) });
            try self.circle_points_buffer.append(.{ .x = @floatFromInt(circle.x + offset_y), .y = @floatFromInt(circle.y + offset_x) });
            try self.circle_points_buffer.append(.{ .x = @floatFromInt(circle.x - offset_y), .y = @floatFromInt(circle.y + offset_x) });
            try self.circle_points_buffer.append(.{ .x = @floatFromInt(circle.x + offset_y), .y = @floatFromInt(circle.y - offset_x) });
            try self.circle_points_buffer.append(.{ .x = @floatFromInt(circle.x - offset_y), .y = @floatFromInt(circle.y - offset_x) });

            offset_x += 1;

            if (d < 0) {
                d += 2 * offset_x + 1;
            } else {
                offset_y -= 1;
                d += 2 * (offset_x - offset_y) + 1;
            }
        }

        try self.drawPoints(self.circle_points_buffer.items, circle_color);
    }

    pub fn drawFilledCircle(self: *Ui, circle: Circle, color: ?Color) !void {
        self.filled_circle_rect_buffer.clearRetainingCapacity();

        var offset_x: i32 = 0;
        var offset_y = circle.radius;
        var d = 1 - circle.radius;

        while (offset_y >= offset_x) {
            // try points.append(.{ .x = @floatFromInt(circle.x + offset_x), .y = @floatFromInt(circle.y + offset_y) });
            // try points.append(.{ .x = @floatFromInt(circle.x - offset_x), .y = @floatFromInt(circle.y + offset_y) });
            try self.filled_circle_rect_buffer.append(toSDLRect(.{ .x = circle.x - offset_x, .y = circle.y + offset_y, .w = 2 * offset_x + 1, .h = 1 }));

            // try points.append(.{ .x = @floatFromInt(circle.x + offset_x), .y = @floatFromInt(circle.y - offset_y) });
            // try points.append(.{ .x = @floatFromInt(circle.x - offset_x), .y = @floatFromInt(circle.y - offset_y) });
            try self.filled_circle_rect_buffer.append(toSDLRect(.{ .x = circle.x - offset_x, .y = circle.y - offset_y, .w = 2 * offset_x + 1, .h = 1 }));
            // try points.append(.{ .x = @floatFromInt(circle.x + offset_y), .y = @floatFromInt(circle.y + offset_x) });
            // try points.append(.{ .x = @floatFromInt(circle.x - offset_y), .y = @floatFromInt(circle.y + offset_x) });
            try self.filled_circle_rect_buffer.append(toSDLRect(.{ .x = circle.x - offset_y, .y = circle.y + offset_x, .w = 2 * offset_y + 1, .h = 1 }));
            // try points.append(.{ .x = @floatFromInt(circle.x + offset_y), .y = @floatFromInt(circle.y - offset_x) });
            // try points.append(.{ .x = @floatFromInt(circle.x - offset_y), .y = @floatFromInt(circle.y - offset_x) });
            try self.filled_circle_rect_buffer.append(toSDLRect(.{ .x = circle.x - offset_y, .y = circle.y - offset_x, .w = 2 * offset_y + 1, .h = 1 }));

            offset_x += 1;

            if (d < 0) {
                d += 2 * offset_x + 1;
            } else {
                offset_y -= 1;
                d += 2 * (offset_x - offset_y) + 1;
            }
        }

        try self.renderer.setColor(color orelse Color.WHITE);
        if (!c.SDL_RenderFillRects(self.renderer.handle, self.filled_circle_rect_buffer.items.ptr, @intCast(self.filled_circle_rect_buffer.items.len))) return error.DrawFilledCircleFailed;
    }

    pub fn label(self: *Ui, text: []const u8, x: i32, y: i32, color: ?Color) !void {
        _ = try self.font.renderText(text, x, y, color orelse Color.WHITE);
    }

    pub fn button(self: *Ui, labelText: []const u8, dimensions: Rect, btn_colors: BtnColors) !bool {
        if (labelText.len == 0) return error.InvalidLabel;

        if (ui_state.active_id == null) ui_state.hot_id = null;
        const text_size = try self.font.renderText(labelText, 0, -1000, null); // Measure offscreen first
        const actual_w = @max(dimensions.w, text_size.w + 20);

        const buttonId = std.hash.Wyhash.hash(0, labelText);

        const mouse_over =
            self.mouse_state.x >= @as(f32, @floatFromInt(dimensions.x)) and
            self.mouse_state.x <= @as(f32, @floatFromInt(dimensions.x + dimensions.w)) and
            self.mouse_state.y >= @as(f32, @floatFromInt(dimensions.y)) and
            self.mouse_state.y <= @as(f32, @floatFromInt(dimensions.y + dimensions.h));

        // Set hot_id if mouse is over and no other widget is active (or this is the active one)
        if (mouse_over and (ui_state.active_id == null or ui_state.active_id == buttonId)) {
            ui_state.hot_id = buttonId;
        }

        var clicked = false;
        var state: ButtonState = .inactive;

        // Set active_id on press if this button is hot
        if (ui_state.hot_id == buttonId and self.mouse_state.left_just_pressed) ui_state.active_id = buttonId;

        // Trigger click on release if this button was pressed
        if (ui_state.active_id == buttonId and self.mouse_state.left_released) {
            clicked = mouse_over; // Only click if mouse is over button on release
            ui_state.active_id = null; // Clear active_id after click
        }

        if (ui_state.active_id == buttonId) {
            state = .clicked;
        } else if (ui_state.hot_id == buttonId) {
            state = .hovered;
        }

        const btn_color = switch (state) {
            .inactive => btn_colors.inactive,
            .hovered => btn_colors.hover,
            .clicked => btn_colors.active,
        };

        try self.drawFilledRect(dimensions, btn_color);

        const text_x = dimensions.x + @divTrunc(actual_w - text_size.w, 2);
        const text_y = dimensions.y + @divTrunc(dimensions.h - text_size.h, 2);
        _ = try self.font.renderText(labelText, text_x, text_y, btn_colors.label);

        return clicked;
    }

    pub fn progress(self: *Ui, x: i32, y: i32, w: i32, value: i32) !void {
        const track: Rect = .{ .x = x, .y = y, .w = w, .h = self.theme.progress_height };
        const active_width = if (value <= w) value else w;
        const active: Rect = .{ .x = x, .y = y, .w = active_width, .h = self.theme.progress_height };
        try self.drawFilledRect(track, self.theme.progress_colors.track);
        try self.drawFilledRect(active, self.theme.progress_colors.foreground);
    }

    pub fn slider(self: *Ui, labelText: []const u8, x: i32, y: i32, w: i32, value: *i32) !void {
        if (labelText.len == 0) return error.InvalidLabel;

        if (ui_state.active_id == null) ui_state.hot_id = null;

        const sliderId = std.hash.Wyhash.hash(0, labelText);

        const track_start_x = x;
        const track_end_x = x + w;

        // Clamp value to valid range (0 to w)
        value.* = @max(0, @min(value.*, w));

        const handle_x = track_start_x + value.*;
        const sh_vertical_center = y + @divTrunc(self.theme.slider_height, 2);
        const sh_radius: i32 = self.theme.slider_height * @divTrunc(self.theme.slider_height, 6);

        // Check if mouse is over the handle
        const mouse_x = self.mouse_state.x;
        const mouse_y = self.mouse_state.y;

        const dx = mouse_x - @as(f32, @floatFromInt(handle_x));
        const dy = mouse_y - @as(f32, @floatFromInt(sh_vertical_center));
        const distance_squared = dx * dx + dy * dy;
        const mouse_over_handle = distance_squared <= (@as(f32, @floatFromInt(sh_radius)) * @as(f32, @floatFromInt(sh_radius)));

        // Or check if mouse is over the track area (easier to grab)
        const mouse_over_track = mouse_x >= @as(f32, @floatFromInt(track_start_x)) and
            mouse_x <= @as(f32, @floatFromInt(track_end_x)) and
            mouse_y >= @as(f32, @floatFromInt(y - sh_radius)) and
            mouse_y <= @as(f32, @floatFromInt(y + self.theme.slider_height + sh_radius));

        const mouse_over = mouse_over_handle or mouse_over_track;

        // Set hot_id if mouse is over and no other widget is active
        if (mouse_over and (ui_state.active_id == null or ui_state.active_id == sliderId)) {
            ui_state.hot_id = sliderId;
        }

        // Set active_id on press if this slider is hot
        if (ui_state.hot_id == sliderId and self.mouse_state.left_just_pressed) {
            ui_state.active_id = sliderId;
        }

        // Handle dragging when this slider is active
        if (ui_state.active_id == sliderId and self.mouse_state.left_pressed) {
            // Calculate new value based on mouse position
            const mouse_relative_x = @as(i32, @intFromFloat(mouse_x)) - track_start_x;
            const new_value = @max(0, @min(mouse_relative_x, w));
            value.* = new_value;
        }

        // Release active_id when mouse is released
        if (ui_state.active_id == sliderId and self.mouse_state.left_released) {
            ui_state.active_id = null;
        }

        const track: Rect = .{ .x = x, .y = y, .w = w, .h = self.theme.slider_height };
        const active: Rect = .{ .x = x, .y = y, .w = value.*, .h = self.theme.slider_height };
        try self.drawFilledRect(track, self.theme.slider_colors.track);
        try self.drawFilledRect(active, self.theme.slider_colors.foreground);

        try self.drawFilledCircle(
            .{ .x = handle_x, .y = sh_vertical_center, .radius = sh_radius },
            self.theme.slider_colors.handle,
        );
    }
};
