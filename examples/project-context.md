# Candidate per-project context

Example only; not an active `AGENTS.md`.

A project's native context file should retain local facts alongside an installer-managed bootstrap:

```text
Project: <plugin name and repository>
Shared policy: <approved immutable revision; installer-managed bootstrap>
Build/test commands: <read from actual project tooling>
Runtime targets: <Paper/Minecraft/Java versions from this repo>
Architecture: <thread ownership, persistence, integration constraints>
Local exceptions: <specific rule, rationale, approver, scope>
Deployment behavior: <which pushes/workflows publish or deploy>
```

Do not hard-code this template's Java/Paper versions as a team-wide requirement. Do not copy “every src/main change requires a new test” into each project. An explicit project requirement may be stricter for a reason; surface conflicts rather than silently erasing it.
