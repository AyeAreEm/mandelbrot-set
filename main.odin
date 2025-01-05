package main

import "core:fmt"
import "core:math"
import "core:thread"
import rl "vendor:raylib"
import stbi "vendor:stb/image"

WIDTH :: 1024
HEIGHT :: 768
MAX_ITERS :: 250

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

update :: proc(region: ^Region, scale: f64) {
    new_cx := lerp(f64(rl.GetMouseX()) / f64(WIDTH), region.minX, region.maxX)
    new_cy := lerp(f64(rl.GetMouseY()) / f64(HEIGHT), region.minY, region.maxY)

    old_region_width := region.maxX - region.minX
    old_region_height := region.maxY - region.minY

    if rl.IsMouseButtonPressed(.LEFT) {
        region.minX = new_cx - old_region_width / (2 / scale)
        region.maxX = new_cx + old_region_width / (2 / scale)
        region.minY = new_cy - old_region_height / (2 / scale)
        region.maxY = new_cy + old_region_height / (2 / scale)
    }

    if rl.IsMouseButtonPressed(.MIDDLE) {
        region^ = Region{-2.00, 0.47, -1.12, 1.12}
    }

    if rl.IsMouseButtonPressed(.RIGHT) {
        region.minX = new_cx - old_region_width / (2 * scale)
        region.maxX = new_cx + old_region_width / (2 * scale)
        region.minY = new_cy - old_region_height / (2 * scale)
        region.maxY = new_cy + old_region_height / (2 * scale)
    }
}

mandelbrot_set :: proc(region: Region) {
    rl.BeginDrawing()
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
            rl.DrawPixel(i32(px), i32(py), colour)
        }
    }
    rl.EndDrawing()
}

main :: proc() {
    rl.InitWindow(WIDTH, HEIGHT, "mandelbrot yuh")
    defer rl.CloseWindow()

    region := Region{-2.00, 0.47, -1.12, 1.12}
    scale := 0.3 

    for !rl.WindowShouldClose() {
        update(&region, scale)
        mandelbrot_set(region)
    }
}
