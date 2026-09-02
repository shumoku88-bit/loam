import Loam.Application.QuantityInspection
import Loam.Application.CapacityInspection

namespace Loam

/-!
# Application layer

`Loam.Application` is the executable, query-shaped layer between the neutral
Practical Core and human/runtime adapters.

Application operations consume existing Core values directly and may return
human-facing answers or explicit refusal states. They should not duplicate a
parallel household domain model or silently promote interface vocabulary into
`Loam.Core`.

Persistence and CLI concerns remain outside this package. Temporal or
concurrent protocol questions should first be isolated and observed with an
appropriate formal instrument rather than being hidden inside application
code.
-/

namespace Application

end Application
end Loam
