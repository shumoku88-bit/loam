/* Observation 118 candidate protocol.

   The UI renders terminal actions from one admitted snapshot. Before activation,
   another writer may publish a competing terminal claim. The UI handler must not
   trust the old rendered affordance. It re-reads / re-admits under the terminal
   ownership boundary at activation time.

   This bounded model should have errors: 0.
*/

bool completion_claim = false;
bool retirement = false;
bool rendered_complete = false;
bool rendered_cancel = false;
byte phase = 0;

#define TERMINAL_SAFE (!(completion_claim && retirement))

proctype UI()
{
  atomic {
    /* Fresh world at render time exposes both actions. */
    rendered_complete = !retirement;
    rendered_cancel = (!retirement && !completion_claim);
    phase = 1
  };

  /* A competing writer is allowed to change the world before activation. */
  (phase == 2);

  if
  :: rendered_cancel ->
      atomic {
        /* Activation-time re-admission. */
        if
        :: (!retirement && !completion_claim) -> retirement = true
        :: (retirement || completion_claim) -> skip
        fi;
        assert(TERMINAL_SAFE)
      }
  :: rendered_complete ->
      atomic {
        /* Completion may start fresh or resume an existing claim, but never
           competes with retained retirement evidence. */
        if
        :: !retirement -> completion_claim = true
        :: retirement -> skip
        fi;
        assert(TERMINAL_SAFE)
      }
  fi
}

proctype ConcurrentWriter()
{
  (phase == 1);

  if
  :: atomic {
       /* A completion writer publishes its terminal claim. */
       (!retirement && !completion_claim);
       completion_claim = true;
       assert(TERMINAL_SAFE);
       phase = 2
     }
  :: atomic {
       /* Or a cancellation writer publishes retirement. */
       (!retirement && !completion_claim);
       retirement = true;
       assert(TERMINAL_SAFE);
       phase = 2
     }
  fi
}

init
{
  atomic {
    run UI();
    run ConcurrentWriter()
  }
}
