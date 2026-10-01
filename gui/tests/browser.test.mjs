import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { createServer } from "node:http";
import { readFile, mkdtemp, mkdir } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { chromium } from "playwright";
import { localMonth, shiftMonth } from "../web/workbench.mjs";

// Every browser request uses synthetic evidence; no real household path is opened.
const month = localMonth();
const nextMonth = shiftMonth(month, 1);
const effect = (locus, quanta, measure = "jpy") => ({ locus, measure, quanta });
const movement = (quantity, from = "cash", to = "food") =>
  [effect(from, "-" + quantity), effect(to, quantity)];
const fixture = {
  month,
  records: [
    { id: "groceries", date: month + "-01", description: "食材の買い物", effects: movement("680"), history: [
      { id: "original", replacement: "intermediate", date: shiftMonth(month, -1) + "-28", description: "訂正前の買い物", effects: movement("100") },
      { id: "intermediate", replacement: "groceries", date: "", description: "食材の買い物", effects: movement("600") },
    ] },
    { id: "book", date: month + "-07", description: "読書用の本", effects: movement("2470", "bank", "books"), history: [] },
    { id: "split", date: month + "-08", description: "複数の移動", effects: [effect("cash", "-1200"), effect("food", "1000"), effect("fees", "200")], history: [] },
    { id: "large", date: month + "-09", description: "正確な数量の例", effects: movement("900719925474099312345"), history: [] },
  ],
};
let server, browser, baseUrl, screenshotDir;
before(async () => {
  const root = fileURLToPath(new URL("../web/", import.meta.url));
  const allowed = { "/": ["index.html", "text/html"], "/index.html": ["index.html", "text/html"],
    "/app.js": ["app.js", "text/javascript"], "/workbench.mjs": ["workbench.mjs", "text/javascript"],
    "/styles.css": ["styles.css", "text/css"] };
  server = createServer(async (req, res) => {
    const entry = allowed[new URL(req.url, "http://localhost").pathname];
    if (!entry) { res.writeHead(404); res.end(); return; }
    try {
      res.writeHead(200, { "Content-Type": entry[1] + "; charset=utf-8" });
      res.end(await readFile(join(root, entry[0])));
    } catch { res.writeHead(500); res.end(); }
  });
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  baseUrl = `http://127.0.0.1:${server.address().port}`;
  browser = await chromium.launch();
  screenshotDir = process.env.LOAM_GUI_SCREENSHOT_DIR ?? await mkdtemp(join(tmpdir(), "loam-gui-workbench-"));
  await mkdir(screenshotDir, { recursive: true });
});
after(async () => {
  await browser?.close();
  if (server) await new Promise((resolve) => server.close(resolve));
  if (screenshotDir) console.log(`Synthetic GUI screenshots: ${screenshotDir}`);
});

async function openPage(options = {}) {
  const context = await browser.newContext({ viewport: { width: 1440, height: 900 }, ...options.context });
  const page = await context.newPage();
  const errors = [];
  page.on("pageerror", (error) => errors.push(String(error)));
  const readFixture = structuredClone(options.fixture ?? fixture);
  if (options.initialMonth) {
    await page.clock.setFixedTime(new Date(options.initialMonth + "-15T12:00:00Z"));
    readFixture.month = options.initialMonth;
    for (const record of readFixture.records) {
      record.date = options.initialMonth + record.date.slice(7);
      for (const previous of record.history) {
        if (previous.date) previous.date = shiftMonth(options.initialMonth, -1) + previous.date.slice(7);
      }
    }
  }
  await context.addInitScript(({ fixture, nextMonth, mode }) => {
    window.__guiCalls = [];
    window.__TAURI__ = { core: { invoke: async (name, args) => {
      window.__guiCalls.push({ name, ...args });
      if (name !== "load_actual") throw new Error("Unexpected write command");
      const call = window.__guiCalls.length;
      if (call === 1 && mode?.startsWith("stale")) {
        await new Promise((resolve) => setTimeout(resolve, 450));
        if (mode === "stale-error") throw new Error("Old request failed");
      }
      if (mode === "hold-next-month" && args.month !== fixture.month) {
        await new Promise((resolve) => { window.__releaseMonth = resolve; });
      }
      if (args.dataDir === "synthetic-error") throw new Error("Synthetic read refusal");
      if (mode === "wrong-month") return { month: nextMonth, records: [] };
      return args.month === fixture.month ? structuredClone(fixture) : { month: args.month, records: [
        { id: "next", date: args.month + "-02", description: "次の月の記録", effects: [], history: [] },
      ] };
    } } };
  }, { fixture: readFixture, nextMonth, mode: options.mode });
  await page.goto(baseUrl);
  return { page, context, errors };
}
async function ready(page) {
  await page.waitForFunction(() => document.getElementById("status").textContent.includes("現在の記録"));
}
async function selected(page, id) {
  await page.waitForFunction((id) => document.querySelector("tr.selected")?.dataset.id === id, id);
}

