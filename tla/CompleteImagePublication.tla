---- MODULE CompleteImagePublication ----
EXTENDS Naturals

OldImage == "old-image"
NewImage == "new-image"
PartialImage == "partial-image"
NoStage == "no-stage"

TargetStates == {OldImage, NewImage, PartialImage}
StageStates == {NoStage, PartialImage, NewImage}

VARIABLES target, stage, published, observed

vars == <<target, stage, published, observed>>

Init ==
  /\ target = OldImage
  /\ stage = NoStage
  /\ published = FALSE
  /\ observed = {}

\* A complete-image writer may build an arbitrarily incomplete sibling file.
\* The authority path is deliberately unchanged during this transition.
BeginStage ==
  /\ ~published
  /\ stage = NoStage
  /\ stage' = PartialImage
  /\ UNCHANGED <<target, published, observed>>

\* Only after the sibling image is complete does it become publishable.
FinishStage ==
  /\ ~published
  /\ stage = PartialImage
  /\ stage' = NewImage
  /\ UNCHANGED <<target, published, observed>>

\* Rename/replace is modeled as one authority transition. The complete sibling
\* becomes the target in the same state step; no target-partial state exists.
Publish ==
  /\ ~published
  /\ stage = NewImage
  /\ target' = NewImage
  /\ stage' = NoStage
  /\ published' = TRUE
  /\ UNCHANGED observed

\* Readers consult only the authority path, never the staging path.
Observe ==
  /\ observed' = observed \cup {target}
  /\ UNCHANGED <<target, stage, published>>

Next ==
  \/ BeginStage
  \/ FinishStage
  \/ Publish
  \/ Observe

Spec == Init /\ [][Next]_vars

\* Negative comparison: writing the authority path incrementally exposes a
\* partial canonical image before the writer can finish.
DirectBegin ==
  /\ ~published
  /\ target = OldImage
  /\ target' = PartialImage
  /\ UNCHANGED <<stage, published, observed>>

DirectFinish ==
  /\ ~published
  /\ target = PartialImage
  /\ target' = NewImage
  /\ published' = TRUE
  /\ UNCHANGED <<stage, observed>>

DirectNext ==
  \/ DirectBegin
  \/ DirectFinish
  \/ Observe

DirectSpec == Init /\ [][DirectNext]_vars

TypeOK ==
  /\ target \in TargetStates
  /\ stage \in StageStates
  /\ published \in BOOLEAN
  /\ observed \subseteq TargetStates

TargetAlwaysComplete ==
  target \in {OldImage, NewImage}

ReadersSeeOnlyCompleteImages ==
  observed \subseteq {OldImage, NewImage}

BeforePublicationAuthorityIsOld ==
  published \/ target = OldImage

AfterPublicationAuthorityIsNew ==
  ~published \/ target = NewImage

PartialStageDoesNotChangeAuthority ==
  stage # PartialImage \/ target = OldImage

\* Reachability boundaries. These are intentionally too strong and must fail
\* under their dedicated TLC configurations.
NoPartialStageState ==
  stage # PartialImage

NoPublishedState ==
  ~published

====
