import {
  localMonth, shiftMonth, calendarDate, shiftCalendarDate, unmodifiedNavigation,
  amountText, displayText, movementSummary, quantitySummary, effectText,
  visibleRecords, reconcileSelection, changedFields, correctionPairs, requestGate,
} from "./workbench.mjs";

const invoke = window.__TAURI__?.core?.invoke;
const $ = (id) => document.getElementById(id);
const STORAGE = {
  dataDir: "loam.gui.dataDir", scope: "loam.gui.actualScope",
  calendar: "loam.gui.calendarOpen", inspectorWidth: "loam.gui.inspectorWidth",
  density: "loam.gui.density", order: "loam.gui.order",
};
function storageGet(key) {
  try { return localStorage.getItem(key); } catch { return null; }
}
function storageSet(key, value) {
  try { localStorage.setItem(key, value); } catch { /* Disposable UI preferences only. */ }
}
let state = {
  month: localMonth(), records: [], selectedDate: null, selectedId: null,
  calendarFocusDate: null,
  scope: storageGet(STORAGE.scope) === "day" ? "day" : "month",
  order: storageGet(STORAGE.order) === "desc" ? "desc" : "asc",
  query: "", locus: "", tab: "evidence", historyIndex: null,
  loadState: "loading",
};
const gate = requestGate();
// Explicit day confirmation can happen while a read is pending.
let calendarSelectionVersion = 0;
let calendarOpen = window.matchMedia("(min-width: 1101px)").matches &&
  storageGet(STORAGE.calendar) !== "false";
let inspectorWidth = Number(storageGet(STORAGE.inspectorWidth)) || 360;
let calendarReturnFocus = null;

function node(tag, className, text) {
  const element = document.createElement(tag);
  if (className) element.className = className;
  if (text !== undefined) element.textContent = displayText(text);
  return element;
}
function rows() { return visibleRecords(state.records, state); }
function currentRecord() { return rows().find((record) => record.id === state.selectedId) ?? null; }
function recordsOn(date) { return state.records.filter((record) => record.date === date); }
function monthLabel(month) {
  const [year, mon] = month.split("-").map(Number);
  return `${year}年${mon}月`;
}
function todayText() {
  const now = new Date();
  return localMonth(now) + "-" + String(now.getDate()).padStart(2, "0");
}
function reconcile() {
  const oldId = state.selectedId;
  state = reconcileSelection(state.records, state);
  if (oldId !== state.selectedId) state.historyIndex = null;
}
function selectRecord(record, focus = false) {
  if (state.selectedId !== record.id) state.historyIndex = null;
  state.selectedId = record.id;
  state.selectedDate = record.date;
  render();
  if (focus) focusSelectedRow();
}
function focusSelectedRow() {
  const target = $("actual-body").querySelector("tr.selected, tr[tabindex='0']") ?? $("table-wrap");
  target.focus({ preventScroll: true });
  target.scrollIntoView({ block: "nearest", inline: "nearest" });
}

function calendarButton(date) {
  return [...$("calendar").querySelectorAll(".calendar-day")].find((button) => button.dataset.date === date);
}
function focusCalendar() {
  const target = calendarButton(state.calendarFocusDate);
  target?.focus({ preventScroll: true });
  target?.scrollIntoView({ block: "nearest", inline: "nearest" });
}
function confirmCalendarDate(date) {
  calendarSelectionVersion += 1;
  state.selectedDate = date;
  state.selectedId = rows().find((record) => record.date === date)?.id ?? null;
  state.historyIndex = null;
  if (window.matchMedia("(max-width: 1100px)").matches) setCalendar(false);
  render();
  focusSelectedRow();
}
function moveCalendarFocus(date, key) {
  const days = { ArrowLeft: -1, ArrowRight: 1, ArrowUp: -7, ArrowDown: 7 }[key];
  if (days === undefined) return false;
  state.calendarFocusDate = shiftCalendarDate(date, days);
  const month = state.calendarFocusDate.slice(0, 7);
  if (month !== state.month) {
    state.month = month;
    state.selectedDate = null;
    state.selectedId = null;
    // Preview another month, but do not select a day/record without confirmation.
    loadMonth({ selectOnLoad: false });
  } else {
    focusCalendar();
  }
  return true;
}

