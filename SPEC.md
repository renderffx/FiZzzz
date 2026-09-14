# OOO Desk — SPEC (v1)

React-19.2-shaped OOO streaming. One chunked HTML document. No Fiber, no Next, no useState.
`_F.push("…")`. Tags: `J` model, `E` error. Refs: `$hex`, `$@hex`.

## Fizz invariants (F1–F10)

- **F1 Missing id → pending slot.** `$RC`/`__F.get` with an unknown id must not throw.
  Client creates a pending slot. `__F.end()` errors on leftover pending.
  Dup id on the client is `console.error`, never a second render.
- **F2 Child-first → Absorb.** If a child boundary completes while its hole is
  not yet live on the wire (parent not flushed/revealed), its HTML is absorbed
  into the parent segment buffer. **No dest write. No `$RC` for that id.**
  If `14.legs` `$RC` appears on the wire, F2 failed even if it "looks ok".
- **F3 Parent-live → Reveal.** If a boundary completes while its hole is live
  (`parent_flushed == true`), it must `emitReveal`: `<div hidden id="S:id">`
  + `wrap(kind, primary)` + `</div>` + `<script>$RC("B:id","S:id")</script>`
  via `dest.seg`. Then every bound with `parent == bid` becomes live
  (`parent_flushed = true`).
- **F4 `$RC` splice.** `$RC(bid,sid)`: getElementById both; if missing return;
  detach `sid`; `a = hole.previousSibling`; walk `a.nextSibling` with depth on
  comments `$` `$?` `$!` `/$`; remove range; insert `sid` children before the
  `$/` comment; `a.data = "$"`; if `a._reactRetry` call it. Null parentNode → return.
  No `innerHTML` on `<!--$-->` or `<!--$!-->`.
- **F5 `$RX` error.** `failBound` → `CLIENT_RENDERED`. If the hole is live,
  emit `$RX` script that paints the fallback cell with digest/msg and does **not**
  delete `<!--$-->`. Never later `$RC` for the same id. No RC-after-RX on the wire.
- **F6 kinds.** `kind: flow | tr | thead_cell`. `wrap(kind, primary)` is a table
  fragment for `tr`/`thead_cell`, never a bare `<tr` as the `S:` root under `<body>`.
  The `S:` root is always `<div hidden id="S:id">…</div>`.
- **F7 Dup id → error.** Server `push` with `minted[id]` and `tag != 'C'` is
  `error.DupFlightId`. Client dup id is `console.error`.
- **F8 escape.** `escape(s)` for `& < > " '` and break `<!--` inside cells.
  Poison (`<script>`, `<!--`, `&`) is visible text, table intact.
- **F9 abort → Silent.** If `dest.dead` or `req.aborted`: `finish`/`fail`/`emit`
  are no-ops. `/abort?after=N` freezes: remaining terminals are Silent, table intact,
  no further chunks.
- **F10 no bare fallback.** Never emit a bare `<tr` as the `S:` root under body;
  fallbacks are table fragments inside the hole
  `<!--$?--><!--$?-->fallback<!--/$-->`.

## Flight invariants (L1–L6)

- **L1** `J` payload is already JSON text (no nested encode beyond what blotter passes).
- **L2** `E` payload is digest/msg/stack text.
- **L3** Missing flight id → pending slot (`__F.get`).
- **L4** Dup flight id on client → `console.error`.
- **L5** Server remint same id with `tag != 'C'` → `error.DupFlightId`,
  even after abort (minted persists).
- **L6** Push after dead/abort is silent. Buffering flight until end is forbidden:
  pushes must hit the wire in order; abort must cut them (no late flush).

## Temporal boxes (wire classes)

Child-first 2-node tree (legs before parent):

- `legs → Absorb` (no `$RC`, no `$RX`), then parent `→ Reveal` (`$RC`).

Parent-first-then-child (parent reveals, legs later):

- parent `→ Reveal`, legs `→ Reveal` (second `$RC`).

Fail: `→ RX` (`$RX`, never `$RC` later for that id).
After abort: remaining `→ Silent` (no wire).

Blotter tape (must hold):

- `14.legs → Absorb`, `14 → Reveal`, `7,19 → RX`,
  `28 → Reveal`, `28.legs → Reveal`, after abort remaining `→ Silent`.

## Out of scope (v1)

`$RS`, reveal time-batching, `progressiveChunkSize`, preamble Suspense,
Flight `I H T R`, hydration, PPR resume, Server Actions, Fiber.
v1 is React OOO iff F2/F3/F5/F6/F8/F9 hold on a `<table>`.
