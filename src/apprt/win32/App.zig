/// Win32 application runtime. This is the main entrypoint for the
/// Windows native application using native Win32 APIs.
const App = @This();

const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const apprt = @import("../../apprt.zig");
const CoreApp = @import("../../App.zig");
const CoreSurface = @import("../../Surface.zig");
const configpkg = @import("../../config.zig");
const Surface = @import("Surface.zig");
const w = @import("win32.zig");

const log = std.log.scoped(.win32);

core_app: *CoreApp,

/// The application configuration. Loaded at startup, owned by the App.
config: configpkg.Config,

/// The message-only window used for cross-thread wakeup.
msg_hwnd: ?w.HWND = null,

/// The registered window class atom.
class_atom: w.ATOM = 0,

/// The application instance handle.
hinstance: w.HINSTANCE = undefined,

/// The single surface (MVP: one window only).
surface: ?Surface = null,

pub fn init(
    self: *App,
    core_app: *CoreApp,
    opts: struct {},
) !void {
    _ = opts;

    const alloc = core_app.alloc;

    // Load our configuration.
    var config = configpkg.Config.load(alloc) catch |err| err: {
        var def: configpkg.Config = try .default(alloc);
        errdefer def.deinit();
        try def.addDiagnosticFmt(
            "error loading user configuration: {}",
            .{err},
        );
        break :err def;
    };
    errdefer config.deinit();

    // Notify the core app of the initial configuration.
    try core_app.updateConfig(self, &config);

    const hinstance = w.GetModuleHandleW(null) orelse return error.NoModuleHandle;

    // Register the main window class
    const class_name = std.unicode.utf8ToUtf16LeStringLiteral("GhosttyWindow");
    const wc: w.WNDCLASSEXW = .{
        .style = w.CS_HREDRAW | w.CS_VREDRAW | w.CS_OWNDC,
        .lpfnWndProc = &Surface.wndProc,
        .hInstance = hinstance,
        .hCursor = w.LoadCursorW(null, w.IDC_ARROW),
        .hbrBackground = null,
        .lpszClassName = class_name,
    };
    const atom = w.RegisterClassExW(&wc);
    if (atom == 0) return error.RegisterClassFailed;

    // Register a separate class for the message-only window
    const msg_class_name = std.unicode.utf8ToUtf16LeStringLiteral("GhosttyMsg");
    const msg_wc: w.WNDCLASSEXW = .{
        .lpfnWndProc = &msgWndProc,
        .hInstance = hinstance,
        .lpszClassName = msg_class_name,
    };
    _ = w.RegisterClassExW(&msg_wc);

    // Create message-only window for cross-thread wakeup
    const msg_hwnd = w.CreateWindowExW(
        0,
        msg_class_name,
        std.unicode.utf8ToUtf16LeStringLiteral(""),
        0,
        0,
        0,
        0,
        0,
        w.HWND_MESSAGE,
        null,
        hinstance,
        null,
    ) orelse return error.CreateMsgWindowFailed;

    self.* = .{
        .core_app = core_app,
        .config = config,
        .msg_hwnd = msg_hwnd,
        .class_atom = atom,
        .hinstance = hinstance,
    };

    // Store App pointer in the message-only window's user data
    _ = w.SetWindowLongPtrW(msg_hwnd, w.GWLP_USERDATA, @intFromPtr(self));
}

/// Create the main terminal surface/window.
fn createSurface(self: *App) !void {
    self.surface = .{};
    errdefer self.surface = null;
    try self.surface.?.init(self);
}

pub fn run(self: *App) !void {
    // Create the initial terminal window
    try self.createSurface();

    // Win32 message loop
    var msg: w.MSG = undefined;
    while (true) {
        const ret = w.GetMessageW(&msg, null, 0, 0);
        if (ret == 0) break; // WM_QUIT
        if (ret < 0) return error.GetMessageFailed;
        _ = w.TranslateMessage(&msg);
        _ = w.DispatchMessageW(&msg);
    }
}

pub fn terminate(self: *App) void {
    if (self.surface) |*s| {
        s.deinit();
        self.surface = null;
    }
    if (self.msg_hwnd) |hwnd| {
        _ = w.DestroyWindow(hwnd);
        self.msg_hwnd = null;
    }
    self.config.deinit();
}

/// Called by CoreApp to wake up the event loop from any thread.
/// This is thread-safe -- PostMessageW can be called from any thread.
pub fn wakeup(self: *App) void {
    if (self.msg_hwnd) |hwnd| {
        _ = w.PostMessageW(hwnd, w.WM_APP_WAKEUP, 0, 0);
    }
}

pub fn performAction(
    self: *App,
    target: apprt.Target,
    comptime action: apprt.Action.Key,
    value: apprt.Action.Value(action),
) !bool {
    _ = self;
    _ = target;
    _ = value;
    // MVP: most actions are unhandled. Return false so the core
    // knows we didn't handle it.
    return false;
}

pub fn redrawInspector(_: *App, _: *Surface) void {}

pub fn performIpc(
    _: Allocator,
    _: apprt.ipc.Target,
    comptime action: apprt.ipc.Action.Key,
    _: apprt.ipc.Action.Value(action),
) !bool {
    return false;
}

/// Window procedure for the message-only window.
/// Handles WM_APP_WAKEUP to drain the core app mailbox.
fn msgWndProc(hwnd: w.HWND, msg: w.UINT, wparam: w.WPARAM, lparam: w.LPARAM) callconv(.winapi) w.LRESULT {
    switch (msg) {
        w.WM_APP_WAKEUP => {
            const ptr = w.GetWindowLongPtrW(hwnd, w.GWLP_USERDATA);
            if (ptr != 0) {
                const app: *App = @ptrFromInt(ptr);
                app.core_app.tick(app) catch |err| {
                    log.err("error ticking core app: {}", .{err});
                };
            }
            return 0;
        },
        else => return w.DefWindowProcW(hwnd, msg, wparam, lparam),
    }
}
