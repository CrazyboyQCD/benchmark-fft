const std = @import("std");
const allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const PI = std.math.pi;

pub const Complex = struct {
    real: f64,
    imag: f64,
    const Self = @This();
    pub fn new(real: f64, imag: f64) Self {
        return .{ .real = real, .imag = imag };
    }
};

pub fn add(a: Complex, b: Complex) Complex {
    return .{ .real = a.real + b.real, .imag = a.imag + b.imag };
}

pub fn sub(a: Complex, b: Complex) Complex {
    return .{ .real = a.real - b.real, .imag = a.imag - b.imag };
}

pub fn mul(a: Complex, b: Complex) Complex {
    return .{ .real = a.real * b.real - a.imag * b.imag, .imag = a.real * b.imag + a.imag * b.real };
}

pub fn mul_scalar(a: Complex, b: f64) Complex {
    return .{ .real = a.real * b, .imag = a.imag * b };
}

fn _fft(arr: []Complex, arena: allocator) !void {
    const n = arr.len;
    if (n == 1) {
        return;
    }

    var a0 = try std.ArrayList(Complex).initCapacity(arena, n / 2);
    var a1 = try std.ArrayList(Complex).initCapacity(arena, n / 2);

    for (0..n / 2) |i| {
        a0.appendAssumeCapacity(arr[2 * i]);
        a1.appendAssumeCapacity(arr[2 * i + 1]);
    }

    try _fft(a0.items, arena);
    try _fft(a1.items, arena);

    const d: f64 = @floatFromInt(n);
    const ang: f64 = -2.0 * PI / d;
    var w = Complex.new(1.0, 0.0);
    const wn = Complex.new(std.math.cos(ang), std.math.sin(ang));

    for (0..n / 2) |i| {
        const p = a0.items[i];
        const q = mul(w, a1.items[i]);
        arr[i] = add(p, q);
        arr[i + n / 2] = sub(p, q);
        w = mul(w, wn);
    }
}

pub fn fft(arr: []Complex, arena: allocator) !void {
    try _fft(arr, arena);
    const factor = 1.0 / @sqrt(@as(f64, @floatFromInt(arr.len)));
    for (arr) |*it| {
        it.* = mul_scalar(it.*, factor);
    }
}