// Return anchors survive read-driven replacement of calendar buttons/table rows.
function rememberFocus() {
  const active = document.activeElement;
  const date = active?.closest(".calendar-day")?.dataset.date;
  const id = active?.closest("tr[data-id]")?.dataset.id;
  const elementId = active?.id;
  const inDataSource = active?.closest(".data-source");
  return () => {
    const row = id && [...$("actual-body").querySelectorAll("tr")].find((row) => row.dataset.id === id);
    const target = date ? calendarButton(date) : row || (elementId ? $(elementId) : active);
    if (target?.isConnected && target.getClientRects().length) {
      target.focus({ preventScroll: true });
      target.scrollIntoView({ block: "nearest", inline: "nearest" });
    } else if (inDataSource) $("data-toggle").focus();
    else focusSelectedRow();
  };
}
function closeDataSource() {
  const source = document.querySelector(".data-source");
  const returnFocus = source.contains(document.activeElement);
  source.open = false;
  if (returnFocus) $("data-toggle").focus();
}

function renderCalendar() {
  const [year, month] = state.month.split("-").map(Number);
  const offset = (calendarDate(year, month, 1).getUTCDay() + 6) % 7;
  const days = calendarDate(year, month + 1, 0).getUTCDate();
  const calendar = $("calendar");
  const hadFocus = calendar.contains(document.activeElement);
  if (!state.calendarFocusDate?.startsWith(state.month + "-")) {
    state.calendarFocusDate = state.selectedDate?.startsWith(state.month + "-") ? state.selectedDate :
      todayText().startsWith(state.month + "-") ? todayText() : state.month + "-01";
  }
  calendar.replaceChildren();
  for (let i = 0; i < offset; i += 1) calendar.append(node("div", "calendar-spacer"));
  for (let day = 1; day <= days; day += 1) {
    const date = state.month + "-" + String(day).padStart(2, "0");
    const count = recordsOn(date).length;
    const button = node("button", "calendar-day", String(day));
    button.type = "button";
    button.dataset.date = date;
    button.tabIndex = date === state.calendarFocusDate ? 0 : -1;
    const evidence = state.loadState === "ready" ? `${count}件の記録` : "記録は未読込";
    button.setAttribute("aria-label", `${date}、${evidence}`);
    button.setAttribute("aria-pressed", String(date === state.selectedDate));
    button.title = `${date} · ${evidence}`;
    button.classList.toggle("selected", date === state.selectedDate);
    button.classList.toggle("has-records", count > 0);
    button.classList.toggle("today", date === todayText());
    button.addEventListener("focus", () => {
      state.calendarFocusDate = date;
      for (const day of calendar.querySelectorAll(".calendar-day")) day.tabIndex = day === button ? 0 : -1;
    });
    button.addEventListener("click", () => confirmCalendarDate(date));
    button.addEventListener("keydown", (event) => {
      if (!unmodifiedNavigation(event)) return;
      if (moveCalendarFocus(date, event.key)) event.preventDefault();
      // Native button Enter/Space activation confirms; arrows never activate.
    });
    calendar.append(button);
  }
  if (hadFocus && calendarOpen) focusCalendar();
  $("selected-day").textContent = state.selectedDate ?? "日付を選んでください";
  $("selected-day-count").textContent = !state.selectedDate ? "" : state.loadState === "ready" ?
    `${recordsOn(state.selectedDate).length}件の現在の記録` : "未読込";
}

function renderLocusOptions() {
  const loci = [...new Set(state.records.flatMap((record) => record.effects.map((effect) => effect.locus)))];
  if (state.locus && !loci.includes(state.locus)) loci.push(state.locus);
  loci.sort((a, b) => a.localeCompare(b, "ja"));
  const options = [node("option", "", "すべての場所")];
  options[0].value = "";
  for (const locus of loci) {
    const option = node("option", "", locus);
    option.value = locus;
    options.push(option);
  }
  $("locus-filter").replaceChildren(...options);
  $("locus-filter").value = state.locus;
}

