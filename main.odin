package main

import "core:fmt"
import "core:math"
import "core:thread"
import "core:c"
import "core:mem"
import rl "vendor:raylib"

WIDTH :: 1024  // 1024
HEIGHT :: 768 // 768
MAX_ITERS :: 1000

ColourScheme :: enum {
    Red,
    Blue,
    Green,
    Purple,
    Cyan,
    Monochrome,
    Grey,
    Smooth,
    Random,
}

Region :: struct {
    minX, maxX, minY, maxY: f64
}

COLOUR_SCHEME :: ColourScheme.Smooth

@(default_calling_convention="c", link_prefix="stbi_")
foreign {
	write_png :: proc(filename: cstring, w, h, comp: c.int, data: rawptr, stride_in_bytes: c.int) -> c.int ---
}

lerp :: #force_inline proc(t, v0, v1: f64) -> f64 {
    return (1 - t) * v0 + t * v1;
}

get_colour :: #force_inline proc(n: int, zn_abs: f64 = 0) -> rl.Color {
    if (n == MAX_ITERS) {
        return rl.BLACK
    }

    #partial switch COLOUR_SCHEME {
    case .Red:
        return rl.Color{u8(n) * 9 % 255, u8(n) * 2 % 255, u8(n) * 2 % 255, 255}
    case .Blue:
        return rl.Color{u8(n) * 2 % 255, u8(n) * 2 % 255, u8(n) * 10 % 255, 255}
    case .Green:
        return rl.Color{u8(n) * 2 % 255, u8(n) * 10 % 255, u8(n) * 2 % 255, 255}
    case .Purple:
        return rl.Color{u8(n) * 8 % 255, u8(n) * 2 % 255, u8(n) * 10 % 255, 255}
    case .Cyan:
        return rl.Color{u8(n) * 3 % 255, u8(n) * 6 % 255, u8(n) * 10 % 255, 255}
    case .Grey:
        return rl.Color{u8(n) * 5 % 255, u8(n) * 5 % 255, u8(n) * 5 % 255, 255}
    case .Monochrome:
        return rl.WHITE
    case .Smooth:
        nsmooth := f64(n) + 1.0 - math.ln(math.ln(zn_abs)) / math.LN2
        return rl.ColorFromHSV(f32(nsmooth), 1.0, 1.0)
    case:
        return rl.Color{u8(n) * u8(rl.GetRandomValue(0, 10)) % 255, u8(n) * u8(rl.GetRandomValue(0, 10)) % 255, u8(n) * u8(rl.GetRandomValue(0, 10)) % 255, 255}
    }
}

update :: proc(region: ^Region, scale: f64, pixels: [dynamic]rl.Color) -> bool {
    new_cx := lerp(f64(rl.GetMouseX()) / f64(WIDTH), region.minX, region.maxX)
    new_cy := lerp(f64(rl.GetMouseY()) / f64(HEIGHT), region.minY, region.maxY)

    old_region_width := region.maxX - region.minX
    old_region_height := region.maxY - region.minY

    if rl.IsMouseButtonPressed(.LEFT) {
        region.minX = new_cx - old_region_width / (2 / scale)
        region.maxX = new_cx + old_region_width / (2 / scale)
        region.minY = new_cy - old_region_height / (2 / scale)
        region.maxY = new_cy + old_region_height / (2 / scale)
        return true
    }

    if rl.IsMouseButtonPressed(.MIDDLE) {
        region^ = Region{-2.00, 0.47, -1.12, 1.12}
        return true
    }

    if rl.IsMouseButtonPressed(.RIGHT) {
        region.minX = new_cx - old_region_width / (2 * scale)
        region.maxX = new_cx + old_region_width / (2 * scale)
        region.minY = new_cy - old_region_height / (2 * scale)
        region.maxY = new_cy + old_region_height / (2 * scale)
        return true
    }

    if rl.IsKeyPressed(.S) {
        raw_pixels := transmute(mem.Raw_Dynamic_Array)pixels
        if write_png("mandelbrot-set.png", WIDTH, HEIGHT, 4, raw_pixels.data, WIDTH * size_of(rl.Color)) == 0 {
            fmt.eprintln("error, could not save to mandelbrot-set.png")
        }
    }

    return false
}

mandelbrot_set :: proc(region: Region, updated: bool, pixels: ^[dynamic]rl.Color) {
    for py in 0..<HEIGHT {
        for px in 0..<WIDTH {
            x0 := lerp(f64(px) / f64(WIDTH), region.minX, region.maxX)
            y0 := lerp(f64(py) / f64(HEIGHT), region.minY, region.maxY)

            x, x2, y, y2: f64 = 0.0, 0.0, 0.0, 0.0

            i := 0
            for x2 + y2 <= 4 && i < MAX_ITERS {
                y = 2 * x * y + y0
                x = x2 - y2 + x0
                x2 = x * x
                y2 = y * y
                i += 1
            }

            colour := i == MAX_ITERS ? rl.BLACK : get_colour(i, math.sqrt(x2 + y2))
            pixels[WIDTH * py + px] = colour
        }
    }
}

main :: proc() {
    rl.InitWindow(WIDTH, HEIGHT, "mandelbrot yuh")
    defer rl.CloseWindow()

    region := Region{-2.00, 0.47, -1.12, 1.12}
    scale := 0.3 

    startup := true
    pixels: [dynamic]rl.Color; resize(&pixels, HEIGHT * WIDTH)

    mandelbrot_set_texture: rl.Texture

    for !rl.WindowShouldClose() {
        updated := update(&region, scale, pixels)
        if startup || updated {
            mandelbrot_set(region, updated, &pixels)

            if startup {
                startup = false
            } else {
                rl.UnloadTexture(mandelbrot_set_texture)
            }

            raw_pixels := transmute(mem.Raw_Dynamic_Array)pixels
            mandelbrot_set_image := rl.Image {
                data = raw_pixels.data,
                width = i32(WIDTH),
                height = i32(HEIGHT),
                format = rl.PixelFormat.UNCOMPRESSED_R8G8B8A8,
                mipmaps = 1,
            }
            mandelbrot_set_texture = rl.LoadTextureFromImage(mandelbrot_set_image)
        }

        rl.BeginDrawing()
            rl.DrawTexture(mandelbrot_set_texture, 0, 0, rl.WHITE)
        rl.EndDrawing()
    }
}
