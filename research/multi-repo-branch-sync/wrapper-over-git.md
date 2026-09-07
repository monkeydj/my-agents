# Agent 2: Wrapper design over git + gh/glab

**Status:** IN PROGRESS
**Last updated:** 2026-09-07

---

## CRITICAL INSTRUCTIONS FOR AGENT

> **YOU WILL BE STOPPED AND RELAUNCHED IF YOU VIOLATE THIS PROTOCOL.**
>
> The ONLY acceptable pattern is: **Search -> Edit -> Search -> Edit -> Search -> Edit.**
> NEVER: Search -> Search. NO EXCEPTIONS. NOT EVEN ONCE.
>
> After EVERY search or fetch, IMMEDIATELY Edit this file with what you learned.
> If you do two searches in a row without an Edit to this file, you are VIOLATING THE PROTOCOL and will be killed.
>
> Work through sections in order. For each section:
> 1. Search/fetch for information
> 2. IMMEDIATELY write findings to this file under that section
> 3. Search/fetch for more information on the same section
> 4. IMMEDIATELY update this file with additional findings
> 5. Move to next section only after writing current section
>
> If a web fetch returns a 403 error, WRITE WHAT YOU HAVE before trying another URL.
>
> Every number needs a source. Every source needs a clickable URL inline.
> Do NOT collect sources at the end -- put them inline with the facts.
>
> When you are DONE with all sections, change "Status: IN PROGRESS" to "Status: COMPLETE" at the top.

---

## 1. Safe-refresh git primitives

The whole wrapper reduces to one idea: **fetch is the only network step, and every local ref update is a fast-forward or nothing.** Git already has the primitives for this; the script's job is to combine them so a failure in one repo cannot leave that repo half-updated.

### 1.1 `git fetch --prune` — the network step, always safe for the working tree

`git fetch` only writes to `refs/remotes/<remote>/*` (and `FETCH_HEAD`) by default. It never touches the working tree or the index, so it is always safe to run under a human's live checkout. Key options, quoted from [git-fetch(1)](https://git-scm.com/docs/git-fetch):

| Option | Doc wording | Why the wrapper wants it |
|---|---|---|
| `-p, --prune` | "Before fetching, remove any remote-tracking references that no longer exist on the remote." | Deleted `release/*` branches on the forge disappear locally, so the AI agent never reads a stale branch. |
| `-P, --prune-tags` | "remove any local tags that no longer exist on the remote if `--prune` is enabled ... it will remove any local references (local tags) that have been created." | Usually **omit**: it deletes human-created local tags. |
| `--all` | "Fetch all remotes, except for the ones that have the `remote.<name>.skipFetchAll` configuration variable set." | Only needed when repos have multiple remotes (e.g. `upstream` + fork). Otherwise fetch `origin` explicitly to keep behaviour predictable. |
| `--atomic` | "Use an atomic transaction to update local refs. Either all refs are updated, or on error, no refs are updated." | Makes the ref-update phase all-or-nothing per repo. Directly answers "never half-updated". |
| `--dry-run` | "Show what would be done, without making any changes." | Backs the wrapper's own `--dry-run` flag. Under `--dry-run` "the file [FETCH_HEAD] is never written." |
| `--no-write-fetch-head` | "tells Git not to write the file" | Cosmetic; avoids churn in `.git/FETCH_HEAD` when the wrapper runs every few minutes. |

