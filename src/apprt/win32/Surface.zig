/// Win32 surface implementation. Each surface represents a single
/// terminal window with an OpenGL rendering context via WGL.
const Surface = @This();

const std = @import("std");
const Allocator = std.mem.Allocator;
const apprt = @import("../../apprt.zig");
const configpkg = @import("../../config.zig");
const input = @import("../../input.zig");
const CoreSurface = @import("../../Surface.zig");
const App = @import("App.zig");
const keycodes = @import("../../input/keycodes.zig");
const w = @import("win32.zig");

const log = std.log.scoped(.win32);

/// The core surface.
core_surface: CoreSurface = undefined,

/// The app that owns this surface.
app: *App = undefined,

/// The window handle.
hwnd: ?w.HWND = null,

/// The device context (persists because of CS_OWNDC).
hdc: ?w.HDC = null,

/// The WGL OpenGL rendering context.
hglrc: ?w.HGLRC = null,

/// Current size in pixels.
width: u32 = 800,
height: u32 = 600,

pub fn init(self: *Surface, app: *App) !void {
    self.* = .{
        .app = app,
    };

    const class_name = std.unicode.utf8ToUtf16LeStringLiteral("GhosttyWindow");
    const window_name = std.unicode.utf8ToUtf16LeStringLiteral("Ghostty");

    // Create the terminal window
    const hwnd = w.CreateWindowExW(
        w.WS_EX_APPWINDOW,
        class_name,
        window_name,
        w.WS_OVERLAPPEDWINDOW,
        w.CW_USEDEFAULT,
        w.CW_USEDEFAULT,
        800,
        600,
        null,
        null,
        app.hinstance,
        null,
    ) orelse return error.CreateWindowFailed;

    self.hwnd = hwnd;

    // Store Surface pointer in window user data for wndProc dispatch
    _ = w.SetWindowLongPtrW(hwnd, w.GWLP_USERDATA, @intFromPtr(self));

    // Get the device context (persists due to CS_OWNDC)
    const hdc = w.GetDC(hwnd) orelse return error.GetDCFailed;
    self.hdc = hdc;

    // Set up pixel format for OpenGL
    const pfd: w.PIXELFORMATDESCRIPTOR = .{
        .dwFlags = w.PFD_DRAW_TO_WINDOW | w.PFD_SUPPORT_OPENGL | w.PFD_DOUBLEBUFFER,
        .iPixelType = w.PFD_TYPE_RGBA,
        .cColorBits = 32,
        .cDepthBits = 24,
        .cStencilBits = 8,
        .iLayerType = w.PFD_MAIN_PLANE,
    };

    const pixel_format = w.ChoosePixelFormat(hdc, &pfd);
    if (pixel_format == 0) return error.ChoosePixelFormatFailed;
    if (w.SetPixelFormat(hdc, pixel_format, &pfd) == 0) return error.SetPixelFormatFailed;

    // Create WGL context
    const hglrc = w.wglCreateContext(hdc) orelse return error.WglCreateContextFailed;
    self.hglrc = hglrc;

    // Make the context current on the main thread for initialization
    if (w.wglMakeCurrent(hdc, hglrc) == 0) return error.WglMakeCurrentFailed;

    // Update client area size
    var rect: w.RECT = .{};
    if (w.GetClientRect(hwnd, &rect) != 0) {
        self.width = @intCast(rect.right - rect.left);
        self.height = @intCast(rect.bottom - rect.top);
    }

    const alloc = self.app.core_app.alloc;

    // Register ourselves with the core app.
    try self.app.core_app.addSurface(self);
    errdefer self.app.core_app.deleteSurface(self);

    // Derive a surface-specific config from the app config.
    var config = try apprt.surface.newConfig(
        self.app.core_app,
        &self.app.config,
        .window,
    );
    defer config.deinit();

    // Initialize the core surface. This calls Renderer.surfaceInit()
    // which loads OpenGL via GLAD, so the WGL context must be current.
    try self.core_surface.init(
        alloc,
        &config,
        self.app.core_app,
        self.app,
        self,
    );

    // Release the GL context from the main thread so the renderer
    // thread can acquire it in threadEnter.
    _ = w.wglMakeCurrent(null, null);

    // Show the window
    _ = w.ShowWindow(hwnd, w.SW_SHOWDEFAULT);
    _ = w.UpdateWindow(hwnd);
}