// Explicit contexts isolate UI preferences and requests between specimens.
test("workbench keeps selection, filters, keyboard and exact evidence synchronized", async () => {
  const { page, context, errors } = await openPage();
  try {
    await ready(page);
    assert.equal(await page.locator("#actual-body tr").count(), 4);
    await page.locator('tr[data-id="groceries"]').click();
    await page.keyboard.press("ArrowDown");
    await selected(page, "book");
    assert.match(await page.locator("#selected-detail").innerText(), /読書用の本/);
    await page.keyboard.press("Control+f");
    await page.locator("#search").fill("食材");
    await selected(page, "groceries");
    assert.equal(await page.locator("#actual-body tr").count(), 1);
    await page.locator("#search").fill("見つからない検索");
    assert.equal(await page.locator("#actual-body tr").count(), 0);
    assert.equal(await page.locator("#selected-detail .effects").count(), 0);
    await page.keyboard.press("Escape");
    await page.locator("#locus-filter").selectOption("books");
    await selected(page, "book");
    await page.locator("#clear-filters").click();
    await page.locator('tr[data-id="split"]').click();
    assert.match(await page.locator('tr[data-id="split"] .amount').innerText(), /内訳を見る/);
    assert.equal(await page.locator("#selected-detail .effect-row").count(), 3);
    await page.locator('tr[data-id="large"]').click();
    assert.match(await page.locator("#selected-detail").innerText(), /900,719,925,474,099,312,345/);
    assert.equal(await page.evaluate(() => window.__guiCalls.every((call) => call.name === "load_actual")), true);
    assert.deepEqual(errors, []);
  } finally { await context.close(); }
});

test("correction pairs show real relation order, unknown dates and changes", async () => {
  const { page, context, errors } = await openPage();
  try {
    await ready(page);
    await page.locator('tr[data-id="groceries"]').click();
    await page.keyboard.press("Control+k");
    await page.locator("#command-query").fill("訂正");
    await page.keyboard.press("Enter");
    assert.equal(await page.locator("#tab-history").getAttribute("aria-selected"), "true");
    assert.match(await page.locator("#history-detail").innerText(), /日付不明/);
    assert.match(await page.locator(".version-card").first().innerText(), /intermediate/);
    assert.match(await page.locator(".version-card").last().innerText(), /groceries/);
    assert.equal(await page.locator(".change-chip").count(), 2);
    await page.locator("#history-step").selectOption("0");
    assert.match(await page.locator(".version-card").first().innerText(), /original/);
    await page.screenshot({ path: join(screenshotDir, "correction-comparison.png") });
    await page.locator('tr[data-id="book"]').click();
    assert.equal(await page.locator(".comparison").count(), 0);
    assert.match(await page.locator("#history-detail").innerText(), /訂正はありません/);
    await page.locator("#tab-evidence").click();
    await page.screenshot({ path: join(screenshotDir, "workbench.png") });
    assert.deepEqual(errors, []);
  } finally { await context.close(); }
});

