module experiments/observation_109_attention_lifecycle_boundary

open util/ordering[Day] as ord

sig Day {}

abstract sig Node {}
sig Movement extends Node {}
sig Scheduled extends Node {
  due: one Day
}
sig Attention extends Node {}

abstract sig DueState {}
sig DueOn extends DueState {
  dueDay: one Day
}
one sig NoDueDate, DueUndetermined extends DueState {}

abstract sig AttentionCloseKind {}
one sig ResolvedClose, DroppedClose extends AttentionCloseKind {}

-- One deliberately shared relation record shape. Its meaning is interpreted by
-- source kind rather than assumed to be universal lifecycle semantics.
sig RelationEvidence {
  source: one (Scheduled + Attention),
  target: lone Node,
  knownOn: one Day
}

-- Attention closure is intentionally separate from relation provenance.
sig AttentionClosureEvidence {
  attention: one Attention,
  knownOn: one Day,
  kind: one AttentionCloseKind
}

sig World {
  relations: set RelationEvidence,
  attentionClosures: set AttentionClosureEvidence,
  dueOf: Attention -> one DueState
}

one sig Left, Right extends World {}

fact RelationTargetShape {
  all e: RelationEvidence | {
    e.source in Scheduled implies
      (no e.target or e.target in Movement + Scheduled)

    e.source in Attention implies
      (one e.target and e.target in Movement + Attention)
  }
}

fact OneScheduledTerminalPerWorld {
  all w: World, s: Scheduled |
    lone { e: w.relations | e.source = s }
}

fact OneAttentionRelationPerDay {
  all w: World, a: Attention, d: Day |
    lone { e: w.relations | e.source = a and e.knownOn = d }
}

fact OneAttentionClosurePerWorld {
  all w: World, a: Attention |
    lone { c: w.attentionClosures | c.attention = a }
}

fun present: one Day {
  ord/next[ord/next[ord/first]]
}

fun visibleRelations[w: World, n: Node, d: Day]: set RelationEvidence {
  { e: w.relations |
    e.source = n and
    e.knownOn in d.*(ord/prev)
  }
}

fun visibleAttentionClosures[w: World, a: Attention, d: Day]: set AttentionClosureEvidence {
  { c: w.attentionClosures |
    c.attention = a and
    c.knownOn in d.*(ord/prev)
  }
}

fun openScheduledAt[w: World, d: Day]: set Scheduled {
  { s: Scheduled | no visibleRelations[w, s, d] }
}

fun openAttentionAt[w: World, d: Day]: set Attention {
  { a: Attention | no visibleAttentionClosures[w, a, d] }
}

fun closedAttentionAt[w: World, d: Day]: set Attention {
  Attention - openAttentionAt[w, d]
}

fun resolvedAttentionAt[w: World, d: Day]: set Attention {
  { a: Attention |
    some c: visibleAttentionClosures[w, a, d] |
      c.kind = ResolvedClose
  }
}

fun droppedAttentionAt[w: World, d: Day]: set Attention {
  { a: Attention |
    some c: visibleAttentionClosures[w, a, d] |
      c.kind = DroppedClose
  }
}

fun attentionDueDate[w: World, a: Attention]: lone Day {
  { d: Day |
    some q: w.dueOf[a] & DueOn |
      q.dueDay = d
  }
}

fun attentionDueDateMap[w: World]: Attention -> Day {
  { a: Attention, d: Day | d in attentionDueDate[w, a] }
}

fun attentionNoDueDate[w: World]: set Attention {
  { a: Attention | w.dueOf[a] = NoDueDate }
}

fun attentionDueUndetermined[w: World]: set Attention {
  { a: Attention | w.dueOf[a] = DueUndetermined }
}

pred representativeSharedShape {
  some s: Scheduled, a: Attention, m: Movement, se, ae: RelationEvidence | {
    se in Left.relations
    ae in Left.relations
    se.source = s
    se.target = m
    ae.source = a
    ae.target = m
    se.knownOn in present.*(ord/prev)
    ae.knownOn in present.*(ord/prev)

    s not in openScheduledAt[Left, present]
    a in openAttentionAt[Left, present]
  }
}

pred sameAttentionRelationsDifferentLifecycle {
  Left.relations = Right.relations

  some a: Attention |
    a in openAttentionAt[Left, present] and
    a not in openAttentionAt[Right, present]
}

pred sameClosedAttentionDifferentDisposition {
  closedAttentionAt[Left, present] = closedAttentionAt[Right, present]

  some a: Attention |
    a in resolvedAttentionAt[Left, present] and
    a in droppedAttentionAt[Right, present]
}

pred sameOptionalDueDateDifferentMeaning {
  some a: Attention | {
    no attentionDueDate[Left, a]
    no attentionDueDate[Right, a]
    Left.dueOf[a] = NoDueDate
    Right.dueOf[a] = DueUndetermined
  }
}

pred attentionRelationToMovementDoesNotClose {
  some a: Attention, m: Movement, e: RelationEvidence | {
    e in Left.relations
    e.source = a
    e.target = m
    e.knownOn in present.*(ord/prev)
    a in openAttentionAt[Left, present]
  }
}

pred attentionContinuationDoesNotClose {
  some disj earlier, later: Attention, e: RelationEvidence | {
    e in Left.relations
    e.source = earlier
    e.target = later
    e.knownOn in present.*(ord/prev)
    earlier in openAttentionAt[Left, present]
  }
}

