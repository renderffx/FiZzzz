// Adversarial falsification: real React 19.2 renderToPipeableStream vs ooo byte shape.
// Each case renders the same tree in React and captures raw wire chunks.
// Run: node cases.mjs > react_wire.txt, then compare markers against Zig dump.
import React, { Suspense } from 'react';
import { renderToPipeableStream } from 'react-dom/server';
import { Writable } from 'node:stream';

function collect(el, opts = {}) {
  return new Promise((resolve, reject) => {
    let chunks = [];
    const { pipe, abort } = renderToPipeableStream(el, {
      ...opts,
      onShellReady() {},
      onAllReady() {},
      onError(e) { chunks.push(`[onError:${e?.message ?? e}]`); },
    });
    const w = new Writable({
      write(c, _, cb) { chunks.push(c.toString()); cb(); },
      final(cb) { cb(); resolve(chunks.join('')); },
    });
    w.on('error', reject);
    pipe(w);
    if (opts.abortAfterMs) setTimeout(() => abort(opts.abortAfterMs_reason ?? 'abort'), opts.abortAfterMs);
  });
}

const sleep = (ms, v) => new Promise(r => setTimeout(() => r(v), ms));
const Never = () => sleep(60000, 'never');
const C1 = ({ v = 'legs' }) => React.createElement('tr', { className: 'row' },
  React.createElement('td', { className: 'leg' }, v),
  React.createElement('td', { className: 'wake' }, '$14.10'));
const Fallback = () => React.createElement('tr', { className: 'loading' },
  React.createElement('td', { colSpan: 2 }, 'waiting…'));

// Case A: tiny boundary, fast resolve — React INLINES, ooo OUTLINES (always-$RC)
async function caseA() {
  const el = React.createElement('table', null,
    React.createElement('tbody', null,
      React.createElement(Suspense, { fallback: React.createElement(Fallback) },
        React.createElement(C1, { v: 'tiny' }))));
  return ['A-inline-vs-outline', await collect(el)];
}
// Case B: parent flushed first, then late child — tests $RC vs inline + $RB batching
async function caseB() {
  const el = React.createElement('table', null,
    React.createElement('tbody', null,
      React.createElement('tr', null, React.createElement('td', null, 'shell')),
      React.createElement(Suspense, { fallback: React.createElement(Fallback) },
        React.createElement(Never))));
  return ['B-parent-first-late-child', await collect(el, { abortAfterMs: 300 })];
}
// Case C: error boundary — tests $RX shape (real: $! + dataset, ooo: paints <tr>)
async function caseC() {
  const Boom = () => { throw new Error('kablam <&>'); };
  const el = React.createElement('table', null,
    React.createElement('tbody', null,
      React.createElement(Suspense, { fallback: React.createElement(Fallback) },
        React.createElement(Boom))));
  return ['C-error-shape', await collect(el)];
}
// Case D: aborted before resolve — tests queued boundary still flushes vs ooo dead=true kill
async function caseD() {
  const el = React.createElement('table', null,
    React.createElement('tbody', null,
      React.createElement(Suspense, { fallback: React.createElement(Fallback) },
        React.createElement(Never))));
  return ['D-abort-queued', await collect(el, { abortAfterMs: 100, abortAfterMs_reason: 'aborted!' })];
}
// Case E: nested boundaries — tests B:!=S: id namespaces + $RS segment moves
async function caseE() {
  const Inner = () => React.createElement(Suspense, { fallback: React.createElement(Fallback) },
    React.createElement(C1, { v: 'inner' }));
  const el = React.createElement('table', null,
    React.createElement('tbody', null,
      React.createElement(Suspense, { fallback: React.createElement(Fallback) },
        React.createElement(Inner))));
  return ['E-nested-ids', await collect(el)];
}

for (const fn of [caseA, caseB, caseC, caseD, caseE]) {
  const [name, wire] = await fn();
  console.log(`===== ${name} len=${wire.length} =====`);
  console.log(wire.slice(0, 4000));
  console.log();
}