test("empty calendar days preserve monthly context without selecting another day", async () => {
  const { page, context } = await openPage();
  try {
    await ready(page);
    await page.locator(`.calendar-day[data-date="${month}-03"]`).click();
    assert.equal(await page.locator("#actual-body tr").count(), 4);
    assert.equal(await page.locator("tr.selected").count(), 0);
    await page.locator("#scope-day").click();
    assert.equal(await page.locator("#actual-body tr").count(), 0);
    assert.match(await page.locator("#selected-day").innerText(), /-03/);
    await page.locator("#scope-month").click();
    assert.equal(await page.locator("#actual-body tr").count(), 4);
  } finally { await context.close(); }
});

for (const mode of ["stale-success", "stale-error"]) {
  test(`${mode}: older requests cannot overwrite a new month or its status`, async () => {
    const { page, context, errors } = await openPage({ mode });
    try {
      await page.locator("#next-month").click();
      await ready(page);
      await page.waitForTimeout(550);
      assert.equal(await page.locator('tr[data-id="next"]').count(), 1);
      assert.equal(await page.locator('tr[data-id="groceries"]').count(), 0);
      assert.equal(await page.locator("#load-notice").isVisible(), false);
      assert.deepEqual(errors, []);
    } finally { await context.close(); }
  });
}

test("read refusals and mismatched months clear stale evidence and remain visible", async () => {
  const { page, context } = await openPage();
  try {
    await ready(page);
    await page.locator(".data-source summary").click();
    await page.locator("#data-dir").fill("synthetic-error");
    await page.locator("#reload").click();
    await page.waitForFunction(() => !document.getElementById("load-notice").hidden);
    assert.equal(await page.locator("#actual-body tr").count(), 0);
    assert.equal(await page.locator("#selected-detail .effects").count(), 0);
    assert.match(await page.locator("#load-notice").innerText(), /Synthetic read refusal/);
  } finally { await context.close(); }
  const wrong = await openPage({ mode: "wrong-month" });
  try {
    await wrong.page.waitForFunction(() => !document.getElementById("load-notice").hidden);
    assert.equal(await wrong.page.locator("#actual-body tr").count(), 0);
    assert.match(await wrong.page.locator("#load-notice").innerText(), /一致しません/);
  } finally { await wrong.context.close(); }
});

test("splitter works with pointer and keyboard; narrow/dark layout stays inside viewport", async () => {
  const { page, context, errors } = await openPage();
  try {
    await ready(page);
    const splitter = page.locator("#splitter");
    const initial = Number(await splitter.getAttribute("aria-valuenow"));
    const bounds = await splitter.boundingBox();
    await page.mouse.move(bounds.x + bounds.width / 2, bounds.y + 70);
    await page.mouse.down();
    await page.mouse.move(bounds.x - 40, bounds.y + 70);
    await page.mouse.up();
    assert.ok(Number(await splitter.getAttribute("aria-valuenow")) > initial);
    await splitter.focus();
    const beforeKey = Number(await splitter.getAttribute("aria-valuenow"));
    await page.keyboard.press("ArrowLeft");
    assert.ok(Number(await splitter.getAttribute("aria-valuenow")) > beforeKey);
    await page.setViewportSize({ width: 760, height: 900 });
    await page.emulateMedia({ colorScheme: "dark" });
    await page.locator('tr[data-id="groceries"]').click();
    await page.locator("#tab-history").click();
    assert.equal(await page.locator(".ledger-pane").isVisible(), true);
    assert.equal(await page.locator(".comparison").isVisible(), true);
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true);
    await page.screenshot({ path: join(screenshotDir, "narrow-dark.png") });
    await page.setViewportSize({ width: 480, height: 800 });
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true);
    assert.deepEqual(errors, []);
  } finally { await context.close(); }
});

