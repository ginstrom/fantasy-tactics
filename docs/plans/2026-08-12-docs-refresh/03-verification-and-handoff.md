# Step 3 - Verification and handoff

## Milestone

The refresh has evidence that its documentation is internally consistent and
current for this checkout.

## Steps

1. Review `git diff` for unrelated changes and confirm every changed factual
   statement has code/test evidence.
2. Run the editor cache scan, full test suite, and whitespace check.
3. Ask the user to perform the manual `make play` check described in Steps 1
   and 2 before committing and merging locally.

## Verification

```bash
godot --headless --path . --editor --quit
make check
git diff --check
git status --short
```

## Handoff

Report changed files, commands and outcomes, and any remaining design-only
work. Do not push or open a pull request.
