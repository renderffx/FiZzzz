# FiZz

Out of order streaming for the modern web. React 19.2 wire compatible. One chunked HTML document. No framework baggage.

FiZz is a standalone streaming engine that implements the exact suspension and reveal semantics of React Fizz and Flight, rebuilt from first principles in Zig for byte level control.

---

## What is FiZz

FiZz takes a tree with suspense boundaries and streams it to the client as it resolves. No waiting for everything to finish. Fast parts go first, slow parts fill in later, failures degrade gracefully, aborts freeze cleanly.

It speaks the React wire format natively so a normal browser with the tiny FiZz client can hydrate the stream without React on the server.

```
Server renders shell  ->  streams chunks  ->  client splices boundaries  ->  complete page
```

You get the same shapes React sends: `_F.push` chunks, `J` model, `E` error, `$RC` reveal, `$RX` failure, `$` holes.

---

## Why FiZz

React knows how to do this but the real implementation is tangled inside Fiber, Scheduler, and Next. Hard to see the protocol, hard to test the rules, hard to know what is invariant and what is artifact.

FiZz extracts the protocol and nothing else.

* A request owns segments and boundaries
* A boundary is pending, completed, failed, or flushed
* The wire is a single HTML document with script tags that push Flight payloads
* The client walks the DOM to splice completed boundaries into their holes

If the wire from FiZz matches the wire from React, the protocol is correct. Everything else is just detail.

---

## How it works

### 1. Request and boundaries

Every page render is a request. The request holds all segments and all boundaries for that render. A boundary is a suspense point. It has a fallback that ships immediately and primary content that may arrive later.

Four states:

* **pending** waiting for data
* **completed** data ready, waiting to emit or absorb
* **failed** error, will render fallback forever
* **flushed** already on the wire, children now have a live hole

### 2. The two golden rules

This is the core of FiZz. Every boundary completion hits one branch.

**If parent is not yet flushed, absorb.** The child HTML is folded directly into the parent segment buffer. No extra write. No `$RC` for that child on the wire. From the outside it looks like the child was never suspended at all.

**If parent is already flushed and live, reveal.** The child is emitted as its own chunk: a hidden div with the HTML plus a script that calls `$RC` to splice it into the hole. Every child of that boundary becomes live in turn.

Get this wrong and the page still looks okay but the wire is lying. FiZz treats that as a failure.

### 3. Failures

A boundary can fail. When it does it becomes `CLIENT_RENDERED` and never recovers.

* If its hole is live, FiZz emits `$RX` which paints the fallback cell with a digest and message and leaves the `<!--$-->` marker intact.
* If its hole is not live, it fails silently in place. No `$RX`, no later `$RC`.
* A failed boundary never later reveals. No RC after RX ever. The wire enforces this.

### 4. Abort

If the destination is dead or the request is aborted, every further finish, fail, and emit is a silent no op. `/abort?after=N` freezes the stream mid flight. Remaining boundaries stay silent, the table stays intact, no extra chunks leak after the cut.

Abort is global and sticky. Once dead, nothing else hits the wire.

---

## Client runtime

The client is a tiny script that runs in the browser.

* `_F.push` appends Flight payloads
* `$RC(bid, sid)` finds the hole and the hidden div by id, detaches the div, walks the DOM from `hole.previousSibling` counting `<!--$-->`, `<!--$?-->`, `<!--$!-->`, `<!--/$-->` to find the range, removes the range, inserts the real children before `<!--/$-->`, marks the hole comment as `$`, and calls `_reactRetry` if present. If either element is missing or has no parent, it returns quietly.
* `$RX(bid, digest, msg)` paints the error into the fallback and never touches the hole marker.

Rules the client enforces:

* Missing id creates a pending slot. `__F.end` will throw if any pending remains.
* Duplicate id is a `console.error`, never a second render.
* Never use `innerHTML` on a `<!--$-->` or `<!--$!-->` comment.

---

## Wire format

FiZz streams a single chunked HTML document.

* Normal chunks are length prefixed HTML
* Flight payloads ride inside `<script>` tags and are escaped so `<script>`, `<!--`, `&`, quotes cannot break the document
* Table content is always wrapped as a fragment. The hidden div that carries a segment is always `<div hidden id="S:id">...</div>`, never a bare `<tr>` under `<body>`
* Fallbacks are holes: `<!--$?--><!--$?-->fallback<!--/$-->` inside the table, not bare fallbacks

Flight tags:

* `J` JSON model payloads, already serialized text
* `E` error payloads with digest, message, and stack
* Refs `$hex` and `$@hex` for model references

Server guarantees:

* Duplicate Flight id with tag not `C` is `DupFlightId`, even after abort
* Duplicate id after abort still errors because minted set persists
* Push after dead or abort is silent
* Buffering Flight until the end is forbidden. Pushes must hit the wire in order. Abort must cut them.

---

## Correctness

FiZz is correct iff these hold on a `<table>`. These are not preferences, they are invariants.

* Missing id makes a pending slot on the client
* Child before parent absorbs with no `$RC`
* Parent live then child reveals with `$RC` and wakes its children
* `$RC` splices by walking comments, not innerHTML
* `$RX` paints fallback, keeps the hole, never followed by `$RC`
* Table fragments wrap rows, hidden divs are always the segment root
* Dup ids error on server and warn on client
* Poison strings are escaped and visible as text with table intact
* Abort and dead freeze the stream with no further chunks
* No bare `<tr>` fallback under body

Temporal model:

* Child first 2 node tree: child absorbs, parent reveals with `$RC`
* Parent first then child: parent reveals, child later reveals with second `$RC`
* Fail: emits `$RX`, never `$RC` after
* After abort: all remaining are silent

The canonical tape that must never move:

`14.legs` absorbs, `14` reveals, `7` and `19` fail with `$RX`, `28` reveals then `28.legs` reveals, after abort remainder silent. If this order shifts, something broke.

---

## Verification

FiZz does not rely on eyeballing. It has three ways to catch itself lying.

**Oracle** A pure spec that encodes the invariants and checks any wire against expected instruction classes.

**Gen** A fuzzer that permutes completion orders and tries to find a counterexample where FiZz and the oracle disagree. No counterexample means the rules held for all generated orders.

**Mutants** Seven rule flips that each must be caught. If a mutant survives, the oracle or the fuzzer is too weak. Seven for seven is the bar.

**Dump** A wire printer so you can look with your own eyes when gen says something is off.

There is also a prove harness that renders the same trees in real React 19.2 `renderToPipeableStream` and compares raw wire chunks against FiZz.

---

## Why Zig, for real

I tried this first in JS and kept getting fooled. Things looked correct but the runtime hid the cost. GC would pause between chunks, allocations were implicit, a string copy would happen somewhere I did not expect and the wire timing would shift just enough to hide a bug. When absorb versus reveal was off by one condition, JS still painted a fine page and I would not notice until the fuzzer ran for a long time.

Zig makes that impossible to ignore. Bytes are bytes. There is no GC. Every allocation takes an allocator you pass in. If you want an arena for a request you create it, if you want to dupe a string you call dupe and you own the free. If you free wrong or dupe wrong it blows up right there, not later. That is what I wanted for a streaming protocol where order and lifetime are the whole correctness.

A few things that mattered while learning this:

* **Explicit lifetimes** A request owns segments and boundaries. In Zig the table owns the wakes, the dest owns the chunks, the request owns the table. Nothing dangles because nothing is shared behind a runtime. When a boundary completes, you can see exactly which buffer it writes to and whether dest is dead.
* **No hidden control flow** No promises, no async scheduler, no microtask queue in the core. The sched table is just a table. `wake ok` saves html and finishes, `wake err` saves the error and fails. You call it, it runs, you see the wire change. Easy to trace with dump.
* **Error unions over exceptions** `DupFlightId` is a real error you must handle where it happens. Not a throw that unwinds far away. Minted ids persist even after abort, so a remint after abort still errors at the call site. You see that rule in the code, not in a comment.
* **Comptime and types for the wire** Escape, wrap, chunk framing, Flight push. All of it is checked at compile time and costs nothing at runtime. No helper you forgot to import, no runtime helper patching the chunk.
* **If it matches React, you trust it** JS keeps the DOM walk for `$RC` and `$RX`. Zig keeps the bytes on the server. Two separate programs, same shape. When gen finds no counterexample and mutants all get caught and the dumped wire looks identical to `renderToPipeableStream`, you trust the bytes because Zig gave you no place to hide.

I did not pick Zig to be clever. I picked it because I wanted the stream to be deterministic and the bugs to be loud. It did both.

**Not a port** FiZz is not a line for line port of React. A port would bring Fiber, Scheduler, thenables, and all the baggage that makes the real codebase hard to learn. This is a rewrite of the idea from the spec. Each side owns its bugs. The wire is the contract. If FiZz makes `/` pretty and the oracle disagrees, the pretty reverts and the rule gets fixed.

**One document** No separate fetch for boundaries. One HTML document, chunked, with Flight payloads riding in script tags. The browser paints the shell immediately and fills holes as they arrive. That is the whole performance story.

## Where this maps in React core

FiZz implements the same protocol as React 19.2. If you want to read the source that inspired each part, read these exact files in `facebook/react`:

* `packages/react-server/src/ReactFizzServer.js` the core orchestrator. `createRequest` builds the request with destination and renderState, `renderNode` walks the tree, `Task` and `Segment` model work and output regions, `writeCompletedBoundaryInstruction` and `writeCompletedSegmentInstruction` emit `$RC` reveals. This is where absorb versus reveal lives.
* `packages/react-dom/src/server/ReactDOMFizzServerNode.js` Node entry that wraps the core with `renderToPipeableStream`. Same for `ReactDOMFizzServerBrowser.js` and `ReactDOMFizzServerEdge.js` which wrap it with `renderToReadableStream`.
* `packages/react-server/src/ReactFlightServer.js` the Flight side. `createRequest`, `startWork`, `startFlowing`, `abort`, plus `J` and `E` tag emit and ref handling for `$` and `$@`.
* `packages/react-server/src/ReactFizzConfigDOM.js` and `packages/react-dom-bindings/src/server/ReactFizzConfigDOM.js` format config. `pushStartInstance`, `pushEndInstance`, `pushTextInstance`, `writePlaceholder`, `writeStartSegment`, `writeEndSegment`, and the suspense comment markers `<!--$-->`, `<!--$?-->`, `<!--$!-->`, `<!--/$-->`.
* `packages/react-server/src/ReactServerStreamConfig*.js` stream configs for Node, Browser, Edge, Bun. Chunk type, destination write, scheduleWork and scheduleMicrotask.
* `packages/react-client/src/ReactFlightClient.js` and `ReactDOMClient` hydration path, client side `$RC` splice walk and `$RX` error paint, `__F.get` pending slots and `console.error` on dup.

Read those alongside `SPEC.md` in this repo. The spec is the distilled version of exactly those files. When in doubt, the React file is the truth.

---

## Out of scope

`$RS`, time batched reveals, `progressiveChunkSize`, preamble suspense, Flight `I` `H` `T` `R`, hydration, PPR resume, Server Actions, Fiber. FiZz v1 is React OOO iff absorb, reveal, error, table wrap, escape, and abort hold.

---

## Project

FiZz by renderffx.

If you change FiZz to make `/` look nicer and the oracle disagrees, revert the nice and fix the rule.
