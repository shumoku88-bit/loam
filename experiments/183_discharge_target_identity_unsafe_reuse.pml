/* Observation 183: unsafe RelationUnit identity reuse.

   This model keeps the current practical allocator boundary: fresh RelationUnit
   identity excludes only already-existing RelationUnit ids. It does not reserve
   RelationUnit ids named only by retained raw RelationDischarge targets.

   A raw discharge whose later Event already exists but whose target relation is
   absent is initially inert. If an unrelated writer later allocates that target
   token, the old row can become semantically connected without any new discharge
   decision.

   Expected: assertion violation.
*/

byte existing_relation_id = 9;
byte orphan_discharge_target = 1;
byte allocated_relation_id = 0;
bool orphan_discharge_active = false;
bool writer_done = false;

proctype Writer()
{
    if
    :: (1 != existing_relation_id) -> allocated_relation_id = 1
    :: (1 == existing_relation_id) -> allocated_relation_id = 2
    fi;

    orphan_discharge_active =
        (allocated_relation_id == orphan_discharge_target);
    writer_done = true
}

proctype Reader()
{
    writer_done;
    assert(!orphan_discharge_active)
}

init
{
    run Writer();
    run Reader()
}
