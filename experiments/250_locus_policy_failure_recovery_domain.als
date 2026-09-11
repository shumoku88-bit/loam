module experiments/observation_250_locus_policy_failure_recovery_domain

-- Observation 250
--
-- Pressure-test whether current Locus write policy must share the same failure
-- and recovery domain as retained Movement evidence. This model does not choose
-- a file format. It compares only observable availability and recovery answers.

abstract sig Artifact {}
one sig MovementEvidence, LocusPolicy extends Artifact {}

sig Availability {
  available : set Artifact
}

pred evidenceReadAvailable[s : Availability] {
  MovementEvidence in s.available
}

pred coupledReadAvailable[s : Availability] {
  MovementEvidence in s.available
  LocusPolicy in s.available
}

pred writeAvailable[s : Availability] {
  MovementEvidence in s.available
  LocusPolicy in s.available
}

pred policyOnlyFailureLeavesEvidenceReadable {
  some s : Availability |
    MovementEvidence in s.available
    and LocusPolicy not in s.available
    and evidenceReadAvailable[s]
    and not coupledReadAvailable[s]
}

assert PolicyOnlyFailureDoesNotPermitWrite {
  all s : Availability |
    (MovementEvidence in s.available and LocusPolicy not in s.available)
      implies not writeAvailable[s]
}

sig Locus {}
sig MovementGeneration {}

sig Policy {
  approved : set Locus
}

sig Draft {
  uses : some Locus
}

sig RecoveryCase {
  historicalMovement : one MovementGeneration,
  currentMovement : one MovementGeneration,
  historicalPolicy : one Policy,
  currentPolicy : one Policy,
  draft : one Draft
}

pred admitted[p : Policy, d : Draft] {
  d.uses in p.approved
}

pred addOnlyGrowth[c : RecoveryCase] {
  c.historicalMovement != c.currentMovement
  c.historicalPolicy.approved in c.currentPolicy.approved
  c.historicalPolicy.approved != c.currentPolicy.approved
}

-- Coupled recovery selects the policy paired with the historical Movement
-- generation. Split recovery restores Movement evidence while leaving current
-- operational policy selected.
fun coupledRecoveredPolicy[c : RecoveryCase] : one Policy {
  c.historicalPolicy
}

fun splitRecoveredPolicy[c : RecoveryCase] : one Policy {
  c.currentPolicy
}

pred coupledRecoveryCanLoseCurrentPermission {
  some c : RecoveryCase |
    addOnlyGrowth[c]
    and admitted[c.currentPolicy, c.draft]
    and not admitted[coupledRecoveredPolicy[c], c.draft]
}

assert AddOnlyHistoricalAdmissionSurvivesSplitRecovery {
  all c : RecoveryCase |
    addOnlyGrowth[c] implies
      (admitted[c.historicalPolicy, c.draft]
        implies admitted[splitRecoveredPolicy[c], c.draft])
}

assert SplitRecoveryPreservesCurrentPolicyAnswer {
  all c : RecoveryCase |
    admitted[splitRecoveredPolicy[c], c.draft]
      iff admitted[c.currentPolicy, c.draft]
}

run policyOnlyFailureLeavesEvidenceReadable for 3 but exactly 2 Artifact, 2 Availability
check PolicyOnlyFailureDoesNotPermitWrite for 3 but exactly 2 Artifact, 2 Availability
run coupledRecoveryCanLoseCurrentPermission for 4 but 3 Locus, 3 MovementGeneration, 3 Policy, 2 Draft, 2 RecoveryCase
check AddOnlyHistoricalAdmissionSurvivesSplitRecovery for 4 but 3 Locus, 3 MovementGeneration, 3 Policy, 2 Draft, 2 RecoveryCase
check SplitRecoveryPreservesCurrentPolicyAnswer for 4 but 3 Locus, 3 MovementGeneration, 3 Policy, 2 Draft, 2 RecoveryCase
