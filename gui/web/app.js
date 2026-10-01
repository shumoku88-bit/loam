const invoke = window.__TAURI__?.core?.invoke;

const STORAGE = {
  dataDir: "loam.gui.dataDir",
  calendarWidth: "loam.gui.calendarWidth",
  scope: "loam.gui.actualScope",
};

const state = {
  month: localMonth(),
  records: [],
  selectedDate: null,
  selectedId: null,
  scope: readStoredScope(),
  query: "",
};

const els = {
  monthTitle: document.querySelector("#month-title"),
  monthCount: document.querySelector("#month-count"),
  selectedDayCount: document.querySelector("#selected-day-count"),
  visibleCount: document.querySelector("#visible-count"),
  calendar: document.querySelector("#calendar"),
  actualBody: document.querySelector("#actual-body"),
  empty: document.querySelector("#empty"),
  selectedDate: document.querySelector("#selected-date"),
  selectedDetail: document.querySelector("#selected-detail"),
  status: document.querySelector("#status"),
  dataDir: document.querySelector("#data-dir"),
  dataSource: document.querySelector(".data-source"),
  search: document.querySelector("#search"),
  scopeMonth: document.querySelector("#scope-month"),
  scopeDay: document.querySelector("#scope-day"),
  workspace: document.querySelector("#workspace"),
  splitter: document.querySelector("#splitter"),
};

function storageGet(key) {
  try {
    return localStorage.getItem(key);
  } catch {
    return null;
  }
}

function storageSet(key, value) {
  try {
    localStorage.setItem(key, value);
  } catch {
    // UI preferences are disposable; failure must not block household reads.
  }
}

function readStoredScope() {
  return storageGet(STORAGE.scope) === "day" ? "day" : "month";
}

function localMonth() {
  const now = new Date();
  return now.getFullYear() + "-" + String(now.getMonth() + 1).padStart(2, "0");
}

function shiftMonth(month, delta) {
  const parts = month.split("-").map(Number);
  const date = new Date(parts[0], parts[1] - 1 + delta, 1);
  return date.getFullYear() + "-" + String(date.getMonth() + 1).padStart(2, "0");
}

function monthLabel(month) {
  const parts = month.split("-").map(Number);
  return new Intl.DateTimeFormat("ja-JP", { year: "numeric", month: "long" })
    .format(new Date(parts[0], parts[1] - 1, 1));
}

function amountText(quanta) {
  try {
    return new Intl.NumberFormat("ja-JP").format(BigInt(quanta));
  } catch {
    return quanta;
  }
}

function movementSummary(record) {
  if (record.effects.length === 2) {
    const negative = record.effects.find((effect) => effect.quanta.startsWith("-"));
    const positive = record.effects.find((effect) => !effect.quanta.startsWith("-"));
    if (negative && positive) {
      return negative.locus + " → " + positive.locus;
    }
  }
  return record.effects.length + " effects";
}

function quantitySummary(record) {
  const positive = record.effects.find((effect) => !effect.quanta.startsWith("-"));
  const effect = positive ?? record.effects[0];
  if (!effect) return "";
  return amountText(effect.quanta.replace(/^-/, "")) + " " + effect.measure;
}

function currentRecord() {
  return state.records.find((record) => record.id === state.selectedId) ?? null;
}

function recordsOn(date) {
  return state.records.filter((record) => record.date === date);
}

function matchesQuery(record) {
  const query = state.query.trim().toLowerCase();
  if (!query) return true;

  const fields = [
    record.id,
    record.date,
    record.description,
    ...record.effects.flatMap((effect) => [
      effect.locus,
      effect.measure,
      effect.quanta,
    ]),
  ];

  return fields.some((field) => String(field).toLowerCase().includes(query));
}

function visibleRecords() {
  return state.records.filter((record) => {
    if (state.scope === "day" && state.selectedDate && record.date !== state.selectedDate) {
      return false;
    }
    return matchesQuery(record);
  });
}

function ensureSelection() {
  if (state.selectedId && currentRecord()) return;

  if (state.selectedDate) {
    const record = recordsOn(state.selectedDate)[0];
    if (record) {
      state.selectedId = record.id;
      return;
    }
  }

  const today = new Date();
  const todayText =
    today.getFullYear() + "-" +
    String(today.getMonth() + 1).padStart(2, "0") + "-" +
    String(today.getDate()).padStart(2, "0");

  if (todayText.startsWith(state.month + "-")) {
    state.selectedDate = todayText;
    const record = recordsOn(todayText)[0];
    state.selectedId = record?.id ?? null;
    return;
  }

  state.selectedDate = state.month + "-01";
  state.selectedId = state.records[0]?.id ?? null;
}