test("calendar arrows move focus only; Enter confirms the focused day", async () => {
  const { page, context, errors } = await openPage();
  try {
    await ready(page);
    await page.locator('tr[data-id="groceries"]').click();
    await page.locator(`.calendar-day[data-date="${month}-01"]`).focus();
    for (const [key, day] of [["ArrowRight", "02"], ["ArrowDown", "09"], ["ArrowUp", "02"], ["ArrowLeft", "01"]]) {
      await page.keyboard.press(key);
      assert.equal(await page.evaluate(() => document.activeElement.dataset.date), `${month}-${day}`);
      assert.equal(await page.locator('tr.selected').getAttribute("data-id"), "groceries");
      assert.equal(await page.locator("#selected-day").innerText(), month + "-01");
    }
    for (let day = 0; day < 6; day += 1) await page.keyboard.press("ArrowRight");
    assert.equal(await page.locator(".calendar-day[tabindex='0']").count(), 1);
    assert.equal(await page.evaluate(() => window.__guiCalls.length), 1);
    assert.equal(await page.evaluate(() => document.activeElement.matches(":focus-visible")), true);
    assert.equal(await page.evaluate(() => getComputedStyle(document.activeElement).outlineWidth), "3px");
    await page.screenshot({ path: join(screenshotDir, "calendar-keyboard.png") });
    await page.keyboard.press("Enter");
    await selected(page, "book");
    assert.equal(await page.evaluate(() => document.activeElement.dataset.id), "book");
    assert.equal(await page.locator("#selected-day").innerText(), month + "-07");
    assert.deepEqual(errors, []);
  } finally { await context.close(); }
});

test("Tab leaves the roving calendar/ledger, tab arrows require confirmation, and Esc returns to the row", async () => {
  const { page, context, errors } = await openPage();
  try {
    await ready(page);
    await page.locator('tr[data-id="groceries"]').click();
    await page.locator(`.calendar-day[data-date="${month}-01"]`).focus();
    await page.keyboard.press("Tab");
    assert.equal(await page.evaluate(() => document.activeElement.id), "toggle-calendar");
    await page.keyboard.press("Shift+Tab");
    assert.equal(await page.evaluate(() => document.activeElement.dataset.date), month + "-01");
    await page.keyboard.press("Shift+Tab");
    assert.equal(await page.evaluate(() => document.activeElement.id), "close-calendar");
    await page.locator('tr[data-id="groceries"]').focus();
    await page.keyboard.press("Tab");
    assert.equal(await page.evaluate(() => document.activeElement.id), "splitter");
    await page.keyboard.press("Tab");
    assert.equal(await page.evaluate(() => document.activeElement.id), "tab-evidence");
    await page.keyboard.press("ArrowRight");
    assert.equal(await page.evaluate(() => document.activeElement.id), "tab-history");
    assert.equal(await page.locator("#tab-evidence").getAttribute("aria-selected"), "true");
    assert.equal(await page.locator("#evidence-panel").isVisible(), true);
    await page.keyboard.press("Enter");
    assert.equal(await page.locator("#tab-history").getAttribute("aria-selected"), "true");
    await page.keyboard.press("Tab");
    assert.equal(await page.evaluate(() => document.activeElement.id), "history-panel");
    await page.keyboard.press("Escape");
    assert.equal(await page.evaluate(() => document.activeElement.dataset.id), "groceries");
    await page.keyboard.press("Enter");
    assert.equal(await page.evaluate(() => document.activeElement.id), "tab-history");
    assert.deepEqual(errors, []);
  } finally { await context.close(); }
});

