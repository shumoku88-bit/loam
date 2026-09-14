import Loam.ActualAuthority
import Loam.WriterOwnership

namespace Loam.ScheduledActualOwnership

set_option autoImplicit false

/-!
# Shared Scheduled / Actual ownership order

Several production operations need one coherent interval spanning both
`scheduled.loam` and normalized `actual.loam`. The semantic reason differs by
operation: some publish Scheduled, some publish Actual, some publish both, and
some only read one authority as guard evidence.

What is shared is the lock order itself:

```text
Scheduled lifecycle authority -> actual.loam
```

Keeping that mechanics in one place prevents equal-looking publishers from
silently drifting into conflicting ownership order without merging their
semantic authorities.
-/

def withOwnership {α : Type}
    (scheduledFile root : System.FilePath)
    (action : IO (Except String α)) : IO (Except String α) :=
  Loam.WriterOwnership.withOwnership scheduledFile <|
    Loam.ActualAuthority.withActualOwnership root action

end Loam.ScheduledActualOwnership