pub fn deinit(self: *Surface) void {
    self.core_surface.deinit();
    self.app.core_app.deleteSurface(self);

    if (self.hglrc) |hglrc| {
        _ = w.wglMakeCurrent(null, null);
        _ = w.wglDeleteContext(hglrc);
        self.hglrc = null;
    }
    if (self.hdc) |hdc| {
        if (self.hwnd) |hwnd| {
            _ = w.ReleaseDC(hwnd, hdc);
        }
        self.hdc = null;
    }
    if (self.hwnd) |hwnd| {
        _ = w.DestroyWindow(hwnd);
        self.hwnd = null;
    }
}

// ---- Apprt Surface interface ----

pub fn core(self: *Surface) *CoreSurface {
    return &self.core_surface;
}

pub fn rtApp(self: *Surface) *App {
    return self.app;
}

pub fn close(self: *Surface, process_active: bool) void {
    _ = process_active;
    // TODO: confirmation dialog if process_active
    if (self.hwnd) |hwnd| {
        _ = w.DestroyWindow(hwnd);
    }
}

pub fn getContentScale(self: *const Surface) !apprt.ContentScale {
    if (self.hwnd) |hwnd| {
        const dpi = w.GetDpiForWindow(hwnd);
        const scale: f32 = @as(f32, @floatFromInt(dpi)) / 96.0;
        return .{ .x = scale, .y = scale };
    }
    return .{ .x = 1.0, .y = 1.0 };
}

pub fn getSize(self: *const Surface) !apprt.SurfaceSize {
    return .{ .width = self.width, .height = self.height };
}

pub fn getCursorPos(self: *const Surface) !apprt.CursorPos {
    if (self.hwnd) |hwnd| {
        var pt: w.POINT = .{};
        if (w.GetCursorPos(&pt) != 0) {
            _ = w.ScreenToClient(hwnd, &pt);
            return .{
                .x = @floatFromInt(pt.x),
                .y = @floatFromInt(pt.y),
            };
        }
    }
    return .{ .x = 0, .y = 0 };
}

pub fn getTitle(self: *Surface) ?[:0]const u8 {
    _ = self;
    return null;
}

pub fn supportsClipboard(self: *const Surface, clipboard_type: apprt.Clipboard) bool {
    _ = self;
    return clipboard_type == .standard;
}

pub fn clipboardRequest(
    self: *Surface,
    clipboard_type: apprt.Clipboard,
    state: apprt.ClipboardRequest,
) !bool {
    _ = self;
    _ = clipboard_type;
    _ = state;
    // TODO: Win32 clipboard read
    return false;
}

pub fn setClipboard(
    self: *Surface,
    clipboard_type: apprt.Clipboard,
    contents: []const apprt.ClipboardContent,
    confirm: bool,
) !void {
    _ = self;
    _ = clipboard_type;
    _ = contents;
    _ = confirm;
    // TODO: Win32 clipboard write
}

pub fn defaultTermioEnv(self: *Surface) !std.process.EnvMap {
    _ = self;
    var env = std.process.EnvMap.init(std.heap.page_allocator);
    try env.put("TERM", "xterm-ghostty");
    try env.put("COLORTERM", "truecolor");
    return env;
}

// ---- WGL context management for renderer thread ----

pub fn makeContextCurrent(self: *Surface) void {
    if (self.hdc != null and self.hglrc != null) {
        _ = w.wglMakeCurrent(self.hdc, self.hglrc);
    }
}

pub fn releaseContext(self: *Surface) void {
    _ = self;
    _ = w.wglMakeCurrent(null, null);
}

pub fn swapBuffers(self: *Surface) void {
    if (self.hdc) |hdc| {
        _ = w.SwapBuffers(hdc);
    }
}

// ---- Input helpers ----

