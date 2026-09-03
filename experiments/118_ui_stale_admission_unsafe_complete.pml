/* Observation 118 counterexample B.

   The UI renders Complete while the Scheduled occurrence is fresh. Before the
   user activates it, another writer publishes retirement. The unsafe handler
   trusts the old rendered affordance and publishes a completion claim without
   re-admitting.

   SPIN should find completion_claim && retirement.
*/

bool completion_claim = false;
bool retirement = false;
bool rendered_complete = false;
byte phase = 0;

#define TERMINAL_SAFE (!(completion_claim && retirement))

proctype UI()
{
  atomic {
    rendered_complete = !retirement;
    phase = 1
  };

  (phase == 2);

  if
  :: rendered_complete ->
      completion_claim = true;
      assert(TERMINAL_SAFE)
  fi
}

proctype ConcurrentCancellation()
{
  (phase == 1);
  atomic {
    if
    :: (!retirement && !completion_claim) -> retirement = true
    :: else -> skip
    fi;
    assert(TERMINAL_SAFE);
    phase = 2
  }
}

init
{
  atomic {
    run UI();
    run ConcurrentCancellation()
  }
}
