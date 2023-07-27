const std = @import("std");
const c = @cImport({
    @cInclude("raylib.h");
    @cInclude("raymath.h");
});

const Texture2DArrayList = std.ArrayList(c.Texture2D);

const CYCLE_FILTER_KEY = c.KEY_S;
const CLEAR_TEXTURE_KEY = c.KEY_DELETE;
const MOUSE_WHEEL_MOVE_SENSITIVITY = 0.01;
const VECTOR2ZERO = c.Vector2Zero();

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

    var default_texture_filter = c.TEXTURE_FILTER_TRILINEAR;
    var target_zoom: f32 = 1;
    var target_rotation: f32 = 0;

    var camera = c.Camera2D{
        .offset = VECTOR2ZERO,
        .target = VECTOR2ZERO,
        .rotation = 0,
        .zoom = 1,
    };

    while (!c.WindowShouldClose()) {
        if (c.IsKeyPressed(CLEAR_TEXTURE_KEY)) {
            for (textures.items) |texture| {
                c.UnloadTexture(texture);
            }
            textures.clearRetainingCapacity();
        }

        if (c.IsKeyPressed(CYCLE_FILTER_KEY)) {
            default_texture_filter = @mod(default_texture_filter + 1, 3);
            for (textures.items) |texture| {
                c.SetTextureFilter(texture, default_texture_filter);
            }
        }

        if (c.IsMouseButtonDown(c.MOUSE_LEFT_BUTTON)) {
            camera.target = c.Vector2Add(camera.target, c.Vector2Negate(c.GetMouseDelta()));
        }

        const mouse_wheel_move = c.GetMouseWheelMove();

        if (mouse_wheel_move != 0) {
            if (c.IsKeyDown(c.KEY_LEFT_SHIFT)) {
                target_rotation += mouse_wheel_move;
            } else {
                target_zoom += mouse_wheel_move * MOUSE_WHEEL_MOVE_SENSITIVITY;
                const mouse_position = c.GetMousePosition();

                camera.target = c.GetScreenToWorld2D(mouse_position, camera);
                camera.offset = mouse_position;
                camera.zoom = target_zoom;
            }
        }

        if (c.IsFileDropped()) {
            const dropped_files = c.LoadDroppedFiles();
            defer c.UnloadDroppedFiles(dropped_files);

            const dropped_files_slice = dropped_files.paths[0..dropped_files.count];
            for (dropped_files_slice) |dropped_file_path| {
                var texture = c.LoadTexture(dropped_file_path);
                if (texture.id == 0) continue;
                c.GenTextureMipmaps(&texture);

                if (texture.mipmaps == 1) {
                    std.debug.print("{s}", .{"Texture Mipmaps failed to generate!\n"});
                }
                c.SetTextureFilter(texture, default_texture_filter);
                try textures.append(texture);
            }
        }

        {
            c.BeginDrawing();
            defer c.EndDrawing();

            c.ClearBackground(c.WHITE);

            var x: i32 = 0;

            {
                c.BeginMode2D(camera);
                defer c.EndMode2D();

                for (textures.items) |texture| {
                    c.DrawTexture(texture, x, 0, c.WHITE);
                    x += texture.width;
                }
            }
        }
    }
}
