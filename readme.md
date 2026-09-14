# FiZz

I kept getting lost in React so I built the smallest thing that still suspends.

FiZz is a React 19.2 wire compatible streaming engine. One chunked HTML document. Out of order, but correct. Rebuilt from first principles in Zig because I wanted bytes to be bytes and bugs to be loud.

This is not slop. It is hand written, hand traced, hand dumped. If the wire lies, the fuzzer tells me. If the fuzzer is weak, the mutants tell me. Nothing is vibe checked.

---

## The story

I wanted to see suspense on the wire without all the React around it.

Real Fizz is spread across Fiber and Scheduler and format configs and Flight. You can read for a week and still not see the protocol. I could not hold it in my head, so I shrank it. One request. Some segments. Some boundaries. That is it. A shell that ships now and holes that fill later. The whole trick is order.

The first version looked fine. Page rendered. I thought I was done. Then I dumped the wire and saw an extra `$RC` where there should have been none. Child had completed before parent flushed, so it should have been absorbed, not revealed. The page still looked correct because the client spliced it anyway, just with an extra script. The wire was lying and the page hid it. That was the day I learned the page is not the truth. The wire is.

So I froze the tape. `14.legs` must absorb with no `$RC`. `14` must reveal with `$RC`. `7` and `19` must fail with `$RX` and never later `$RC`. `28` reveals, then `28.legs` reveals after. After abort the rest stays silent. If that order moves, I broke something. No matter how pretty `/` looks, if it moves the tape, it reverts.

I tried it in JS first. It taught me the wrong lessons. GC pauses between chunks, allocations you did not call for, copies hiding in string helpers. Bugs Timing shifted and hid the branch that mattered. I could write a stream that was wrong and still looked right until I compared raw bytes.

I picked Zig because Zig does not let you hide. You pass the allocator. You dupe the string and you own the free. You write the chunk or you do not. If you free wrong it blows up right there. If you forget `DupFlightId` the compiler stops you. If you buffer Flight when you should have flushed it, the buffer grows where you can see it. I wanted deterministic bytes and loud bugs. Zig gave me both.

I did not port React. Porting would drag Fiber and all its baggage and I would learn nothing. I rewrote the idea from the spec. Two programs, same shape. JS keeps the DOM walk for `$RC` and `$RX`, Zig keeps the bytes on the server. When they match under gen and mutants and against `renderToPipeableStream`, I trust it. That is the loop. Spec, Zig, fuzz, compare to React, fix the rule. Repeat until quiet.

There was a night I messed up abort. I cut the stream but then still sent a clean end after. It felt tidy. It was wrong. Dead stays dead. Abort is sticky and global, once the destination is dead nothing else hits the wire. The fix was to make every finish, fail, and emit a no op after dead. One condition, no exception. The oracle caught it. I will not make it again.

Why this matters. Suspense is not a UI trick, it is a wire discipline. Fast parts go now, slow parts fill holes, errors stay where they fell, abort freezes. Get that discipline right and any page feels fast because bytes are in the right order. Get it wrong and the page still paints but you paid for an extra round trip that the wire hid.

FiZz is my notes that run. Not a product. Just the protocol, small enough to hold in your head, correct enough to match React byte for byte on a table.

If you are here to learn it, read it in this order. Dest and stream, then fizz on `flow` only, then html escape and boot, then oracle and gen and mutants so you cannot lie to yourself, then render and sched, then flight, then blotter and tape, then abort. That is the build order and also the learning order. Skip one and the next makes no sense.

---

## What it speaks

FiZz streams a single HTML document, chunked. Normal HTML is length prefixed. Flight payloads ride in `<script>` tags and are escaped so `<script>`, `<!--`, `&`, and quotes can never break the document. Table content is always wrapped as a fragment. The hidden div that carries a segment is always `<div hidden id="S:id">...</div>`, never a bare `<tr>` under `<body>`.

You see the same shapes React sends: `_F.push` chunks, `J` model and `E` error, refs `$` and `$@`, `$RC` reveal, `$RX` failure, `<!--$-->` holes and `<!--$?-->` fallbacks.

---

## How it works

### The request

Every render is a request. The request owns segments and boundaries. A boundary is a suspense point with a fallback that ships immediately and primary content that may arrive later.

Four states. Pending means waiting. Completed means data ready. Failed means `CLIENT_RENDERED` forever. Flushed means already on the wire, so children now have a live hole. That is all there is.

### The two golden rules

Every boundary completion hits one branch. This is the whole engine.

If parent is not yet flushed, absorb. The child HTML folds directly into the parent segment buffer. No dest write. No `$RC` for that child. From the outside it looks like the child never suspended.

