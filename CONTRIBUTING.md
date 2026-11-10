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

## Who the review rule actually binds

Branch protection is set with `enforce_admins: false`, which means **repo admins bypass the review
requirement entirely** — an admin merge goes through unreviewed without even passing a flag. The
requirement is real for everyone else.

GitHub offers no middle setting on this plan: either admins are exempt, or they are bound and
cannot override at all. We chose exempt, so the owner can ship without waiting.

If you are an admin, that makes the review rule a convention you are keeping rather than one being
enforced on you. Get a second pair of eyes on anything that touches sharing, tokens or the server
side, even though nothing will stop you.

```bash
gh pr merge <n> --squash --admin    # explicit override; harmless but redundant for admins
```

## Before you open one

- `bash -n bin/tnshare server/tnshare-host install.sh` — the shell is most of this project.
- `app/build-app.sh` builds cleanly.
- If you touched sharing, actually share a file and download it. The failure modes here are quiet
  ones: a link that 404s, a revoke that leaves the route published, an exit code of 0 on refusal.
