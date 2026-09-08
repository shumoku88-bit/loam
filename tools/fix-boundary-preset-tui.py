from pathlib import Path

path = Path("Loam/Tui/Reports.lean")
text = path.read_text()
marker = '''/-- Human-readable label for presentation only; it never enters a report query. -/
def windowSourceLabel'''
insert = '''private def presetAt? : List Loam.BoundaryPresetConfig.Preset → Nat → Option Loam.BoundaryPresetConfig.Preset
  | [], _ => none
  | preset :: _, 0 => some preset
  | _ :: rest, index + 1 => presetAt? rest index

/-- Human-readable label for presentation only; it never enters a report query. -/
def windowSourceLabel'''
if text.count(marker) != 1:
    raise SystemExit("windowSourceLabel marker changed")
text = text.replace(marker, insert, 1)
old = "state.windowPresets.get? index"
if text.count(old) != 2:
    raise SystemExit(f"expected two List get? uses, got {text.count(old)}")
text = text.replace(old, "presetAt? state.windowPresets index")
path.write_text(text)
