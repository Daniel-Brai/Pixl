const std = @import("std");
const c = @cImport({
    @cInclude("raylib.h");
    @cInclude("raymath.h");
});

const Texture2DArrayList = std.ArrayList(c.Texture2D);

const APPLICATION_TITLE = "Pixl";
const VECTOR2ZERO = c.Vector2Zero();
const CYCLE_FILTER_KEY = c.KEY_S;
const CLEAR_TEXTURE_KEY = c.KEY_DELETE;
const TOGGLE_FULLSCREEN_KEY = c.KEY_F;
const ZOOM_SENSITIVITY = 0.08;
const ZOOM_DURATION = 0.2;
const ROTATION_SENSITIVITY = 15;
const ROTATION_DURATION = 0.2;

fn focusCamera(camera: *c.Camera2D, screen_position: c.Vector2) void {
    camera.*.target = c.GetScreenToWorld2D(screen_position, camera.*);
    camera.*.target = screen_position;
}

pub fn main() error{OutOfMemory}!void {
    c.SetConfigFlags(c.FLAG_WINDOW_RESIZABLE | c.FLAG_VSYNC_HINT);
    c.InitWindow(750, 500, APPLICATION_TITLE);
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
        if (c.IsKeyPressed(TOGGLE_FULLSCREEN_KEY)) {
            c.ToggleFullscreen();
        }

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

        const mouse_wheel_move = c.GetMouseWheelMove();
        const mouse_position = c.GetMousePosition();

        if (mouse_wheel_move != 0) {
            if (c.IsKeyDown(c.KEY_LEFT_SHIFT)) {
                target_rotation += mouse_wheel_move * ROTATION_SENSITIVITY;
                focusCamera(&camera, mouse_position);
            } else {
                target_zoom = std.math.max(target_zoom + mouse_wheel_move * ZOOM_SENSITIVITY, ZOOM_SENSITIVITY);
                focusCamera(&camera, mouse_position);
            }
        }

        if (c.IsMouseButtonDown(c.MOUSE_MIDDLE_BUTTON)) {
            focusCamera(&camera, mouse_position);
            target_zoom = 1;
        }

        const FRAME_DELTA_TIME = c.GetFrameTime();

        camera.zoom *= std.math.pow(f32, target_zoom / camera.zoom, FRAME_DELTA_TIME / ZOOM_DURATION);
        camera.rotation = c.Lerp(camera.rotation, target_rotation, FRAME_DELTA_TIME / ROTATION_DURATION);

        if (c.IsMouseButtonDown(c.MOUSE_LEFT_BUTTON)) {
            const translation = c.Vector2Negate(c.Vector2Scale(c.GetMouseDelta(), 1 / target_zoom));
            camera.target = c.Vector2Add(camera.target, c.Vector2Rotate(translation, -camera.rotation * c.DEG2RAD));
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
