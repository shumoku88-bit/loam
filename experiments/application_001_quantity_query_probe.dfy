datatype EffectiveQuantityEvidence =
  NoEffectiveQuantity |
  EffectiveQuantity(value: int)

datatype QuantityInspectionEvidence = Evidence(
  correctionCount: nat,
  recordedQuantity: int,
  effectiveQuantity: EffectiveQuantityEvidence
)

datatype QuantityInspectionAnswer =
  RecordedQuantity(value: int) |
  SingleCorrectionEffectiveQuantity(value: int) |
  MissingCorrectionEndpoint |
  FrontierRequired

// Application 001 does not compute accounting quantity semantics in Dafny.
// It receives already-derived quantity evidence and decides only which answer
// the current correction shape permits the application to expose.
function ExpectedAnswer(evidence: QuantityInspectionEvidence): QuantityInspectionAnswer
{
  if evidence.correctionCount == 0 then
    RecordedQuantity(evidence.recordedQuantity)
  else if evidence.correctionCount == 1 then
    match evidence.effectiveQuantity
      case EffectiveQuantity(value) => SingleCorrectionEffectiveQuantity(value)
      case NoEffectiveQuantity => MissingCorrectionEndpoint
  else
    FrontierRequired
}

method InspectQuantity(evidence: QuantityInspectionEvidence)
    returns (answer: QuantityInspectionAnswer)
  ensures answer == ExpectedAnswer(evidence)
{
  if evidence.correctionCount == 0 {
    answer := RecordedQuantity(evidence.recordedQuantity);
  } else if evidence.correctionCount == 1 {
    match evidence.effectiveQuantity
      case EffectiveQuantity(value) =>
        answer := SingleCorrectionEffectiveQuantity(value);
      case NoEffectiveQuantity =>
        answer := MissingCorrectionEndpoint;
  } else {
    answer := FrontierRequired;
  }
}

// When there is no Correction, any single-correction evidence is outside this
// query vocabulary and therefore cannot change the recorded answer.
lemma ZeroCorrectionIgnoresEffectiveEvidence(
    recorded: int,
    left: EffectiveQuantityEvidence,
    right: EffectiveQuantityEvidence)
  ensures ExpectedAnswer(Evidence(0, recorded, left)) ==
          ExpectedAnswer(Evidence(0, recorded, right))
{
}

// Once more than one Correction exists, Application 001 deliberately refuses
// to choose a frontier. Neither candidate quantity may smuggle in an answer.
lemma MultipleCorrectionsIgnoreQuantityCandidates(
    correctionCount: nat,
    leftRecorded: int,
    rightRecorded: int,
    leftEffective: EffectiveQuantityEvidence,
    rightEffective: EffectiveQuantityEvidence)
  requires correctionCount > 1
  ensures ExpectedAnswer(Evidence(correctionCount, leftRecorded, leftEffective)) == FrontierRequired
  ensures ExpectedAnswer(Evidence(correctionCount, rightRecorded, rightEffective)) == FrontierRequired
{
}

function AnswerName(answer: QuantityInspectionAnswer): string
{
  match answer
    case RecordedQuantity(value) => "RecordedQuantity"
    case SingleCorrectionEffectiveQuantity(value) => "SingleCorrectionEffectiveQuantity"
    case MissingCorrectionEndpoint => "MissingCorrectionEndpoint"
    case FrontierRequired => "FrontierRequired"
}

method {:main} Main()
{
  var recorded := InspectQuantity(Evidence(0, 1200, NoEffectiveQuantity));
  assert recorded == RecordedQuantity(1200);
  print AnswerName(recorded), "\n";

  var effective := InspectQuantity(Evidence(1, 1200, EffectiveQuantity(900)));
  assert effective == SingleCorrectionEffectiveQuantity(900);
  print AnswerName(effective), "\n";

  var missing := InspectQuantity(Evidence(1, 1200, NoEffectiveQuantity));
  assert missing == MissingCorrectionEndpoint;
  print AnswerName(missing), "\n";

  var frontier := InspectQuantity(Evidence(2, 1200, EffectiveQuantity(900)));
  assert frontier == FrontierRequired;
  print AnswerName(frontier), "\n";
}
