/* Observation 059: bounded split-stream publication protocol.

   Old semantic state:
     original Event is already visible
     replacement Event is not visible
     Correction is not visible

   New semantic state:
     replacement Event is visible
     Correction is visible and therefore admitted

   The target Event is assumed to be the already-visible original Event.
   `disk_event_new` therefore represents visibility of the new replacement Event,
   and `disk_correction_new` represents visibility of the raw Correction relation.

   Writer order: relation -> Event
   Reader order: Event -> relation

   A reader seeing the relation without the Event remains on the old effective
   view because fail-closed admission hides the dangling relation. The dangerous
   state is the opposite: replacement Event visible while Correction is not.
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

    seen_event = disk_event_new;
    seen_correction = disk_correction_new;

    /* With the original Event always present, a seen Correction is admitted
       exactly when the replacement Event is also seen. If the replacement is
       seen without the Correction, the correction-aware effective view can
       transiently contain both original and replacement. */
    assert(!(seen_event && !seen_correction));
}

init
{
    atomic {
        run Writer();
        run Reader();
    }
}
