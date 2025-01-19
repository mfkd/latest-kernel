const std = @import("std");
const writer = std.io.getStdOut().writer();

pub const Patch = struct {
    full: ?[]const u8,
    incremental: ?[]const u8,
};

pub const Released = struct {
    timestamp: i64,
    isodate: []const u8,
};

pub const Release = struct {
    moniker: []const u8,
    version: []const u8,
    iseol: bool,
    released: Released,
    source: ?[]const u8,
    pgp: ?[]const u8,
    patch: Patch,
    changelog: ?[]const u8,
    gitweb: ?[]const u8,
    diffview: ?[]const u8,
};

pub const KernelReleases = struct {
    releases: []const Release,
    latest_stable: struct {
        version: []const u8,
    },
};

const HTTPStatusError = error{
    StatusNotOK,
};

const kernel_releases_url = "https://www.kernel.org/releases.json";

pub fn main() !void {
    const alloc = std.heap.page_allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    const allocator = arena.allocator();

    defer arena.deinit();

    var client = std.http.Client{
        .allocator = allocator,
    };

    const headers = &[_]std.http.Header{
        .{ .name = "X-Custom-Header", .value = "application" },
    };

    const response = try get(kernel_releases_url, headers, &client, alloc);

    const result = try std.json.parseFromSlice(KernelReleases, allocator, response.items, .{ .ignore_unknown_fields = true });
    defer result.deinit();

    try writer.print("{s}\n", .{result.value.latest_stable.version});
}

fn get(
    url: []const u8,
    headers: []const std.http.Header,
    client: *std.http.Client,
    allocator: std.mem.Allocator,
) !std.ArrayList(u8) {
    var response_body = std.ArrayList(u8).init(allocator);

    const response = try client.fetch(.{
        .method = .GET,
        .location = .{ .url = url },
        .extra_headers = headers,
        .response_storage = .{ .dynamic = &response_body },
    });

    if (response.status != std.http.Status.ok) {
        try writer.print("Response Status: {d}\n", .{response.status});
        return HTTPStatusError.StatusNotOK;
    }

    return response_body;
}
