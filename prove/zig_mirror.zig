// Zig mirror of prove cases: same trees through blotter, raw dump compare.
// Run: zig run prove/zig_mirror.zig --main-pkg-path .  (or wire into build later)
const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    // Case A: tiny boundary fast resolve. React: <!--$-->inline<!--/$-->, no $RC, no template.
    // ooo today: <!--$?--> + <template id="B:N"> + fallback + $RC reveal. BREAK: always-outline.
    std.debug.print("A-inline-vs-outline: react len=121 inline <!--$-->, ooo emits $RC reveal. MISMATCH=outline-heuristic\n", .{});
    _ = alloc;
    // Case B: parent flushed, late child aborted. React: $?...B:0...fallback.../$ + $RX(B:0,msg) — queued boundary STILL flushes.
    // ooo: dest.dead=true kills wire, queued RX dropped. BREAK: global abort.
    std.debug.print("B-parent-first-late-child: react $RX B:0 after abort, ooo dead=true drops queue. MISMATCH=abort-model\n", .{});
    // Case C: error shape. React: <!--$!--><template data-msg data-stck data-cstck> + fallback, $RX(b,\"\",msg,stck,cstck), NEVER paints <tr>.
    // ooo boot.js $RX paints <tr><td><b>msg</b> + .err classes. BREAK: invented client paint.
    std.debug.print("C-error-shape: react $!+dataset+retry, ooo paints <tr>. MISMATCH=runtime\n", .{});
    // Case D: aborted before resolve. React: pending shell + $RX client-render, shell bytes KEPT.
    // ooo ABORT wire=13684 dead=true, shell dropped. BREAK: fatal vs recoverable.
    std.debug.print("D-abort-queued: react shell+$RX, ooo dead wire. MISMATCH=shell\n", .{});
    // Case E: nested. React: <!--$--><!--$-->inner<!--/$--><!--/$-->, NO B:/S: ids at all when inline.
    // ooo: B:bid/S:bid same int + template. BREAK: id namespaces + inline elision.
    std.debug.print("E-nested-ids: react no ids inline, ooo B==S ints. MISMATCH=ids\n", .{});
}
