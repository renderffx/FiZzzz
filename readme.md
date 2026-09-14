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

## Quick start

Prerequisites: Zig 0.13 or later, Node 20 for the React prove harness.

```bash
zig build run
# open http://127.0.0.1:8787

# abort variant
# open http://127.0.0.1:8787/abort?after=11

zig build test

# fuzz for counterexamples
zig build gen

# print the raw wire
zig build dump
```

Client entry is `boot.js`. Server entry is `main.zig`. Build is `build.zig`.

---

## Design choices

**Why Zig** Bytes should be bytes. No GC pause in the middle of a chunk, no hidden allocation. If you duplicate or free wrong it blows up right there. JS keeps the DOM walk, Zig keeps the bytes. Separate programs, same shape. When they match, you trust it.

**Not a port** FiZz is not a line for line port of React. A port brings all the baggage and all the bugs. This is a rewrite of the idea. Each side owns its bugs, the wire is the contract.

**One document** No separate fetch for boundaries. One HTML document, chunked, with script tags. The browser can paint the shell immediately and fill holes as they arrive.

---

## Out of scope

`$RS`, time batched reveals, `progressiveChunkSize`, preamble suspense, Flight `I` `H` `T` `R`, hydration, PPR resume, Server Actions, Fiber. FiZz v1 is React OOO iff absorb, reveal, error, table wrap, escape, and abort hold.

---

## Project

FiZz by renderffx. Spec is `SPEC.md`. Agent brief is `AGENT.md`. Verify script is `verify.ps1`.

If you change FiZz to make `/` look nicer and the oracle disagrees, revert the nice and fix the rule.
