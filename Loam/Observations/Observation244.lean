namespace Loam.Observations.Observation244

set_option autoImplicit false

/-!
Observation 244

Question: once one retained semantic dependency has been established, does its
crash-safety law determine how many physical containers must represent it?

This is a deliberately tiny topology comparison. It keeps one semantic shape
fixed:

  dependent evidence -> activation anchor

and compares three physical publication strategies:

A. two containers, evidence first;
B. one atomic bundled image;
C. two containers, activation anchor first.

The observation does not choose a production persistence design. It only tests
whether physical container count follows from the semantic activation law.
-/

/-- Observable publication state at one crash cut. -/
inductive CrashState where
  | neither
  | evidenceOnly
  | anchorOnly
  | both
  deriving Repr, DecidableEq

/--
A crash cut is semantically closed exactly when an exposed activation anchor has
its required dependent evidence. Dangling evidence is inert and therefore safe.
-/
def semanticallyClosed : CrashState → Bool
  | .neither => true
  | .evidenceOnly => true
  | .anchorOnly => false
  | .both => true

/-- Representative physical publication strategies. -/
inductive Topology where
  | splitEvidenceFirst
  | atomicBundle
  | splitAnchorFirst
  deriving Repr, DecidableEq

/--
Crash prefixes reachable from each representative strategy.

The list is a finite model of externally observable cuts, not a filesystem
implementation. `atomicBundle` exposes no intermediate half-image.
-/
def crashPrefixes : Topology → List CrashState
  | .splitEvidenceFirst => [.neither, .evidenceOnly, .both]
  | .atomicBundle => [.neither, .both]
  | .splitAnchorFirst => [.neither, .anchorOnly, .both]

/-- All crash cuts of one topology preserve semantic closure. -/
def crashSafe (topology : Topology) : Bool :=
  (crashPrefixes topology).all semanticallyClosed

/-- Two physical containers can satisfy the activation law when evidence is first. -/
theorem split_evidence_first_is_safe :
    crashSafe .splitEvidenceFirst = true := by
  decide

/-- One atomic bundled image can satisfy the same semantic law. -/
theorem atomic_bundle_is_safe :
    crashSafe .atomicBundle = true := by
  decide

/-- Publishing the activation anchor first exposes a concrete unsafe crash cut. -/
theorem split_anchor_first_is_unsafe :
    crashSafe .splitAnchorFirst = false := by
  decide

/--
The same dependent-evidence semantics therefore admits at least two different
physical container counts while preserving every crash-prefix closure property
modeled here.

This is the negative result needed by the topology audit: semantic dependence
plus crash closure does not imply `one semantic family = one file`, nor does it
imply that two dependent facts require two files.
-/
theorem safe_topology_is_not_unique :
    crashSafe .splitEvidenceFirst = true ∧
    crashSafe .atomicBundle = true ∧
    .splitEvidenceFirst ≠ .atomicBundle := by
  decide

/--
Conversely, equal container count does not imply equal safety: the two split
strategies have the same broad physical cardinality but differ in crash closure.
-/
theorem equal_split_shape_does_not_determine_safety :
    crashSafe .splitEvidenceFirst ≠ crashSafe .splitAnchorFirst := by
  decide

end Loam.Observations.Observation244