/// Translate a Win32 scan code (from WM_KEYDOWN LPARAM) to an input.Key.
/// The scan code is in bits 16-23, and the extended flag is bit 24.
fn keyFromScanCode(lparam: w.LPARAM) input.Key {
    const scancode: u16 = @truncate(@as(u32, @bitCast(@as(i32, @truncate(lparam >> 16)))) & 0x1FF);
    // Build the native code: extended keys use 0xe0XX format.
    const native: u32 = if (scancode > 0xFF)
        0xe000 | (scancode & 0xFF)
    else
        scancode;

    for (keycodes.entries) |entry| {
        if (entry.native == native) return entry.key;
    }
    return .unidentified;
}

/// Build an input.Mods from the current keyboard state.
fn getModifiers() input.Mods {
    var mods: input.Mods = .{};
    if (w.GetKeyState(w.VK_SHIFT) < 0) mods.shift = true;
    if (w.GetKeyState(w.VK_CONTROL) < 0) mods.ctrl = true;
    if (w.GetKeyState(w.VK_MENU) < 0) mods.alt = true;
    if (w.GetKeyState(w.VK_LWIN) < 0 or w.GetKeyState(w.VK_RWIN) < 0) mods.super = true;
    if (w.GetKeyState(w.VK_CAPITAL) & 1 != 0) mods.caps_lock = true;
    if (w.GetKeyState(w.VK_NUMLOCK) & 1 != 0) mods.num_lock = true;
    return mods;
}

// ---- Win32 Window Procedure ----

pub fn wndProc(hwnd: w.HWND, msg: w.UINT, wparam: w.WPARAM, lparam: w.LPARAM) callconv(.winapi) w.LRESULT {
    // Retrieve the Surface pointer stored in the window's user data
    const ptr = w.GetWindowLongPtrW(hwnd, w.GWLP_USERDATA);
    if (ptr == 0) return w.DefWindowProcW(hwnd, msg, wparam, lparam);
    const self: *Surface = @ptrFromInt(ptr);

    switch (msg) {
        // ---- Window events ----

        w.WM_SIZE => {
            const width: u32 = @intCast(w.loword(lparam));
            const height: u32 = @intCast(w.hiword(lparam));
            if (width > 0 and height > 0) {
                self.width = width;
                self.height = height;
                self.core_surface.sizeCallback(.{
                    .width = width,
                    .height = height,
                }) catch |err| {
                    log.err("error in size callback: {}", .{err});
                };
            }
            return 0;
        },

        w.WM_SETFOCUS => {
            self.core_surface.focusCallback(true) catch |err| {
                log.err("error in focus callback: {}", .{err});
            };
            return 0;
        },

        w.WM_KILLFOCUS => {
            self.core_surface.focusCallback(false) catch |err| {
                log.err("error in focus callback: {}", .{err});
            };
            return 0;
        },

        w.WM_DPICHANGED => {
            self.core_surface.contentScaleCallback(.{
                .x = @as(f32, @floatFromInt(w.loword(wparam))) / 96.0,
                .y = @as(f32, @floatFromInt(w.hiword(wparam))) / 96.0,
            }) catch |err| {
                log.err("error in content scale callback: {}", .{err});
            };
            return 0;
        },

        w.WM_CLOSE => {
            self.close(false);
            return 0;
        },

        w.WM_DESTROY => {
            w.PostQuitMessage(0);
            return 0;
        },

        w.WM_ERASEBKGND => {
            // Prevent flickering - OpenGL handles all drawing
            return 1;
        },

        w.WM_PAINT => {
            // Validate the region so Windows stops sending WM_PAINT
            _ = w.ValidateRect(hwnd, null);
            return 0;
        },

        // ---- Keyboard events ----

        w.WM_KEYDOWN,
        w.WM_SYSKEYDOWN,
        => {
            const action: input.Action = if (lparam & (1 << 30) != 0) .repeat else .press;
            self.handleKeyEvent(action, wparam, lparam);
            return 0;
        },

        w.WM_KEYUP,
        w.WM_SYSKEYUP,
        => {
            self.handleKeyEvent(.release, wparam, lparam);
            return 0;
        },

        w.WM_CHAR => {
            // WM_CHAR gives us the UTF-16 codepoint. We accumulate it
            // and deliver as part of the next key event. For now, the
            // key event handler uses TranslateMessage which generates
            // WM_CHAR, but we handle text input through the key event
            // itself using the virtual key to UTF-8 translation.
            return 0;
        },

        // ---- Mouse events ----

        w.WM_MOUSEMOVE => {
            const x: f32 = @floatFromInt(w.GET_X_LPARAM(lparam));
            const y: f32 = @floatFromInt(w.GET_Y_LPARAM(lparam));
            self.core_surface.cursorPosCallback(.{ .x = x, .y = y }, getModifiers()) catch |err| {
                log.err("error in cursor pos callback: {}", .{err});
            };
            return 0;
        },

        w.WM_LBUTTONDOWN => {
            self.handleMouseButton(.press, .left);
            return 0;
        },
        w.WM_LBUTTONUP => {
            self.handleMouseButton(.release, .left);
            return 0;
        },
        w.WM_RBUTTONDOWN => {
            self.handleMouseButton(.press, .right);
            return 0;
        },
        w.WM_RBUTTONUP => {
            self.handleMouseButton(.release, .right);
            return 0;
        },
        w.WM_MBUTTONDOWN => {
            self.handleMouseButton(.press, .middle);
            return 0;
        },
        w.WM_MBUTTONUP => {
            self.handleMouseButton(.release, .middle);
            return 0;
        },

        w.WM_MOUSEWHEEL => {
            const delta = w.GET_WHEEL_DELTA_WPARAM(wparam);
            const yoff: f64 = @as(f64, @floatFromInt(delta)) / 120.0;
            self.core_surface.scrollCallback(0, yoff, .{}) catch |err| {
                log.err("error in scroll callback: {}", .{err});
            };
            return 0;
        },

        w.WM_MOUSEHWHEEL => {
            const delta = w.GET_WHEEL_DELTA_WPARAM(wparam);
            const xoff: f64 = @as(f64, @floatFromInt(delta)) / 120.0;
            self.core_surface.scrollCallback(xoff, 0, .{}) catch |err| {
                log.err("error in scroll callback: {}", .{err});
            };
            return 0;
        },

        else => return w.DefWindowProcW(hwnd, msg, wparam, lparam),
    }
}

