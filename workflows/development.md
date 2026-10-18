# Agent-assisted development lifecycle (ADLC)

Stages are thinking checkpoints, not mandatory artifacts or separate agents.

1. **Understand:** identify the request, repository, local constraints, authorization, and acceptance criteria. Investigation-only tasks end with findings.
2. **Assess:** classify risk using [scope and testing](../policy/scope-and-testing.md). Decide whether tests need implementation separately from which checks to run. For tiny tasks this can be an internal assessment; do not produce a ceremony-heavy plan.
3. **Agree when needed:** ask only for missing decisions or material scope/risk expansion. Larger designs and migrations need approval before implementation. Record exclusions where useful.
4. **Implement:** make scoped changes, preserve unrelated work, and use relevant skills only. Escalate discovered blockers rather than silently adding infrastructure.
5. **Verify:** run proportional checks and inspect the diff against acceptance criteria. Identify evidence type and gaps. Do not confuse successful publication with deployment.
6. **Review and deliver:** self-review for correctness, secrets, and scope; publish through the authorized branch/PR path; read back remote state. Do not merge or deploy without permission. Keep the report concise.
7. **Learn selectively:** propose reusable policy improvements when useful. Changes to shared rules require review, not an agent's automatic “memory” rewrite.

## Risk gates

- A low-risk edit needs no standalone plan, new tests, multi-agent review, or new infrastructure by default.
- A bounded behavior change needs focused acceptance and evidence, normally using existing tooling.
- High-risk work needs an agreed verification/rollback approach. A short diff does not waive this gate.

## Proposed evidence note

For nontrivial work, record: requested scope; risk; changed files; checks actually run and results; checks not run and why; remaining risks. For a tiny task, a concise final message is sufficient.