test("month-boundary preview preserves focus, does not select a date, and does not steal focus after loading", async () => {
  const { page, context, errors } = await openPage({ initialMonth: "2024-02", mode: "hold-next-month" });
  try {
    await ready(page);
    await page.locator('.calendar-day[data-date="2024-02-28"]').focus();
    await page.keyboard.press("ArrowRight");
    assert.equal(await page.evaluate(() => document.activeElement.dataset.date), "2024-02-29");
    assert.equal(await page.evaluate(() => window.__guiCalls.length), 1);
    await page.keyboard.press("ArrowRight");
    await page.waitForFunction(() => typeof window.__releaseMonth === "function");
    assert.equal(await page.evaluate(() => document.activeElement.dataset.date), "2024-03-01");
    assert.match(await page.locator('.calendar-day[data-date="2024-03-01"]').getAttribute("aria-label"), /未読込/);
    await page.keyboard.press("Tab");
    assert.equal(await page.evaluate(() => document.activeElement.id), "toggle-calendar");
    await page.evaluate(() => window.__releaseMonth());
    await ready(page);
    assert.equal(await page.locator("tr.selected").count(), 0);
    assert.equal(await page.locator(".calendar-day[aria-pressed='true']").count(), 0);
    assert.equal(await page.evaluate(() => document.activeElement.id), "toggle-calendar");
    assert.deepEqual(errors, []);
  } finally { await context.close(); }
});

test("confirming a calendar day during a month read survives completion", async () => {
  const { page, context, errors } = await openPage({ initialMonth: "2024-02", mode: "hold-next-month" });
  try {
    await ready(page);
    await page.locator('.calendar-day[data-date="2024-02-29"]').focus();
    await page.keyboard.press("ArrowRight");
    await page.waitForFunction(() => typeof window.__releaseMonth === "function");
    await page.keyboard.press("ArrowRight");
    await page.keyboard.press("Enter");
    assert.equal(await page.locator("#selected-day").innerText(), "2024-03-02");
    assert.equal(await page.evaluate(() => document.activeElement.id), "table-wrap");
    await page.evaluate(() => window.__releaseMonth());
    await ready(page);
    await selected(page, "next");
    assert.equal(await page.evaluate(() => document.activeElement.dataset.id), "next");
    assert.equal(await page.locator("#selected-day").innerText(), "2024-03-02");
    assert.deepEqual(errors, []);
  } finally { await context.close(); }
});

test("Esc restores rebuilt calendar and popup anchors without overriding command destinations", async () => {
  const { page, context, errors } = await openPage();
  try {
    await ready(page);
    await page.locator(`.calendar-day[data-date="${month}-02"]`).focus();
    await page.keyboard.press("Control+k");
    await page.evaluate(() => document.getElementById("reload").click());
    await ready(page);
    await page.keyboard.press("Escape");
    assert.equal(await page.evaluate(() => document.activeElement.dataset.date), month + "-02");
    await page.keyboard.press("Control+k");
    await page.locator("#command-query").fill("記録を検索");
    await page.keyboard.press("Enter");
    assert.equal(await page.evaluate(() => document.activeElement.id), "search");
    await page.locator("#data-toggle").click();
    await page.locator("#data-dir").fill("unapplied-synthetic-path");
    await page.keyboard.press("Control+k");
    await page.keyboard.press("Escape");
    assert.equal(await page.evaluate(() => document.activeElement.id), "data-dir");
    assert.equal(await page.locator(".data-source").getAttribute("open"), "");
    await page.keyboard.press("Escape");
    assert.equal(await page.evaluate(() => document.activeElement.id), "data-toggle");
    assert.equal(await page.locator(".data-source").getAttribute("open"), null);
    assert.equal(await page.locator("#data-dir").inputValue(), "unapplied-synthetic-path");
    assert.equal(await page.evaluate(() => window.__guiCalls.length), 2);
    assert.deepEqual(errors, []);
  } finally { await context.close(); }
});

