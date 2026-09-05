module experiments/observation_198_authorization_hold_reservation

-- F001 asks whether a temporary authorization reservation is independent from
-- both physical holdings and the already-qualified initiated/unsettled state.
--
-- The model deliberately keeps one authorization identity and one exact held
-- quantity. `reserved` is observation-local evidence only. It is not a proposal
-- for a production CardAuthorization, Hold, PendingBalance, or Account state.

sig Authorization {}

sig World {
  held: one Int,
  initiated: set Authorization,
  settled: set Authorization,
  reserved: Authorization -> lone Int
}

one sig Left, Right extends World {}
one sig A extends Authorization {}

fun reserveAmount[w: World, a: Authorization]: one Int {
  sum { i: Int | a->i in w.reserved }
}

fun totalReserved[w: World]: one Int {
  sum a: Authorization | reserveAmount[w, a]
}

fun available[w: World]: one Int {
  w.held - totalReserved[w]
}

fact WellFormed {
  all w: World | {
    w.held >= 0
    w.settled in w.initiated
    all a: Authorization | {
      reserveAmount[w, a] >= 0
      some w.reserved[a] implies {
        a in w.initiated
        a not in w.settled
        reserveAmount[w, a] > 0
      }
    }
    totalReserved[w] <= w.held
  }
}

pred representativeHeldAuthorization {
  Left.held = 100
  A in Left.initiated
  A not in Left.settled
  reserveAmount[Left, A] = 30
  available[Left] = 70
}

pred samePhysicalAndLifecycleDifferentReservation {
  Left.held = Right.held
  Left.initiated = Right.initiated
  Left.settled = Right.settled

  Left.held = 100
  A in Left.initiated
  A not in Left.settled

  reserveAmount[Left, A] = 30
  reserveAmount[Right, A] = 0

  available[Left] = 70
  available[Right] = 100
}

-- Deliberately too strong: Observation 050-style physical + lifecycle evidence
-- does not necessarily determine temporary availability while a reservation
-- overlay may differ.
assert PhysicalAndLifecycleDetermineAvailability {
  Left.held = Right.held and
  Left.initiated = Right.initiated and
  Left.settled = Right.settled implies
    available[Left] = available[Right]
}

-- Positive sufficiency check for the selected vocabulary. Once held quantity
-- and explicit reservation evidence are fixed, selected availability is fixed.
assert ExplicitReservationDeterminesAvailability {
  Left.held = Right.held and
  Left.reserved = Right.reserved implies
    available[Left] = available[Right]
}

-- A settled authorization cannot still carry a reservation in this bounded
-- snapshot. Release/capture transition mechanics are deliberately out of scope.
assert SettledHasNoReservation {
  all w: World, a: Authorization |
    a in w.settled implies reserveAmount[w, a] = 0
}

run representativeHeldAuthorization for exactly 1 Authorization, exactly 2 World, 8 Int
run samePhysicalAndLifecycleDifferentReservation for exactly 1 Authorization, exactly 2 World, 8 Int
check PhysicalAndLifecycleDetermineAvailability for exactly 1 Authorization, exactly 2 World, 8 Int
check ExplicitReservationDeterminesAvailability for exactly 1 Authorization, exactly 2 World, 8 Int
check SettledHasNoReservation for exactly 1 Authorization, exactly 2 World, 8 Int
