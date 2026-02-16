/// Win32 API declarations needed for the Win32 application runtime.
/// This supplements std.os.windows and src/os/windows.zig with
/// windowing, GDI, and WGL functions.
const std = @import("std");
const windows = std.os.windows;

pub const BOOL = windows.BOOL;
pub const DWORD = windows.DWORD;
pub const UINT = windows.UINT;
pub const LONG = windows.LONG;
pub const WORD = windows.WORD;
pub const BYTE = windows.BYTE;
pub const LPARAM = windows.LPARAM;
pub const WPARAM = windows.WPARAM;
pub const LRESULT = windows.LRESULT;
pub const HINSTANCE = windows.HINSTANCE;
pub const HMODULE = windows.HMODULE;
pub const HANDLE = windows.HANDLE;
pub const HMENU = *opaque {};
pub const HDC = *opaque {};
pub const HGLRC = *opaque {};
pub const HWND = *opaque {};
pub const HICON = *opaque {};
pub const HCURSOR = *opaque {};
pub const HBRUSH = *opaque {};
pub const HGDIOBJ = *opaque {};
pub const ATOM = u16;
pub const COLORREF = DWORD;

pub const TRUE: BOOL = 1;
pub const FALSE: BOOL = 0;

// ---- Window Styles ----
pub const WS_OVERLAPPED = 0x00000000;
pub const WS_CAPTION = 0x00C00000;
pub const WS_SYSMENU = 0x00080000;
pub const WS_THICKFRAME = 0x00040000;
pub const WS_MINIMIZEBOX = 0x00020000;
pub const WS_MAXIMIZEBOX = 0x00010000;
pub const WS_OVERLAPPEDWINDOW = WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX;
pub const WS_VISIBLE = 0x10000000;
pub const WS_EX_APPWINDOW = 0x00040000;

// ---- Class Styles ----
pub const CS_HREDRAW = 0x0002;
pub const CS_VREDRAW = 0x0001;
pub const CS_OWNDC = 0x0020;

// ---- Window Messages ----
pub const WM_NULL = 0x0000;
pub const WM_DESTROY = 0x0002;
pub const WM_SIZE = 0x0005;
pub const WM_SETFOCUS = 0x0007;
pub const WM_KILLFOCUS = 0x0008;
pub const WM_CLOSE = 0x0010;
pub const WM_QUIT = 0x0012;
pub const WM_PAINT = 0x000F;
pub const WM_ERASEBKGND = 0x0014;
pub const WM_KEYDOWN = 0x0100;
pub const WM_KEYUP = 0x0101;
pub const WM_CHAR = 0x0102;
pub const WM_SYSKEYDOWN = 0x0104;
pub const WM_SYSKEYUP = 0x0105;
pub const WM_SYSCHAR = 0x0106;
pub const WM_MOUSEMOVE = 0x0200;
pub const WM_LBUTTONDOWN = 0x0201;
pub const WM_LBUTTONUP = 0x0202;
pub const WM_RBUTTONDOWN = 0x0204;
pub const WM_RBUTTONUP = 0x0205;
pub const WM_MBUTTONDOWN = 0x0207;
pub const WM_MBUTTONUP = 0x0208;
pub const WM_MOUSEWHEEL = 0x020A;
pub const WM_MOUSEHWHEEL = 0x020E;
pub const WM_DPICHANGED = 0x02E0;
pub const WM_USER = 0x0400;
pub const WM_APP = 0x8000;

// Custom app message for cross-thread wakeup
pub const WM_APP_WAKEUP = WM_APP + 1;

// ---- ShowWindow Commands ----
pub const SW_SHOW = 5;
pub const SW_SHOWDEFAULT = 10;

// ---- Cursor ----
pub const IDC_ARROW = @as([*:0]const u16, @ptrFromInt(32512));

// ---- Color ----
pub const COLOR_WINDOW = 5;