test("narrow calendar opens into the date widget and Esc closes it back to its opener", async () => {
  const { page, context, errors } = await openPage({ initialMonth: "2026-10", context: { viewport: { width: 760, height: 900 } } });
  try {
    await ready(page);
    await page.locator('tr[data-id="book"]').click();
    await page.locator("#toggle-calendar").click();
    assert.equal(await page.evaluate(() => document.activeElement.classList.contains("calendar-day")), true);
    await page.keyboard.press("ArrowDown");
    await page.keyboard.press("Escape");
    assert.equal(await page.locator("#calendar-pane").isVisible(), false);
    assert.equal(await page.evaluate(() => document.activeElement.id), "toggle-calendar");
    assert.equal(await page.locator("tr.selected").getAttribute("data-id"), "book");
    await page.locator('tr[data-id="book"]').focus();
    await page.keyboard.press("Control+k");
    await page.locator("#command-query").fill("カレンダー");
    await page.keyboard.press("Enter");
    assert.equal(await page.evaluate(() => document.activeElement.classList.contains("calendar-day")), true);
    await page.keyboard.press("Escape");
    assert.equal(await page.locator("#calendar-pane").isVisible(), false);
    assert.equal(await page.evaluate(() => document.activeElement.dataset.id), "book");
    assert.deepEqual(errors, []);
  } finally { await context.close(); }
});

test("text/select editors and IME retain their keys; technical details close before leaving the inspector", async () => {
  const { page, context, errors } = await openPage();
  try {
    await ready(page);
    await page.locator("#search").fill("book");
    await page.keyboard.press("Home");
    assert.equal(await page.locator("#search").evaluate((input) => input.selectionStart), 0);
    await page.keyboard.press("ArrowRight");
    assert.equal(await page.locator("#search").evaluate((input) => input.selectionStart), 1);
    await page.keyboard.press("Alt+ArrowRight");
    assert.equal(await page.evaluate(() => window.__guiCalls.length), 1);
    await page.locator("#clear-filters").click();
    await page.locator('tr[data-id="groceries"]').click();
    await page.locator(`.calendar-day[data-date="${month}-01"]`).focus();
    const accepted = await page.evaluate(() => document.activeElement.dispatchEvent(new KeyboardEvent("keydown", {
      key: "ArrowRight", isComposing: true, bubbles: true, cancelable: true,
    })));
    assert.equal(accepted, true);
    assert.equal(await page.evaluate(() => document.activeElement.dataset.date), month + "-01");
    await page.locator("#tab-history").click();
    await page.locator("#history-step").focus();
    await page.evaluate(() => document.addEventListener("keydown", (event) => {
      window.__selectKeyPrevented = event.defaultPrevented;
    }, { once: true }));
    await page.keyboard.press("ArrowUp");
    assert.equal(await page.evaluate(() => window.__selectKeyPrevented), false);
    // Closed-select arrow behavior differs by OS; retain the native popup/commit rules.
    await page.keyboard.press("Escape");
    assert.equal(await page.evaluate(() => document.activeElement.id), "history-step");
    await page.locator("#history-step").selectOption("0");
    assert.equal(await page.locator("#history-step").inputValue(), "0");
    await page.locator("#tab-evidence").click();
    await page.locator("#technical-toggle").focus();
    await page.keyboard.press("Enter");
    assert.equal(await page.locator("#technical-info").getAttribute("open"), "");
    await page.keyboard.press("Escape");
    assert.equal(await page.locator("#technical-info").getAttribute("open"), null);
    assert.equal(await page.evaluate(() => document.activeElement.id), "technical-toggle");
    await page.keyboard.press("Escape");
    assert.equal(await page.evaluate(() => document.activeElement.dataset.id), "groceries");
    assert.deepEqual(errors, []);
  } finally { await context.close(); }
});

test("descriptions render as text, never executable markup", async () => {
  const hostile = structuredClone(fixture);
  hostile.records[0].description = '<img src="x" onerror="window.__executed=true">';
  const { page, context, errors } = await openPage({ fixture: hostile });
  try {
    await ready(page);
    await page.locator('tr[data-id="groceries"]').click();
    assert.equal(await page.locator("#selected-detail img").count(), 0);
    assert.match(await page.locator("#selected-detail").innerText(), /<img/);
    assert.equal(await page.evaluate(() => window.__executed), undefined);
    assert.deepEqual(errors, []);
  } finally { await context.close(); }
});
