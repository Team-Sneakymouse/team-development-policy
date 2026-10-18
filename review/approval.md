# Approval and rollout checklist

A PR merge of this repository is not installation authorization. Work the **pilot** list before any live install; complete **general enrollment** before broad rollout.

## Pilot (EmptyPlugin + one existing plugin)

Minimum before installing into the selected pilot projects/profiles:

- [ ] Team approves core policy, risk tiers, scope exceptions, and conflict handling for pilot use.
- [ ] Identify policy maintainers/reviewers and how approval of immutable revisions is recorded.
- [ ] Approve one immutable revision for pilot install (evaluation mode if still unapproved for general use).
- [ ] Confirm agent product/version and OS for each pilot developer.
- [ ] Validate the chosen pilot adapter(s) in a fresh isolated session (tiny-edit + high-risk scenarios).
- [ ] Obtain separate installation consent for each pilot developer/project/profile.
- [ ] Install only into the named pilots; leave all other repos and profiles untouched.
- [ ] Record outcomes and open questions before expanding.

Potential pilot targets: EmptyPlugin plus one existing plugin, after the checks above. This repository does not change either by itself.

## General enrollment

After a successful pilot, before wider install/update:

- [ ] Select licensing before importing skills or external redistribution.
- [ ] Confirm supported agent versions and developer operating systems for claimed targets.
- [ ] Verify Claude Code and Antigravity native mechanisms if those targets will be claimed; keep them design-scope until validated.
- [ ] Confirm sibling-checkout pointer as the default distribution (optional committed snapshot only for non-multi-repo machines).
- [ ] Approve installer design and separate implementation scope.
- [ ] Curate optional team skills; reconcile strict TDD defaults and other conflicting mandatory procedures before adoption.
- [ ] Approve isolated behavioral evaluations and record outcomes for every claimed supported adapter.
- [ ] Replace conflicting per-repo rules deliberately; do not silently propagate policy.
- [ ] Approve an immutable release and only then permit general installation/update.
