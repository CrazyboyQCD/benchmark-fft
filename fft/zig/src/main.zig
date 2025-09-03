const std = @import("std");
const fft = @import("fft.zig");
const Complex = fft.Complex;
const assert = std.debug.assert;
fn round(n: f64) f64 {
    // precision = 2
    return std.math.round(n * 100.0) / 100.0;
}

fn generate_inputs(len: usize, gpa: std.mem.Allocator) !std.ArrayList(Complex) {
    var res = try std.ArrayList(Complex).initCapacity(gpa, len);
    for (0..len) |i| {
        const theta = @as(f64, @floatFromInt(i)) / @as(f64, @floatFromInt(len)) * std.math.pi;
        const re = 1.0 * std.math.cos(10.0 * theta) + 0.5 * std.math.cos(25.0 * theta);
        const im = 1.0 * std.math.sin(10.0 * theta) + 0.5 * std.math.sin(25.0 * theta);
        res.appendAssumeCapacity(Complex.new(round(re), round(im)));
    }
    return res;
}

pub fn main() !void {
    var args = try std.process.argsWithAllocator(std.heap.page_allocator);
    defer args.deinit();
    _ = args.skip();
    const size: usize = try std.fmt.parseInt(usize, args.next().?, 10);
    var signals = try generate_inputs(@as(usize, 1) << @truncate(size), std.heap.page_allocator);
    defer signals.deinit(std.heap.page_allocator);

    var timer = try std.time.Timer.start();
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    try fft.fft(signals.items, arena.allocator());
    const end = timer.read();

    if (args.next()) |path| {
        const f = try std.fs.cwd().openFile(path, .{});
        defer f.close();
        var buf: [1024]u8 = undefined;
        var reader = f.reader(&buf);
        var input = try std.ArrayList(Complex).initCapacity(std.heap.page_allocator, signals.items.len);
        defer input.deinit(std.heap.page_allocator);

        while (reader.interface.takeDelimiterExclusive('\n')) |line| {
            var it = std.mem.splitScalar(u8, line, ',');
            const re = try std.fmt.parseFloat(f64, it.next().?);
            const im = try std.fmt.parseFloat(f64, it.next().?);
            const complex = Complex.new(re, im);
            try input.append(std.heap.page_allocator, complex);
        } else |err| if (err != error.EndOfStream) return err;

        for (0..signals.items.len) |i| {
            const s = signals.items[i];
            const t = input.items[i];
            assert(s.real == t.real and s.imag == t.imag);
        }
    } else {
        std.debug.print("execution time: {d:.3} ms\n", .{@as(f64, @floatFromInt(end)) / 1000000.0});
    }
}
