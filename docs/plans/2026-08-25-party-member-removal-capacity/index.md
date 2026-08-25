# Party Details Member Removal and Capacity Plan

This plan delivers an encampment-only selected-member removal action and a
live party-capacity label. It keeps durable membership mutation in
`GameSession`'s existing party service and keeps `party_details.gd` as a thin
UI controller.

Execute the steps serially on `feat/party-member-removal-capacity`. After the
automated checks pass, run `make play` and manually confirm the documented
flow before committing and merging locally to `main` after user signoff.

1. [UI behavior and coverage](01-ui-behavior-and-coverage.md)
