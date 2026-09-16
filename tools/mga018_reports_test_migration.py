#!/usr/bin/env python3
from pathlib import Path
import re

path = Path("Loam/Tests/TuiReports.lean")
text = path.read_text()

# First rewrite the four structure-update fixtures that used the retired flat Form owner.
replacements = {
'''  let customEditing : Loam.Tui.Reports.State := {
    pensionState with form := { pensionState.form with focus := ⟨0, by decide⟩ }
  }
''': '''  let customEditing : Loam.Tui.Reports.State := {
    pensionState with
      window := { pensionState.window with
        form := { pensionState.window.form with focus := ⟨0, by decide⟩ } }
  }
''',
'''  let explicit : Loam.Tui.Reports.State := {
    stock with
      form := {
        start := "2026-08-17"
        endExclusive := "2026-10-15"
        focus := ⟨2, by decide⟩
      }
  }
''': '''  let explicit : Loam.Tui.Reports.State := {
    stock with
      window := { stock.window with
        form := {
          start := "2026-08-17"
          endExclusive := "2026-10-15"
          focus := ⟨2, by decide⟩
        }
        source := .custom
      }
  }
''',
'''  let editing : Loam.Tui.Reports.State := {
    stockReport with form := { stockReport.form with focus := ⟨0, by decide⟩ }
  }
''': '''  let editing : Loam.Tui.Reports.State := {
    stockReport with
      window := { stockReport.window with
        form := { stockReport.window.form with focus := ⟨0, by decide⟩ } }
  }
''',
'''  let incomeExpenseEditing : Loam.Tui.Reports.State := {
    incomeExpenseReport with form := { incomeExpenseReport.form with focus := ⟨0, by decide⟩ }
  }
''': '''  let incomeExpenseEditing : Loam.Tui.Reports.State := {
    incomeExpenseReport with
      window := { incomeExpenseReport.window with
        form := { incomeExpenseReport.window.form with focus := ⟨0, by decide⟩ } }
  }
''',
'''  let budget : Loam.Tui.Reports.State := {
    initial with
      mode := .budgetWindow
      form := {
        start := "2026-08-17"
        endExclusive := "2026-10-15"
        focus := ⟨2, by decide⟩
      }
  }
''': '''  let budget : Loam.Tui.Reports.State := {
    initial with
      mode := .budgetWindow
      window := { initial.window with
        form := {
          start := "2026-08-17"
          endExclusive := "2026-10-15"
          focus := ⟨2, by decide⟩
        }
        source := .custom
      }
  }
''',
}
for old, new in replacements.items():
    if text.count(old) != 1:
        raise SystemExit(f"expected one fixture occurrence, found {text.count(old)}: {old.splitlines()[0]}")
    text = text.replace(old, new, 1)

# All remaining direct reads of Reports' retired flat Form now observe its canonical nested owner.
text = re.sub(r"(?<!\.)\b([A-Za-z_][A-Za-z0-9_]*)\.form\b", r"\1.window.form", text)

# No old Reports flat Form update/read may remain.
if "with form :=" in text:
    raise SystemExit("retired Reports flat `with form :=` fixture remains")
for match in re.finditer(r"(?<!window)\.form\b", text):
    context = text[max(0, match.start()-40):match.end()+40]
    raise SystemExit(f"unexpected flat .form remains: {context!r}")

path.write_text(text)
print("updated", path)
