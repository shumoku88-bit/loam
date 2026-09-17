import Loam.Core.EventMemory
import Loam.Core.ExternalParty
import Loam.Core.FiniteKeyed

namespace Loam.Core

set_option autoImplicit false

/-!
# Event Merchant evidence

Observations 266–269 qualified one query-specific Event-scoped relation for the
retained external commercial provider from whom the household regards an Event as
acquiring goods or services.

This module retains only Merchant disposition evidence. It deliberately does not
introduce a generic EventParty relation, Party registry, display-name authority,
role taxonomy, merchant amount, payment-recipient meaning, creditor meaning, or
Effect-level seller attribution.

Missing evidence is intentionally distinct from explicit `nonmerchant` evidence:

```text
no row                         = unresolved
merchant ExternalPartyId       = retained Merchant identity
nonmerchant                     = explicitly outside EventMerchant
```
-/

/--
The retained Merchant disposition for one Event.

`merchant` carries shared role-free external identity only. Commercial-provider
meaning belongs to this relation, not to `ExternalPartyId` itself.
-/
inductive MerchantDisposition where
  | merchant (party : ExternalPartyId)
  | nonmerchant
deriving Repr, DecidableEq

/-- One explicit Merchant disposition for one Event identity. -/
structure EventMerchantEvidence where
  event : EventId
  disposition : MerchantDisposition
deriving Repr, DecidableEq

/--
A practical memory of Event Merchant dispositions.

Each EventId may occur at most once. Representation order carries no temporal,
causal, priority, authority, or arrival-order meaning.
-/
structure EventMerchantEvidenceMemory where
  entries : List EventMerchantEvidence
  eventNodup : (entries.map EventMerchantEvidence.event).Nodup
deriving Repr

namespace EventMerchantEvidenceMemory

/--
Admit raw Merchant evidence only when one Event does not receive two retained
dispositions. This check does not yet require the referenced Event to exist.
-/
def ofEntries?
    (entries : List EventMerchantEvidence) : Option EventMerchantEvidenceMemory :=
  if h : (entries.map EventMerchantEvidence.event).Nodup then
    some { entries := entries, eventNodup := h }
  else
    none

/-- Empty Merchant evidence memory is valid. -/
def empty : EventMerchantEvidenceMemory :=
  { entries := [], eventNodup := by simp }

@[simp] theorem ofEntries?_nil :
    ofEntries? [] = some empty := by
  simp [ofEntries?, empty]

@[simp] theorem ofEntries?_singleton (entry : EventMerchantEvidence) :
    ofEntries? [entry] = some { entries := [entry], eventNodup := by simp } := by
  simp [ofEntries?]

/--
Append one raw disposition while preserving the one-disposition-per-Event law.
Referential closure remains a separate admission question.
-/
def add?
    (memory : EventMerchantEvidenceMemory)
    (entry : EventMerchantEvidence) : Option EventMerchantEvidenceMemory :=
  ofEntries? (memory.entries ++ [entry])

/--
Look up the retained Merchant disposition for one Event.

`none` means unresolved. `some .nonmerchant` is therefore observably distinct
from absence, preserving Observation 268's coverage boundary.
-/
def findDisposition?
    (memory : EventMerchantEvidenceMemory)
    (target : EventId) : Option MerchantDisposition :=
  (FiniteKeyed.findBy? EventMerchantEvidence.event memory.entries target).map
    EventMerchantEvidence.disposition

/--
Whether every retained Merchant disposition refers to an Event present in the
supplied EventMemory.

This is admission closure only. It does not inspect Event Effects, AccountingRole,
validity, description, or any other semantic family.
-/
def referencesOnlyKnownEvents
    (events : EventMemory)
    (memory : EventMerchantEvidenceMemory) : Bool :=
  memory.entries.all fun evidence =>
    (EventMemory.findById? events evidence.event).isSome

/--
Admit a complete candidate collection against current Event identity authority.

Duplicate Event dispositions fail in `ofEntries?`; dangling Event references fail
in the closure check. Missing disposition rows remain valid and mean unresolved.
-/
def ofEntriesAgainst?
    (events : EventMemory)
    (entries : List EventMerchantEvidence) : Option EventMerchantEvidenceMemory :=
  match ofEntries? entries with
  | none => none
  | some memory =>
      if referencesOnlyKnownEvents events memory then
        some memory
      else
        none

@[simp] theorem referencesOnlyKnownEvents_empty (events : EventMemory) :
    referencesOnlyKnownEvents events empty = true := by
  simp [referencesOnlyKnownEvents, empty]

@[simp] theorem findDisposition?_empty (event : EventId) :
    findDisposition? empty event = none := by
  simp [findDisposition?, empty, FiniteKeyed.findBy?]

end EventMerchantEvidenceMemory

end Loam.Core
