# FiZz — agent brief (this file)

Build a protocol, not a dashboard. React 19.2 Fizz + sliver of Flight.
One chunked HTML document. No Fiber, no Next, no useState.

Wire: `_F.push("…")`. Tags `J`/`E`. Refs `$hex`/`$@hex`.
Missing id → pending slot. Dup id → error.

Suspend only via explicit await tasks in the tiny render walk.

## URLs

- `http://127.0.0.1:8787/` — blotter
- `http://127.0.0.1:8787/abort?after=11` — abort scene (freezes)

## Build order (do not skip)

1. dest + mem
2. fizz F1–F4, F6, F7 on kind=flow
3. html F8/F10 + boot F5/F9
4. oracle + gen + mutants
5. render/sched
6. flight L1–L6
7. blotter + tape
8. abort URL

## Output format (after work, report)

- Quote the `parent_flushed` branch in `completeBound`.
- Child-first 2-node tree: wire instruction class.
- Parent-first-then-child: class.
- Gen: counterexample or NO COUNTEREXAMPLE.
- Mutants: 7/7 caught or which survived.
- Do not say "tests pass" as the conclusion.

If you change fizz to make `/` pretty and oracle disagrees, revert the pretty
and fix the rule.