// ---- Pixel Format ----
pub const PFD_DRAW_TO_WINDOW = 0x00000004;
pub const PFD_SUPPORT_OPENGL = 0x00000020;
pub const PFD_DOUBLEBUFFER = 0x00000001;
pub const PFD_TYPE_RGBA = 0;
pub const PFD_MAIN_PLANE = 0;

// ---- Virtual Key Codes ----
pub const VK_SHIFT = 0x10;
pub const VK_CONTROL = 0x11;
pub const VK_MENU = 0x12; // Alt
pub const VK_CAPITAL = 0x14; // Caps Lock
pub const VK_NUMLOCK = 0x90;
pub const VK_LWIN = 0x5B;
pub const VK_RWIN = 0x5C;

// ---- Default Window Position ----
pub const CW_USEDEFAULT: i32 = @bitCast(@as(u32, 0x80000000));

// ---- HWND_MESSAGE for message-only windows ----
pub const HWND_MESSAGE: ?HWND = @ptrFromInt(@as(usize, @bitCast(@as(isize, -3))));

// ---- Structures ----
pub const WNDCLASSEXW = extern struct {
    cbSize: UINT = @sizeOf(WNDCLASSEXW),
    style: UINT = 0,
    lpfnWndProc: WNDPROC = undefined,
    cbClsExtra: c_int = 0,
    cbWndExtra: c_int = 0,
    hInstance: ?HINSTANCE = null,
    hIcon: ?HICON = null,
    hCursor: ?HCURSOR = null,
    hbrBackground: ?HBRUSH = null,
    lpszMenuName: ?[*:0]const u16 = null,
    lpszClassName: [*:0]const u16 = undefined,
    hIconSm: ?HICON = null,
};

pub const WNDPROC = *const fn (HWND, UINT, WPARAM, LPARAM) callconv(.winapi) LRESULT;

pub const MSG = extern struct {
    hwnd: ?HWND,
    message: UINT,
    wParam: WPARAM,
    lParam: LPARAM,
    time: DWORD,
    pt: POINT,
};

pub const POINT = extern struct {
    x: LONG = 0,
    y: LONG = 0,
};

pub const RECT = extern struct {
    left: LONG = 0,
    top: LONG = 0,
    right: LONG = 0,
    bottom: LONG = 0,
};

pub const PIXELFORMATDESCRIPTOR = extern struct {
    nSize: WORD = @sizeOf(PIXELFORMATDESCRIPTOR),
    nVersion: WORD = 1,
    dwFlags: DWORD = 0,
    iPixelType: BYTE = 0,
    cColorBits: BYTE = 0,
    cRedBits: BYTE = 0,
    cRedShift: BYTE = 0,
    cGreenBits: BYTE = 0,
    cGreenShift: BYTE = 0,
    cBlueBits: BYTE = 0,
    cBlueShift: BYTE = 0,
    cAlphaBits: BYTE = 0,
    cAlphaShift: BYTE = 0,
    cAccumBits: BYTE = 0,
    cAccumRedBits: BYTE = 0,
    cAccumGreenBits: BYTE = 0,
    cAccumBlueBits: BYTE = 0,
    cAccumAlphaBits: BYTE = 0,
    cDepthBits: BYTE = 0,
    cStencilBits: BYTE = 0,
    cAuxBuffers: BYTE = 0,
    iLayerType: BYTE = 0,
    bReserved: BYTE = 0,
    dwLayerMask: DWORD = 0,
    dwVisibleMask: DWORD = 0,
    dwDamageMask: DWORD = 0,
};

// ---- Clipboard ----
pub const CF_UNICODETEXT: UINT = 13;

