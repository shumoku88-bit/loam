datatype PublicationSnapshot = Snapshot(token: string)

datatype WriterEvidence = WriterEvidence(
  observedSnapshot: PublicationSnapshot,
  currentSnapshot: PublicationSnapshot,
  candidateIdentityAlreadyPresent: bool
)

datatype WriterDecision =
  PublishCandidate |
  RefuseStaleSnapshot |
  RefuseDuplicateEventIdentity

// Application 002 does not write files and does not construct EventMemory in
// Dafny. It receives already-derived publication evidence and decides only
// whether one already-admitted candidate is authorized to reach publication.
function ExpectedWriterDecision(evidence: WriterEvidence): WriterDecision
{
  if evidence.observedSnapshot != evidence.currentSnapshot then
    RefuseStaleSnapshot
  else if evidence.candidateIdentityAlreadyPresent then
    RefuseDuplicateEventIdentity
  else
    PublishCandidate
}

method AuthorizeWriter(evidence: WriterEvidence)
    returns (decision: WriterDecision)
  ensures decision == ExpectedWriterDecision(evidence)
{
  if evidence.observedSnapshot != evidence.currentSnapshot {
    decision := RefuseStaleSnapshot;
  } else if evidence.candidateIdentityAlreadyPresent {
    decision := RefuseDuplicateEventIdentity;
  } else {
    decision := PublishCandidate;
  }
}

predicate Publishable(evidence: WriterEvidence)
{
  evidence.observedSnapshot == evidence.currentSnapshot &&
  !evidence.candidateIdentityAlreadyPresent
}

// Publication is authorized exactly when the snapshot is still current and the
// candidate Event identity is not already present in current EventMemory.
lemma PublishExactlyWhenAuthorized(evidence: WriterEvidence)
  ensures (ExpectedWriterDecision(evidence) == PublishCandidate) <==>
          Publishable(evidence)
{
}

// A stale preparation cannot become publishable merely because its Event
// identity appears distinct. The caller must re-observe current state first.
lemma StaleSnapshotAlwaysRefuses(
    observed: PublicationSnapshot,
    current: PublicationSnapshot,
    candidateIdentityAlreadyPresent: bool)
  requires observed != current
  ensures ExpectedWriterDecision(
            WriterEvidence(observed, current, candidateIdentityAlreadyPresent)) ==
          RefuseStaleSnapshot
{
}

// Once the preparation snapshot is current, repeated Event identity remains a
// separate fail-closed admission result rather than being silently overwritten.
lemma CurrentDuplicateIdentityAlwaysRefuses(snapshot: PublicationSnapshot)
  ensures ExpectedWriterDecision(
            WriterEvidence(snapshot, snapshot, true)) ==
          RefuseDuplicateEventIdentity
{
}

// Under stale evidence, whether the candidate identity looks fresh or repeated
// is outside the authorization decision. Staleness dominates and forces retry.
lemma StaleSnapshotIgnoresCandidateIdentityStatus(
    observed: PublicationSnapshot,
    current: PublicationSnapshot)
  requires observed != current
  ensures ExpectedWriterDecision(WriterEvidence(observed, current, false)) ==
          ExpectedWriterDecision(WriterEvidence(observed, current, true))
  ensures ExpectedWriterDecision(WriterEvidence(observed, current, false)) ==
          RefuseStaleSnapshot
{
}

function DecisionName(decision: WriterDecision): string
{
  match decision
    case PublishCandidate => "PublishCandidate"
    case RefuseStaleSnapshot => "RefuseStaleSnapshot"
    case RefuseDuplicateEventIdentity => "RefuseDuplicateEventIdentity"
}

method {:main} Main()
{
  var snapshot := Snapshot("snapshot-a");
  var changed := Snapshot("snapshot-b");

  var publish := AuthorizeWriter(WriterEvidence(snapshot, snapshot, false));
  assert publish == PublishCandidate;
  print DecisionName(publish), "\n";

  var duplicate := AuthorizeWriter(WriterEvidence(snapshot, snapshot, true));
  assert duplicate == RefuseDuplicateEventIdentity;
  print DecisionName(duplicate), "\n";

  var stale := AuthorizeWriter(WriterEvidence(snapshot, changed, false));
  assert stale == RefuseStaleSnapshot;
  print DecisionName(stale), "\n";

  var staleDuplicate := AuthorizeWriter(WriterEvidence(snapshot, changed, true));
  assert staleDuplicate == RefuseStaleSnapshot;
  print DecisionName(staleDuplicate), "\n";
}
