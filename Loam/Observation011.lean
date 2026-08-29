namespace Loam.Observation011

set_option autoImplicit false

universe u

abbrev Availability (Unit : Type u) := Unit → Prop

/-- Consuming one unit keeps every previously available unit except the one
that was used. -/
def consume {Unit : Type u}
    (available : Availability Unit)
    (used : Unit) : Availability Unit :=
  fun u => available u ∧ u ≠ used

/-- Availability derived from an initial observation and a finite use history.
The newest use is at the head; depletion itself is insensitive to that choice
of presentation. -/
def evolve {Unit : Type u}
    (initial : Availability Unit) :
    List Unit → Availability Unit
  | [] => initial
  | used :: history => consume (evolve initial history) used

/-- If a stored availability observation has the same initial value and exact
one-use evolution law as the derived observation, then it is not an
independent choice: every finite history determines it uniquely. -/
theorem exactEvolutionUnique
    {Unit : Type u}
    (initial : Availability Unit)
    (stored : List Unit → Availability Unit)
    (hInitial : stored [] = initial)
    (hStep : ∀ used history,
      stored (used :: history) = consume (stored history) used) :
    ∀ history, stored history = evolve initial history := by
  intro history
  induction history with
  | nil =>
      exact hInitial
  | cons used history ih =>
      calc
        stored (used :: history) = consume (stored history) used :=
          hStep used history
        _ = consume (evolve initial history) used :=
          congrArg (fun available => consume available used) ih
        _ = evolve initial (used :: history) := rfl

/-- Two separately stored availability traces that obey the same exact law
must therefore agree on every finite history. -/
theorem exactStoresAgree
    {Unit : Type u}
    (initial : Availability Unit)
    (storedA storedB : List Unit → Availability Unit)
    (aInitial : storedA [] = initial)
    (aStep : ∀ used history,
      storedA (used :: history) = consume (storedA history) used)
    (bInitial : storedB [] = initial)
    (bStep : ∀ used history,
      storedB (used :: history) = consume (storedB history) used) :
    ∀ history, storedA history = storedB history := by
  intro history
  calc
    storedA history = evolve initial history :=
      exactEvolutionUnique initial storedA aInitial aStep history
    _ = storedB history :=
      (exactEvolutionUnique initial storedB bInitial bStep history).symm

/-- Immediately after a unit is included in the use history, that unit cannot
remain available in the derived observation. -/
theorem consumedUnitUnavailable
    {Unit : Type u}
    (initial : Availability Unit)
    (history : List Unit)
    (used : Unit) :
    ¬ evolve initial (used :: history) used := by
  change ¬ (evolve initial history used ∧ used ≠ used)
  intro h
  exact h.2 rfl

end Loam.Observation011
