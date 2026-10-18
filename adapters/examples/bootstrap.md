# Candidate team-policy bootstrap

Do not copy into active instructions until an approved revision is installed.

The future installer will materialize this only for an explicitly approved revision. Candidate instruction body (keep this block thin; load further docs on branch):

> This project is enrolled in Team-Sneakymouse development policy. Before implementing, or when authorization or risk is unclear, read `.team-policy/manifest.json` and `.team-policy/policy/core.md` from this project root. Read `.team-policy/policy/scope-and-testing.md` when classifying risk or changing behavior. Read `.team-policy/workflows/development.md` for nontrivial multi-step work. Read `.team-policy/policy/sneakyutils.md` when adding or sharing Paper util/manager code. Report a missing payload or a manifest/payload revision mismatch rather than substituting remembered rules. Load optional skills only when relevant. Follow local build/architecture facts and explicit exceptions. When host instructions and team policy repeat the same norm, follow the host wording. If they require incompatible actions, surface the conflict before expanding work. Distinguish running checks from implementing tests; a source edit does not automatically require a new test.

The project root and installed revision must be resolved by the approved adapter; do not assume paths are relative to an arbitrary shell working directory. A future installer must generate an explicit resolved root/reference where needed.