function renderTable() {
  const visible = rows();
  const body = $("actual-body");
  const hadRowFocus = body.contains(document.activeElement) || document.activeElement === $("table-wrap");
  body.replaceChildren();
  $("table-wrap").tabIndex = visible.length ? -1 : 0;
  $("empty").hidden = visible.length > 0;
  $("empty").textContent = state.loadState === "loading" ? "Loam の記録を読み込んでいます…" :
    state.loadState === "error" ? "記録を読み込めませんでした。データの場所を確認して読み直してください。" :
    state.records.length === 0 ? "この月の現在の記録はありません。" :
    "表示条件に合う記録はありません。検索や絞り込みを解除してみてください。";
  let previousDate = null;
  for (const [index, record] of visible.entries()) {
    const row = node("tr");
    row.dataset.id = record.id;
    row.tabIndex = record.id === state.selectedId || (!state.selectedId && index === 0) ? 0 : -1;
    row.classList.toggle("selected", record.id === state.selectedId);
    row.classList.toggle("day-start", record.date !== previousDate);
    row.setAttribute("aria-selected", String(record.id === state.selectedId));
    const date = node("td", "date-cell", record.date.slice(5).replace("-", "/"));
    date.title = record.date;
    date.setAttribute("aria-label", record.date);
    date.classList.toggle("repeated", record.date === previousDate);
    const description = node("td", "description", record.description || "（内容なし）");
    description.title = displayText(record.description);
    if (record.history.length) {
      const marker = node("span", "history-marker", "↺");
      marker.setAttribute("aria-label", `${record.history.length}件の訂正履歴`);
      description.append(marker);
    }
    const movement = node("td", "movement", movementSummary(record));
    movement.title = record.effects.map((effect) => displayText(effectText(effect))).join("\n");
    const amount = node("td", "amount", quantitySummary(record));
    amount.title = movement.title;
    row.append(date, description, movement, amount);
    row.addEventListener("click", () => selectRecord(record, true));
    row.addEventListener("keydown", (event) => {
      if (!unmodifiedNavigation(event)) return;
      let target = index;
      if (event.key === "ArrowDown") target = Math.min(index + 1, visible.length - 1);
      else if (event.key === "ArrowUp") target = Math.max(index - 1, 0);
      else if (event.key === "Home") target = 0;
      else if (event.key === "End") target = visible.length - 1;
      else if (event.key === "Enter" || event.key === " ") {
        event.preventDefault();
        selectRecord(record);
        $("tab-" + state.tab).focus();
        return;
      } else return;
      event.preventDefault();
      selectRecord(visible[target], true);
    });
    body.append(row);
    previousDate = record.date;
  }
  if (hadRowFocus) focusSelectedRow();
  $("visible-count").textContent = state.loadState === "ready" ?
    `${visible.length} / ${state.records.length}件` : "未読込";
  $("month-count").textContent = state.loadState === "ready" ? `${state.records.length}件` : "";
  $("table-wrap").setAttribute("aria-busy", String(state.loadState === "loading"));
}

function renderEvidence(record) {
  const target = $("selected-detail");
  if (!record) {
    target.replaceChildren(node("p", "muted selection-empty",
      "一覧から記録を選ぶと、移動の内訳と根拠をここに表示します。"));
    return;
  }
  const heading = node("div");
  heading.append(node("h2", "selected-description", record.description || "（内容なし）"));
  const meta = node("div", "record-meta");
  meta.append(node("span", "readonly-badge", "現在の記録"), node("span", "", record.date));
  heading.append(meta);
  const effectSection = node("section");
  effectSection.append(node("h3", "evidence-heading", "場所ごとの増減（記録された数量）"));
  const effects = node("div", "effects");
  for (const effect of record.effects) {
    const line = node("div", "effect-row");
    line.append(node("span", "effect-locus", effect.locus),
      node("span", "effect-quanta", amountText(effect.quanta)),
      node("span", "effect-measure", `単位: ${effect.measure} · quanta`));
    effects.append(line);
  }
  if (!record.effects.length) effects.append(node("p", "muted", "数量の増減は記録されていません。"));
  effectSection.append(effects);
  const technical = node("details", "technical-info");
  technical.id = "technical-info";
  const technicalToggle = node("summary", "", "記録の識別情報");
  technicalToggle.id = "technical-toggle";
  technical.append(technicalToggle, node("div", "event-id", record.id));
  target.replaceChildren(heading, effectSection, technical,
    node("p", "evidence-note", "数量は正確な quanta のまま表示しています。異なる単位の合算や換算、口座残高の推測はしません。"));
}

