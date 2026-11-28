# Pull requests

How to write the PR body. When to open a PR and what needs authorization is in [core policy](./core.md).

From the body alone, a reviewer should learn what changed, how it is known to work, and what merging can break. Skip preambles, keep prose brief, use the project's own terms, and do not list the changed files: the Files tab already shows them.

## Template

```markdown
## Summary

<one or two sentences: what was asked and what this changes>

<diagram, diff sketch, or tree>

## Evidence

- **Before:** <screenshot, output, or failing test>
  **After:** <screenshot, output, or passing test>
- **Checked:** <check> (<evidence type>): <result>
- **Not checked:** <check>: <why>

## Merge danger

- **Risk tier:** <mechanical, ordinary, or high>
- **Door:** <one-way or two-way>
- **Blast radius:** <what can break, and for whom>

<remaining risks, what merging triggers, how to roll back>
```

## Size it to the risk

Take the tier from [scope and testing](./scope-and-testing.md).

- **Mechanical:** the summary sentence, the checks you ran, and the three Merge danger lines. No visual and no before/after.
- **Ordinary:** the full template.
- **High:** the full template, and Merge danger states the agreed verification and rollback approach.

## Summary

Start with the requested scope. If the change went beyond the ask, say what was added and why.

Then show the change in the smallest view that makes the key point clear:

| What changed | View |
|--------------|------|
| Logic or state handling | Pseudocode |
| Runtime control flow | Call tree |
| File layout or a broad refactor | Shallow file tree |
| Interaction between plugins, services, or threads | Mermaid sequence diagram |
| A block that is mostly new | The whole block |

Use a `diff` of that view when the surrounding shape already exists and the point is what changes. Keep only the calls, files, and boundaries the reviewer needs. One view is usual.

If the branch carries a [next-change](./next-change.md) migration or a [stub sync](./stub-check.md), name its commit. If you skipped an entry, say which one and why.

## Evidence

Show the same check before and after the change. Prefer, in this order:

1. A screenshot or recording, when the change is visible in game: an item look, a GUI, a display entity, chat output.
2. Execution: the test that failed and now passes, command output, a log line.
3. Source inspection, when nothing can be run. Say that this is all there is.

Label every check with its evidence type: source inspection, compilation, unit test, mock, integration check, or live server. Green mocks are not live-server verification, and a merged PR is not a deployment.

List the checks you did not run and why. Report actual results only, and redact credentials from any pasted output.

## Merge danger

- **Risk tier:** the tier you classified the change as.
- **Door:** two-way when reverting the merge restores the previous state. One-way when something outlives a revert: migrated or deleted persistent data, a published artifact version that other plugins resolve, a changed id that saved items or configs reference.
- **Blast radius:** who is affected if the change is wrong: this plugin only, plugins that call its API, players on the live server, saved world or player data, the resource pack, CI or publishing.

Below the three lines, state the remaining risks and anything the merge triggers, such as a publish or a deployment.

## Example

````markdown
## Summary

Asked: stop the bank GUI from paying interest again each time a player reopens it.

```diff
 onOpen(player)
-  payInterest(player)
+  if lastPaid(player) < currentPeriod
+    payInterest(player)
+    lastPaid(player) = currentPeriod
```

## Evidence

- **Before:** `InterestTest.reopenDoesNotPayTwice` fails: balance 110, expected 105.
  **After:** the same test passes.
- **Checked:** `./gradlew build` (compilation, unit test): passed, 42 tests.
- **Not checked:** live server: no test server was available for this task.

## Merge danger

- **Risk tier:** ordinary
- **Door:** two-way
- **Blast radius:** player balances in this plugin

Interest already paid twice before this merge is not corrected.
````
