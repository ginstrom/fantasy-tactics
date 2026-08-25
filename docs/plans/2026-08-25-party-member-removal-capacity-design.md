# Party Details Member Removal and Capacity Design

Party Details will show the selected party's current occupancy and its live
maximum near the party name (for example, `2/3`). The maximum remains owned
by `GameSession`; this screen only renders it.

For an encamped party, a `Remove from Party` button will operate on the
currently selected member. It will call a party-scoped durable removal API,
refresh the table and selection, and leave the adventurer in the roster as an
unassigned, available member. The API will reject unknown, deployed, and
non-member targets; the existing selected-party helper becomes a thin wrapper.
The button will be disabled until a current party member is selected. Deployed
parties will not show this control, as their composition cannot be changed in
the field; this mirrors Add Member and Recruit.

Tests will instantiate the real Party Details scene and prove the visible
capacity, selected-member removal, stale/no-selection safety, and deployed
visibility rules.