function renderCalendar() {
  els.calendar.replaceChildren();
  const parts = state.month.split("-").map(Number);
  const year = parts[0];
  const mon = parts[1];
  const first = new Date(year, mon - 1, 1);
  const days = new Date(year, mon, 0).getDate();
  const mondayOffset = (first.getDay() + 6) % 7;

  for (let i = 0; i < mondayOffset; i += 1) {
    const spacer = document.createElement("div");
    spacer.className = "calendar-spacer";
    els.calendar.append(spacer);
  }

  for (let day = 1; day <= days; day += 1) {
    const date = state.month + "-" + String(day).padStart(2, "0");
    const count = recordsOn(date).length;
    const button = document.createElement("button");
    button.type = "button";
    button.className = "calendar-day";
    button.textContent = String(day);
    button.title = count ? count + " Actual" : "No Actual";

    if (date === state.selectedDate) button.classList.add("selected");
    if (count) button.classList.add("has-records");

    button.addEventListener("click", () => {
      state.selectedDate = date;
      state.selectedId = recordsOn(date)[0]?.id ?? null;
      render();

      if (state.scope === "month" && state.selectedId) {
        const selector = 'tr[data-id="' + CSS.escape(state.selectedId) + '"]';
        document.querySelector(selector)?.scrollIntoView({
          block: "center",
          behavior: "smooth",
        });
      }
    });

    els.calendar.append(button);
  }
}

function renderScope() {
  els.scopeMonth.classList.toggle("selected", state.scope === "month");
  els.scopeDay.classList.toggle("selected", state.scope === "day");
  els.scopeMonth.setAttribute("aria-pressed", String(state.scope === "month"));
  els.scopeDay.setAttribute("aria-pressed", String(state.scope === "day"));
}

function renderTable() {
  const rows = visibleRecords();
  els.actualBody.replaceChildren();
  els.empty.hidden = rows.length !== 0;

  if (rows.length === 0) {
    els.empty.textContent =
      state.records.length === 0
        ? "この月のCurrent Actualはありません。"
        : "現在の表示条件に合うActualはありません。";
  }

  let previousDate = null;

  for (const record of rows) {
    const row = document.createElement("tr");
    row.dataset.id = record.id;
    row.tabIndex = 0;

    const isDayStart = record.date !== previousDate;
    if (isDayStart) row.classList.add("day-start");
    if (record.id === state.selectedId) row.classList.add("selected");
    if (record.date === state.selectedDate) row.classList.add("focus-date");

    const date = document.createElement("td");
    date.className = "date-cell";
    date.textContent = isDayStart ? record.date : record.date;
    if (!isDayStart) {
      date.classList.add("repeated");
      date.setAttribute("aria-label", record.date);
    }

    const description = document.createElement("td");
    description.className = "description";
    description.textContent = record.description || "(no description)";
    description.title = record.description;

    const movement = document.createElement("td");
    movement.className = "movement";
    movement.textContent = movementSummary(record);
    movement.title = record.effects
      .map((effect) => effect.locus + " " + effect.quanta + " " + effect.measure)
      .join(" · ");

    const amount = document.createElement("td");
    amount.className = "amount";
    amount.textContent = quantitySummary(record);

    row.append(date, description, movement, amount);

    const select = () => {
      state.selectedId = record.id;
      state.selectedDate = record.date;
      render();
    };

    row.addEventListener("click", select);
    row.addEventListener("keydown", (event) => {
      if (event.key === "Enter" || event.key === " ") {
        event.preventDefault();
        select();
      }
    });

    els.actualBody.append(row);
    previousDate = record.date;
  }

  els.visibleCount.textContent =
    rows.length === state.records.length && !state.query
      ? rows.length + " rows"
      : rows.length + " / " + state.records.length + " rows";
}