assert GenericTargetRelationClosesAttention {
  all w: World, a: Attention, d: Day |
    some visibleRelations[w, a, d]
    implies
    a not in openAttentionAt[w, d]
}

assert AttentionRelationsDetermineLifecycle {
  Left.relations = Right.relations
  implies
  all d: Day |
    openAttentionAt[Left, d] = openAttentionAt[Right, d]
}

assert ClosedAttentionDeterminesDisposition {
  all d: Day |
    closedAttentionAt[Left, d] = closedAttentionAt[Right, d]
    implies {
      resolvedAttentionAt[Left, d] = resolvedAttentionAt[Right, d]
      droppedAttentionAt[Left, d] = droppedAttentionAt[Right, d]
    }
}

assert OptionalDueDateDeterminesDueMeaning {
  attentionDueDateMap[Left] = attentionDueDateMap[Right]
  implies {
    attentionNoDueDate[Left] = attentionNoDueDate[Right]
    attentionDueUndetermined[Left] = attentionDueUndetermined[Right]
  }
}

assert ExplicitAttentionClosureAndDueDetermineAttentionView {
  Left.attentionClosures = Right.attentionClosures and
  Left.dueOf = Right.dueOf
  implies
  all d: Day | {
    openAttentionAt[Left, d] = openAttentionAt[Right, d]
    closedAttentionAt[Left, d] = closedAttentionAt[Right, d]
    resolvedAttentionAt[Left, d] = resolvedAttentionAt[Right, d]
    droppedAttentionAt[Left, d] = droppedAttentionAt[Right, d]
    attentionDueDateMap[Left] = attentionDueDateMap[Right]
    attentionNoDueDate[Left] = attentionNoDueDate[Right]
    attentionDueUndetermined[Left] = attentionDueUndetermined[Right]
  }
}

assert ScheduledRelationTargetIsTerminal {
  all w: World, s: Scheduled, d: Day |
    some visibleRelations[w, s, d]
    implies
    s not in openScheduledAt[w, d]
}

run representativeSharedShape for exactly 4 Day, exactly 2 Movement, exactly 2 Scheduled, exactly 3 Attention, exactly 2 DueOn, exactly 7 RelationEvidence, exactly 4 AttentionClosureEvidence, exactly 2 World
run sameAttentionRelationsDifferentLifecycle for exactly 4 Day, exactly 2 Movement, exactly 2 Scheduled, exactly 3 Attention, exactly 2 DueOn, exactly 7 RelationEvidence, exactly 4 AttentionClosureEvidence, exactly 2 World
run sameClosedAttentionDifferentDisposition for exactly 4 Day, exactly 2 Movement, exactly 2 Scheduled, exactly 3 Attention, exactly 2 DueOn, exactly 7 RelationEvidence, exactly 4 AttentionClosureEvidence, exactly 2 World
run sameOptionalDueDateDifferentMeaning for exactly 4 Day, exactly 2 Movement, exactly 2 Scheduled, exactly 3 Attention, exactly 2 DueOn, exactly 7 RelationEvidence, exactly 4 AttentionClosureEvidence, exactly 2 World
run attentionRelationToMovementDoesNotClose for exactly 4 Day, exactly 2 Movement, exactly 2 Scheduled, exactly 3 Attention, exactly 2 DueOn, exactly 7 RelationEvidence, exactly 4 AttentionClosureEvidence, exactly 2 World
run attentionContinuationDoesNotClose for exactly 4 Day, exactly 2 Movement, exactly 2 Scheduled, exactly 3 Attention, exactly 2 DueOn, exactly 7 RelationEvidence, exactly 4 AttentionClosureEvidence, exactly 2 World
check GenericTargetRelationClosesAttention for exactly 4 Day, exactly 2 Movement, exactly 2 Scheduled, exactly 3 Attention, exactly 2 DueOn, exactly 7 RelationEvidence, exactly 4 AttentionClosureEvidence, exactly 2 World
check AttentionRelationsDetermineLifecycle for exactly 4 Day, exactly 2 Movement, exactly 2 Scheduled, exactly 3 Attention, exactly 2 DueOn, exactly 7 RelationEvidence, exactly 4 AttentionClosureEvidence, exactly 2 World
check ClosedAttentionDeterminesDisposition for exactly 4 Day, exactly 2 Movement, exactly 2 Scheduled, exactly 3 Attention, exactly 2 DueOn, exactly 7 RelationEvidence, exactly 4 AttentionClosureEvidence, exactly 2 World
check OptionalDueDateDeterminesDueMeaning for exactly 4 Day, exactly 2 Movement, exactly 2 Scheduled, exactly 3 Attention, exactly 2 DueOn, exactly 7 RelationEvidence, exactly 4 AttentionClosureEvidence, exactly 2 World
check ExplicitAttentionClosureAndDueDetermineAttentionView for exactly 4 Day, exactly 2 Movement, exactly 2 Scheduled, exactly 3 Attention, exactly 2 DueOn, exactly 7 RelationEvidence, exactly 4 AttentionClosureEvidence, exactly 2 World
check ScheduledRelationTargetIsTerminal for exactly 4 Day, exactly 2 Movement, exactly 2 Scheduled, exactly 3 Attention, exactly 2 DueOn, exactly 7 RelationEvidence, exactly 4 AttentionClosureEvidence, exactly 2 World