function versionCard(record, title, changes) {
  const card = node("section", "version-card");
  const heading = node("div", "version-heading");
  heading.append(node("strong", "", title), node("div", "event-id", record.id));
  card.append(heading);
  for (const [key, label, value] of [
    ["date", "日付", record.date || "日付不明"],
    ["description", "内容", record.description || "（内容なし）"],
    ["effects", "増減の構成", null],
  ]) {
    const field = node("div", "version-field" + (changes[key] ? " changed" : ""));
    const caption = node("div", "version-label");
    caption.append(node("span", "", label));
    if (changes[key]) caption.append(node("span", "change-label", "変更"));
    field.append(caption);
    if (key === "effects") {
      const effects = node("div", "version-effects");
      for (const effect of record.effects) effects.append(node("div", "", effectText(effect)));
      if (!record.effects.length) effects.append(node("span", "muted", "数量の増減なし"));
      field.append(effects);
    } else field.append(node("div", "", value));
    card.append(field);
  }
  return card;
}

function renderHistory(record) {
  const target = $("history-detail");
  if (!record) {
    target.replaceChildren(node("p", "muted selection-empty", "訂正前後を調べたい記録を一覧から選んでください。"));
    return;
  }
  const pairs = correctionPairs(record);
  if (!pairs.length) {
    target.replaceChildren(node("p", "history-intro", "この記録につながる、記録そのものの訂正はありません。"),
      node("p", "evidence-note", "日付だけの訂正履歴は、この表示には含まれません。"));
    return;
  }
  state.historyIndex = Math.max(0, Math.min(state.historyIndex ?? pairs.length - 1, pairs.length - 1));
  const picker = node("label", "history-picker", "比較する訂正");
  const select = node("select");
  select.id = "history-step";
  for (const [index, pair] of pairs.entries()) {
    const option = node("option", "", `${index + 1} / ${pairs.length} · ${pair.before.id} → ${pair.after.id}`);
    option.value = String(index);
    select.append(option);
  }
  select.value = String(state.historyIndex);
  select.addEventListener("change", () => {
    state.historyIndex = Number(select.value);
    renderHistory(record);
    $("history-step").focus();
  });
  picker.append(select);
  const { before, after } = pairs[state.historyIndex];
  const changes = changedFields(before, after);
  const summary = node("div", "change-summary");
  for (const [key, label] of [["date", "日付"], ["description", "内容"], ["effects", "増減の構成"]]) {
    if (changes[key]) summary.append(node("span", "change-chip", `${label}が変更`));
  }
  if (!Object.values(changes).some(Boolean)) summary.append(node("span", "muted", "表示対象の内容・日付・増減の構成は同じです。"));
  const comparison = node("div", "comparison");
  comparison.append(versionCard(before, "訂正前", changes), versionCard(after, "訂正後", changes));
  target.replaceChildren(node("p", "history-intro", "保存された訂正関係で結ばれた記録を、そのまま並べています。"),
    picker, summary, comparison,
    node("p", "evidence-note", "順序は訂正関係に基づきます。表示する日付は各記録の現在の有効日で、訂正した日時ではありません。日付だけの訂正履歴や、数量の差額計算は含みません。"));
}

function renderInspector() {
  const record = currentRecord();
  const active = document.activeElement;
  const hadFocus = document.querySelector(".inspector-pane").contains(active);
  const focusedId = active?.id;
  $("selected-date").textContent = record?.date ?? "未選択";
  $("history-count").textContent = record ? `${record.history.length}件` : "";
  renderEvidence(record);
  renderHistory(record);
  if (hadFocus && !active.isConnected) {
    const target = focusedId && $(focusedId);
    (target?.getClientRects().length ? target : $("tab-" + state.tab)).focus({ preventScroll: true });
  }
}
function setTab(tab, focus = false) {
  state.tab = tab;
  for (const name of ["evidence", "history"]) {
    $("tab-" + name).setAttribute("aria-selected", String(name === tab));
    $("tab-" + name).tabIndex = name === tab ? 0 : -1;
    $(name + "-panel").hidden = name !== tab;
  }
  if (focus) $("tab-" + tab).focus();
}
function render() {
  $("month-title").textContent = monthLabel(state.month);
  $("scope-month").setAttribute("aria-pressed", String(state.scope === "month"));
  $("scope-day").setAttribute("aria-pressed", String(state.scope === "day"));
  renderCalendar();
  renderTable();
  renderInspector();
}

