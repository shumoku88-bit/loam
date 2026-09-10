import Loam.Persistence.AmountPersistence
import Loam.Persistence.EventCorrectionPersistence
import Loam.Persistence.EventPersistence

/-!
# Persistence compatibility umbrella

`Loam.Persistence` preserves the historical import surface while concrete wire
ownership lives in narrower modules:

- `AmountPersistence` owns runtime `SomeAmount` persistence.
- `EventPersistence` owns `Event` and `EventMemory` persistence.
- `EventCorrectionPersistence` owns raw `EventCorrectionMemory` persistence.

New code should prefer the narrow owner it actually uses. This umbrella does not
add persistence semantics of its own.
-/
