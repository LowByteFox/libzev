#!/bin/sh

zig build && python3 -m http.server -d zig-out/docs/; rm -r .zig-cache/
