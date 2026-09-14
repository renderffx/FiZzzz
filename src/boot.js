"use strict";
// Boot: $RC splice + $RX error + __F flight slots. No innerHTML on holes.
(function () {
  function $(id) { return document.getElementById(id); }

  // $RC(bid, sid): splice hidden S: content into B: hole.
  window.$RC = function (bid, sid) {
    var hole = $(bid), src = $(sid);
    if (!hole || !src) return;
    var parent = hole.parentNode;
    if (!parent) return;
    // detach sid
    if (src.parentNode) src.parentNode.removeChild(src);
    var a = hole.previousSibling;
    if (!a) return;
    // walk a.nextSibling with depth on comments $ $? $! /$
    var depth = 0, cur = a.nextSibling, end = null, guard = 0;
    while (cur && guard++ < 100000) {
      if (cur.nodeType === 8) {
        var d = cur.data;
        if (d === "$" || d === "$?" || d === "$!") depth++;
        else if (d === "/$") {
          if (depth === 0) { end = cur; break; }
          depth--;
        }
      }
      cur = cur.nextSibling;
    }
    if (!end) return;
    // remove range a.nextSibling .. end.previousSibling
    var n = a.nextSibling;
    while (n && n !== end) { var nx = n.nextSibling; parent.removeChild(n); n = nx; }
    // insert sid children before the $/ comment
    var kids = [];
    var c = src.firstChild;
    while (c) { kids.push(c); c = c.nextSibling; }
    for (var i = 0; i < kids.length; i++) parent.insertBefore(kids[i], end);
    a.data = "$";
    if (a._reactRetry) { try { a._reactRetry(); } catch (e) {} }
  };

  // $RX(bid, digest, msg, stack): paint fallback row, do not delete hole.
  // Hole is <template id="B:N"> followed by fallback <tr>. Template is
  // inert/invisible, so we must paint the TR after it (not the template).
  window.$RX = function (bid, digest, msg, stack) {
    var hole = $(bid);
    if (!hole) return;
    var parent = hole.parentNode;
    if (!parent) return;
    // forward search: fallback TR is after the template, before /$/ comment
    var n = hole.nextSibling, row = null;
    while (n) {
      if (n.nodeType === 8 && n.data === "/$") break;
      if (n.nodeType === 1 && (n.tagName === "TR" || n.tagName === "TD" || n.tagName === "TH")) { row = n; break; }
      n = n.nextSibling;
    }
    if (!row) return;
    var target = row;
    // paint the note cell if this is a full row, else the row itself
    var cell = target;
    if (target.tagName === "TR") {
      var tds = target.getElementsByTagName("td");
      if (tds.length > 0) cell = tds[tds.length - 1];
      target.className = (target.className ? target.className + " " : "") + "err-row";
    }
    // paint without innerHTML on holes: build nodes (fallback cell only,
    // keep the row + hole comments intact per F5)
    while (cell.firstChild) cell.removeChild(cell.firstChild);
    cell.className += (cell.className ? " " : "") + "err";
    var b = document.createElement("b");
    b.textContent = msg;
    var s = document.createElement("span");
    s.textContent = " " + digest + " " + (stack || "");
    cell.appendChild(b);
    cell.appendChild(s);
  };

  // __F flight: pending slots, J revive $/$@, E errored, dup console.error, end() errors leftover.
  var slots = {};
  window.__F = {
    get: function (id) {
      if (!slots[id]) slots[id] = { status: "pending", value: null };
      return slots[id];
    },
    push: function (row) {
      var i = row.indexOf(":");
      if (i < 0) { console.error("bad flight row", row); return; }
      var id = row.slice(0, i), rest = row.slice(i + 1);
      var tag = rest[0], payload = rest.slice(1);
      if (slots[id] && slots[id].status !== "pending") { console.error("dup flight id", id); return; }
      if (tag === "J") {
        var v;
        try { v = JSON.parse(payload, reviver); }
        catch (e) { slots[id] = { status: "errored", value: e }; return; }
        slots[id] = { status: "ready", value: v };
      } else if (tag === "E") {
        slots[id] = { status: "errored", value: new Error(payload) };
      } else {
        console.error("unknown flight tag", tag);
      }
    },
    end: function () {
      for (var k in slots) {
        if (slots[k].status === "pending") console.error("leftover pending", k);
      }
    }
  };
  function reviver(key, value) {
    if (typeof value === "string") {
      if (value.length > 1 && value[0] === "$") {
        if (value[1] === "@") {
          var ref = value.slice(2);
          return slots[ref] ? slots[ref].value : null;
        }
        var r2 = value.slice(1);
        return slots[r2] ? slots[r2].value : null;
      }
    }
    return value;
  }
})();