// ---- Extern functions: user32 ----
pub extern "user32" fn RegisterClassExW(lpWndClass: *const WNDCLASSEXW) callconv(.winapi) ATOM;
pub extern "user32" fn CreateWindowExW(
    dwExStyle: DWORD,
    lpClassName: [*:0]const u16,
    lpWindowName: [*:0]const u16,
    dwStyle: DWORD,
    X: i32,
    Y: i32,
    nWidth: i32,
    nHeight: i32,
    hWndParent: ?HWND,
    hMenu: ?HMENU,
    hInstance: ?HINSTANCE,
    lpParam: ?*anyopaque,
) callconv(.winapi) ?HWND;
pub extern "user32" fn DestroyWindow(hWnd: HWND) callconv(.winapi) BOOL;
pub extern "user32" fn ShowWindow(hWnd: HWND, nCmdShow: c_int) callconv(.winapi) BOOL;
pub extern "user32" fn UpdateWindow(hWnd: HWND) callconv(.winapi) BOOL;
pub extern "user32" fn DefWindowProcW(hWnd: HWND, Msg: UINT, wParam: WPARAM, lParam: LPARAM) callconv(.winapi) LRESULT;
pub extern "user32" fn PostQuitMessage(nExitCode: c_int) callconv(.winapi) void;
pub extern "user32" fn GetMessageW(lpMsg: *MSG, hWnd: ?HWND, wMsgFilterMin: UINT, wMsgFilterMax: UINT) callconv(.winapi) BOOL;
pub extern "user32" fn TranslateMessage(lpMsg: *const MSG) callconv(.winapi) BOOL;
pub extern "user32" fn DispatchMessageW(lpMsg: *const MSG) callconv(.winapi) LRESULT;
pub extern "user32" fn PostMessageW(hWnd: HWND, Msg: UINT, wParam: WPARAM, lParam: LPARAM) callconv(.winapi) BOOL;
pub extern "user32" fn GetClientRect(hWnd: HWND, lpRect: *RECT) callconv(.winapi) BOOL;
pub extern "user32" fn GetCursorPos(lpPoint: *POINT) callconv(.winapi) BOOL;
pub extern "user32" fn ScreenToClient(hWnd: HWND, lpPoint: *POINT) callconv(.winapi) BOOL;
pub extern "user32" fn SetWindowTextW(hWnd: HWND, lpString: [*:0]const u16) callconv(.winapi) BOOL;
pub extern "user32" fn LoadCursorW(hInstance: ?HINSTANCE, lpCursorName: [*:0]const u16) callconv(.winapi) ?HCURSOR;
pub extern "user32" fn GetDpiForWindow(hwnd: HWND) callconv(.winapi) UINT;
pub extern "user32" fn GetKeyState(nVirtKey: c_int) callconv(.winapi) i16;
pub extern "user32" fn GetKeyboardState(lpKeyState: *[256]u8) callconv(.winapi) BOOL;
pub extern "user32" fn ToUnicode(
    wVirtKey: UINT,
    wScanCode: UINT,
    lpKeyState: *const [256]u8,
    pwszBuff: [*]u16,
    cchBuff: c_int,
    wFlags: UINT,
) callconv(.winapi) c_int;
pub extern "user32" fn OpenClipboard(hWndNewOwner: ?HWND) callconv(.winapi) BOOL;
pub extern "user32" fn CloseClipboard() callconv(.winapi) BOOL;
pub extern "user32" fn GetClipboardData(uFormat: UINT) callconv(.winapi) ?HANDLE;
pub extern "user32" fn SetClipboardData(uFormat: UINT, hMem: HANDLE) callconv(.winapi) ?HANDLE;
pub extern "user32" fn EmptyClipboard() callconv(.winapi) BOOL;
pub extern "user32" fn SetWindowLongPtrW(hWnd: HWND, nIndex: c_int, dwNewLong: usize) callconv(.winapi) usize;
pub extern "user32" fn GetWindowLongPtrW(hWnd: HWND, nIndex: c_int) callconv(.winapi) usize;
pub extern "user32" fn ValidateRect(hWnd: ?HWND, lpRect: ?*const RECT) callconv(.winapi) BOOL;
pub extern "user32" fn FillRect(hDC: HDC, lprc: *const RECT, hbr: HBRUSH) callconv(.winapi) c_int;

pub const GWLP_USERDATA: c_int = -21;

