/* Observation 182 counterexample: Event-first discharge writer.

   Truth: the new later Movement Event discharges 4 from an outstanding relation
   of 10. The writer exposes Event authority before the required discharge row.
   An Event-first reader can then observe the authoritative Event while still
   seeing old discharge absence and incorrectly report outstanding 10 instead of
   the true post-Event outstanding 6.
*/

bool disk_event = false;
bool disk_discharge = false;
bool qualification_done = false;

proctype Writer()
{
    qualification_done = true;
    disk_event = true;
    disk_discharge = true
}

proctype Reader()
{
    bool seen_event;
    bool seen_discharge;
    byte observed_outstanding;

    seen_event = disk_event;
    seen_discharge = disk_discharge;

    observed_outstanding = 10;
    if
    :: seen_event ->
        if
        :: seen_discharge -> observed_outstanding = 6
        :: !seen_discharge -> observed_outstanding = 10
        fi;
        assert(observed_outstanding == 6)
    :: !seen_event -> skip
    fi
}

init
{
    atomic {
        run Writer();
        run Reader()
    }
}
