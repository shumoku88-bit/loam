module experiments/observation_213_locus_alias_role_separation

-- Real household dogfood exposed a naming seam:
--
--   paypay
--   smbc
--   expenses:タバコ
--   income:年金
--
-- are all opaque Locus identities to production Movement, but the HRA/hledger-
-- shaped prefixes make the input surface look as though accounting role or
-- purpose is encoded by canonical identity spelling.
--
-- Earlier observations already separated:
--
--   Locus identity != Account
--   physical placement != AccountingRole
--   Locus identity != Purpose routing
--
-- This probe asks whether a human-facing alias used for display/input can remain
-- another independent plane, and what minimum condition makes alias resolution
-- safe for a new write.

abstract sig Locus {}
one sig HistoricalTobacco, OtherTobacco, Coffee extends Locus {}

abstract sig Alias {}
one sig TobaccoLabel, CoffeeLabel extends Alias {}

abstract sig AccountingRole {}
one sig AssetRole, IncomeRole, ExpenseRole extends AccountingRole {}

abstract sig Purpose {}
one sig TobaccoPurpose, FoodPurpose extends Purpose {}

sig World {
  -- Existing Observation 212 operational policy.
  approved: set Locus,

  -- Presentation/input relation only. One alias may deliberately be ambiguous
  -- in the raw relation; safe write resolution below requires exactly one
  -- currently approved target.
  aliasTarget: Alias -> set Locus,

  -- Independent semantic planes. These are observation vocabulary here, not a
  -- production proposal for permanent enums.
  role: Locus -> lone AccountingRole,
  purpose: Locus -> lone Purpose
}

one sig Left, Right extends World {}

fun approvedAliasTargets[w: World, a: Alias]: set Locus {
  a.(w.aliasTarget) & w.approved
}

pred resolves[w: World, a: Alias, l: Locus] {
  approvedAliasTargets[w, a] = l
}

pred ambiguous[w: World, a: Alias] {
  #(approvedAliasTargets[w, a]) > 1
}

-- A friendly spelling can select one historical canonical identity without
-- rewriting the retained Event identity itself.
pred friendlyAliasCanResolveHistoricalIdentity {
  HistoricalTobacco in Left.approved
  approvedAliasTargets[Left, TobaccoLabel] = HistoricalTobacco
  resolves[Left, TobaccoLabel, HistoricalTobacco]
}

-- Presentation can change while identity admission, accounting role and purpose
-- remain exactly the same. Alias spelling is therefore not forced to be semantic
-- identity in this bounded candidate.
pred sameSemanticsDifferentAliases {
  Left.approved = Right.approved
  Left.role = Right.role
  Left.purpose = Right.purpose
  Left.aliasTarget != Right.aliasTarget

  HistoricalTobacco in Left.approved
  HistoricalTobacco -> ExpenseRole in Left.role
  HistoricalTobacco -> TobaccoPurpose in Left.purpose
}

-- Hold alias and admission fixed while changing only accounting interpretation.
-- If this witness exists, a human label does not determine AccountingRole.
pred sameAliasDifferentRole {
  Left.approved = Right.approved
  Left.aliasTarget = Right.aliasTarget
  Left.purpose = Right.purpose

  HistoricalTobacco in Left.approved
  TobaccoLabel -> HistoricalTobacco in Left.aliasTarget
  HistoricalTobacco -> ExpenseRole in Left.role
  HistoricalTobacco -> AssetRole in Right.role
}

-- Hold alias and admission fixed while changing only Purpose routing.
pred sameAliasDifferentPurpose {
  Left.approved = Right.approved
  Left.aliasTarget = Right.aliasTarget
  Left.role = Right.role

  HistoricalTobacco in Left.approved
  TobaccoLabel -> HistoricalTobacco in Left.aliasTarget
  HistoricalTobacco -> TobaccoPurpose in Left.purpose
  HistoricalTobacco -> FoodPurpose in Right.purpose
}

-- A raw alias relation may become ambiguous when two currently approved Loci
-- share the same friendly spelling. A write surface must not guess here.
pred ambiguousAliasCanExist {
  HistoricalTobacco + OtherTobacco in Left.approved
  TobaccoLabel -> HistoricalTobacco in Left.aliasTarget
  TobaccoLabel -> OtherTobacco in Left.aliasTarget
  ambiguous[Left, TobaccoLabel]
}

-- Deliberately too strong. Equal aliases do not determine accounting semantics.
assert AliasDeterminesAccountingRole {
  all left, right: World |
    left.approved = right.approved and left.aliasTarget = right.aliasTarget implies
      left.role = right.role
}

-- Deliberately too strong. Equal aliases do not determine Purpose routing.
assert AliasDeterminesPurpose {
  all left, right: World |
    left.approved = right.approved and left.aliasTarget = right.aliasTarget implies
      left.purpose = right.purpose
}

-- Resolution is exactly the unique currently approved target. This assertion
-- checks the positive information-sufficiency direction for the selected write
-- input question.
assert UniqueApprovedAliasTargetDeterminesResolution {
  all w: World, a: Alias, l: Locus |
    approvedAliasTargets[w, a] = l implies resolves[w, a, l]
}

-- Ambiguous friendly input has no selected canonical Locus.
assert AmbiguousAliasNeverResolves {
  all w: World, a: Alias |
    ambiguous[w, a] implies no l: Locus | resolves[w, a, l]
}

-- An alias can never make a currently unapproved Locus writable. Alias is an
-- input selector over the existing admission policy, not a bypass around it.
assert AliasResolutionCannotBypassAdmission {
  all w: World, a: Alias, l: Locus |
    resolves[w, a, l] implies l in w.approved
}

run friendlyAliasCanResolveHistoricalIdentity for exactly 3 Locus, exactly 2 Alias, exactly 3 AccountingRole, exactly 2 Purpose, exactly 2 World
run sameSemanticsDifferentAliases for exactly 3 Locus, exactly 2 Alias, exactly 3 AccountingRole, exactly 2 Purpose, exactly 2 World
run sameAliasDifferentRole for exactly 3 Locus, exactly 2 Alias, exactly 3 AccountingRole, exactly 2 Purpose, exactly 2 World
run sameAliasDifferentPurpose for exactly 3 Locus, exactly 2 Alias, exactly 3 AccountingRole, exactly 2 Purpose, exactly 2 World
run ambiguousAliasCanExist for exactly 3 Locus, exactly 2 Alias, exactly 3 AccountingRole, exactly 2 Purpose, exactly 2 World
check AliasDeterminesAccountingRole for exactly 3 Locus, exactly 2 Alias, exactly 3 AccountingRole, exactly 2 Purpose, exactly 2 World
check AliasDeterminesPurpose for exactly 3 Locus, exactly 2 Alias, exactly 3 AccountingRole, exactly 2 Purpose, exactly 2 World
check UniqueApprovedAliasTargetDeterminesResolution for exactly 3 Locus, exactly 2 Alias, exactly 3 AccountingRole, exactly 2 Purpose, exactly 2 World
check AmbiguousAliasNeverResolves for exactly 3 Locus, exactly 2 Alias, exactly 3 AccountingRole, exactly 2 Purpose, exactly 2 World
check AliasResolutionCannotBypassAdmission for exactly 3 Locus, exactly 2 Alias, exactly 3 AccountingRole, exactly 2 Purpose, exactly 2 World