If parent is already flushed and live, reveal. The child emits its own chunk as a hidden div plus a script that calls `$RC` to splice it into the hole. Every child of that boundary becomes live in turn.

Get this wrong and the page still looks okay but the wire is wrong. FiZz treats that as a failure. Dump and gen exist so you cannot fool yourself.

### Failures

A boundary can fail and when it does it never recovers.

If its hole is live, FiZz emits `$RX` that paints the fallback cell with digest and message and leaves `<!--$-->` intact. If its hole is not live, it fails silently where it is. A failed boundary never later reveals. No RC after RX, ever. The wire enforces it. I learned to love that rule because it makes errors local. The page stays intact around the failed hole.

### Abort

If the destination is dead or the request is aborted, every further finish, fail, and emit is a silent no op. The stream freezes mid flight. Remaining boundaries stay silent. The table stays intact. No extra chunks leak after the cut. Once dead, nothing else hits the wire. No tidy trailer after.

---

## The client, tiny on purpose

A small script runs in the browser.

`_F.push` appends Flight payloads. `$RC(bid, sid)` finds the hole and the hidden div by id, detaches the div, walks from `hole.previousSibling` counting `<!--$-->`, `<!--$?-->`, `<!--$!-->`, `<!--/$-->` to find the range, removes the range, inserts the real children before `<!--/$-->`, marks the hole comment as `$`, and calls `_reactRetry` if present. If either element is missing or has no parent it returns quietly. `$RX(bid, digest, msg)` paints the error into the fallback and never touches the hole marker.

Rules it holds: missing id creates a pending slot and `__F.end` throws if any pending remains. Duplicate id is `console.error`, never a second render. Never use `innerHTML` on a `<!--$-->` or `<!--$!-->` comment.

---

## Guarantees

FiZz is correct on a `<table>` iff these hold. They are not preferences.

* Missing id makes a pending slot on the client
* Child before parent absorbs with no `$RC`
* Parent live then child reveals with `$RC` and wakes its children
* `$RC` splices by walking comments, not `innerHTML`
* `$RX` paints fallback, keeps the hole, never followed by `$RC`
* Table fragments wrap rows, hidden divs are always the segment root
* Dup Flight ids error on server and warn on client, even after abort where minted persists
* Poison strings are escaped and visible as text with table intact. Row 3 has a script in it on purpose so I can see if I broke it
* Abort and dead freeze with no further chunks
* No bare `<tr>` fallback under `<body>`. Fallbacks are holes `<!--$?--><!--$?-->fallback<!--/$-->`

Temporal model: child first 2 node tree means child absorbs then parent reveals with `$RC`. Parent first then child means parent reveals then child later reveals with second `$RC`. Fail means `$RX` and never `$RC` after. After abort, all silent.

The canonical tape that must never move: `14.legs` absorbs, `14` reveals, `7` and `19` fail with `$RX`, `28` reveals then `28.legs` reveals, after abort remainder silent.

---

## How I know it is not lying

I do not trust my eyes. I trust three things that tell me when I am lying to myself.

**Oracle** A pure spec that encodes the invariants and checks any wire against expected instruction classes.

**Gen** A fuzzer that permutes completion orders and searches for a counterexample where FiZz and the oracle disagree. No counterexample means the rules held for all generated orders.

**Mutants** Seven rule flips, each must be caught. If a mutant survives, the oracle or the fuzzer is too weak. Seven for seven is the bar. I keep them around so I cannot feel good for free.

**Dump** A wire printer so I can look with my own eyes when gen says something is off. bytes are bytes, print them.

There is also a prove harness that renders the same trees in real React 19.2 `renderToPipeableStream` and compares raw wire chunks against FiZz. When they match, the protocol is yours. The harness is there because matching React is the only honest definition of correct.

---

## Why Zig, for real, from the trench

I kept getting fooled in JS. A boundary that should absorb would reveal and still paint fine, just with an extra script. No error, no hint, just a wire that was subtly wrong. Timing hid it. GC hid it.

Zig refuses to hide anything.

**Allocators are honest.** No global allocator. A request gets an allocator, the dest owns the buffer, the table owns the wakes. You pick arena for the request or gpa for checked frees. The ownership tree is in the code: request owns table, table owns wakes, dest owns chunks. Leaks are visible, not silent.

**No hidden control flow.** No promises, no microtask queue in the core. The table is just a table. `wake ok` saves html and finishes, `wake err` saves the error and fails. You call it, it runs, you see the wire change. Traced with dump, every state is a call you can print.

**Errors at the call site.** `DupFlightId` is an error union you handle where it happens, not a throw that unwinds somewhere you forgot. Minted ids persist even after abort, so a remint after abort still errors at the push site. You see the rule in the signature, not in a comment.

