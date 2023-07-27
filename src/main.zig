const std = @import("std");
const c = @cImport({
    @cInclude("raylib.h");
});

pub fn main() void {
    c.InitWindow(750, 500, "Pixl");
    defer c.CloseWindow();

    while (!c.WindowShouldClose()) {
        c.BeginDrawing();
        defer c.EndDrawing();
    }
}
