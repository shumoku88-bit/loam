import test from "node:test";
import assert from "node:assert/strict";
import {
  shiftMonth, calendarDate, shiftCalendarDate, unmodifiedNavigation,
  amountText, displayText, movementSummary, quantitySummary, visibleRecords,
  reconcileSelection, changedFields, correctionPairs, requestGate,
} from "../web/workbench.mjs";

const effect = (locus, quanta, measure = "jpy") => ({ locus, measure, quanta });
const first = { id: "a", date: "2026-10-01", description: "Coffee 豆", history: [],
  effects: [effect("cash", "-680"), effect("food", "680")] };
const second = { id: "b", date: "2026-10-07", description: "book", history: [],
  effects: [effect("bank", "-2470"), effect("books", "2470")] };
const initial = { scope: "month", selectedDate: "2026-10-01", selectedId: "a",
  query: "", locus: "", order: "asc" };

test("month movement handles year boundaries and the 1..9999 range", () => {
  assert.equal(shiftMonth("2026-12", 1), "2027-01");
  assert.equal(shiftMonth("2026-01", -1), "2025-12");
  assert.equal(shiftMonth("0099-12", 1), "0100-01");
  assert.equal(shiftMonth("0001-01", -1), "0001-01");
  assert.equal(shiftMonth("9999-12", 1), "9999-12");
});

test("calendar day/week movement follows Gregorian boundaries without a year-1900 offset", () => {
  for (const [date, days, expected] of [
    ["2024-02-28", 1, "2024-02-29"],
    ["2024-02-29", 1, "2024-03-01"],
    ["2026-02-28", 1, "2026-03-01"],
    ["1900-02-28", 1, "1900-03-01"],
    ["2000-03-01", -1, "2000-02-29"],
    ["2026-12-29", 7, "2027-01-05"],
    ["2026-01-03", -7, "2025-12-27"],
    ["0099-12-31", 1, "0100-01-01"],
    ["0001-01-01", -1, "0001-01-01"],
    ["9999-12-31", 7, "9999-12-31"],
  ]) assert.equal(shiftCalendarDate(date, days), expected);
  assert.equal(calendarDate(1, 1, 1).getUTCFullYear(), 1);
  assert.equal(calendarDate(2024, 3, 0).getUTCDate(), 29);
});

test("widget navigation does not consume IME or modified editing keys", () => {
  assert.equal(unmodifiedNavigation({ key: "ArrowRight" }), true);
  for (const event of [{ isComposing: true }, { keyCode: 229 },
    { altKey: true }, { ctrlKey: true }, { metaKey: true }, { shiftKey: true }]) {
    assert.equal(unmodifiedNavigation(event), false);
  }
});

test("exact quanta are never converted to Number", () => {
  assert.equal(amountText("900719925474099312345"), "900,719,925,474,099,312,345");
  assert.equal(amountText("-900719925474099312345"), "-900,719,925,474,099,312,345");
});

test("control characters remain distinguishable and visible without executing them", () => {
  assert.equal(displayText("a\x1bb"), "a\\u001bb");
  assert.equal(displayText("a\x07b"), "a\\u0007b");
  assert.notEqual(displayText("a\x1bb"), displayText("a\x07b"));
});

test("only an exact simple same-Measure movement has a one-quantity summary", () => {
  assert.equal(quantitySummary(first), "680 jpy");
  assert.equal(movementSummary(first), "cash → food");
  for (const effects of [
    [effect("cash", "-680"), effect("food", "680", "usd")],
    [effect("cash", "-680"), effect("food", "600"), effect("fees", "80")],
    [effect("cash", "-680"), effect("food", "100")],
  ]) assert.equal(quantitySummary({ effects }), "内訳を見る");
  assert.equal(quantitySummary({ effects: [] }), "数量の増減なし");
});

test("search is normalized literal AND matching across visible record fields", () => {
  assert.deepEqual(visibleRecords([first, second], { ...initial, query: "ＣＯＦＦＥＥ food" }), [first]);
  assert.deepEqual(visibleRecords([first, second], { ...initial, query: ".*" }), []);
  assert.deepEqual(visibleRecords([first, second], { ...initial, query: "-2470" }), [second]);
  assert.deepEqual(visibleRecords([first, second], { ...initial, query: "coffee", locus: "books" }), []);
});

test("day/locus scope and sorting are presentation-only", () => {
  const records = [first, second];
  assert.deepEqual(visibleRecords(records, { ...initial, scope: "day" }), [first]);
  assert.deepEqual(visibleRecords(records, { ...initial, locus: "books" }), [second]);
  assert.deepEqual(visibleRecords(records, { ...initial, order: "desc" }), [second, first]);
  assert.deepEqual(records, [first, second]);
});

test("selection cannot remain attached to a filtered-out row", () => {
  const state = reconcileSelection([first, second], { ...initial, query: "book" });
  assert.equal(state.selectedId, "b");
  assert.equal(state.selectedDate, "2026-10-07");
  const empty = reconcileSelection([first, second], { ...initial, query: "missing" });
  assert.equal(empty.selectedId, null);
  const emptyDay = reconcileSelection([first, second], { ...initial, scope: "day", selectedDate: "2026-10-03" });
  assert.equal(emptyDay.selectedId, null);
  assert.equal(emptyDay.selectedDate, "2026-10-03");
});

test("correction comparison preserves relation order and unknown dates", () => {
  const original = { ...first, id: "old", date: "2026-09-30", replacement: "middle" };
  const middle = { ...first, id: "middle", date: "", replacement: first.id };
  const current = { ...first, history: [original, middle] };
  assert.deepEqual(correctionPairs(current).map(({ before, after }) => [before.id, after.id]),
    [["old", "middle"], ["middle", "a"]]);
  assert.equal(correctionPairs(current)[1].before.date, "");
  assert.deepEqual(changedFields(middle, first), { date: true, description: false, effects: false });
});

test("Effect comparison ignores representation order but preserves exact tuples and multiplicity", () => {
  assert.equal(changedFields(first, { ...first, effects: [...first.effects].reverse() }).effects, false);
  assert.equal(changedFields(first, { ...first, effects: [...first.effects, first.effects[0]] }).effects, true);
  assert.equal(changedFields(first, { ...first, effects: [effect("cash", "-680"), effect("food", "680", "usd")] }).effects, true);
  const large = { ...first, effects: [effect("food", "900719925474099312345")] };
  assert.equal(changedFields(large, { ...large, effects: [effect("food", "900719925474099312346")] }).effects, true);
});

test("only the newest async request may publish a read answer or an error", () => {
  const gate = requestGate();
  const old = gate.next();
  const current = gate.next();
  assert.equal(gate.isCurrent(old), false);
  assert.equal(gate.isCurrent(current), true);
  const newest = gate.next();
  assert.equal(gate.isCurrent(current), false);
  assert.equal(gate.isCurrent(newest), true);
});
