# LOAM Beancount / Fava Projection

Status: **disposable external observation projection**

LOAM provides a one-way deterministic projection from its canonical Actual evidence into Beancount format, allowing [Fava](https://beancount.github.io/fava/) to serve as a rich graphical observation instrument (Balance Sheet, Income Statement, Charts, and Journal) without compromising LOAM's authority.

## Architectural Boundaries

1. **LOAM remains authoritative**: `actual.loam` and `accounting-role.loam` are the sole canonical household authority. The generated `.beancount` file is disposable scaffolding.
2. **No heuristic classification**: Unresolved Loci are never guessed or automatically assigned to Asset/Expense/Income roles.
3. **Strict balance enforcement**: Every Event must balance independently in each Measure across all modes.
4. **Source overwrite protection**: Output and report files must never conflict with source authority files.

## Projection Modes

`loamBeancountExport` supports three explicit modes:

| Mode | Flag | Behavior on Unresolved Locus | Recommended Use |
| :--- | :--- | :--- | :--- |
| **Suspense** | `--suspense` | Projects unresolved Effects to `Equity:Loam-Unresolved` with `loam_unresolved_locus` metadata. Retains **all current Events**. | **Standard household observation** (no transaction is dropped, complete balance sheet). |
| **Partial** | `--partial` | **Skips the entire Event** containing unresolved Loci so that no unbalanced split leaks. | Clean reporting of only fully categorized transactions. |
| **Strict** | *(none)* | **Fails closed** with exit code 2 if any unresolved Locus exists. | Automated qualification and strict audit pipelines. |

## Quick Start Guide

### Launch from TUI (One-Touch)

In `loamTui`:
1. Press `v` to open **Reports**.
2. Press `f` (or navigate to `Fava Projection` and press `Enter`).

This automatically regenerates `/tmp/loam-fava-household.beancount` in `--suspense` mode, starts the Fava server on port 5001 if not already running, and opens `http://127.0.0.1:5001` in your browser.

---

### Manual CLI Workflow

#### 1. Generate Disposable Beancount View

Run the exporter from the repository root (using `lake exe` or directly calling `./.lake/build/bin/loamBeancountExport`):

```bash
# Recommended: Suspense mode (retains all events; unclassified effects go to Equity:Loam-Unresolved)
lake exe loamBeancountExport --suspense \
  ../loam-data/actual.loam \
  ../loam-data/accounting-role.loam \
  /tmp/loam-fava-household.beancount \
  /tmp/loam-fava-household-report.txt
```

For partial mode (skipping events containing unclassified loci):
```bash
lake exe loamBeancountExport --partial \
  ../loam-data/actual.loam \
  ../loam-data/accounting-role.loam \
  /tmp/loam-fava-household.beancount \
  /tmp/loam-fava-household-report.txt
```

For strict mode (fails closed if any locus lacks an AccountingRole):
```bash
lake exe loamBeancountExport \
  ../loam-data/actual.loam \
  ../loam-data/accounting-role.loam \
  /tmp/loam-fava-household.beancount
```

### 2. Launch Fava Web Interface

Run Fava against the generated file (using `uvx` to run without global Python pollution):

```bash
uvx --from fava fava --port 5001 /tmp/loam-fava-household.beancount
```

Open in your web browser:
```text
http://127.0.0.1:5001
```

*(Note: Port 5001 is recommended on macOS where AirPlay Receiver may listen on port 5000.)*

### 3. Fava Navigation & Reports

Inside Fava, use the left sidebar navigation:

- **Balance Sheet (貸借対照表)**:
  - **Assets**: Cash, bank balances (SMBC, Yucho), electronic money (PayPay), and holdings.
  - **Liabilities**: Short-term borrowings or debts.
  - **Equity**: Opening balances and `Equity:Loam-Unresolved` (holding unclassified effects).
- **Income Statement (損益計算書)**:
  - **Expenses**: Breakdown by food, utilities, rent, transit, etc.
  - **Income**: Breakdown of income sources.
- **Journal (仕訳帳)**:
  - Chronological transaction log. Each transaction includes LOAM metadata (`loam_event_id`, `loam_locus`, `loam_measure`, and `loam_unresolved_locus` if unclassified).
- **Changes / Net Worth**:
  - Monthly net asset trajectory and flow charts.

### 4. Reading the Export Report

The export report (`/tmp/loam-fava-household-report.txt`) is safe to share or log. It only contains aggregated event/effect counts and unresolved locus names—never transaction amounts, dates, or descriptions:

```bash
cat /tmp/loam-fava-household-report.txt
```

Example suspense report:
```text
Beancount suspense projection

Exported current Events: 633
Unresolved Effects projected to suspense: 9

Unresolved source Loci:
  historical-unclassified: 7 Effects
  income:立替精算: 1 Effects
  income:返金: 1 Effects

Result:
  all current Events retained
  unresolved roles were NOT inferred
  Equity:Loam-Unresolved is target scaffolding only
  LOAM remains authoritative
```
