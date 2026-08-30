# Observation 053: storage order without history

## Question

When several Events are persisted together, should the physical order used to serialize them become temporal, causal, priority, authority, or posting-order meaning?

## Model

The model separates two relations:

- `members : set Event` is the remembered Event membership.
- `placed : Slot -> Event` is one concrete storage placement used to serialize those members.

`Slot` has an order only so the experiment can ask what would happen if a consumer treated storage position as meaningful. Event quantity is attached to Event identity, not to Slot.

## Commands

Expected Alloy results:

- `sameMembersDifferentStorageOrder`: SAT
- `sameMembersCanChangeFirstQuantity`: SAT
- `MembershipDeterminesTotal`: UNSAT
- `MembershipDeterminesFirstQuantity`: SAT

The first witness shows that one Event membership can have more than one storage order. The second shows that a query such as "first quantity" changes when storage order is promoted into meaning. The total over Event membership does not change under reordering, so Alloy finds no counterexample to that membership-only law.

## Interpretation

Storage order is not household history by default.

A practical multi-Event persistence format may retain a deterministic row/block order for round-trip stability, but that representation must not silently answer questions such as "what happened first", "what caused what", "which Event has priority", or "which Event is authoritative".

Those questions need an explicit semantic relation of their own when they become real requirements.

Event identity remains meaningful. Re-serializing the same Event identities in a different order does not create different Events. A future practical collection should therefore reject repeated Event identity rather than manufacture multiplicity from repeated rows.

This observation does **not** introduce a `CollectionId` or claim that two future collections with identical membership must always be the same entity. Current practical queries do not yet require collection identity, so adding it now would answer a question we have not asked.

## Practical consequence

The next practical step can use a versioned multi-Event file whose decoder preserves each Event and checks Event identity uniqueness. Its in-memory representation may be a list for deterministic persistence, while domain queries should operate on Event membership and explicit relations rather than list position.
