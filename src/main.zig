const std = @import("std");
const writer = std.io.getStdOut().writer();

pub fn main() !void {
    // Where we are going we need dynamic allocation
    const alloc = std.heap.page_allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    const allocator = arena.allocator();

    //I like simple lifetimes so I am just clearing all allocations together
    defer arena.deinit();

    //The client is what handles making and receiving the request for us
    var client = std.http.Client{
        .allocator = allocator,
    };

    //We can set up any headers we want
    const headers = &[_]std.http.Header{
        .{ .name = "X-Custom-Header", .value = "application" },
        // if we wanted to do a post request with JSON payload we would add
        // .{ .name = "Content-Type", .value = "application/json" },
    };

    // I moved this part into a seperate function just to keep it clean
    const response = try get("https://www.kernel.org/releases.json", headers, &client, alloc);

    // .ignore_unknown_fields will just omit any fields the server returns that are not in our type
    // otherwise an unknown field causes an error
    const result = try std.json.parseFromSlice(Result, allocator, response.items, .{ .ignore_unknown_fields = true });

    try writer.print("title: {s}\n", .{result.value.title});
}

//This is what we are going to parse the response into
const Result = struct {
    userId: i32,
    id: i32,
    title: []u8,
    body: []u8,
};

fn get(
    url: []const u8,
    headers: []const std.http.Header,
    client: *std.http.Client,
    allocator: std.mem.Allocator,
) !std.ArrayList(u8) {
    try writer.print("\nURL: {s} GET\n", .{url});

    var response_body = std.ArrayList(u8).init(allocator);

    try writer.print("Sending request...\n", .{});
    const response = try client.fetch(.{
        .method = .GET,
        .location = .{ .url = url },
        .extra_headers = headers, //put these here instead of .headers
        .response_storage = .{ .dynamic = &response_body }, // this allows us to get a response of unknown size
        // if we were doing a post request we would include the payload here
        //.payload = "<some string>"
    });

    try writer.print("Response Status: {d}\n Response Body:{s}\n", .{ response.status, response_body.items });

    // Return the response body to the caller
    return response_body;
}
