/* Observation 118 counterexample A.

   The UI renders Cancel while the Scheduled occurrence is fresh. Before the user
   activates it, another writer publishes a completion claim. The unsafe handler
   trusts the old rendered affordance and publishes retirement without re-admitting.

   SPIN should find completion_claim && retirement.
*/

bool completion_claim = false;
bool retirement = false;
bool rendered_cancel = false;
byte phase = 0;

#define TERMINAL_SAFE (!(completion_claim && retirement))

proctype UI()
{
  atomic {
    rendered_cancel = (!retirement && !completion_claim);
    phase = 1
  };

  (phase == 2);

  if
  :: rendered_cancel ->
      retirement = true;
      assert(TERMINAL_SAFE)
  fi
}

proctype ConcurrentCompletion()
{
  (phase == 1);
  atomic {
    if
    :: (!retirement && !completion_claim) -> completion_claim = true
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
    run ConcurrentCompletion()
  }
}
