const invoke = window.__TAURI__?.core?.invoke;

const state = {
  month: localMonth(),
  records: [],
  selectedDate: null,
  selectedId: null,
};

const els = {
  monthTitle: document.querySelector("#month-title"),
  monthCount: document.querySelector("#month-count"),
  calendar: document.querySelector("#calendar"),
  actualBody: document.querySelector("#actual-body"),
  empty: document.querySelector("#empty"),
  selectedDate: document.querySelector("#selected-date"),
  selectedDetail: document.querySelector("#selected-detail"),
  status: document.querySelector("#status"),
  dataDir: document.querySelector("#data-dir"),
  workspace: document.querySelector("#workspace"),
  splitter: document.querySelector("#splitter"),
};

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
      if (state.selectedId) {
        const selector = 'tr[data-id="' + CSS.escape(state.selectedId) + '"]';
        document.querySelector(selector)?.scrollIntoView({ block: "center", behavior: "smooth" });
      }
    });
    els.calendar.append(button);
  }
}

function renderTable() {
  els.actualBody.replaceChildren();
  els.empty.hidden = state.records.length !== 0;

  for (const record of state.records) {
    const row = document.createElement("tr");
    row.dataset.id = record.id;
    row.tabIndex = 0;
    if (record.id === state.selectedId) row.classList.add("selected");
    if (record.date === state.selectedDate) row.classList.add("focus-date");

    const date = document.createElement("td");
    date.textContent = record.date;

    const description = document.createElement("td");
    description.className = "description";
    description.textContent = record.description || "(no description)";
    description.title = record.description;

    const movement = document.createElement("td");
    movement.className = "movement";
    movement.textContent = movementSummary(record);

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
  }
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
  els.monthTitle.textContent = monthLabel(state.month);
  els.monthCount.textContent = state.records.length + " rows";
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
    const result = await invoke("load_actual", { month: state.month, dataDir });
    state.records = result.records;
    state.selectedId = null;
    if (!state.selectedDate?.startsWith(state.month + "-")) {
      state.selectedDate = null;
    }
    ensureSelection();
    render();
    els.status.textContent = result.records.length + " rows · read-only";
  } catch (error) {
    state.records = [];
    state.selectedId = null;
    render();
    els.status.classList.add("error");
    els.status.textContent = String(error);
  }
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
});

render();
loadMonth();
