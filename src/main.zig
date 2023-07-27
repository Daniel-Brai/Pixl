const std = @import("std");
const c = @cImport({
    @cInclude("raylib.h");
});

const Texture2DArrayList = std.ArrayList(c.Texture2D);

pub fn main() error{OutOfMemory}!void {
    c.SetConfigFlags(c.FLAG_WINDOW_RESIZABLE | c.FLAG_VSYNC_HINT);
    c.InitWindow(750, 500, "Pixl");
    defer c.CloseWindow();

    var arena = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    defer arena.deinit();

    var allocator = arena.allocator();

    var textures = Texture2DArrayList.init(allocator);
    defer {
        for (textures.items) |texture| {
            c.UnloadTexture(texture);
        }
        textures.deinit();
    }

    while (!c.WindowShouldClose()) {
        if (c.IsFileDropped()) {
            const dropped_files = c.LoadDroppedFiles();
            defer c.UnloadDroppedFiles(dropped_files);

            const dropped_files_slice = dropped_files.paths[0..dropped_files.count];
            for (dropped_files_slice) |dropped_file_path| {
                const texture = c.LoadTexture(dropped_file_path);
                if (texture.id == 0) continue;
                try textures.append(texture);
            }
        }

        {
            c.BeginDrawing();
            defer c.EndDrawing();
        }
    }
}
