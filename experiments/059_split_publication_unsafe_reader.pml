/* Observation 059 counterexample B.

   Writer uses relation -> Event publication, but Reader acquires relation before
   Event. SPIN should find an interleaving where Reader first sees the old
   Correction stream, Writer then completes both publications, and Reader finally
   sees the new replacement Event. The local mixed snapshot is therefore
   replacement-visible / Correction-old and is unsafe for the effective view.
*/

bool disk_event_new = false;
bool disk_correction_new = false;

proctype Writer()
{
    disk_correction_new = true;
    disk_event_new = true;
}

proctype Reader()
{
    bool seen_event;
    bool seen_correction;

    seen_correction = disk_correction_new;
    seen_event = disk_event_new;

    assert(!(seen_event && !seen_correction));
}

init
{
    atomic {
        run Writer();
        run Reader();
    }
}
