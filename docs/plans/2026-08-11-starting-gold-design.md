# Starting Gold Design

New campaigns begin with 200 gold to make building testing possible. The
value is named by a `GameSession` constant and assigned only by
`start_new_game()` after it resets durable state. `reset()` continues to
produce a zero-gold baseline for tests and low-level session setup.

Difficulty levels and other starting resources are deliberately out of scope.
When they are designed, their policy can replace the single assignment in
`start_new_game()` without changing reset semantics.
