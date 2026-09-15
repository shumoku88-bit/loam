# Fresh numbered identity graduation

## Question

LOAM historically allocated numbered identities through `firstUnusedNumberedToken?`.
That helper accepted an arbitrary collision predicate plus a caller-supplied fuel
budget and returned `Option String`. Production callers therefore carried failure
branches for fuel exhaustion.

Observations 242–248 asked whether those failures were actually reachable under
the retained finite namespaces used by production.

## Qualification trail

- Observation 242 proved the generic finite-search result: a used-token witness
  of length `n` cannot cover more than `n` distinct numbered candidates. A search
  over `n + 1` candidates therefore cannot exhaust.
- Observation 243 connected that result to ActualValidity revision identities.
  Only retained revision facts reserve the `validity-` namespace.
- Observation 244 qualified Correction replacement EventIds against retained
  Event identities.
- Observation 245 qualified Capacity movement identity across the two retained
  families that reserve it: movement authority and effective-coordinate evidence.
- Observation 246 qualified Scheduled occurrence identity against retained
  Scheduled occurrences.
- Observation 247 qualified Movement record EventId across five retained
  Event-reference families: Events, ActualValidity facts, descriptions,
  RelationUnit source Events, and RelationDischarge Events.
- Observation 248 qualified repeated Movement RelationUnit allocation. Adding
  each selected id to the finite used namespace preserves totality for every
  subsequent allocation.

## Production graduation

The research result was then transferred into production incrementally:

- PR #864 introduced `firstUnusedNumberedToken`, a total finite-namespace
  allocator, and migrated Scheduled identity allocation.
- PR #865 migrated Correction replacement identity.
- PR #866 migrated ActualValidity revision identity.
- PR #867 migrated Capacity movement identity.
- PR #868 migrated Movement record EventId allocation.
- PR #869 migrated recursive Movement RelationUnit allocation.

The production primitive now receives the represented finite namespace directly
as `List String`. On a collision it erases that candidate before advancing to the
next number, so the represented namespace strictly shrinks on every recursive
call. Termination and success are therefore properties of the implementation
shape rather than caller-supplied fuel.

Identity namespace, collision policy, starting index, and typed wrappers remain
local to each semantic owner. The shared primitive owns only deterministic
`stem ++ Nat` enumeration over one explicit finite namespace.

## Result

No current production numbered-identity allocator requires the bounded predicate
API, an `Option` result for fresh-number exhaustion, or a caller-supplied fuel
budget. The corresponding failure corridors have been removed from production.

Observations 242–248 have therefore completed their role as live proof
obligations. Their exact Lean witnesses remain available in Git history; this
record preserves the question, qualification sequence, conclusion, and the
production invariant that replaced them.