async function loadMonth({ selectOnLoad = true } = {}) {
  const request = gate.next();
  const selectionVersion = calendarSelectionVersion;
  const requestedMonth = state.month;
  const preferredId = state.selectedId;
  const dataDir = $("data-dir").value.trim() || null;
  storageSet(STORAGE.dataDir, dataDir ?? "");
  state.records = [];
  state.selectedId = null;
  state.historyIndex = null;
  state.loadState = "loading";
  $("status").classList.remove("error");
  $("status").textContent = "読み込み中…";
  $("load-notice").hidden = true;
  render();
  try {
    if (!invoke) throw new Error("Tauri から起動してください。通常のブラウザーでは家計データを読み込みません。");
    const result = await invoke("load_actual", { month: requestedMonth, dataDir });
    if (!gate.isCurrent(request)) return;
    if (result.month !== requestedMonth || !Array.isArray(result.records)) {
      throw new Error("Loam の応答が要求した月と一致しません。");
    }
    state.records = result.records;
    state.loadState = "ready";
    if (selectOnLoad && selectionVersion === calendarSelectionVersion) {
      state.selectedId = preferredId;
      if (!state.selectedDate?.startsWith(requestedMonth + "-")) {
        state.selectedDate = todayText().startsWith(requestedMonth + "-") ? todayText() : requestedMonth + "-01";
      }
      reconcile();
    } else {
      // Preserve an explicit day (including an empty one), never fall back to another day.
      state.selectedId = rows().find((record) => record.date === state.selectedDate)?.id ?? null;
    }
    renderLocusOptions();
    render();
    $("status").textContent = `${result.records.length}件の現在の記録 · 閲覧専用 · 家計データは変更しません`;
    closeDataSource();
  } catch (error) {
    if (!gate.isCurrent(request)) return;
    state.records = [];
    state.selectedId = null;
    state.loadState = "error";
    renderLocusOptions();
    render();
    $("status").classList.add("error");
    $("status").textContent = "読み込みに失敗しました · データは変更されていません";
    $("load-notice").textContent = String(error);
    $("load-notice").hidden = false;
    document.querySelector(".data-source").open = true;
  }
}

function navigateMonth(month) {
  if (month === state.month && state.loadState === "loading") return;
  state.month = month;
  state.calendarFocusDate = null;
  state.selectedDate = null;
  state.selectedId = null;
  loadMonth();
}
function setScope(scope) {
  state.scope = scope;
  storageSet(STORAGE.scope, scope);
  reconcile();
  render();
}
function clearFilters() {
  state.query = "";
  state.locus = "";
  state.scope = "month";
  $("search").value = "";
  $("locus-filter").value = "";
  storageSet(STORAGE.scope, "month");
  reconcile();
  render();
}
function setCalendar(open, remember = true) {
  const hadFocus = document.querySelector(".calendar-pane").contains(document.activeElement);
  calendarOpen = open;
  $("workspace").classList.toggle("calendar-open", open);
  $("toggle-calendar").setAttribute("aria-expanded", String(open));
  if (remember) storageSet(STORAGE.calendar, String(open));
  setInspectorWidth(inspectorWidth);
  if (!open) {
    const restore = calendarReturnFocus;
    calendarReturnFocus = null;
    if (hadFocus) {
      if (restore) restore(); else $("toggle-calendar").focus();
    }
  }
}
function toggleCalendar() {
  if (!calendarOpen) calendarReturnFocus = rememberFocus();
  setCalendar(!calendarOpen);
  if (calendarOpen) focusCalendar();
}
function setInspectorWidth(width) {
  const calendarWidth = calendarOpen && window.matchMedia("(min-width: 1101px)").matches ? 212 : 0;
  const available = $("workspace").getBoundingClientRect().width - calendarWidth - 400;
  const maximum = Math.max(280, Math.min(620, available));
  inspectorWidth = Math.max(280, Math.min(width, maximum));
  $("workspace").style.setProperty("--inspector-width", inspectorWidth + "px");
  $("splitter").setAttribute("aria-valuenow", String(Math.round(inspectorWidth)));
  $("splitter").setAttribute("aria-valuemax", String(Math.round(maximum)));
}

