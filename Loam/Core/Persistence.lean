import Loam.Persistence

/-!
Compatibility import for the former persistence module path.

The persistence implementation now lives outside `Loam.Core` so the practical
core does not contain filesystem or wire-format responsibilities. Existing
callers may keep importing this module temporarily while they move to
`Loam.Persistence`.
-/
