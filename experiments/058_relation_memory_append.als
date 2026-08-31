module experiments/observation_058_relation_memory_append

// This model represents one practical relation kind at a time.
// `RelationId` is therefore per-kind identity, not a global FactId.
sig Event {}
sig RelationId {}

sig Relation {
  id: one RelationId,
  refs: some Event
}

// Add a raw relation using only the local collection law established by
// Observation 056: one relation identity names at most one raw relation fact.
fun identityOnlyAdd[stored: set Relation, added: Relation]: set Relation {
  (no existing: stored | existing.id = added.id)
    => stored + added
    else stored
}

// An alternative eager policy: refuse to remember the raw relation unless all
// referenced Events happen to be present at the moment of append.
fun referentialAdd[
    events: set Event,
    stored: set Relation,
    added: Relation
]: set Relation {
  (added.refs in events and no existing: stored | existing.id = added.id)
    => stored + added
    else stored
}

// Observation 055/057 admission remains a derived view over current Events and
// raw relation facts.
fun admitted[events: set Event, stored: set Relation]: set Relation {
  { relation: stored | relation.refs in events }
}

pred referentialAddCanDependOnArrivalState {
  some added: Relation, missing: added.refs | {
    #added.refs >= 2
    let beforeEvents = added.refs - missing |
      referentialAdd[beforeEvents, none, added] = none
      and referentialAdd[added.refs, none, added] = added
  }
}

// If the relation arrives before one required Event and there is no explicit
// retry, eager referential append can leave the final canonical raw relation set
// different from the Events-first arrival order.
pred referentialPolicyCanMakeFinalFactsArrivalDependent {
  some added: Relation, missing: added.refs | {
    #added.refs >= 2
    let beforeEvents = added.refs - missing,
        relationFirstRaw = referentialAdd[beforeEvents, none, added],
        eventsFirstRaw = referentialAdd[added.refs, none, added] | {
      no relationFirstRaw
      added in eventsFirstRaw
      relationFirstRaw != eventsFirstRaw
    }
  }
}

// Local identity append can remember the raw relation even while it is not yet
// semantically admissible. Once the missing Event appears, the same raw fact is
// exposed by derived admission without rewriting or retrying the relation.
pred identityOnlyKeepsEarlyRawRelationUntilAdmissible {
  some added: Relation, missing: added.refs | {
    #added.refs >= 2
    let beforeEvents = added.refs - missing,
        raw = identityOnlyAdd[none, added] | {
      added in raw
      added not in admitted[beforeEvents, raw]
      added in admitted[added.refs, raw]
    }
  }
}

// When every endpoint is already present, the eager referential policy adds no
// extra semantic discrimination beyond the local identity law.
assert EventsPresentMakesPoliciesAgree {
  all events: set Event, stored: set Relation, added: Relation |
    added.refs in events implies
      referentialAdd[events, stored, added] = identityOnlyAdd[stored, added]
}

// Local append must reject a repeated per-kind relation identity rather than
// letting list/arrival position choose a winner.
assert IdentityOnlyRejectsDuplicateId {
  all stored: set Relation, added: Relation |
    (some existing: stored | existing.id = added.id) implies
      identityOnlyAdd[stored, added] = stored
}

// Identity-only raw append does not promise immediate semantic admission.
// A retained raw relation remains invisible until all current Event references
// are present.
assert IdentityOnlyDoesNotBypassDerivedAdmission {
  all events: set Event, stored: set Relation, added: Relation |
    let raw = identityOnlyAdd[stored, added] |
      admitted[events, raw] in raw
}

run referentialAddCanDependOnArrivalState for exactly 2 Event, exactly 1 RelationId, exactly 1 Relation
run referentialPolicyCanMakeFinalFactsArrivalDependent for exactly 2 Event, exactly 1 RelationId, exactly 1 Relation
run identityOnlyKeepsEarlyRawRelationUntilAdmissible for exactly 2 Event, exactly 1 RelationId, exactly 1 Relation
check EventsPresentMakesPoliciesAgree for exactly 3 Event, exactly 3 RelationId, exactly 3 Relation
check IdentityOnlyRejectsDuplicateId for exactly 3 Event, exactly 2 RelationId, exactly 3 Relation
check IdentityOnlyDoesNotBypassDerivedAdmission for exactly 3 Event, exactly 3 RelationId, exactly 3 Relation
