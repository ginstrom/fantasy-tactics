# 04 — Migrate Existing Tabular Screens

## Milestone

Parties, Party Details, Add Member, and Deploy Party use `TableView` while preserving their current selection, action, empty-state, and deployment behavior.

## Files

- Modify: `scenes/ui/parties.tscn`, `scripts/ui/parties.gd`, `tests/unit/test_parties.gd`
- Modify: `scenes/ui/party_details.tscn`, `scripts/ui/party_details.gd`, `tests/unit/test_party_details.gd`
- Modify: `scenes/ui/add_member.tscn`, `scripts/ui/add_member.gd`, `tests/unit/test_add_member.gd`
- Modify: `scenes/ui/deploy_party.tscn`, `scripts/ui/deploy_party.gd`, `tests/unit/test_deploy_party.gd`

## Steps

1. **Red:** replace each VBox/Button-list assertion with a `TableView` assertion and test column contracts: Parties = Party/Members/Status; Party Details and Add Member = Name/Class/Level; Deploy = Party/Members/Status. Retain tests for empty state, panel selection/View, stale selection refresh, deployed Add Member hiding, and Deploy's immediate eligible-row deployment.
2. Run:

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_parties,test_party_details,test_add_member,test_deploy_party -gexit
   ```

   Expected: existing button-list implementation fails the new contracts.
3. **Green:** replace each list container in its `.tscn` with a named `TableView`; retain EmptyLabel/Back/InformationPanel. Configure `TableColumn` instances in each controller and pass row dictionaries using durable party/adventurer IDs.
4. **Green:** map `row_selected` to the existing local selection + InformationPanel refresh and map activation/panel View to existing routes. Keep Add Member's existing immediate assignment behavior on activation; keep Deploy Party's immediate deploy on activation and its stale in-place refresh. Do not make table sorting alter session arrays.
5. Re-run the focused command; then run `make check`. Commit:

   ```bash
   git add scenes/ui/parties.tscn scripts/ui/parties.gd tests/unit/test_parties.gd scenes/ui/party_details.tscn scripts/ui/party_details.gd tests/unit/test_party_details.gd scenes/ui/add_member.tscn scripts/ui/add_member.gd tests/unit/test_add_member.gd scenes/ui/deploy_party.tscn scripts/ui/deploy_party.gd tests/unit/test_deploy_party.gd
   git commit -m "feat: render encampment lists with TableView"
   ```
