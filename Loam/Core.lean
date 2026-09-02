import Loam.Core.Quantity
import Loam.Core.Measure
import Loam.Core.Effect
import Loam.Core.BalancedMovement
import Loam.Core.Capacity
import Loam.Core.Event
import Loam.Core.EventMemory
import Loam.Core.EventCorrection
import Loam.Core.EventCorrectionMemory
import Loam.Core.EventResolution
import Loam.Core.EventResolutionMemory
import Loam.Core.RelationAdmission
import Loam.Core.CorrectionQuantity
import Loam.Core.Rate
import Loam.Core.Allocation
import Loam.Core.RecipientAssignment

namespace Loam

/-!
# Practical core

This module is the entry point for the practical Lean domain core.

The historical observation proofs remain separate under `Loam.Observations`,
and persistence remains a separate runtime boundary under `Loam.Persistence`.
New domain code should grow from this module rather than importing either
boundary accidentally.
-/

namespace Core

end Core
end Loam