Persistent equivalent of `--prune`: `git config fetch.prune true` ("fetch will automatically behave as if the `--prune` option was given" — [git-config(1) fetch.prune](https://git-scm.com/docs/git-config#Documentation/git-config.txt-fetchprune)). Set it per repo the first time the wrapper touches it, so a manual `git fetch` by the human behaves identically.

```zsh
# Minimal safe fetch: prunes deleted remote branches, all-or-nothing ref update
git -C "$repo" fetch --prune --atomic --no-write-fetch-head origin
```

### 1.2 Refspecs: `<src>:<dst>`, the `+` force prefix, and globbing

From [git-fetch(1) § <refspec>](https://git-scm.com/docs/git-fetch#_refspec_):

> "The format of a <refspec> parameter is an optional plus `+`, followed by the source <src>, followed by a colon `:`, followed by the destination <dst>. The colon can be omitted when <dst> is empty."

> "Whether that update is allowed without `--force` depends on the ref namespace it's being fetched to, the type of object being fetched, and whether the update is considered to be a fast-forward. Generally, the same rules apply for fetching as when pushing."

> "all of the rules described above about what's not allowed as an update can be overridden by adding an optional leading `+` to a refspec (or using the `--force` command line option)."

Consequence for the wrapper: **never write `+` in front of a refspec that targets `refs/heads/*`**. The `+` is exactly what turns a rejected non-fast-forward into a silent history rewrite. The default clone refspec `+refs/heads/*:refs/remotes/origin/*` *does* carry a `+`, which is correct: remote-tracking refs are supposed to mirror the remote even after a force-push there. The plus is only dangerous on local branch heads.

Globbing, same page:

> "A <refspec> may contain a `*` in its <src> to indicate a simple pattern match ... A pattern <refspec> must have one and only one `*` in both the <src> and <dst>. It will map refs to the destination by replacing the `*` with the contents matched from the source."

So `release*` branches can be tracked with a single pattern refspec. Note the restriction: exactly one `*`, and it must appear on both sides.

```zsh
# Fetch only main plus every release/* branch into remote-tracking refs (force is fine here)
git -C "$repo" fetch --prune origin \
  '+refs/heads/main:refs/remotes/origin/main' \
  '+refs/heads/release/*:refs/remotes/origin/release/*'

# Branch names like release-1.2 (no slash) also match a glob:
git -C "$repo" fetch --prune origin '+refs/heads/release*:refs/remotes/origin/release*'
```

Tag caveat (same page): "Since Git version 2.20, fetching to update `refs/tags/*` works the same way as when pushing. I.e. any updates will be rejected without `+` in the refspec (or `--force`)." A moved tag on the forge will therefore make the fetch report a rejection; with `--atomic` that rejection aborts *all* ref updates for that fetch. Decide up front whether the wrapper adds `--no-tags` (skip auto-following) or tolerates the failure.

### 1.3 Updating a NON-checked-out branch: `git fetch origin main:main`

The cleanest way to move a local branch that nobody has checked out is to fetch straight into it:

```zsh
git -C "$repo" fetch origin main:main
```

Three refusal modes to design around, all from [git-fetch(1)](https://git-scm.com/docs/git-fetch):

1. **Checked-out branch.** "By default `git fetch` refuses to update the head which corresponds to the current branch. This flag [`--update-head-ok`] disables the check. This is purely for the internal use for `git pull` to communicate with `git fetch`, and unless you are implementing your own Porcelain you are not supposed to use it." Result: `fetch origin main:main` while `main` is checked out fails with `! [rejected] main -> main (can't fetch into checked-out branch)`. This is the safety net that keeps the working tree consistent with `HEAD`; do **not** pass `--update-head-ok`. Fall through to `git merge --ff-only` (1.4) or a separate worktree (Section 3) instead.
2. **Non-fast-forward.** Without `+`, a local `main` that has diverged from `origin/main` is rejected (`! [rejected] main -> main (non-fast-forward)`). This is the desired behaviour for the wrapper: it means the human has local commits on `main`, and the script must skip and report, not force.
3. **Forced.** `git fetch origin +main:main` would overwrite the local branch. Never emit this from the wrapper.

Because rejection is signalled by a non-zero exit status and a `!` line in the output, the wrapper can treat "fetch into branch failed" as the single skip signal for both cases.

### 1.4 `git merge --ff-only` and `git pull --ff-only` — for the checked-out branch

When the branch to refresh *is* checked out, `fetch origin main:main` is refused (1.3), so the wrapper must move `HEAD` together with the index and working tree. `git merge --ff-only` is the primitive for that. From [git-merge(1)](https://git-scm.com/docs/git-merge):

> "With `--ff-only`, resolve the merge as a fast-forward when possible. When not possible, refuse to merge and exit with a non-zero status."

The FAST-FORWARD MERGE section explains what actually happens on success: "the `HEAD` (along with the index) is updated to point at the named commit, without creating an extra merge commit." No merge commit means the human's `main` never gains an unexpected commit authored by the sync job.

The PRE-MERGE CHECKS section is the part that matters for "never destroy the human's in-progress work":

> "`git pull` and `git merge` will stop without doing anything when local uncommitted changes overlap with files that `git pull`/`git merge` may need to update."

> "To avoid recording unrelated changes in the merge commit, `git pull` and `git merge` will also abort if there are any changes registered in the index relative to the `HEAD` commit."

And from the TRUE MERGE section: "It is possible to have modifications in the working tree as long as they do not overlap; the update will preserve them."

Consequences for the wrapper:

- A fast-forward with *non-overlapping* uncommitted worktree edits will succeed and keep those edits. That is safe but surprising to the human, whose diff base silently moved. Section 3 argues for skipping dirty repos anyway so the behaviour is predictable.
- Any *staged* change aborts the merge outright, and *overlapping* unstaged changes abort it too. Both surface as non-zero exit, so the wrapper needs no extra diffing to be safe, only to be informative.
- `--abort` is not a reliable undo when the tree was dirty: "If there were uncommitted worktree changes present when the merge started, `git merge --abort` will in some cases be unable to reconstruct these changes." A fast-forward never enters the conflict state, so this only bites if someone later swaps `--ff-only` for `--ff`. Keep `--ff-only`.

```zsh
# Refresh the checked-out branch, fast-forward or nothing
git -C "$repo" merge --ff-only --quiet "refs/remotes/origin/$branch"
```

Persistent belt-and-braces: `git config merge.ff only` — "When set to `only`, only such fast-forward merges are allowed (equivalent to giving the `--ff-only` option from the command line)" ([git-config(1) merge.ff](https://git-scm.com/docs/git-config#Documentation/git-config.txt-mergeff)). Setting it per repo protects the human's manual `git pull` as well; a missing `--ff-only` in a later script edit stays harmless.

`git pull --ff-only` is `fetch` + `merge --ff-only` in one command. The wrapper should prefer the two separate commands because (a) the fetch phase is shared across all branches of the repo while the merge is per-branch, and (b) separating them lets the script run `fetch` even when the checkout is dirty and decide about the merge afterwards.

What [git-pull(1)](https://git-scm.com/docs/git-pull) adds if you do use it:

- `--ff-only`: "Only update to the new history if there is no divergent local history. This is the default when no method for reconciling divergent histories is provided (via the `--rebase` flags)." Since Git 2.27 a bare `git pull` on divergent history refuses and prints a hint instead of merging; but a user with `pull.rebase=true` in `~/.gitconfig` silently rebases. The wrapper must therefore pass `--ff-only` explicitly (or `-c pull.ff=only`) and never trust the default.
- `--autostash`: "Automatically create a temporary stash entry before the operation begins, record it in the ref `MERGE_AUTOSTASH` and apply it after the operation ends. This means that you can run the operation on a dirty worktree. However, use with care: the final stash application after a successful merge might result in non-trivial conflicts." An unattended job cannot resolve those conflicts, so `--autostash` is disqualified for this use case (Section 3 discusses stash in more depth).
- DEFAULT BEHAVIOUR: which remote branch is merged depends on `branch.<name>.merge`; "If the refspec is a globbing one, nothing is merged." A repo whose current branch has no upstream configured makes `git pull` fail with "There is no tracking information for the current branch". The explicit `merge --ff-only refs/remotes/origin/<branch>` form has no such dependency, which is another reason to prefer it.

Neutralising user config in scripts: prefix every git call with `-c` overrides so a human's global settings cannot change the wrapper's semantics:

```zsh
git -c pull.rebase=false -c pull.ff=only -c merge.ff=only -c fetch.prune=true -C "$repo" pull --ff-only origin "$branch"
```

### 1.5 `git update-ref` / `git branch -f` — the plumbing alternative

Both commands move a branch pointer directly. Neither one checks fast-forwardness, so they are only safe when the script performs the ancestry check itself first.

**`git update-ref`** ([git-update-ref(1)](https://git-scm.com/docs/git-update-ref)):

> "Given three arguments, stores the <new-oid> in the <ref>, possibly dereferencing the symbolic refs, after verifying that the current value of the <ref> matches <old-oid>. E.g. `git update-ref refs/heads/master <new-oid> <old-oid>` updates the master branch head to <new-oid> only if its current value is <old-oid>."

That three-argument form is a compare-and-swap: if the human commits to `main` between the script's read and its write, the old value no longer matches and the update is refused. Combined with an explicit ancestry test, this gives a race-free fast-forward without going through `merge`:

```zsh
# Fast-forward local branch $b to origin/$b using plumbing only.
local old new
old=$(git -C "$repo" rev-parse --verify --quiet "refs/heads/$b") || return 1
new=$(git -C "$repo" rev-parse --verify --quiet "refs/remotes/origin/$b") || return 1
[[ "$old" == "$new" ]] && return 0                                   # already current
# --is-ancestor exits 0 iff $old is an ancestor of $new, i.e. the move is a fast-forward
git -C "$repo" merge-base --is-ancestor "$old" "$new" || return 2    # diverged: skip
git -C "$repo" update-ref -m "repo-sync: ff $b" "refs/heads/$b" "$new" "$old"
```

`git merge-base --is-ancestor <commit> <commit>` "Check[s] if the first <commit> is an ancestor of the second <commit>, and exit[s] with status 0 if true, or with status 1 if not" ([git-merge-base(1)](https://git-scm.com/docs/git-merge-base#Documentation/git-merge-base.txt---is-ancestor)). It is a pure graph query, so it is cheap and never touches the working tree.

Multi-branch atomicity comes from `--stdin` transactions: "With `--stdin`, update-ref reads instructions from standard input and performs all modifications together." and "If all <ref>s can be locked with matching <old-oid>s simultaneously, all modifications are performed. Otherwise, no modifications are performed." The documented caveat matters for the reading agents: "while each individual <ref> is updated or deleted atomically, a concurrent reader may still see a subset of the modifications." So ref-level atomicity is *not* a snapshot guarantee for readers; Section 5 covers the swap patterns that provide one.

```zsh
# All-or-nothing update of several non-checked-out branches (each line: update SP ref SP new SP old)
git -C "$repo" update-ref --stdin <<EOF
start
update refs/heads/main $new_main $old_main
update refs/heads/release/2.4 $new_r24 $old_r24
prepare
commit
EOF
```

Reflog: "If config parameter core.logAllRefUpdates is true and the ref is one under refs/heads/ ... then `git update-ref` will append a line to the log file" so every fast-forward the wrapper performs is recoverable via `git reflog show <branch>`. Pass `-m "repo-sync: ..."` so those entries are recognisable.

**`git branch -f <branch> <start-point>`** is the porcelain equivalent ("Reset <branchname> to <start-point>, even if <branchname> exists already. Without `-f`, `git branch` refuses to change an existing branch." — [git-branch(1)](https://git-scm.com/docs/git-branch#Documentation/git-branch.txt--f)). It refuses to move the currently checked-out branch, the same guard as `fetch`, but it has no compare-and-swap argument, so a race between the script and the human is possible. Prefer `update-ref` with the old value, or plain `fetch origin main:main`, which already implies the fast-forward check.

**Ranking of the three ways to move a non-checked-out branch:**

| Method | FF check built in | CAS against concurrent commit | Working-tree touch | Verdict |
|---|---|---|---|---|
| `git fetch origin b:b` | yes (rejects non-FF) | no, but the FF check makes a lost update impossible | none | simplest, use by default |
| `update-ref` + `merge-base --is-ancestor` | you write it | yes (`<old-oid>`) | none | use when several branches must move atomically |
| `git branch -f` | no | no | none | avoid in an unattended job |

Checked-out branch: none of these apply; use `merge --ff-only` (1.4) or the worktree strategy (Section 3).

### 1.6 `git maintenance` — built-in background prefetch, and why it is not enough

Git ships its own unattended fetcher. From [git-maintenance(1)](https://git-scm.com/docs/git-maintenance):

> "The `prefetch` task updates the object directory with the latest objects from all registered remotes. For each remote, a `git fetch` command is run. The configured refspec is modified to place all requested refs within `refs/prefetch/`."

> "Start running maintenance on the current repository. This performs the same config updates as the `register` subcommand, then updates the background scheduler to run `git maintenance run --scheduled` on an hourly basis."

> "Instead, `git maintenance start` interacts with the `launchctl` tool, which is the recommended way to schedule timed jobs in macOS."

Default cadence: "`prefetch`: hourly" ... "At midnight, that process also executes the 'daily' tasks. At midnight on the first day of the week, that process also executes the 'weekly' tasks." The scheduler flag is `--scheduler=auto|crontab|systemd-timer|launchctl|schtasks`.

What this buys the wrapper:

- **Objects arrive in the background.** After `git maintenance start` in each repo, the hourly prefetch means the wrapper's own `git fetch` usually has nothing left to download and completes in well under a second, which shrinks the window in which a repo is "being refreshed".
- **It deliberately does not move any branch.** Prefetch writes to `refs/prefetch/*`, not `refs/remotes/origin/*` or `refs/heads/*`. So it cannot replace the wrapper; `origin/main` and `main` still only move when the wrapper runs `fetch` + fast-forward. This is exactly the separation you want: git handles the bulk transfer on its schedule, the wrapper handles the atomic ref movement on yours.
- **Multi-repo registration is built in.** `register` records the path in the global `maintenance.repo` config (multi-valued), and the scheduled job iterates them with `git for-each-repo --config=maintenance.repo`. The wrapper can reuse the same list as its repo inventory (Section 4) so there is one source of truth.

```zsh
# One-time per repo: register for background prefetch/gc; installs a launchd agent on macOS
git -C "$repo" maintenance register
git maintenance start --scheduler=launchctl     # once per machine; idempotent

# Ad-hoc: pull objects now without touching any branch
git -C "$repo" maintenance run --task=prefetch

# Read the registered repo list back
git config --global --get-all maintenance.repo
```

Caveat: `gc` "can be expensive for large repositories, as it repacks all Git objects into a single pack-file", and `maintenance start` sets `maintenance.strategy=incremental` which schedules `gc` off but `incremental-repack` weekly. Fine for a workstation; just do not add `gc` to the wrapper's hot path.

### 1.7 `git worktree` — a second checkout that shares the object store

[git-worktree(1)](https://git-scm.com/docs/git-worktree): "A git repository can support multiple working trees, allowing you to check out more than one branch at a time ... The new worktree is linked to the current repository, sharing everything except per-worktree files such as `HEAD`, `index`, etc."

The rule that shapes the design: "By default, `add` refuses to create a new worktree when <commit-ish> is a branch name and is already checked out by another worktree". A branch can be checked out in at most one worktree at a time. Two consequences:

1. If the human has `main` checked out in the primary clone, the wrapper cannot also check `main` out in a sidecar worktree *by branch name*. It can, however, check out the same **commit** detached: "`--detach`: With `add`, detach `HEAD` in the new worktree." A detached worktree pointing at `origin/main` is exactly what a read-only AI consumer needs, and it never competes with the human's branch.
2. Conversely, if the wrapper owns a worktree with `release/2.4` checked out, the human's `git switch release/2.4` in the main clone is refused with "fatal: 'release/2.4' is already checked out at ...". Use detached worktrees on the agent side to avoid that friction.

Other primitives the wrapper uses:

- `git worktree add --detach --lock --reason "repo-sync reader" <path> origin/main` — `--lock` "is the equivalent of `git worktree lock` after `git worktree add`, but without a race condition", and a locked worktree cannot be pruned or moved by accident.
- `git worktree list --porcelain [-z]` — machine-readable: "The first attribute of a worktree is always `worktree`, an empty line indicates the end of the record", with `HEAD <oid>`, `branch <ref>` or `detached`, and `locked [reason]` lines. This is how the wrapper discovers which branches are checked out where (Section 3).
- `git worktree remove <path>` — "Only clean worktrees (no untracked files and no modification in tracked files) can be removed. Unclean worktrees or ones with submodules can be removed with `--force`. The main worktree cannot be removed." The refusal on unclean trees is a free safety check for the swap pattern in Section 5.
- `git worktree prune` — "Remove worktree information in `$GIT_DIR/worktrees` for worktrees whose working trees are missing." Run it after any `mv`/`rm -rf` of a sidecar directory.
- Metadata layout: "Each linked worktree has a private sub-directory in the repository's `$GIT_DIR/worktrees` directory ... Within a linked worktree, `$GIT_DIR` is set to point to this private directory ... and `$GIT_COMMON_DIR` is set to point back to the main worktree's `$GIT_DIR`." So `git rev-parse --git-common-dir` from any worktree yields the shared `.git`, which is where the wrapper should place its lock file (Section 5).

```zsh
# Fast-forward a detached reader worktree to the freshly fetched origin/main
git -C "$reader_wt" checkout --detach --quiet "refs/remotes/origin/main"
# or, equivalently and without touching any branch ref:
git -C "$reader_wt" reset --hard --quiet "refs/remotes/origin/main"   # safe ONLY because this worktree is script-owned
```

### 1.8 Putting the primitives together — per-repo refresh algorithm

```
fetch --prune --atomic origin (+ release/* refspec)      # network; never touches worktree
  └─ for each target branch b in {default, release*}:
       b not checked out anywhere → git fetch origin b:b     # refuses non-FF and checked-out
       b checked out, tree clean  → git merge --ff-only origin/b
       b checked out, tree dirty  → skip + report (Section 3)
```

Every arrow above is either a no-op on failure or an atomic ref move, so a crash between steps leaves the repo in a state git itself considers consistent. What it does *not* guarantee is that a reader sees all branches move together; that requires the lock/swap patterns of Section 5.

## 2. Default-branch detection

"Main or master" is not a fixed name; it is whatever the forge's `HEAD` points at, and it can change (GitHub and GitLab both let you rename the default branch). The wrapper needs a cheap local answer for every run and a network answer to refresh the local one occasionally.

### 2.1 Layered lookup: local symref first, network second

| Layer | Command | Network | Cost | Fails when |
|---|---|---|---|---|
| 1 | `git symbolic-ref -q refs/remotes/origin/HEAD` | no | microseconds | `origin/HEAD` was never set (e.g. repo was `git init` + `remote add`, not cloned) or is stale after a rename |
| 2 | `git remote set-head origin -a` then layer 1 | yes (one `ls-remote`) | one round-trip | remote unreachable |
| 3 | `git ls-remote --symref origin HEAD` | yes | one round-trip | remote unreachable |
| 4 | `gh repo view --json defaultBranchRef` / `glab repo view` | yes (REST/GraphQL) | one API call, counts against rate limit | not a GitHub/GitLab remote, or CLI not authenticated |

**Layer 1** — `refs/remotes/origin/HEAD` is a symbolic ref that clone creates. Per [git-remote(1) set-head](https://git-scm.com/docs/git-remote#Documentation/git-remote.txt-emset-headem): it is "the default branch (i.e. the target of the symbolic-ref `refs/remotes/<name>/HEAD`) for the named remote. Having a default branch for a remote is not required, but allows the name of the remote to be specified in lieu of a specific branch." Read it with `git symbolic-ref` ([git-symbolic-ref(1)](https://git-scm.com/docs/git-symbolic-ref)); `-q` suppresses the error when the ref is missing or not symbolic, and `--short` trims the `refs/remotes/` prefix.

```zsh
# → "origin/main" or nothing (exit 1) if unset
git -C "$repo" symbolic-ref -q --short refs/remotes/origin/HEAD
```

**Layer 2** — refresh the symref from the remote: "With `-a` or `--auto`, the remote is queried to determine its `HEAD`, then the symbolic-ref `refs/remotes/<name>/HEAD` is set to the same branch ... This will only work if `refs/remotes/origin/next` already exists; if not it must be fetched first." ([git-remote(1)](https://git-scm.com/docs/git-remote)). Ordering consequence: run `git fetch` *before* `set-head -a`, otherwise a freshly renamed default branch (`master` → `main`) fails with "error: Not a valid ref: refs/remotes/origin/main". Since Git 2.47 `git fetch` also updates `origin/HEAD` automatically when it was unset or matches, but do not rely on that on every workstation; an explicit `set-head -a` after fetch is cheap and idempotent.

```zsh
git -C "$repo" fetch --prune origin && git -C "$repo" remote set-head origin -a
```

**Layer 3** — ask without changing anything. [git-ls-remote(1) --symref](https://git-scm.com/docs/git-ls-remote#Documentation/git-ls-remote.txt---symref): "show the underlying ref pointed by it when showing a symbolic ref. Currently, upload-pack only shows the symref HEAD, so it will be the only one shown by ls-remote." Output format:

```
ref: refs/heads/main	HEAD
27d43aaaf50ef0ae014b88bba294f93658016a2e	HEAD
```

```zsh
# Pure query, works even on a bare clone or a repo with no origin/HEAD
git -C "$repo" ls-remote --symref origin HEAD | awk '/^ref:/ {sub("refs/heads/","",$2); print $2; exit}'
```

`--exit-code` makes it "Exit with status 2 when no matching refs are found", useful for distinguishing "empty repo" from "network down" (the latter exits 128).

**Layer 4** — forge CLIs. `gh repo view [<repository>] --json defaultBranchRef` (fields include `defaultBranchRef`, `name`, `nameWithOwner`, `isArchived`, `isFork`, `sshUrl`, `url`; "With no argument, the repository for the current directory is displayed." — [gh repo view manual](https://cli.github.com/manual/gh_repo_view)):

```zsh
gh repo view --json defaultBranchRef --jq .defaultBranchRef.name            # cwd repo
gh repo view OWNER/REPO --json defaultBranchRef,isArchived --jq '[.defaultBranchRef.name,.isArchived]|@tsv'
```

The forge answer also carries metadata git cannot know, such as `isArchived` (stop syncing archived repos) and `isFork`. Layer 4 is therefore a *discovery-time* tool (Section 6), not a per-run tool: it costs an API call per repo and needs credentials, while layers 1-3 work over the same SSH/HTTPS transport the fetch already uses.

`glab repo view` is covered in 2.3 after checking its JSON support.

### 2.2 `git remote show origin` — human-readable, do not parse

`git remote show <name>` prints a `HEAD branch: main` line, and `-n` means "the remote heads are not queried first with `git ls-remote <name>`; cached information is used instead." ([git-remote(1)](https://git-scm.com/docs/git-remote)). Its output is porcelain intended for humans and not stable across versions; when `origin/HEAD` is unset it prints `HEAD branch: (unknown)`. Use it for debugging, and use layers 1-3 in the script.

### 2.3 Enumerating `release*` branches with `git for-each-ref`

`git for-each-ref` is the scripting-grade command for listing refs; `git branch -r --list 'origin/release*'` gives the same list but with two-space indentation and a possible `origin/HEAD -> origin/main` line that must be filtered out. From [git-for-each-ref(1)](https://git-scm.com/docs/git-for-each-ref):

> "If one or more <pattern> parameters are given, only refs are shown that match against at least one pattern, either using `fnmatch`(3) or literally, in the latter case matching completely or from the beginning up to a slash."

So `refs/remotes/origin/release` (literal, matches `release/*` because the literal form matches "from the beginning up to a slash") and `refs/remotes/origin/release*` (fnmatch, also catches `release-1.2` and `releases`) are both valid, and they behave differently. Pick the glob form when the team's convention is inconsistent; pick the literal form when only `release/<version>` is wanted.

Fields that matter for the wrapper:

- `refname` / `refname:short` / `refname:lstrip=N`: "strip <n> slash-separated path components from the front (back) of the refname (e.g. `%(refname:lstrip=2)` turns `refs/tags/foo` into `foo`". `refs/remotes/origin/release/2.4` with `lstrip=3` gives `release/2.4`, the local branch name.
- `objectname`: the SHA, used for the compare-and-swap in 1.5.
- `upstream:track`: shows "[ahead N, behind M]" and `upstream:trackshort` gives `>`, `<`, `<>`, `=`. This is the one-shot way to see whether local `release/2.4` is fast-forwardable from its upstream: `<` (behind only) means FF is possible, `>` or `<>` means the human has local commits and the branch must be skipped.
- `HEAD`: "`*` if `HEAD` matches current ref (the checked out branch), ' ' otherwise."
- `worktreepath`: "The absolute path to the worktree in which the ref is checked out, if it is checked out in any linked worktree. Empty string otherwise." This answers "is this branch checked out anywhere" in one call, covering both the main worktree and linked worktrees, which is the decision point in the algorithm of 1.8.
- `symref`: "The ref which the given symbolic ref refers to." Lets you read `origin/HEAD` in the same pass as the branch list.

Sorting: `--sort=version:refname` (alias `v:refname`) orders `release/2.10` after `release/2.9`, and a leading `-` reverses so `--sort=-v:refname --count=1` yields the newest release.

```zsh
# Remote release branches → local branch names, newest first
git -C "$repo" for-each-ref --sort=-v:refname \
  --format='%(refname:lstrip=3)' 'refs/remotes/origin/release*'

# Local main + release branches with FF-ability and checkout location in one pass
git -C "$repo" for-each-ref \
  --format='%(refname:short)%09%(objectname)%09%(upstream:trackshort)%09%(HEAD)%09%(worktreepath)' \
  refs/heads/main refs/heads/master 'refs/heads/release*'
# main    3f2a...  <   *   /Users/me/src/app        ← behind upstream, checked out here: merge --ff-only
# release/2.4  9c1...  =           /Users/me/src/app-r24  ← in sync, checked out in a linked worktree
# release/2.3  77e...  <                             ← behind, not checked out: fetch origin release/2.3:release/2.3
```

For shell consumption the docs recommend the quoting flags: "If given, strings that substitute `%(fieldname)` placeholders are quoted as string literals suitable for the specified host language. This is meant to produce a scriptlet that can directly be 'eval'ed." Branch names cannot contain whitespace or control characters ([git-check-ref-format(1)](https://git-scm.com/docs/git-check-ref-format)), so a tab-separated format with `read -r` is enough without `--shell`; `worktreepath` *can* contain spaces on macOS (`/Users/me/My Repos/...`), which is why it is placed last in the format above so `read` swallows the remainder into one variable.

Which local `release*` branches should exist at all? Two policies:

1. **Mirror-only**: refresh `refs/remotes/origin/release*` (fetch does this for free) and let the reading agents consume `origin/release/*` refs directly via `git show origin/release/2.4:path` or a detached worktree. No local branch is created, so nothing can diverge. Simplest and recommended when the human does not need local `release/*` branches.
2. **Local-tracking**: for each remote release branch, create the local branch if missing (`git branch --track release/2.4 origin/release/2.4`) and fast-forward it thereafter. Needed only when tooling or the human expects `refs/heads/release/*` to exist.

### 2.4 `glab repo view` for the default branch

The rendered glab docs page for `glab repo view` could not be fetched (the GitLab web UI served only a JavaScript loading shell). What is known from the glab CLI's own `--help` and its docs at [gitlab.com/gitlab-org/cli](https://gitlab.com/gitlab-org/cli/-/tree/main/docs/source/repo): `glab repo view [repository] [flags]` accepts `OWNER/REPO`, a `group/subgroup/repo` path, a full URL, or no argument for the current directory, and prints the project description plus README by default; the `-b/--branch` and `-w/--web` flags exist. Whether a stable JSON output flag exists on the installed version should be verified locally with `glab repo view --help`; the reliable alternative for a default-branch query on GitLab is the REST API through `glab api`, which is covered in Section 6 and returns `default_branch` as a field:

```zsh
# Project path must be URL-encoded (slash → %2F)
glab api "projects/$(printf '%s' "$group/$project" | sed 's|/|%2F|g')" | jq -r .default_branch
```

For the sync wrapper this is a discovery-time concern only; per-run detection should stay on layers 1-3 of 2.1, which need no forge API at all.

## 3. Dirty-tree and in-progress-work policy

[To be filled by research agent]

## 4. Shell-function design

[To be filled by research agent]

## 5. Concurrency safety

[To be filled by research agent]

## 6. What gh / glab add beyond plain git

[To be filled by research agent]
