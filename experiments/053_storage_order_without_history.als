module experiments/observation_053_storage_order_without_history

open util/ordering[Slot] as slots

sig Event {
  quantity: one Int
}

sig Slot {}

abstract sig Image {
  members: set Event,
  placed: Slot -> lone Event
}

one sig Left, Right extends Image {}

fact BoundedQuantities {
  all e: Event | {
    e.quantity >= -2
    e.quantity <= 2
    e.quantity != 0
  }
}

fact PlacementRepresentsMembership {
  all i: Image | {
    i.members = Slot.(i.placed)
    all e: i.members | one (i.placed).e
  }
}

fun total[i: Image]: one Int {
  sum e: i.members | e.quantity
}

fun firstQuantity[i: Image]: one Int {
  sum e: slots/first.(i.placed) | e.quantity
}

pred sameMembersDifferentStorageOrder {
  Left.members = Event
  Right.members = Event
  Left.members = Right.members
  Left.placed != Right.placed
}

pred sameMembersCanChangeFirstQuantity {
  sameMembersDifferentStorageOrder
  firstQuantity[Left] != firstQuantity[Right]
}

assert MembershipDeterminesTotal {
  Left.members = Right.members implies
    total[Left] = total[Right]
}

assert MembershipDeterminesFirstQuantity {
  (Left.members = Event and
   Right.members = Event and
   Left.members = Right.members) implies
    firstQuantity[Left] = firstQuantity[Right]
}

run sameMembersDifferentStorageOrder for exactly 3 Event, exactly 3 Slot, exactly 2 Image, 5 Int
run sameMembersCanChangeFirstQuantity for exactly 3 Event, exactly 3 Slot, exactly 2 Image, 5 Int
check MembershipDeterminesTotal for exactly 3 Event, exactly 3 Slot, exactly 2 Image, 5 Int
check MembershipDeterminesFirstQuantity for exactly 3 Event, exactly 3 Slot, exactly 2 Image, 5 Int
