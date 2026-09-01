module experiments/observation_090_origin_evidence_shape

abstract sig Coordinate {}
one sig C extends Coordinate {}

abstract sig Event {}
one sig E extends Event {}

abstract sig OriginBoundary {}
one sig ApplicationStart, BeforeFirstEvent extends OriginBoundary {}

abstract sig QuantityMark {}
one sig Zero, NonZero extends QuantityMark {}

sig OriginEvidence {
  coordinate : one Coordinate,
  boundary : one OriginBoundary,
  quantity : one QuantityMark,
  originEvent : lone Event
}

abstract sig World {
  retained : set Event,
  origin : one OriginEvidence
}
one sig Left, Right extends World {}

fact OriginShape {
  all o : OriginEvidence |
    (o.boundary = ApplicationStart implies no o.originEvent)
    and
    (o.boundary = BeforeFirstEvent implies
      (one o.originEvent and o.quantity = Zero))
}

fact RetainedOriginReference {
  all w : World |
    some w.origin.originEvent implies w.origin.originEvent in w.retained
}

pred sameErasedOriginSnapshot[w1, w2 : World] {
  w1.retained = w2.retained
  w1.origin.coordinate = w2.origin.coordinate
  w1.origin.quantity = w2.origin.quantity
}

pred sameZeroAnchorShapeDifferentBoundary {
  Left.origin != Right.origin
  sameErasedOriginSnapshot[Left, Right]
  Left.origin.quantity = Zero
  Left.origin.boundary = ApplicationStart
  Right.origin.boundary = BeforeFirstEvent
}

assert ErasedOriginDeterminesBoundary {
  all disj w1, w2 : World |
    sameErasedOriginSnapshot[w1, w2] implies
      (w1.origin.boundary = w2.origin.boundary
       and w1.origin.originEvent = w2.origin.originEvent)
}

assert ZeroQuantityDeterminesFirstEventBoundary {
  all w : World |
    w.origin.quantity = Zero implies w.origin.boundary = BeforeFirstEvent
}

assert FirstEventOriginIsExactZero {
  all w : World |
    w.origin.boundary = BeforeFirstEvent implies w.origin.quantity = Zero
}

assert ApplicationStartOriginHasNoEvent {
  all w : World |
    w.origin.boundary = ApplicationStart implies no w.origin.originEvent
}

assert FirstEventOriginReferencesRetainedEvent {
  all w : World |
    w.origin.boundary = BeforeFirstEvent implies
      w.origin.originEvent in w.retained
}

run sameZeroAnchorShapeDifferentBoundary for exactly 2 OriginEvidence
check ErasedOriginDeterminesBoundary for exactly 2 OriginEvidence
check ZeroQuantityDeterminesFirstEventBoundary for exactly 2 OriginEvidence
check FirstEventOriginIsExactZero for exactly 2 OriginEvidence
check ApplicationStartOriginHasNoEvent for exactly 2 OriginEvidence
check FirstEventOriginReferencesRetainedEvent for exactly 2 OriginEvidence
