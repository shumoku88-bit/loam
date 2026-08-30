module model/observation_047_selection_policy_overlay

sig Node {}

abstract sig World {
  known: set Node,
  parent: Node -> Node,
  better: Node -> Node
}

one sig Left, Right extends World {}

fact WellFormed {
  all w: World | {
    w.parent in w.known -> w.known
    no iden & ^(w.parent)

    w.better in w.known -> w.known
    no iden & w.better
    w.better.w.better in w.better
    all disj a, b: w.known |
      a->b in w.better or b->a in w.better
  }
}

fun frontier[w: World]: set Node {
  { n: w.known |
      no child: w.known | child->n in w.parent }
}

fun covering[w: World, node: Node]: set Node {
  { tip: frontier[w] |
      tip = node or node in tip.^(w.parent) }
}

fun selected[w: World, node: Node]: set Node {
  { tip: covering[w, node] |
      no other: covering[w, node] | other->tip in w.better }
}

pred sameGraph[a, b: World] {
  a.known = b.known
  a.parent = b.parent
}

pred samePolicy[a, b: World] {
  a.better = b.better
}

pred forkGraph[w: World] {
  #w.known = 3
  some root: w.known | {
    #covering[w, root] = 2
    root not in covering[w, root]
  }
}

pred selectionPolicyCanChangeOnlySelection {
  sameGraph[Left, Right]
  forkGraph[Left]
  Left.better != Right.better

  all n: Left.known |
    covering[Left, n] = covering[Right, n]

  some n: Left.known |
    selected[Left, n] != selected[Right, n]
}

pred oppositePoliciesCanChooseDifferentForkTips {
  sameGraph[Left, Right]
  forkGraph[Left]

  some root: Left.known |
    #covering[Left, root] = 2 and
    one selected[Left, root] and
    one selected[Right, root] and
    selected[Left, root] != selected[Right, root]
}

assert GraphDeterminesCoverage {
  sameGraph[Left, Right] implies
    all n: Left.known |
      covering[Left, n] = covering[Right, n]
}

assert GraphDeterminesSelection {
  sameGraph[Left, Right] implies
    all n: Left.known |
      selected[Left, n] = selected[Right, n]
}

assert GraphPlusPolicyDeterminesSelection {
  (sameGraph[Left, Right] and samePolicy[Left, Right]) implies
    all n: Left.known |
      selected[Left, n] = selected[Right, n]
}

run selectionPolicyCanChangeOnlySelection for exactly 3 Node, exactly 2 World
run oppositePoliciesCanChooseDifferentForkTips for exactly 3 Node, exactly 2 World
check GraphDeterminesCoverage for exactly 3 Node, exactly 2 World
check GraphDeterminesSelection for exactly 3 Node, exactly 2 World
check GraphPlusPolicyDeterminesSelection for exactly 3 Node, exactly 2 World