**Comptime is free correctness.** Escape, wrap, chunk framing, Flight push are checked at compile time and cost nothing at runtime. The table wrapper for `tr` versus `flow`, the hidden div shape, the poison escape for `& < > " ' <!--` and `<script>`. If the shape is wrong it does not compile. No helper you forgot to import.

**No GC means deterministic wire.** The stream does not pause for collection in the middle of a segment. Bytes you wrote stay where you wrote them. When you absorb you append to parent, when you reveal you write a new chunk. That mapping is the protocol. In a GC language that mapping is still true but the pause can hide that you buffered Flight when you should have flushed. In Zig that bug appears as a buffer you can measure.

**If it matches React, you trust it.** Two programs, same shape. JS does the DOM walk, Zig does the bytes. When gen is quiet and mutants all get caught and the dumped wire equals `renderToPipeableStream`, you trust the bytes because Zig left you no place to hide. That is the learning loop. Spec, Zig, fuzz, compare, fix. Repeat until the wire stops arguing.

I did not pick Zig to be clever. I picked it because I wanted the stream deterministic and the bugs loud. It did both. It made every wrong assumption a compile error or a blown free or a visible extra `$RC` on the wire, and that forced me to actually learn the protocol bottom up.

**Not a port.** A port brings Fiber, Scheduler, thenables, all the baggage that makes React hard to hold in your head. This is a rewrite of the idea. Each side owns its bugs. The wire is the contract. If FiZz makes the page pretty and the oracle disagrees, the pretty reverts and the rule gets fixed.

**One document.** No extra fetch for boundaries. One chunked HTML document with script tags. Browser paints the shell now, fills holes as they arrive. Streaming is not about speed of JS, it is about order of bytes.

---

## Where this maps in React core

FiZz speaks the same protocol as React 19.2. If you want to trace the idea to the source, start here in [`facebook/react`](https://github.com/facebook/react) at main tag `19.2`.

* [The core streaming engine](https://github.com/facebook/react/blob/main/packages/react-server/src/ReactFizzServer.js) This is the heart. It owns the request, the tasks, the segments, and the boundary lifecycle. It decides absorb versus reveal and emits the `$RC` instructions that the client splices. Study `createRequest` and `renderNode` and the `parentFlushed` branch and you have half the spec.

* [The Node streaming entry](https://github.com/facebook/react/blob/main/packages/react-dom/src/server/ReactDOMFizzServerNode.js) The `renderToPipeableStream` wrapper that connects the core engine to a Node destination. Same engine, just a different pipe.

* [The Browser and Edge entries](https://github.com/facebook/react/blob/main/packages/react-dom/src/server/ReactDOMFizzServerBrowser.js) The `renderToReadableStream` variants for browser and edge. Identical protocol, different host.

* [The Flight protocol](https://github.com/facebook/react/blob/main/packages/react-server/src/ReactFlightServer.js) The other half. It defines `J` and `E` tags, refs `$` and `$@`, flowing, and abort. `createRequest`, `startWork`, `startFlowing`, `abort`, and the tag emit live here.

* [HTML formatting and placeholders](https://github.com/facebook/react/blob/main/packages/react-server/src/ReactFizzConfigDOM.js) How HTML gets shaped, how placeholders and segment shells are written, and where the suspense markers `<!--$-->`, `<!--$?-->`, `<!--$!-->`, `<!--/$-->` come from. Companion is the [DOM bindings format config](https://github.com/facebook/react/blob/main/packages/react-dom-bindings/src/server/ReactFizzConfigDOM.js).

* [Stream configs for every host](https://github.com/facebook/react/blob/main/packages/react-server/src/ReactServerStreamConfigNode.js) Node, browser, edge, and Bun each have a config that defines chunk types, destination writes, and work scheduling. Node is the clearest to read first, the others mirror it.

* [The client that splices it back](https://github.com/facebook/react/blob/main/packages/react-client/src/ReactFlightClient.js) The Flight client and ReactDOM hydration path. This is where `__F.get` pending slots, `console.error` on dup, `__F.end` checks, and the `$RC` DOM walk and `$RX` error paint live.

Read them alongside `SPEC.md` in this repo. The spec is the distilled version of exactly those pages. When in doubt, the React page is the truth. Start with the core engine, then Flight, then the HTML formatting. That order mirrors how this repo was built.

---

## Out of scope

`$RS`, time batched reveals, `progressiveChunkSize`, preamble suspense, Flight `I` `H` `T` `R`, hydration, PPR resume, Server Actions, Fiber. FiZz v1 is React OOO iff absorb, reveal, error, table wrap, escape, and abort hold.

---

## Project

FiZz by renderffx.

If you change FiZz to make the page pretty and the oracle disagrees, revert the pretty and fix the rule.
