/* Observation 059 counterexample A.

   Writer publishes the replacement Event before the raw Correction relation.
   Reader uses the otherwise-safe Event -> relation acquisition order.

   SPIN should find an interleaving where the reader sees the replacement Event
   but still sees the old Correction stream. In that mixed snapshot the new
   Correction cannot be admitted because it is absent, so the correction-aware
   effective view can transiently expose original + replacement.
*/

bool disk_event_new = false;
bool disk_correction_new = false;

proctype Writer()
{
    disk_event_new = true;
    disk_correction_new = true;
}

proctype Reader()
{
    bool seen_event;
    bool seen_correction;

    seen_event = disk_event_new;
    seen_correction = disk_correction_new;

    assert(!(seen_event && !seen_correction));
}

init
{
    atomic {
        run Writer();
        run Reader();
    }
}
