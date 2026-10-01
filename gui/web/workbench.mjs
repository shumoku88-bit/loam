// Presentation mechanics only. No balance, admission, valuation or delta arithmetic.
export function localMonth(now = new Date()) {
  return String(now.getFullYear()).padStart(4, "0") + "-" +
    String(now.getMonth() + 1).padStart(2, "0");
}

export function shiftMonth(month, delta) {
  const [year, mon] = month.split("-").map(Number);
  const index = year * 12 + mon - 1 + delta;
  if (index < 12 || index > 9999 * 12 + 11) return month;
  return String(Math.floor(index / 12)).padStart(4, "0") + "-" +
    String(index % 12 + 1).padStart(2, "0");
}

// Gregorian calendar geometry only; UTC avoids DST and the Date constructor's
// special treatment of years 1..99. This is not household temporal evidence.
export function calendarDate(year, month, day) {
  const date = new Date(0);
  date.setUTCFullYear(year, month - 1, day);
  date.setUTCHours(12, 0, 0, 0);
  return date;
}

export function shiftCalendarDate(isoDate, days) {
  const [year, month, day] = isoDate.split("-").map(Number);
  const date = calendarDate(year, month, day + days);
  const nextYear = date.getUTCFullYear();
  if (nextYear < 1 || nextYear > 9999) return isoDate;
  return String(nextYear).padStart(4, "0") + "-" +
    String(date.getUTCMonth() + 1).padStart(2, "0") + "-" +
    String(date.getUTCDate()).padStart(2, "0");
}

export function unmodifiedNavigation(event) {
  return !event.isComposing && event.keyCode !== 229 &&
    !event.altKey && !event.ctrlKey && !event.metaKey && !event.shiftKey;
}

export function amountText(quanta) {
  return new Intl.NumberFormat("ja-JP").format(BigInt(quanta));
}

// Make control characters visible without collapsing different retained texts.
// Descriptions already carry LOAM's lossless single-line backslash escaping.
export function displayText(text) {
  return String(text).replace(/[\u0000-\u001f\u007f-\u009f]/g,
    (char) => "\\u" + char.charCodeAt(0).toString(16).padStart(4, "0"));
}

function simpleMovement(record) {
  if (record.effects.length !== 2) return null;
  const from = record.effects.find((effect) => effect.quanta.startsWith("-"));
  const to = record.effects.find((effect) => !effect.quanta.startsWith("-"));
  if (!from || !to || to.quanta === "0" || from.measure !== to.measure ||
      from.quanta.slice(1) !== to.quanta) return null;
  return { from, to };
}

export function movementSummary(record) {
  const simple = simpleMovement(record);
  return simple ? `${simple.from.locus} → ${simple.to.locus}` :
    `${record.effects.length} 件の増減`;
}

export function quantitySummary(record) {
  const simple = simpleMovement(record);
  if (simple) return `${amountText(simple.to.quanta)} ${simple.to.measure}`;
  // Do not summarize a split/multi-Measure Event as its first positive Effect.
  return record.effects.length ? "内訳を見る" : "数量の増減なし";
}

export function effectText(effect) {
  return `${effect.locus} · ${amountText(effect.quanta)} ${effect.measure}`;
}

const normalized = (text) => String(text).normalize("NFKC").toLowerCase();

export function visibleRecords(records, state) {
  const terms = normalized(state.query).trim().split(/\s+/).filter(Boolean);
  const rows = records.filter((record) => {
    if (state.scope === "day" && record.date !== state.selectedDate) return false;
    if (state.locus && !record.effects.some((effect) => effect.locus === state.locus)) return false;
    const fields = [record.id, record.date, record.description,
      ...record.effects.flatMap(({ locus, measure, quanta }) => [locus, measure, quanta])]
      .map(normalized);
    return terms.every((term) => fields.some((field) => field.includes(term)));
  });
  return state.order === "desc" ? rows.reverse() : rows;
}

export function reconcileSelection(records, state) {
  const rows = visibleRecords(records, state);
  const record = rows.find((row) => row.id === state.selectedId) ??
    rows.find((row) => row.date === state.selectedDate) ?? rows[0] ?? null;
  return { ...state, selectedId: record?.id ?? null,
    selectedDate: record && state.scope === "month" ? record.date : state.selectedDate };
}

// A new Event may have entirely new Effect identities. Compare whole exact tuples,
// preserving multiplicity; do not guess a pairing or compute aggregate differences.
function effectSignature(record) {
  return record.effects.map(({ locus, measure, quanta }) =>
    JSON.stringify([locus, measure, quanta])).sort().join("\n");
}

export function changedFields(before, after) {
  return {
    date: before.date !== after.date,
    description: before.description !== after.description,
    effects: effectSignature(before) !== effectSignature(after),
  };
}

export function correctionPairs(record) {
  const versions = [...record.history, record];
  return record.history.map((before, index) => ({ before, after: versions[index + 1] }));
}

export function requestGate() {
  let generation = 0;
  return {
    next: () => ++generation,
    isCurrent: (request) => request === generation,
  };
}