const commands = [
  { label: "記録を検索", terms: "search find", key: "/ · ⌘F", run: () => $("search").focus() },
  { label: "今月を表示", terms: "today month", run: () => navigateMonth(localMonth()) },
  { label: "前の月", terms: "previous month", key: "Alt＋←", run: () => navigateMonth(shiftMonth(state.month, -1)) },
  { label: "次の月", terms: "next month", key: "Alt＋→", run: () => navigateMonth(shiftMonth(state.month, 1)) },
  { label: "カレンダーを表示 / 非表示", terms: "calendar date", run: toggleCalendar },
  { label: "月全体を表示", terms: "all month", run: () => setScope("month") },
  { label: "選択日だけ表示", terms: "day scope", run: () => setScope("day") },
  { label: "絞り込みを解除", terms: "clear filter", run: clearFilters },
  { label: "選択した記録の訂正前後を見る", terms: "history correction", run: () => setTab("history", true) },
  { label: "データを読み直す", terms: "reload refresh", run: loadMonth },
];
let commandIndex = 0;
function commandMatches() {
  const query = $("command-query").value.trim().toLowerCase();
  return commands.filter((command) => `${command.label} ${command.terms}`.toLowerCase().includes(query));
}
let commandReturnFocus = null;
function closeCommands() {
  $("commands").close();
  const restore = commandReturnFocus;
  commandReturnFocus = null;
  restore?.();
}
function runCommand(command) { closeCommands(); command.run(); }
function renderCommands() {
  const matches = commandMatches();
  commandIndex = Math.max(0, Math.min(commandIndex, matches.length - 1));
  const buttons = matches.map((command, index) => {
    const button = node("button", index === commandIndex ? "active" : "");
    button.type = "button";
    button.append(node("span", "", command.label), node("kbd", "", command.key ?? ""));
    button.addEventListener("click", () => runCommand(command));
    return button;
  });
  $("command-list").replaceChildren(...(buttons.length ? buttons : [node("p", "muted", "一致する操作はありません。") ]));
}
function openCommands() {
  commandReturnFocus = rememberFocus();
  $("command-query").value = "";
  commandIndex = 0;
  renderCommands();
  $("commands").showModal();
  $("command-query").focus();
}

$("previous-month").addEventListener("click", () => navigateMonth(shiftMonth(state.month, -1)));
$("next-month").addEventListener("click", () => navigateMonth(shiftMonth(state.month, 1)));
$("today-month").addEventListener("click", () => navigateMonth(localMonth()));
$("reload").addEventListener("click", loadMonth);
$("data-dir").addEventListener("keydown", (event) => { if (event.key === "Enter" && !event.isComposing) loadMonth(); });
$("scope-month").addEventListener("click", () => setScope("month"));
$("scope-day").addEventListener("click", () => setScope("day"));
$("clear-filters").addEventListener("click", clearFilters);
$("search").addEventListener("input", () => { state.query = $("search").value; reconcile(); render(); });
$("search").addEventListener("keydown", (event) => {
  if (event.key === "Enter" && !event.isComposing) { event.preventDefault(); focusSelectedRow(); }
});
$("locus-filter").addEventListener("change", () => { state.locus = $("locus-filter").value; reconcile(); render(); });
$("sort-order").addEventListener("change", () => {
  state.order = $("sort-order").value;
  storageSet(STORAGE.order, state.order);
  reconcile(); render();
});
$("density").addEventListener("change", () => {
  $("workspace").dataset.density = $("density").value;
  storageSet(STORAGE.density, $("density").value);
});
$("toggle-calendar").addEventListener("click", toggleCalendar);
$("close-calendar").addEventListener("click", () => setCalendar(false));
for (const name of ["evidence", "history"]) {
  $("tab-" + name).addEventListener("click", () => setTab(name));
  $("tab-" + name).addEventListener("keydown", (event) => {
    if (!unmodifiedNavigation(event)) return;
    if (["ArrowLeft", "ArrowRight", "Home", "End"].includes(event.key)) {
      event.preventDefault();
      const target = event.key === "Home" ? "evidence" : event.key === "End" ? "history" : name === "evidence" ? "history" : "evidence";
      for (const tab of ["evidence", "history"]) $("tab-" + tab).tabIndex = tab === target ? 0 : -1;
      $("tab-" + target).focus();
      // Enter/Space confirms the tab through its native button click.
    }
  });
}
$("open-commands").addEventListener("click", openCommands);
$("close-commands").addEventListener("click", closeCommands);
$("commands").addEventListener("cancel", (event) => { event.preventDefault(); closeCommands(); });
$("command-query").addEventListener("input", () => { commandIndex = 0; renderCommands(); });
$("command-query").addEventListener("keydown", (event) => {
  if (!unmodifiedNavigation(event)) return;
  if (event.key === "ArrowDown" || event.key === "ArrowUp") {
    event.preventDefault();
    commandIndex += event.key === "ArrowDown" ? 1 : -1;
    renderCommands();
  } else if (event.key === "Enter") {
    event.preventDefault();
    const command = commandMatches()[commandIndex];
    if (command) runCommand(command);
  }
});