fn handleKeyEvent(self: *Surface, action: input.Action, wparam: w.WPARAM, lparam: w.LPARAM) void {
    const mods = getModifiers();
    const key = keyFromScanCode(lparam);

    // Try to get the UTF-8 text for this key press.
    var utf8_buf: [4]u8 = undefined;
    var utf8_len: usize = 0;

    if (action != .release) {
        // Use ToUnicode to get the text the key would produce.
        var keyboard_state: [256]u8 = undefined;
        _ = w.GetKeyboardState(&keyboard_state);
        var utf16_buf: [4]u16 = undefined;
        const scan: u32 = @truncate(@as(u64, @bitCast(@as(i64, @intCast(lparam >> 16)))) & 0xFF);
        const ret = w.ToUnicode(
            @truncate(wparam),
            scan,
            &keyboard_state,
            &utf16_buf,
            utf16_buf.len,
            0,
        );
        if (ret > 0) {
            const utf16_slice = utf16_buf[0..@intCast(ret)];
            utf8_len = std.unicode.utf16LeToUtf8(&utf8_buf, utf16_slice) catch 0;
        }
    }

    const event: input.KeyEvent = .{
        .action = action,
        .key = key,
        .mods = mods,
        .utf8 = utf8_buf[0..utf8_len],
    };

    _ = self.core_surface.keyCallback(event) catch |err| {
        log.err("error in key callback: {}", .{err});
    };
}

fn handleMouseButton(self: *Surface, action: input.MouseButtonState, button: input.MouseButton) void {
    const mods = getModifiers();
    _ = self.core_surface.mouseButtonCallback(action, button, mods) catch |err| {
        log.err("error in mouse button callback: {}", .{err});
    };
}
