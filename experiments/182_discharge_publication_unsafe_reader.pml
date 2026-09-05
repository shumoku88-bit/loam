/* Observation 182 counterexample: discharge-first reader.

   The writer uses the candidate safe order: discharge first, Event last. But a
   reader that snapshots the discharge stream before the writer and then reads
   Event afterward can retain old discharge absence while seeing the new Event.
   It therefore overstates outstanding as 10 instead of 6.
*/

bool disk_event = false;
bool disk_discharge = false;
bool qualification_done = false;

proctype Writer()
{
    disk_discharge = true;
    qualification_done = true;
    disk_event = true
}

proctype Reader()
{
    bool seen_event;
    bool seen_discharge;
    byte observed_outstanding;

    seen_discharge = disk_discharge;
    seen_event = disk_event;

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
