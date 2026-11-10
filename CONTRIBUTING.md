# Contributing

`main` is protected. Work goes through a pull request.

```bash
git checkout -b fix/thing
# ...
git push -u origin fix/thing
gh pr create
```

## Rules on main

- **One approving review** before merge. GitHub will not let you approve your own PR, so someone
  else on the repo has to look at it.
- **Squash merges only.** Merge commits and rebase merges are disabled, and the branch is deleted
  automatically after merge.
- **Linear history.** No force pushes, no branch deletion.

## Overriding

Admins can bypass the review requirement when something has to ship:

```bash
gh pr merge <n> --squash --admin
```

That is an override, not the normal path — it merges unreviewed code. Use it when the alternative
is worse, and say so in the PR.

## Before you open one

- `bash -n bin/tnshare server/tnshare-host install.sh` — the shell is most of this project.
- `app/build-app.sh` builds cleanly.
- If you touched sharing, actually share a file and download it. The failure modes here are quiet
  ones: a link that 404s, a revoke that leaves the route published, an exit code of 0 on refusal.