function renderSelected() {
  const record = currentRecord();

  if (!record) {
    els.selectedDate.textContent = state.selectedDate ?? "行を選択してください";
    els.selectedDetail.innerHTML =
      '<p class="muted">この日にはCurrent Actualがありません。月間表はそのまま残ります。</p>';
    return;
  }

  els.selectedDate.textContent = record.date;

  const summary = document.createElement("div");
  summary.className = "selected-summary";

  const left = document.createElement("div");
  const description = document.createElement("div");
  description.className = "selected-description";
  description.textContent = record.description || "(no description)";

  const id = document.createElement("div");
  id.className = "event-id";
  id.textContent = record.id;
  left.append(description, id);

  const quantity = document.createElement("div");
  quantity.textContent = quantitySummary(record);
  summary.append(left, quantity);

  const effects = document.createElement("div");
  effects.className = "effects";

  for (const effect of record.effects) {
    const locus = document.createElement("span");
    locus.textContent = effect.locus;

    const measure = document.createElement("span");
    measure.textContent = effect.measure;

    const quanta = document.createElement("span");
    quanta.className = "effect-quanta";
    quanta.textContent = amountText(effect.quanta);

    effects.append(locus, measure, quanta);
  }

  els.selectedDetail.replaceChildren(summary, effects);
}

function render() {
  const selectedCount = state.selectedDate ? recordsOn(state.selectedDate).length : 0;

  els.monthTitle.textContent = monthLabel(state.month);
  els.monthCount.textContent = state.records.length + " rows";
  els.selectedDayCount.textContent = selectedCount + " rows";

  renderScope();
  renderCalendar();
  renderTable();
  renderSelected();
}

async function loadMonth() {
  els.status.classList.remove("error");
  els.status.textContent = "読み込み中…";

  if (!invoke) {
    els.status.classList.add("error");
    els.status.textContent = "Tauriから起動してください";
    render();
    return;
  }

  try {
    const dataDir = els.dataDir.value.trim() || null;
    storageSet(STORAGE.dataDir, dataDir ?? "");

    const result = await invoke("load_actual", {
      month: state.month,
      dataDir,
    });

    state.records = result.records;
    state.selectedId = null;

    if (!state.selectedDate?.startsWith(state.month + "-")) {
      state.selectedDate = null;
    }

    ensureSelection();
    render();

    els.status.textContent = result.records.length + " rows · read-only";
    els.dataSource.open = false;
  } catch (error) {
    state.records = [];
    state.selectedId = null;
    render();

    els.status.classList.add("error");
    els.status.textContent = String(error);
    els.dataSource.open = true;
  }
}

function setScope(scope) {
  state.scope = scope;
  storageSet(STORAGE.scope, scope);
  render();
}

document.querySelector("#previous-month").addEventListener("click", () => {
  state.month = shiftMonth(state.month, -1);
  state.selectedDate = null;
  loadMonth();
});

document.querySelector("#next-month").addEventListener("click", () => {
  state.month = shiftMonth(state.month, 1);
  state.selectedDate = null;
  loadMonth();
});

document.querySelector("#today-month").addEventListener("click", () => {
  state.month = localMonth();
  state.selectedDate = null;
  loadMonth();
});

document.querySelector("#reload").addEventListener("click", loadMonth);

els.dataDir.addEventListener("keydown", (event) => {
  if (event.key === "Enter") loadMonth();
});

els.search.addEventListener("input", () => {
  state.query = els.search.value;
  renderTable();
});

els.scopeMonth.addEventListener("click", () => setScope("month"));
els.scopeDay.addEventListener("click", () => setScope("day"));

let dragging = false;

els.splitter.addEventListener("pointerdown", (event) => {
  dragging = true;
  els.splitter.classList.add("dragging");
  els.splitter.setPointerCapture(event.pointerId);
});

els.splitter.addEventListener("pointermove", (event) => {
  if (!dragging) return;

  const rect = els.workspace.getBoundingClientRect();
  const width = Math.max(190, Math.min(event.clientX - rect.left, rect.width * 0.48));

  els.workspace.style.setProperty("--calendar-width", width + "px");
});

els.splitter.addEventListener("pointerup", () => {
  dragging = false;
  els.splitter.classList.remove("dragging");

  const width = parseFloat(
    getComputedStyle(els.workspace).getPropertyValue("--calendar-width")
  );

  if (Number.isFinite(width)) {
    storageSet(STORAGE.calendarWidth, String(Math.round(width)));
  }
});

const storedDataDir = storageGet(STORAGE.dataDir);
if (storedDataDir) {
  els.dataDir.value = storedDataDir;
}

const storedCalendarWidth = Number(storageGet(STORAGE.calendarWidth));
if (Number.isFinite(storedCalendarWidth) && storedCalendarWidth >= 190) {
  els.workspace.style.setProperty(
    "--calendar-width",
    Math.min(storedCalendarWidth, 520) + "px"
  );
}

render();
loadMonth();
