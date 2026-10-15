# Version Control Guide

Load before changing history, describing changes, managing bookmarks, or pushing.

Hearvia uses Jujutsu (jj) colocated with git. Do not use `git commit`, `git add`, `git push`, `git stash` or `git worktree`. Diff and merge tools are set to JayJay in the repo config (`jayjay config`).

## Snapshots and concurrency

- `jj st`, `jj log`, `jj diff`, `jj describe`, `jj new` snapshot the working copy. Never run two jj commands at once in one workspace; that creates divergent `@` commits.
- A running JayJay window watching the repo also snapshots on file changes. Quit it before history rewrites or divergence cleanup.
- Reads that must not snapshot: `jj --ignore-working-copy log`, `... op log`, `... workspace list`.
- If divergence appears, compare the divergent commits by content and abandon only the proven-stale one.

## Workspaces

Use the default workspace only; don't add sibling workspaces. Give each task its own change with `jj new`.

## Describing and publishing

- End a task with `jj describe -m "<area>: <what changed>"` on the task's change. Subject lines name the area (`HearviaKit:`, `iOS:`, `macOS:`, `docs:`).
- Publishing needs an explicit request: `jj bookmark set main -r <rev>` then `jj git push --bookmark main`. Remote: `origin` → github.com/hewigovens/hearvia.
- No AI attribution in descriptions.
