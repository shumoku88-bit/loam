module experiments/observation_251_recomposed_movement_recovery

-- Observation 251
--
-- Refine Observation 250 from semantic recovery domains to one concrete
-- selection law: recover all five historical household-evidence families while
-- preserving the currently selected Locus write policy. This model still does
-- not choose a new file topology.

abstract sig Family {}
one sig EventFamily, ActualValidityFamily, EventDescriptionFamily,
  RelationUnitFamily, RelationDischargeFamily extends Family {}

sig Image {}
sig EvidenceGeneration {
  image : Family -> one Image
}

sig Locus {}
sig Policy {
  approved : set Locus
}

sig Draft {
  uses : some Locus
}

sig SelectedGeneration {
  evidence : one EvidenceGeneration,
  policy : one Policy
}

sig RecoveryCase {
  current : one SelectedGeneration,
  candidate : one SelectedGeneration,
  availablePolicy : set Policy,
  draft : one Draft
}

sig RecoverySelection {
  evidence : one EvidenceGeneration,
  policy : one Policy
}

pred addOnlyPolicyGrowth[c : RecoveryCase] {
  c.candidate.policy.approved in c.current.policy.approved
}

pred admitted[p : Policy, d : Draft] {
  d.uses in p.approved
}

-- The intended recovery product is a recomposition, not the historical manifest
-- verbatim: every household family comes from the requested candidate while the
-- operational policy comes from CURRENT.
pred recomposed[c : RecoveryCase, s : RecoverySelection] {
  all family : Family |
    s.evidence.image[family] = c.candidate.evidence.image[family]
  s.policy = c.current.policy
}

-- Recovery may select the recomposed generation only when CURRENT policy is
-- independently available. There is no fallback to the historical candidate
-- policy when current policy is missing or corrupt.
pred selectableRecomposition[c : RecoveryCase, s : RecoverySelection] {
  recomposed[c, s]
  c.current.policy in c.availablePolicy
}

pred recomposedRecoveryExists {
  some c : RecoveryCase, s : RecoverySelection |
    c.current.policy in c.availablePolicy
    and selectableRecomposition[c, s]
}

assert RecomposedRecoveryRestoresEveryCandidateEvidenceFamily {
  all c : RecoveryCase, s : RecoverySelection |
    recomposed[c, s] implies
      all family : Family |
        s.evidence.image[family] = c.candidate.evidence.image[family]
}

assert RecomposedRecoveryPreservesCurrentPolicy {
  all c : RecoveryCase, s : RecoverySelection |
    recomposed[c, s] implies s.policy = c.current.policy
}

assert MissingCurrentPolicyRefusesRecomposition {
  all c : RecoveryCase |
    c.current.policy not in c.availablePolicy implies
      no s : RecoverySelection | selectableRecomposition[c, s]
}

-- This witness explains why silently falling back to the candidate policy would
-- be a different, weaker contract: recovery could proceed even though CURRENT
-- policy is unavailable.
pred historicalPolicyFallbackWouldMaskCurrentPolicyFailure {
  some c : RecoveryCase |
    c.current.policy not in c.availablePolicy
    and c.candidate.policy in c.availablePolicy
}

-- Under today's add-only policy law, preserving current policy cannot revoke a
-- Locus that the historical candidate policy had admitted.
assert CandidateAdmissionSurvivesRecomposedRecovery {
  all c : RecoveryCase, s : RecoverySelection |
    addOnlyPolicyGrowth[c]
    and recomposed[c, s]
    and admitted[c.candidate.policy, c.draft]
      implies admitted[s.policy, c.draft]
}

-- And the current write-policy answer is unchanged by evidence recovery.
assert CurrentAdmissionAnswerPreserved {
  all c : RecoveryCase, s : RecoverySelection |
    recomposed[c, s] implies
      (admitted[s.policy, c.draft] iff admitted[c.current.policy, c.draft])
}

-- Coupled historical recovery can still lose a later permission, the pressure
-- already exposed by Observation 250.
pred coupledHistoricalRecoveryCanLoseLaterPermission {
  some c : RecoveryCase |
    c.candidate.policy.approved in c.current.policy.approved
    and c.candidate.policy.approved != c.current.policy.approved
    and admitted[c.current.policy, c.draft]
    and not admitted[c.candidate.policy, c.draft]
}

run recomposedRecoveryExists for 5 but exactly 5 Family, 8 Image, 3 EvidenceGeneration, 4 Policy, 4 Locus, 2 Draft, 2 SelectedGeneration, 2 RecoveryCase, 3 RecoverySelection
check RecomposedRecoveryRestoresEveryCandidateEvidenceFamily for 5 but exactly 5 Family, 8 Image, 3 EvidenceGeneration, 4 Policy, 4 Locus, 2 Draft, 3 SelectedGeneration, 2 RecoveryCase, 3 RecoverySelection
check RecomposedRecoveryPreservesCurrentPolicy for 5 but exactly 5 Family, 8 Image, 3 EvidenceGeneration, 4 Policy, 4 Locus, 2 Draft, 3 SelectedGeneration, 2 RecoveryCase, 3 RecoverySelection
check MissingCurrentPolicyRefusesRecomposition for 5 but exactly 5 Family, 8 Image, 3 EvidenceGeneration, 4 Policy, 4 Locus, 2 Draft, 3 SelectedGeneration, 2 RecoveryCase, 3 RecoverySelection
run historicalPolicyFallbackWouldMaskCurrentPolicyFailure for 5 but exactly 5 Family, 8 Image, 3 EvidenceGeneration, 4 Policy, 4 Locus, 2 Draft, 3 SelectedGeneration, 2 RecoveryCase, 3 RecoverySelection
check CandidateAdmissionSurvivesRecomposedRecovery for 5 but exactly 5 Family, 8 Image, 3 EvidenceGeneration, 4 Policy, 4 Locus, 2 Draft, 3 SelectedGeneration, 2 RecoveryCase, 3 RecoverySelection
check CurrentAdmissionAnswerPreserved for 5 but exactly 5 Family, 8 Image, 3 EvidenceGeneration, 4 Policy, 4 Locus, 2 Draft, 3 SelectedGeneration, 2 RecoveryCase, 3 RecoverySelection
run coupledHistoricalRecoveryCanLoseLaterPermission for 5 but exactly 5 Family, 8 Image, 3 EvidenceGeneration, 4 Policy, 4 Locus, 2 Draft, 3 SelectedGeneration, 2 RecoveryCase, 3 RecoverySelection