document.addEventListener("keydown", (event) => {
  if (event.defaultPrevented || event.isComposing || event.keyCode === 229) return;
  const modifier = event.metaKey || event.ctrlKey;
  if (modifier && event.key.toLowerCase() === "k") {
    event.preventDefault();
    if ($("commands").open) closeCommands(); else openCommands();
    return;
  }
  if ($("commands").open) return;
  if (event.key === "Escape" && document.querySelector(".data-source").open &&
      event.target.closest(".data-source")) {
    event.preventDefault(); closeDataSource(); return;
  }
  if (modifier && event.key.toLowerCase() === "f") { event.preventDefault(); $("search").focus(); return; }
  const editing = event.target instanceof HTMLElement &&
    (event.target.matches("input, textarea, select") || event.target.isContentEditable);
  if (event.altKey && ["ArrowLeft", "ArrowRight"].includes(event.key) && !editing) {
    event.preventDefault();
    navigateMonth(shiftMonth(state.month, event.key === "ArrowLeft" ? -1 : 1));
  } else if (event.key === "/" && !modifier && !editing) {
    event.preventDefault(); $("search").focus();
  } else if (event.key === "Escape" && event.target === $("search")) {
    event.preventDefault(); state.query = ""; $("search").value = ""; reconcile(); render(); focusSelectedRow();
  } else if (event.key === "Escape" && !editing) {
    const technical = event.target.closest(".technical-info[open]");
    if (technical) {
      event.preventDefault(); technical.open = false; technical.querySelector("summary").focus();
    } else if (event.target.closest(".calendar-pane")) {
      event.preventDefault();
      if (window.matchMedia("(max-width: 1100px)").matches) setCalendar(false);
      else focusSelectedRow();
    } else if (event.target.closest(".inspector-pane")) {
      event.preventDefault(); focusSelectedRow();
    }
  }
});

let dragging = false;
$("splitter").addEventListener("pointerdown", (event) => {
  if (event.button !== 0) return;
  event.preventDefault();
  dragging = true;
  $("splitter").classList.add("dragging");
  $("splitter").setPointerCapture(event.pointerId);
});
$("splitter").addEventListener("pointermove", (event) => {
  if (dragging) setInspectorWidth($("workspace").getBoundingClientRect().right - event.clientX - 14);
});
for (const name of ["pointerup", "pointercancel", "lostpointercapture"]) {
  $("splitter").addEventListener(name, () => {
    if (!dragging) return;
    dragging = false;
    $("splitter").classList.remove("dragging");
    storageSet(STORAGE.inspectorWidth, String(Math.round(inspectorWidth)));
  });
}
$("splitter").addEventListener("keydown", (event) => {
  if (!unmodifiedNavigation(event) || !["ArrowLeft", "ArrowRight", "Home", "End"].includes(event.key)) return;
  event.preventDefault();
  setInspectorWidth(event.key === "Home" ? 280 : event.key === "End" ? 620 : inspectorWidth + (event.key === "ArrowLeft" ? 24 : -24));
  storageSet(STORAGE.inspectorWidth, String(Math.round(inspectorWidth)));
});
window.addEventListener("resize", () => {
  // A docked calendar must not become an unsolicited overlay over the inspector.
  if (calendarOpen && window.matchMedia("(max-width: 1100px)").matches) setCalendar(false, false);
  setInspectorWidth(inspectorWidth);
});
document.addEventListener("pointerdown", (event) => {
  if (calendarOpen && window.matchMedia("(max-width: 1100px)").matches &&
      !event.target.closest(".calendar-pane, #toggle-calendar")) setCalendar(false);
});

$("data-dir").value = storageGet(STORAGE.dataDir) ?? "";
$("sort-order").value = state.order;
$("density").value = storageGet(STORAGE.density) === "comfortable" ? "comfortable" : "compact";
$("workspace").dataset.density = $("density").value;
setCalendar(calendarOpen, false);
setTab(state.tab);
render();
loadMonth();
