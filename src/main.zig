const std = @import("std");

const Base64 = struct {
    _table: *const [64]u8,

    pub fn init() Base64 {
        const upper = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
        const lower = "abcdefghijklmnopqrstuvwxyz";
        const number_symb = "0123456789+/";

        return Base64{
            ._table = upper ++ lower ++ number_symb,
        };
    }

    fn _char_at(self: Base64, index: usize) u8 {
        return self._table[index];
    }

    fn _index_of(char: u8) u8 {
        switch(char) {
            'A'...'Z' => {
                return char - 'A';
            },
            'a'...'z' => {
                return (char - 'a') + 26;
            },
            '0'...'9' => {
                return (char - '0') + 52;
            },
            '+' => return 62,
            '/' => return 63,
            else => return 64,
        }
    }

    fn _calc_encode_length(input: []const u8) !usize {
        if (input.len < 3) {
            return 4;
        }

        const n_groups: usize = try std.math.divCeil(usize, input.len, 3);

        return n_groups * 4;
    }

    fn _calc_decode_length(input: []const u8) !usize {
        if (input.len < 4) {
            return 3;
        }

        const n_groups: usize = try std.math.divFloor(usize, input.len, 4);

        var multiple_groups: usize = n_groups * 3;
        var i: usize = input.len - 1;
        while (i > 0) : (i -= 1) {
            if (input[i] == '=') {
                multiple_groups -= 1;
            } else {
                break;
            }
        }

        return multiple_groups;
    }

    pub fn encode(self: Base64, allocator: std.mem.Allocator, input: []const u8) ![]u8 {
        if (input.len == 0) {
            return "";
        }

        const n_out = try _calc_encode_length(input);
        var out = try allocator.alloc(u8, n_out);

        var i: usize = 0;
        var out_index: usize = 0;
        var remaining: usize = 0;
        while (i < input.len) : (i += 1) {
            if (i + 3 > input.len) {
                remaining = input.len - i;
                break;
            }

            // Transform byte 1
            out[out_index] = self._char_at(input[i] >> 2);
            out_index += 1;

            // Transform byte 2
            out[out_index] = self._char_at(((input[i] & 0x03) << 4) + (input[i + 1] >> 4));
            out_index += 1;
            i += 1;

            // Transform byte 3
            out[out_index] = self._char_at(((input[i] & 0x0f) << 2) + (input[i + 1] >> 6));
            out_index += 1;
            i += 1;
            out[out_index] = self._char_at(input[i] & 0x3f);
            out_index += 1;
        }

        if (remaining == 1) {
            out[out_index] = self._char_at(input[i] >> 2);
            out_index += 1;

            out[out_index] = self._char_at((input[i] & 0x03) << 4);
            out_index += 1;

            out[out_index] = '=';
            out_index += 1;

            out[out_index] = '=';
            out_index += 1;
        }

        if (remaining == 2) {
            out[out_index] = self._char_at(input[i] >> 2);
            out_index += 1;

            out[out_index] = self._char_at(((input[i] & 0x03) << 4) + (input[i + 1] >> 4));
            out_index += 1;
            i += 1;

            out[out_index] = self._char_at((input[i] & 0x0f) << 2);
            out_index += 1;

            out[out_index] = '=';
            out_index += 1;
        }

        return out;
    }

    pub fn decode(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
        if (input.len == 0) {
            return "";
        }

        if (input.len % 4 != 0) {
            @panic("Invalid input: input length must be a multiple of 4");
        }

        // Calculate length of decoded output and allocate enough space
        const n_out = try _calc_decode_length(input);
        var out = try allocator.alloc(u8, n_out);

        var i: usize = 0;
        var out_index: usize = 0;
        while (i < input.len) : (i += 4) {
            const eq_count = std.mem.count(u8, input[i..i+4], "=");

            if ((eq_count > 0 and (input.len - i) > 4) or eq_count > 2) {
                @panic("Invalid input: invalid Base64 input string");
            }

            // Produce byte 1
            const ch_1 = _index_of(input[i]);
            const ch_2 = _index_of(input[i + 1]);
            if (ch_1 == 64 or ch_2 == 64) {
                @panic("Invalid input: invalid Base64 input string");
            }
            out[out_index] = (ch_1 << 2) + (ch_2 >> 4);
            out_index += 1;

            if (!(eq_count <= 1)) {
                break;
            }

            // Produce byte 2
            const ch_3 = _index_of(input[i + 2]);
            if (ch_3 == 64) {
                @panic("Invalid input: invalid Base64 input string");
            }
            out[out_index] = (ch_2 << 4) + (ch_3 >> 2);
            out_index += 1;

            if (eq_count == 1) {
                break;
            }

            // Produce byte 3
            const ch_4 = _index_of(input[i + 3]);
            if (ch_4 == 64) {
                @panic("Invalid input: invalid Base64 input string");
            }
            out[out_index] = (ch_3 << 6) + ch_4;
            out_index += 1;
        }

        return out;
    }
};

pub fn main(init: std.process.Init) !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;


    var memory_buffer: [1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&memory_buffer);
    const allocator = fba.allocator();

    const base64 = Base64.init();

    const text = "Hey there!";
    const encoded_text = try base64.encode(allocator, text);
    const decoded_text = try Base64.decode(allocator, encoded_text);

    try stdout.print("Encoded Text: {s}\n", .{encoded_text});
    try stdout.print("Decoded Text: {s}\n", .{decoded_text});
    try stdout.flush();
}
