# Candidate team-policy bootstrap

**UNAPPROVED DRAFT — do not copy into active instructions yet.**

The future installer will remove the draft wrapper only for an explicitly approved revision. Candidate instruction body:

> This project is enrolled in Team-Sneakymouse development policy. Before acting, read `.team-policy/manifest.json`, `.team-policy/policy/core.md`, `.team-policy/policy/scope-and-testing.md`, and `.team-policy/workflows/development.md` from this project root. Report a missing or inconsistent payload rather than silently substituting remembered rules. Load optional procedures only when relevant. Follow local build/architecture facts and explicit exceptions. If mandatory instructions conflict with task scope, surface the conflict before expanding work. Distinguish running checks from implementing tests; a source edit does not automatically require a new test.

The project root and installed revision must be resolved by the approved adapter; do not assume paths are relative to an arbitrary shell working directory. A future installer must generate an explicit resolved root/reference where needed.