// ---- Extern functions: gdi32 ----
pub extern "gdi32" fn GetDC(hWnd: ?HWND) callconv(.winapi) ?HDC;
pub extern "gdi32" fn ReleaseDC(hWnd: ?HWND, hDC: HDC) callconv(.winapi) c_int;
pub extern "gdi32" fn ChoosePixelFormat(hdc: HDC, ppfd: *const PIXELFORMATDESCRIPTOR) callconv(.winapi) c_int;
pub extern "gdi32" fn SetPixelFormat(hdc: HDC, format: c_int, ppfd: *const PIXELFORMATDESCRIPTOR) callconv(.winapi) BOOL;
pub extern "gdi32" fn SwapBuffers(hdc: HDC) callconv(.winapi) BOOL;
pub extern "gdi32" fn CreateSolidBrush(color: COLORREF) callconv(.winapi) ?HBRUSH;
pub extern "gdi32" fn DeleteObject(ho: HGDIOBJ) callconv(.winapi) BOOL;

// ---- Extern functions: opengl32 (WGL) ----
pub extern "opengl32" fn wglCreateContext(hdc: HDC) callconv(.winapi) ?HGLRC;
pub extern "opengl32" fn wglMakeCurrent(hdc: ?HDC, hglrc: ?HGLRC) callconv(.winapi) BOOL;
pub extern "opengl32" fn wglDeleteContext(hglrc: HGLRC) callconv(.winapi) BOOL;
pub extern "opengl32" fn wglGetCurrentDC() callconv(.winapi) ?HDC;

// ---- Extern functions: kernel32 ----
pub extern "kernel32" fn GetModuleHandleW(lpModuleName: ?[*:0]const u16) callconv(.winapi) ?HINSTANCE;
pub extern "kernel32" fn GlobalAlloc(uFlags: UINT, dwBytes: usize) callconv(.winapi) ?HANDLE;
pub extern "kernel32" fn GlobalLock(hMem: HANDLE) callconv(.winapi) ?[*]u8;
pub extern "kernel32" fn GlobalUnlock(hMem: HANDLE) callconv(.winapi) BOOL;
pub extern "kernel32" fn GlobalFree(hMem: HANDLE) callconv(.winapi) ?HANDLE;

pub const GMEM_MOVEABLE: UINT = 0x0002;

// ---- Extern functions: dwmapi (Desktop Window Manager) ----
pub extern "dwmapi" fn DwmSetWindowAttribute(
    hwnd: HWND,
    dwAttribute: DWORD,
    pvAttribute: *const anyopaque,
    cbAttribute: DWORD,
) callconv(.winapi) LONG;

// DWM Window Attributes
pub const DWMWA_WINDOW_CORNER_PREFERENCE: DWORD = 33;

// Window corner preferences (Windows 11+)
pub const DWMWCP_DEFAULT: DWORD = 0;
pub const DWMWCP_DONOTROUND: DWORD = 1;
pub const DWMWCP_ROUND: DWORD = 2;
pub const DWMWCP_ROUNDSMALL: DWORD = 3;

// ---- Helpers ----
pub fn RGB(r: u8, g: u8, b: u8) COLORREF {
    return @as(COLORREF, r) | (@as(COLORREF, g) << 8) | (@as(COLORREF, b) << 16);
}

pub fn loword(l: anytype) u16 {
    return @truncate(@as(u64, @bitCast(@as(i64, @intCast(l)))));
}

pub fn hiword(l: anytype) u16 {
    return @truncate(@as(u64, @bitCast(@as(i64, @intCast(l)))) >> 16);
}

pub fn GET_X_LPARAM(lp: LPARAM) i16 {
    return @bitCast(loword(lp));
}

pub fn GET_Y_LPARAM(lp: LPARAM) i16 {
    return @bitCast(hiword(lp));
}

pub fn GET_WHEEL_DELTA_WPARAM(wp: WPARAM) i16 {
    return @bitCast(hiword(wp));
}
