# Agent 2: Wrapper design over git + gh/glab

**Status:** COMPLETE
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

Verified against the glab source-tree docs on 2026-09-07 ([gitlab-org/cli, docs/source/repo/view.md](https://gitlab.com/gitlab-org/cli/-/raw/main/docs/source/repo/view.md)); the earlier fetch of the rendered page had returned only a JavaScript shell. `glab repo view [repository] [flags]` will "Display the description and README of a project, or open it in the browser." The repository argument accepts no argument (current directory, "must be a Git repository"), `user/repo`, `group/namespace/repo`, an SSH URL (`git@gitlab.com:user/repo.git`) or an HTTPS URL. Documented flags:

| Flag | Doc wording |
|---|---|
| `-b, --branch string` | "View a specific branch of the repository." |
| `-w, --web` | "Open a project in the browser." |
| `-F, --output string` | "Format output as: text, json. (default "text")" |
| `--jq string` | "Filter JSON output with a jq expression." |

So a JSON output flag **does** exist: `glab repo view group/project -F json` returns the project object, and `--jq .default_branch` (or an external `jq`) extracts the default branch without a hand-built REST call. The docs page does not list the JSON field names, so `default_branch` is inferred from the REST project object the command wraps; confirm once with `glab repo view -F json | jq keys` on the installed version. The `glab api` route below remains valid and is the fallback for older glab releases that predate `-F`:

```zsh
# Project path must be URL-encoded (slash → %2F)
glab api "projects/$(printf '%s' "$group/$project" | sed 's|/|%2F|g')" | jq -r .default_branch
```

For the sync wrapper this is a discovery-time concern only; per-run detection should stay on layers 1-3 of 2.1, which need no forge API at all.

## 3. Dirty-tree and in-progress-work policy

The invariant the wrapper must hold is "never destroy the human's in-progress work". Git's own guards (Section 1.4) already refuse most dangerous fast-forwards, but they refuse *late*, one branch at a time, with error text that differs by case. The wrapper needs its own up-front classification so it can (a) decide once per repo whether the checkout may be touched at all, and (b) report *why* a repo was skipped in a way the operator can act on.

### 3.1 Detecting a dirty tree: `git status --porcelain=v2`

`--porcelain=v2` is the only status format documented as stable for scripts, and it carries everything the wrapper needs in a single pass: current branch, ahead/behind counts, per-file staged/unstaged state, untracked files, and (with `--show-stash`) the stash depth. From [git-status(1)](https://git-scm.com/docs/git-status):

Header lines (each begins with `# `):

```
# branch.oid <commit> | (initial)
# branch.head <branch> | (detached)
# branch.upstream <upstream-branch>
# branch.ab +<ahead> -<behind>
# stash <N>                        ← only with --show-stash, only when N > 0
```

Entry lines, keyed by the first character:

| First char | Doc line format | Meaning for the wrapper |
|---|---|---|
| `1` | `1 <XY> <sub> <mH> <mI> <mW> <hH> <hI> <path>` | ordinary tracked change; `X` = staged (index vs HEAD), `Y` = unstaged (worktree vs index) |
| `2` | `2 <XY> <sub> <mH> <mI> <mW> <hH> <hI> <X><score> <path><sep><origPath>` | rename/copy; two paths, separated by tab (or NUL with `-z`) |
| `u` | `u <XY> <sub> <m1> <m2> <m3> <mW> <h1> <h2> <h3> <path>` | **unmerged** entry, i.e. a conflict is in progress. Any `u` line is an automatic skip. |
| `?` | `? <path>` | untracked file |
| `!` | `! <path>` | ignored file (only with `--ignored`) |

XY: "A 2 character field containing the staged and unstaged XY values described in the short format, with unchanged indicated by a `.` rather than a space." Values are `M` modified, `T` type changed, `A` added, `D` deleted, `R` renamed, `C` copied, `U` unmerged. So `1 .M` = unstaged edit only, `1 M.` = staged only, `1 MM` = both.

Flags to combine with it:

- `-z`: "Terminate entries with NUL, instead of LF ... no quoting or backslash-escaping is performed." Required if any repo can contain paths with newlines or non-ASCII characters that git would otherwise C-quote. With `-z` and `--porcelain=v2` the header lines are still present, and rename entries put `<path>` first, then NUL, then `<origPath>`.
- `--untracked-files=<mode>`: `no` (skip the untracked scan entirely — fastest), `normal` (show untracked files and directories, one entry per untracked directory), `all` (show every file inside untracked directories). For a "is it dirty?" boolean, `normal` is enough and cheaper than `all`.
- `--ignored=no` is the default; do **not** pass `--ignored`, because build output (`node_modules/`, `.venv/`) would otherwise flood the output and make an untouched repo look dirty.
- `--show-stash`: "Show the number of entries currently stashed away." Useful for the audit line in the summary so the operator sees repos where a previous stash-based run left entries behind (3.4).

Two operational warnings from the same page that matter for an unattended job:

1. **Status writes the index.** "By default, `git status` will automatically refresh the index, updating the cached stat information from the working tree and writing out the result." and "Scripts running `status` in the background should consider using `git --no-optional-locks status`" because "the lock held during the write may conflict with other simultaneous processes, causing them to fail." Without `--no-optional-locks`, the wrapper's status call can make the human's concurrent `git commit` fail with `index.lock` exists (Section 5.3). Always use it.
2. **Status can be slow on big trees.** The documented mitigations are `core.untrackedCache=true` ("only search directories that have been modified since the previous `git status` command") and `core.fsmonitor=true` on top of that, which "is faster than using just the untracked cache alone." Both are per-repo config the wrapper may set on first touch; neither changes semantics.

```zsh
# One call, machine-readable, does not take the index lock
git -C "$repo" --no-optional-locks status --porcelain=v2 -z --untracked-files=normal --show-stash
```

The classic shortcuts `git diff --quiet` (unstaged, exit 1 if any) and `git diff --cached --quiet` (staged, exit 1 if any) remain valid and are cheaper when the wrapper only wants a boolean and does not care about untracked files; but they do not see untracked files or unmerged state, and `git diff --quiet` also refreshes the index unless run with `--no-optional-locks`. The single porcelain-v2 call replaces both plus `git ls-files --others --exclude-standard` (the untracked check), and gives the ahead/behind headers for free.

### 3.2 Detecting in-progress operations under `.git`

`git status --porcelain=v2` does **not** print a header for "rebase in progress" or "merge in progress"; only the long human format says "You are currently rebasing". The stable way to detect these states is the same way git's own shell prompt does it: test for marker files in the git directory. The reference implementation is [`contrib/completion/git-prompt.sh`](https://github.com/git/git/blob/master/contrib/completion/git-prompt.sh) (`__git_ps1` and `__git_sequencer_status`), which maps markers to labels in this order:

| Test (`$g` = git dir) | Label | Operation |
|---|---|---|
| `-d "$g/rebase-merge"` | `REBASE` | interactive / merge-backend rebase (the default backend since Git 2.26). `rebase-merge/head-name` holds the branch being rebased, `rebase-merge/msgnum` and `rebase-merge/end` give step/total. |
| `-d "$g/rebase-apply"` and `-f "$g/rebase-apply/rebasing"` | `REBASE` | apply-backend rebase (`git rebase --apply`); `rebase-apply/next`/`last` give step/total |
| `-d "$g/rebase-apply"` and `-f "$g/rebase-apply/applying"` | `AM` | `git am` in progress |
| `-d "$g/rebase-apply"` with neither flag file | `AM/REBASE` | indeterminate; treat as in progress |
| `-f "$g/MERGE_HEAD"` | `MERGING` | `git merge` stopped on conflicts (or `--no-commit`) |
| `-f "$g/CHERRY_PICK_HEAD"` | `CHERRY-PICKING` | single cherry-pick stopped |
| `-f "$g/REVERT_HEAD"` | `REVERTING` | single revert stopped |
| `$g/sequencer/todo` starts with `p `/`pick ` | `CHERRY-PICKING` | multi-commit cherry-pick between steps |
| `$g/sequencer/todo` starts with `revert ` | `REVERTING` | multi-commit revert between steps |
| `-f "$g/BISECT_LOG"` | `BISECTING` | `git bisect` session open |

Verbatim from the prompt script, so the wrapper can copy the exact tests:

```sh
if [ -d "$g/rebase-merge" ]; then
	r="|REBASE"
else
	if [ -d "$g/rebase-apply" ]; then
		if [ -f "$g/rebase-apply/rebasing" ]; then r="|REBASE"
		elif [ -f "$g/rebase-apply/applying" ]; then r="|AM"
		else r="|AM/REBASE"; fi
	elif [ -f "$g/MERGE_HEAD" ]; then r="|MERGING"
	elif __git_sequencer_status; then :          # CHERRY_PICK_HEAD / REVERT_HEAD / sequencer/todo
	elif [ -f "$g/BISECT_LOG" ]; then r="|BISECTING"
	fi
fi
```

Three details that are easy to get wrong:

1. **Resolve `$g` with `git rev-parse --git-dir`, not `"$repo/.git"`.** The prompt script uses `git rev-parse --git-dir --is-inside-git-dir --is-bare-repository --is-inside-work-tree ...`. In a linked worktree (Section 1.7) `.git` is a *file* containing `gitdir: /path/to/main/.git/worktrees/<name>`, and the per-worktree markers (`MERGE_HEAD`, `rebase-merge/`, `BISECT_LOG`) live in that private directory, not in the common dir. Testing `"$repo/.git/MERGE_HEAD"` would miss a rebase happening in a linked worktree. Use `git -C "$repo" rev-parse --absolute-git-dir` (Git ≥ 2.13) and test under that path.
2. **Detached HEAD is a separate signal.** The prompt detects it by `git symbolic-ref HEAD` failing (`test -z "$head"`), and `--porcelain=v2` reports it as `# branch.head (detached)`. A detached primary checkout is not "dirty", but it means no branch is checked out, so *every* target branch can be moved with `git fetch origin b:b` (Section 1.3) and the working tree is left alone. The wrapper should treat detached as "all branches free", not as an error.
3. **Order matters only for labelling.** For the skip decision, any single true test is enough; the wrapper can short-circuit. For the summary line (Section 4), keeping the prompt script's order gives the same label a human would see in their shell prompt, which reduces confusion when they investigate.

```zsh
# Returns 0 and prints a label if an operation is in progress; returns 1 if the repo is quiescent.
repo_sync_inprogress() {
  local g; g=$(git -C "$1" rev-parse --absolute-git-dir 2>/dev/null) || return 1
  if   [[ -d $g/rebase-merge ]];                                    then print REBASE
  elif [[ -d $g/rebase-apply ]]; then
       if   [[ -f $g/rebase-apply/rebasing ]]; then print REBASE
       elif [[ -f $g/rebase-apply/applying ]]; then print AM
       else print AM/REBASE; fi
  elif [[ -f $g/MERGE_HEAD ]];                                       then print MERGING
  elif [[ -f $g/CHERRY_PICK_HEAD ]];                                 then print CHERRY-PICKING
  elif [[ -f $g/REVERT_HEAD ]];                                      then print REVERTING
  elif [[ -f $g/sequencer/todo ]];                                   then print SEQUENCER
  elif [[ -f $g/BISECT_LOG ]];                                       then print BISECTING
  else return 1; fi
}
```

Combined decision for one repo (before touching any branch):

```
in-progress marker present      → SKIP repo entirely (even fetch is fine, but no ref moves; a rebase's
                                   ORIG_HEAD/head-name may reference the branch you want to move)
porcelain v2 has any `u` line   → SKIP (conflict state without a marker should not happen, but be defensive)
porcelain v2 has `1`/`2` lines  → checkout is dirty → policy A/B/C below applies to the checked-out branch only;
                                   non-checked-out branches are still safe to `fetch b:b`
porcelain v2 has only `?` lines → untracked-only; see 3.3 for why this is still "dirty" by default
nothing but headers             → clean → merge --ff-only is safe
```

### 3.3 Policy option A: skip the checked-out branch, refresh everything else

The default policy, and the one that should stay the default unless the human explicitly opts into B.

Behaviour: run `fetch --prune` (always safe), fast-forward every branch that is **not** checked out with `git fetch origin b:b`, and for the checked-out branch: if the tree is clean, `merge --ff-only`; otherwise leave `HEAD` and the tree untouched and record `SKIPPED (dirty: 3 modified, 1 untracked)` in the summary.

Why untracked-only should still count as dirty by default: git's own pre-merge check only blocks a fast-forward when an untracked file *collides* with a file the merge would create ("error: The following untracked working tree files would be overwritten by merge"). A non-colliding untracked file lets the fast-forward through, and the human's diff base silently moves under their feet (Section 1.4). Correctness is preserved either way; predictability is not. Offer `--allow-untracked` as an opt-in flag that downgrades `?` lines to "clean" for humans who keep scratch files around.

Trade-offs:

| | |
|---|---|
| **+** | Zero risk to the human's work; no state (stash entries, temp branches) is created that could be orphaned by a crash. |
| **+** | The reading agents still get a fresh `origin/<branch>` ref in every repo, because fetch never skips. Agents that read via `git show origin/main:path` or a detached reader worktree (policy C) are unaffected by the skip. |
| **−** | Local `main` in a dirty repo lags until the human commits or stashes. If agents read the *working tree* (not refs), that repo's knowledge-base slice is stale. The summary table must make this visible (Section 4). |
| **−** | A repo that is permanently dirty (a forgotten local edit to a config file) never refreshes. Mitigation: report "skipped for N consecutive runs" so the operator notices. |

### 3.4 Policy option B: stash, fast-forward, un-stash

Behaviour, using the semantics quoted from [git-stash(1)](https://git-scm.com/docs/git-stash):

```zsh
# 1. Stash tracked + untracked; leaves HEAD, index and tree clean
git -C "$repo" stash push --quiet --include-untracked -m "repo-sync $(date -u +%FT%TZ)" || return 1
# 2. Fast-forward the checked-out branch
git -C "$repo" merge --ff-only --quiet "refs/remotes/origin/$branch"; rc=$?
# 3. Restore. `pop` drops the entry only on success; on conflict it stays in refs/stash.
git -C "$repo" stash pop --quiet || echo "STASH LEFT IN PLACE: resolve with git stash show/pop" >&2
```

What the docs promise and where the gaps are:

- `push`: "Save your local modifications to a new stash entry and roll them back to `HEAD` (in the working tree and in the index)." Both index and worktree are captured, so a partially staged commit-in-preparation survives round-trip *as content*; but the index/worktree split is only restored with `git stash pop --index`, which is not the default. Without `--index`, the human's carefully staged hunks come back unstaged. Pass `--index` on pop.
- `--include-untracked`: "all untracked files are also stashed and then cleaned up with `git clean`." The `git clean` step is the risk: it *deletes* the untracked files from the working tree between step 1 and step 3. If the wrapper dies between those steps (SIGKILL, laptop sleep, `launchd` timeout), the human returns to a tree where their new files are gone and exist only in `refs/stash`. Recoverable, but alarming and non-obvious. Never use `--all` ("All ignored and untracked files are also stashed and then cleaned up") in an unattended job: it would stash and delete `node_modules/`, `.venv/`, build caches, adding gigabytes to the stash and minutes to the run.
- `pop`: "The working directory must match the index." and "Applying the state can fail with conflicts; in this case, it is not removed from the stash list. You need to resolve the conflicts by hand and call `git stash drop` manually afterwards." An unattended job cannot resolve conflicts, so a conflicting pop leaves the repo *both* fast-forwarded *and* mid-conflict with `u` entries in status; the next run's classifier (3.2) will then skip it forever until a human intervenes. This is the same disqualifier that rules out `git pull --autostash` in Section 1.4.
- `--keep-index` / `--staged` do not help here: `--staged` stashes only staged changes, leaving unstaged edits in the tree, which still blocks or contaminates the merge.
- Stash bookkeeping: "The latest stash you created is stored in `refs/stash`; older stashes are found in the reflog of this reference" and `stash list` shows `stash@{0}: On main: <sha>... repo-sync 2026-09-07T03:00:00Z`. Using a recognisable `-m` message is what lets the operator (or the next run, via `--show-stash` in 3.1) tell wrapper-created leftovers from the human's own stashes.
- Exit status when there is nothing to stash: `git stash push` prints "No local changes to save" and exits 0 (verified behaviour of the command, not stated in the man page). The wrapper must therefore not pair a `push` with an unconditional `pop`; if it does, it will pop the *human's* most recent stash. Guard: only pop when `push` actually created an entry, e.g. compare `git rev-parse -q --verify refs/stash` before and after.

Trade-offs:

| | |
|---|---|
| **+** | Dirty repos do get their checked-out branch refreshed, so working-tree readers see fresh code. |
| **−** | Two extra mutating steps with a real window of data invisibility (untracked files removed by `git clean`) and a non-automatable failure mode (pop conflict). |
| **−** | Rebases the human's uncommitted diff onto new upstream content without asking. Even a clean pop changes what `git diff` shows them. |
| **−** | Interacts badly with editors/IDEs that watch the tree: files vanish and reappear, triggering reindexing or, worse, an IDE auto-save that re-creates a file mid-pop and causes the conflict. |

Verdict: only acceptable as an explicit opt-in (`--stash`), never the unattended default. If working-tree freshness in dirty repos matters, policy C solves it without touching the human's checkout.

### 3.5 Policy option C: refresh a script-owned worktree, never the human's checkout

Behaviour: the wrapper keeps one **detached** linked worktree per repo (or per target branch) that only it writes to, and AI agents read from that worktree. The human's primary checkout is never fast-forwarded by the script; only its non-checked-out branches move (`fetch b:b`), and even that is optional.

```zsh
# One-time per repo: create a locked, detached reader worktree that shares the object store
git -C "$repo" worktree add --detach --lock --reason "repo-sync reader" "$readers/$name/main" origin/main

# Every run, after `git fetch --prune`:
git -C "$readers/$name/main" checkout --detach --quiet refs/remotes/origin/main
# reset --hard is equivalent here and also discards any stray edits an agent made in the reader tree:
git -C "$readers/$name/main" reset --hard --quiet refs/remotes/origin/main
```

Why this is the strongest answer to the research question's constraints:

- **Never destroys the human's work** — by construction. The wrapper writes to a directory the human does not edit. Dirty-tree detection (3.1/3.2) is still run on the primary checkout, but only to decide whether `merge --ff-only` is *additionally* safe there; a skip there costs the agents nothing.
- **Never half-updated** — `git checkout --detach <commit>` on a clean worktree is a single working-tree update; combined with the lock/swap patterns in Section 5 the reader can be given a fully consistent snapshot.
- **Fast-forward-only is moot** — a detached worktree has no branch to diverge; it always tracks `origin/<branch>` exactly, including after a force-push on the forge (which the human's `main` would correctly refuse to follow). This is desirable for a knowledge base that should mirror the forge, and it means a human's local-only commits on `main` are *not* visible to the agents, which is also correct: unpublished work should not enter a shared knowledge base.
- **Cheap** — worktrees share the object store ("sharing everything except per-worktree files such as `HEAD`, `index`, etc." — Section 1.7), so the cost is one extra checkout of the tree, not a second clone. For `release*` branches, add one detached worktree per branch under `$readers/$name/release-2.4`, or point agents at `git show origin/release/2.4:path` and keep only `main` materialised.
- **No branch-name collision** — because the reader worktree is detached, the human is free to `git switch main` or `git switch release/2.4` in the primary clone; the "already checked out" refusal (Section 1.7) never triggers in either direction.

Costs:

| | |
|---|---|
| **−** | Disk: one extra checkout per repo (working files only; objects are shared). For a 50-repo estate of typical service repos this is usually hundreds of MB, not GB, but a monorepo with large binaries doubles its footprint. |
| **−** | Two paths per repo: agents must be told to read `$readers/<name>/main`, not the human's `~/src/<name>`. If an agent config already hard-codes the human path, that is a migration. |
| **−** | Hooks and per-worktree config: `core.hooksPath` and most config are shared; a `post-checkout` hook the human installed (e.g. an IDE plugin's) will fire in the reader worktree too. Run reader-worktree git commands with `-c core.hooksPath=/dev/null` to keep the unattended run hook-free. |
| **−** | Submodules: detached worktrees do not initialise submodules by default; add `git -C "$reader" submodule update --init --recursive` if agents need them. |

### 3.6 Policy comparison

| Policy | Human checkout touched | Dirty repo refreshed for agents | Unattended-safe | Extra state created | Recommended role |
|---|---|---|---|---|---|
| A. Skip | only when clean | no (refs yes, tree no) | yes | none | default when agents read refs or when C is not set up |
| B. Stash | yes, always | yes | **no** (pop conflicts, `git clean` window) | stash entries | explicit opt-in only |
| C. Reader worktree | never (optionally FF when clean) | yes | yes | one worktree per repo/branch | default when agents read working trees |

A + C together is the recommended configuration: fetch once, fast-forward the human's non-checked-out branches, fast-forward their checked-out branch only when the tree is quiescent, and always refresh the detached reader worktree that the agents actually consume.

## 4. Shell-function design

Everything in Sections 1-3 is per-repo. This section is about the wrapper *around* that: how it learns which repos exist, how it runs them concurrently on macOS, how it reports, and how it behaves the same whether a human types `repo-sync` in a terminal or a remote trigger runs `zsh -c 'repo-sync'` with no profile loaded.

### 4.1 Repo inventory: three sources, one resolved list

| Source | Command | Pros | Cons |
|---|---|---|---|
| **Explicit list file** | `~/.config/repo-sync/repos` — one absolute path per line, `#` comments | Deterministic; the operator controls exactly what agents read; supports per-repo options as extra columns | Must be edited when a repo is cloned or removed; drifts silently |
| **`git maintenance` registry** | `git config --global --get-all maintenance.repo` | Already exists if Section 1.6 is adopted; one source of truth for "repos this machine cares about" | Multi-valued config, so removal is `git config --global --unset maintenance.repo <path>`; no per-repo options |
| **Directory scan** | `find ~/src -mindepth 2 -maxdepth 2 -name .git -prune -print` (see 4.2) | Zero maintenance; new clones join automatically | Picks up throwaway clones, vendored repos, and worktrees; depth must match the operator's layout; slower on large trees |
| **Forge enumeration** | `gh repo list ORG` / `glab repo list --group G` (Section 6) | Discovers repos that are *not yet cloned* | Network + auth + rate limit; only tells you what *could* be synced, not where it is on disk |

Recommended composition: scan (or forge-enumerate) *once* to generate the list file, then run from the list file. The list file is what makes `--dry-run` meaningful ("here is exactly what I would touch") and what a reading agent can also consult to learn where checkouts live. Keep it in `~/.config/repo-sync/` following XDG conventions so it survives the machine's dotfile sync.

The list-file parser needs three properties: tolerate blank lines and `#` comments, accept `~`, and reject anything that is not a git work tree *before* the parallel phase starts so one typo does not become one failed job per run.

```zsh
# Resolve the inventory to absolute paths of git top-levels; print bad entries to stderr.
repo_sync_inventory() {
  local cfg=${REPO_SYNC_LIST:-${XDG_CONFIG_HOME:-$HOME/.config}/repo-sync/repos}
  local line top
  while IFS= read -r line; do
    line=${line%%#*}; line=${line## }; line=${line%% }      # strip comment + edge blanks
    [[ -z $line ]] && continue
    line=${~line}                                         # expand a leading ~
    top=$(git -C "$line" rev-parse --show-toplevel 2>/dev/null) \
      || { print -u2 "repo-sync: not a git work tree, ignoring: $line"; continue; }
    print -r -- "$top"
  done < "$cfg" | sort -u
}
```

`sort -u` collapses duplicates such as `~/src/app` and `~/src/app/subdir`, which both resolve to the same top-level; without it the same repo would be refreshed twice concurrently, and Section 5's per-repo lock would report a spurious "already running".

### 4.2 Directory scan: `find -name .git -maxdepth`

Two things make the naive `find ~/src -name .git` wrong for this job:

1. `.git` can be a **file** (linked worktrees and submodules store `gitdir: ...` in a file), so `-type d` misses them and `-type f` misses ordinary clones. Drop the type test and let `git rev-parse` decide.
2. Without `-prune`, `find` descends *into* every `.git` directory it finds, which on a large estate is most of the I/O. `-prune` stops descent at the match.

```zsh
# Ordinary layout: ~/src/<repo>/.git  → depth 2. Adjust -maxdepth for ~/src/<group>/<repo>.
find ~/src -mindepth 2 -maxdepth 3 -name .git -prune -print0 \
  | while IFS= read -r -d '' g; do print -r -- "${g:h}"; done      # ${g:h} = dirname, zsh modifier
```

`-print0` plus `read -d ''` keeps paths with spaces intact; macOS BSD `find` supports both flags. Nested repos (a clone inside another clone's tree) are excluded by `-prune` only if the inner one is *under* an outer `.git`, which it never is; they will appear as separate entries, which is correct.

### 4.3 Parallel execution on macOS

Four viable mechanisms, none of which require anything beyond a stock macOS plus optional Homebrew:

| Mechanism | Ships with macOS | Concurrency cap | Output interleaving | Exit-status aggregation |
|---|---|---|---|---|
| `xargs -P N` | yes (BSD xargs) | `-P N` | interleaved unless each job writes to its own file | exit 1 if any invocation failed, but not *which* |
| zsh `zargs -P N` | yes (autoloadable function) | `-P N` | same as xargs | see 4.3.2 |
| background jobs + `wait` | yes (shell builtin) | manual (count running jobs) | same | `wait $pid` returns each child's status (zsh/bash ≥ 4.3 `wait -n` for "next finished") |
| GNU `parallel` | `brew install parallel` | `-j N` | `--group` (default) buffers per job; `--line-buffer` | exit = number of failed jobs (capped at 101); `--joblog` gives a TSV per job |

#### 4.3.1 `xargs -P N` (BSD xargs, stock macOS)

The lowest-common-denominator choice: works from `zsh -c`, `sh`, `launchd`, and `ssh host cmd` alike. Pattern:

```zsh
repo_sync_inventory | tr '\n' '\0' \
  | xargs -0 -P "${REPO_SYNC_JOBS:-4}" -n 1 -I{} zsh -c 'repo_sync_one "$1"' _ {}
```

Notes: `-0` pairs with NUL-delimited input; `-n 1` one repo per invocation; `-I{}` substitutes the path. The child is `zsh -c`, which means the per-repo function must be reachable from a non-interactive shell (4.6) — either the wrapper is a script file on `PATH`, or the function is exported via `functions -x` / `typeset -f` into a `zsh -c` string. macOS xargs reports exit 1 if any child failed, so the summary table (4.4) cannot be driven from xargs' exit code alone; it must be assembled from per-repo result files.

#### 4.3.2 zsh `zargs -P N` (autoloadable, stock macOS)

zsh ships `zargs` as a contributed function ([Functions/Misc/zargs](https://github.com/zsh-users/zsh/blob/master/Functions/Misc/zargs)): "This function works like GNU xargs, except that instead of reading lines of arguments from the standard input, it takes them from the command line." Loaded with `autoload -Uz zargs`. Relevant options, quoted from the function header:

- `-P, --max-procs`: "Run up to max-procs command lines in the background at once." Implementation detail visible in the source: it launches a batch of up to N background jobs and `wait`s for the whole batch before launching the next, so it is *batch-parallel*, not a sliding window. With 4 jobs and one slow monorepo, the other 3 slots idle until the slow one finishes. Acceptable for a handful of repos; for 30+ repos of uneven size prefer 4.3.3 or GNU parallel.
- `-n, --max-args`: "Use at most max-args arguments per command line (including initial-args)."
- `-i, -I replace-str`: "Substitute replace-str in the initial-args by each initial-arg. Implies --exit --max-lines=1."
- `-t, --verbose`: "Print each command line to stderr before executing it." — a free `--dry-run` preview when combined with `-r`.
- `-r, --no-run-if-empty`: "Do nothing if there are no input arguments before the eof-str."
- Separator: "`--` is used both to end the options and to begin the command, so to specify some options along with an empty set of input-args, one must repeat the `--` as TWO consecutive arguments."
- Exit status: "0 if it succeeds; 123 if any invocation of the command exited with status 1-125; 124 if the command exited with status 255; 125 if the command is killed by a signal; 126 if the command cannot be run; 127 if the command is not found; 1 if some other error occurred." This matches GNU xargs, so a wrapper can treat 123 as "some repos failed, consult the summary".

Because zargs runs the command *inside the current shell*, the per-repo function needs no export: it is already defined.

```zsh
autoload -Uz zargs
local -a repos; repos=("${(@f)$(repo_sync_inventory)}")
zargs -P "${REPO_SYNC_JOBS:-4}" -r -i{} -- "${repos[@]}" -- repo_sync_one {}
rc=$?   # 0 = all ok, 123 = at least one repo returned 1-125
```

#### 4.3.3 Background jobs + `wait` (sliding window, pure zsh)

The most flexible native option and the only one of the stock choices that keeps all N slots busy. zsh's `wait` accepts a PID and returns that child's exit status, so per-repo results can be captured without result files, but the simplest robust pattern still writes one result file per repo (4.4) because the `/bin/zsh` 5.9 that ships with macOS has no `wait -n` ("wait for whichever child finishes next"); bash gained `wait -n` in 4.3 ([bash NEWS](https://tiswww.case.edu/php/chet/bash/NEWS)), but macOS's `/bin/bash` is 3.2 and so lacks it too. (Whether a zsh release newer than 5.9 adds `wait -n` could not be confirmed from the zsh NEWS file during this research; do not depend on it.) The portable substitute is polling the job table, which is what the loop below does.

```zsh
local -A pid_of; local max=${REPO_SYNC_JOBS:-4} r
for r in "${repos[@]}"; do
  while (( ${#jobstates} >= max )); do sleep 0.2; done   # $jobstates: zsh/parameter module
  repo_sync_one "$r" &
  pid_of[$!]=$r
done
wait                                                    # all remaining
```

`$jobstates` requires `zmodload zsh/parameter` (auto-loaded in interactive shells, not guaranteed under `zsh -c`; see 4.6) and the `MONITOR` option to be *off* or job-control messages will print `[1] 12345` lines into the log. Under `zsh -c` MONITOR is off by default, so this is only an interactive-run concern; `setopt NO_MONITOR NO_NOTIFY` in the function body makes both modes behave identically.

#### 4.3.4 GNU `parallel` (Homebrew)

`brew install parallel` provides the richest option set: `-j N` sliding window, `--group` (default) buffers each job's stdout/stderr and prints them together so logs never interleave, `--joblog FILE` writes a TSV with start time, runtime, exit value and command per job, `--halt soon,fail=1` to stop launching new jobs after the first failure, and `--tag` prefixes every output line with the argument (repo path). Its exit code is the number of failed jobs (0-100; 101 when more than 100 failed), which is more informative than xargs' 1/0. Costs: a Homebrew dependency the remote-trigger side must also find on `PATH` (4.6), and the first run prints a citation notice unless `parallel --citation` or `--will-cite` has been run once. For a personal workstation sync it is worth installing; the wrapper should detect it and fall back to 4.3.2 when absent:

```zsh
if (( $+commands[parallel] )); then
  print -rl -- "${repos[@]}" | parallel -j "${REPO_SYNC_JOBS:-4}" --tag --joblog "$logdir/joblog.tsv" repo_sync_one {}
else
  zargs -P "${REPO_SYNC_JOBS:-4}" -r -i{} -- "${repos[@]}" -- repo_sync_one {}
fi
```

(`parallel` executes the command via the shell it detects from `$PARALLEL_SHELL`/parent process; to call a zsh *function* rather than a script, export it first with `functions -x repo_sync_one` — zsh ≥ 5.8 — or, more portably, make `repo_sync_one` a standalone script on `PATH`.)

#### 4.3.5 Choosing N

Fetch is network-bound, not CPU-bound; the practical limit is the forge's per-connection SSH rate and the disk for the checkout phase. GitLab.com and GitHub both tolerate a handful of concurrent SSH fetches from one IP without throttling in normal use, but neither publishes a hard number for git-over-SSH (their published limits are for the HTTP APIs, Section 6). Start at `REPO_SYNC_JOBS=4`, measure the wall-clock with `time`, and raise to 8 only if the estate is large and the forge is not the bottleneck. Above that, the checkout phase's disk writes on a laptop SSD start to dominate and gains flatten.

### 4.4 Per-repo logging, summary table, exit codes

Concurrency makes a shared log unreadable, so the design rule is: **each repo job writes only to its own files; the parent assembles the summary after `wait`.**

Layout per run (`$run = ${XDG_STATE_HOME:-$HOME/.local/state}/repo-sync/runs/<UTC-timestamp>`):

```
$run/
  <repo-slug>.log      full stdout+stderr of every git command for that repo
  <repo-slug>.result   one machine-readable line, written last, atomically (write to .tmp, mv)
  summary.tsv          parent concatenates all .result files
latest -> runs/<UTC-timestamp>   (symlink flipped with ln -sfn after summary.tsv exists)
```

`<repo-slug>` is the repo path with `/` replaced by `%` (or `basename` plus a short hash when basenames collide). The `.result` line is what the summary table and the exit code are computed from, so its fields are the contract:

```
status	repo	branch	before_sha	after_sha	reason	seconds
OK	/Users/me/src/app	main	3f2a1c0	9c1e77d	ff	1.8
UPTODATE	/Users/me/src/lib	main	77e0b21	77e0b21	-	0.4
SKIPPED	/Users/me/src/tool	main	a1b2c3d	a1b2c3d	dirty:2M,1?	0.5
SKIPPED	/Users/me/src/svc	main	e4f5a6b	e4f5a6b	REBASE	0.3
DIVERGED	/Users/me/src/api	main	0d1e2f3	0d1e2f3	local-ahead:2	0.6
FAILED	/Users/me/src/old	-	-	-	fetch:exit128	12.0
```

Status vocabulary (fixed, so agents and humans can grep it):

| Status | Meaning | Contributes to exit code |
|---|---|---|
| `OK` | at least one branch fast-forwarded | no |
| `UPTODATE` | fetch ran, nothing to move | no |
| `SKIPPED` | policy decision (dirty tree, in-progress op, archived) — expected, human-actionable | no by default; yes with `--strict` |
| `DIVERGED` | local branch has commits not on origin; nothing done | no by default; yes with `--strict` |
| `FAILED` | git error: network, auth, corrupt repo, lock timeout | **yes** |

Exit code of the wrapper:

- `0` — every repo `OK`/`UPTODATE` (or `SKIPPED`/`DIVERGED` without `--strict`)
- `1` — at least one `FAILED` (or any `SKIPPED`/`DIVERGED` under `--strict`)
- `2` — usage / configuration error (inventory file missing, bad flag) — nothing was touched
- `3` — could not acquire the global lock: another run is in progress (Section 5.1). Distinct so a remote trigger can treat it as "already running, retry later" rather than as a failure.
- `124` — reserved for `timeout`-style wrappers around the whole run (matches coreutils `timeout` convention), so callers can distinguish a hang from a failure.

A remote trigger only needs the code and, on non-zero, `cat "$state/latest/summary.tsv"`. The human-facing rendering is a `column -t` of the same file, printed to the terminal only when stdout is a TTY (`[[ -t 1 ]]`), so cron/launchd/SSH invocations stay quiet unless something failed.

Per-repo log hygiene: prefix every git call with `GIT_TERMINAL_PROMPT=0` so a missing credential fails instantly ("fatal: could not read Username") instead of blocking a background job forever, and `GIT_SSH_COMMAND='ssh -oBatchMode=yes -oConnectTimeout=10'` for the same reason over SSH. Both belong in the per-repo function, not the user's environment.

### 4.5 `--dry-run` and idempotency

**Idempotency** is mostly free: every mutating primitive in Section 1 is a no-op when already current (`fetch` with nothing new, `merge --ff-only` on an up-to-date branch, `update-ref` with equal old/new). Two places need care:

1. First-touch config (`fetch.prune`, `merge.ff=only`, `core.untrackedCache`, `maintenance register`) — write with `git config --get` guards or accept that `git config key value` overwrites an identical value harmlessly. The one non-idempotent call is `git config --add` (multi-valued), which duplicates on every run; never use `--add` from the wrapper.
2. Reader-worktree creation (policy C) — `git worktree add` fails if the path exists; guard with `git worktree list --porcelain | grep -Fx "worktree $path"`.

**`--dry-run`** must answer "what *would* move" without moving anything, which needs a real fetch to know. Two levels:

- `--dry-run` (default meaning): performs `git fetch --dry-run --prune origin` — per [git-fetch(1)](https://git-scm.com/docs/git-fetch), "Show what would be done, without making any changes", and `FETCH_HEAD` "is never written" — then prints the intended ref moves computed from `origin/*` as they currently stand (which may be stale, since the fetch was a dry run). Mutates nothing, not even remote-tracking refs.
- `--fetch-only`: performs the real fetch (which is always safe for the working tree) and then prints the exact fast-forwards it would do using `for-each-ref --format='%(upstream:trackshort)'` (Section 2.3). This is the more useful preview because it shows the true delta, and it is still non-destructive: nothing under `refs/heads/*` or the working tree changes.

Both modes still write `.result` files and the summary, tagged `DRYRUN` in an extra column, so the operator sees exactly the table a real run would produce.

### 4.6 Interactive zsh vs `zsh -c`: PATH, aliases, options

The remote trigger will run something like `ssh mac 'zsh -c repo-sync'` or a `launchd` job with `ProgramArguments: [/bin/zsh, -c, repo-sync]`. That shell is **neither interactive nor login**, so most of the environment a human takes for granted is missing. From the zsh manual's [Files](https://zsh.sourceforge.io/Doc/Release/Files.html) chapter:

| File | Read when | Consequence for the wrapper |
|---|---|---|
| `/etc/zshenv`, then `$ZDOTDIR/.zshenv` | every zsh, "this cannot be overridden" for `/etc/zshenv` | the **only** user file guaranteed to run under `zsh -c`; keep it tiny — the doc warns "it is important that it be kept as small as possible" |
| `/etc/zprofile`, `$ZDOTDIR/.zprofile` | login shells only | on macOS `/etc/zprofile` runs `path_helper`, which is how `/usr/local/bin` and `/opt/homebrew/bin` reach `PATH` for terminal users; a `zsh -c` job never sees this |
| `/etc/zshrc`, `$ZDOTDIR/.zshrc` | interactive shells only | aliases, `setopt`, plugin managers, `autoload` of completion — all absent |
| `RCS` / `GLOBAL_RCS` options (`-f` = `NO_RCS`) | "the former affects all startup files, while the second only affects global startup files" | `zsh -f` skips even `.zshenv`, so a launchd job using `-f` has *no* user config at all |

Practical rules that follow:

1. **Set `PATH` inside the function.** Homebrew git (`/opt/homebrew/bin/git`) is usually newer than Apple's `/usr/bin/git`, and `gh`/`glab`/`parallel` live only in the Homebrew prefix. `path=(/opt/homebrew/bin /usr/local/bin $path)` at the top of the wrapper removes the dependency on `path_helper`. Also `export HOMEBREW_NO_AUTO_UPDATE=1` is irrelevant here, but `GIT_CONFIG_NOSYSTEM` is not: leave it unset so the system gitconfig (Xcode's `credential.helper=osxkeychain`) still applies.
2. **No aliases, no `~/.zshrc` functions.** If `repo-sync` is defined as a function in `.zshrc`, `zsh -c repo-sync` fails with "command not found". Ship it as an executable file (`~/.local/bin/repo-sync` with `#!/bin/zsh -f`), or define it in a file that `.zshenv` sources *and* that the script re-sources. The file-on-`PATH` approach is simpler and is what makes `xargs`/`parallel` children (4.3) work too.
3. **Options differ.** Non-interactive zsh has `NO_MONITOR` (no job control messages), `NO_INTERACTIVE_COMMENTS` is not an issue in scripts, and crucially `SH_WORD_SPLIT` is *off* in both modes, so `$var` never splits — use arrays (`"${repos[@]}"`) rather than relying on splitting. Emulate a fixed environment at the top of the script so interactive and `-c` runs are identical: `emulate -L zsh; setopt err_return pipe_fail no_unset warn_create_global no_monitor no_notify`.
4. **`zsh/parameter` and `zsh/zutil` are not auto-loaded.** `$jobstates` (4.3.3) and `zparseopts` (flag parsing) need `zmodload zsh/parameter zsh/zutil` explicitly; interactive shells often have them via completion init, which hides the omission until the first remote run.
5. **`HOME` and `USER` are set, but `TMPDIR` may not be**, and `launchd` jobs get a minimal environment. Use `${TMPDIR:-/tmp}` and the XDG-style state dir from 4.4 rather than relying on the per-user `$TMPDIR` path macOS hands to login sessions.
6. **Credentials.** SSH agent forwarding is not present in a `launchd` job; git over SSH needs a key without passphrase or a key loaded in the macOS keychain (`ssh-add --apple-use-keychain`, with `UseKeychain yes` in `~/.ssh/config`). HTTPS with `osxkeychain` works because the keychain is unlocked while the user is logged in. `gh auth token` (Section 6) can supply an HTTPS token to git via `GIT_ASKPASS` if SSH is not available.

A ten-line self-test catches all of this before the first remote invocation:

```zsh
zsh -f -c '
  path=(/opt/homebrew/bin /usr/local/bin $path)
  for c in git gh glab parallel; do print -n "$c: "; command -v $c || print MISSING; done
  git --version; gh auth status 2>&1 | head -3; glab auth status 2>&1 | head -3
  GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND="ssh -oBatchMode=yes" git ls-remote --exit-code -h git@gitlab.com:GROUP/REPO.git HEAD
'
```

If that passes under `zsh -f -c`, it will pass under `launchd` and `ssh host zsh -c`.

## 5. Concurrency safety

Three different actors can touch the same repository at the same moment: the human (editor, `git commit`), a second copy of the wrapper (remote trigger fired while a cron run is still going), and the reading agents (which open files while a checkout is being rewritten). Each needs a different mechanism.

### 5.1 Wrapper-vs-wrapper: a run lock without `flock(1)`

macOS ships the `flock(2)` *system call* but not the util-linux `flock(1)` *command* that Linux scripts use. Options, ranked by dependency weight:

| Mechanism | Ships with macOS | Atomic | Stale-lock handling | Notes |
|---|---|---|---|---|
| `mkdir "$lock"` | yes | yes — `mkdir(2)` is atomic on every POSIX filesystem, including APFS | manual: write PID into `$lock/pid`, check `kill -0` | portable to every shell; the standard answer |
| `shlock -f "$lock" -p $$` | yes (`/usr/bin/shlock`) | yes (link-based) | **automatic**: refuses only if the PID in the file is alive | see 5.1.1 |
| `lockfile` (procmail) | no (`brew install procmail`) | yes | `-l <seconds>` forced expiry | heavy dependency for one feature |
| `flock` (util-linux) | no (`brew install util-linux`, keg-only, binary under `$(brew --prefix util-linux)/bin`) | yes, kernel-level | **automatic**: lock dies with the process | best semantics; extra `PATH` entry under `zsh -c` (4.6) |
| `python3 -c 'import fcntl...'` | yes (Xcode CLT or `/usr/bin/python3` shim) | yes, kernel-level | automatic | ~60 ms interpreter start; fine for one global lock, wasteful per repo |
| `zsh/system` module `zsystem flock` | yes (zsh builtin module) | yes, kernel-level | automatic | pure zsh, no external binary; see 5.1.2 |

The reason kernel locks (`flock`, `fcntl`, `zsystem flock`) beat file-existence locks (`mkdir`, `shlock`, `lockfile`) is *crash cleanup*: the OS releases a kernel lock when the holding process dies, including on SIGKILL and laptop-sleep-induced kills, whereas a `mkdir` lock left behind by a killed job blocks every future run until someone removes it. File-existence locks therefore need a liveness check on the recorded PID, and PIDs are reused, so the check is heuristic.

#### 5.1.1 `shlock` (stock macOS)

`/usr/bin/shlock` is the least-known stock option and the one that does the stale-PID check for you. From the [shlock(1) man page](https://keith.github.io/xcode-man-pages/shlock.1.html) (Xcode/macOS):

- Purpose: "create or verify a lock file for shell scripts". Synopsis `shlock [-du] [-p PID] -f lockfile`; "The `-f` argument with lockfile is always required. The `-p` option with PID is given when the program is to create a lock file".
- Atomicity: "shlock uses the link(2) system call to make the final target lock file, which is an atomic operation" — it writes the PID to a temp file, then `link()`s it to the lock name; `link` fails if the name exists, so two racers cannot both win.
- Stale detection: "shlock verifies that an extant lock file is still valid by using kill(2) with a zero signal to check for the existence of the process". If the recorded PID is dead, shlock removes the stale file and takes the lock. This is the same heuristic as the manual `mkdir` version (5.1.3), including its PID-reuse weakness, but implemented once, in C.
- Exit status: "A zero exit code indicates a valid lock file." Non-zero means another live process holds it.
- Limitation: "Does not work on NFS or other network file system on different systems because the disparate systems have disjoint PID spaces." Irrelevant for a local `~/.local/state` lock; relevant if the state dir is ever moved to a network share.

The man page's own example, adapted to the wrapper's exit-code contract (4.4):

```zsh
lck=${XDG_STATE_HOME:-$HOME/.local/state}/repo-sync/run.lock
if shlock -f "$lck" -p $$; then
  trap 'rm -f "$lck"' EXIT INT TERM HUP
else
  print -u2 "repo-sync: already running (pid $(<"$lck"))"; exit 3
fi
```

Trade-off versus `mkdir`: identical guarantees, fewer lines, one more external process per run (negligible). Trade-off versus kernel locks: still a file-existence lock, so a `SIGKILL`ed run leaves a file that is only reclaimed once its PID is dead — which is exactly what shlock checks, so in practice the stale window closes on the next invocation.

#### 5.1.2 `zsystem flock` (pure zsh, stock macOS)

zsh's `zsh/system` module exposes a kernel advisory lock as a builtin, which gives the wrapper `flock(1)`-grade semantics with no Homebrew dependency and no `PATH` concern under `zsh -c`. Because the lock belongs to an open file descriptor, it is released by the kernel when the shell exits for *any* reason, including `SIGKILL` — the property none of the file-existence locks in 5.1.1/5.1.3 have.

```zsh
zmodload zsh/system
lck=${XDG_STATE_HOME:-$HOME/.local/state}/repo-sync/run.lock
: >> "$lck"                                     # the lock file must exist
if ! zsystem flock -t 0 -f lockfd "$lck"; then  # -t 0: do not wait; -f: keep fd in $lockfd
  print -u2 "repo-sync: already running"; exit 3
fi
# ... run ...
# lock released when the shell exits or explicitly: zsystem flock -u $lockfd
```

Semantics, quoted from the [zsh/system module documentation](https://github.com/zsh-users/zsh/blob/master/Doc/Zsh/mod_system.yo) (`Doc/Zsh/mod_system.yo`):

- Mechanism: "The builtin `zsystem`'s subcommand `flock` performs advisory file locking (via the `fcntl(2)` system call)". Advisory means git and other tools do not honour it; it only coordinates wrapper instances (and anything else that opts in to the same file), which is all a run lock needs.
- Precondition: "the named file, which must already exist, is locked by opening a file descriptor" — hence the `: >> "$lck"` above. The lock file itself carries no content and is never removed; only the kernel lock comes and goes, so there is no stale-file problem.
- Waiting: "By default the shell waits indefinitely for the lock to succeed." `-t timeout` "specifies a timeout for the lock in seconds; fractional seconds are allowed", and "the shell will attempt to lock the file every *interval* seconds if the `-i interval` option is given". For the wrapper `-t 0` gives the non-blocking "exit 3 if busy" behaviour a remote trigger wants; a cron-style run may prefer `-t 30` to wait briefly for a finishing sweep.
- Mode: "If the option `-r` is given, the lock is only for reading, otherwise it is for reading and writing." The wrapper takes the default exclusive lock; a *reading agent* could take `-r` on the same file to be told "a refresh is in progress" without blocking other readers (see 5.4).
- Holding: "on a successful lock, the shell variable *var* is set to the file descriptor used for locking" (`-f var`), and "The lock terminates when the shell process that created the lock exits". Release early with `zsystem flock -u $fd`: "the file descriptor given by the arithmetic expression *fd_expr* is closed, releasing a lock."
- Exit status: "Status 0 is returned if the lock succeeds, else status 1." and "If the attempt times out, status 2 is returned." So `-t 0` on a busy lock returns 2, not 1; map both to the wrapper's exit 3.

Caveat: `fcntl` locks are per-process, and the descriptor is inherited by children. Background jobs (4.3.3) or `xargs` children forked *after* the lock is taken share it harmlessly, but if the parent exits while a child is still running the lock is released even though work continues. Keep the parent alive until `wait` returns, which the design in 4.3 already does.

Ranking for this use case: `zsystem flock` (kernel lock, zero deps, pure zsh) > `shlock` (stock, self-cleaning file lock) > `mkdir` (portable to `sh`) > Homebrew `flock`/procmail `lockfile` (extra install for no additional benefit) > `python3 -c` (works, slow start).

#### 5.1.3 `mkdir` lock with stale detection (portable fallback)

```zsh
repo_sync_lock() {                 # global run lock; returns 3 if another run is live
  local lock=${XDG_STATE_HOME:-$HOME/.local/state}/repo-sync/run.lock
  if mkdir "$lock" 2>/dev/null; then
    print $$ > "$lock/pid"
    trap 'rm -rf "$lock"' EXIT INT TERM HUP
    return 0
  fi
  local pid; pid=$(<"$lock/pid" 2>/dev/null)
  if [[ -n $pid ]] && kill -0 "$pid" 2>/dev/null; then return 3; fi   # live holder
  rm -rf "$lock" && repo_sync_lock                                      # stale: reclaim once
}
```

The `trap ... EXIT` is what removes the lock on normal exit and on `INT`/`TERM`; it cannot run on `SIGKILL`, which is why the stale-PID branch exists. `kill -0` only tests existence, not identity: if the PID was reused by an unrelated process the lock is wrongly considered live and the run exits 3. Acceptable for a job that reruns every few minutes; not acceptable if a missed run matters, in which case use a kernel lock.

### 5.2 Per-repo locks vs one global lock

One global lock (5.1) is enough to stop two *wrappers* colliding. A per-repo lock is still useful for two reasons: it lets a remote "sync just repo X" request run alongside a full sweep without waiting, and it is the natural place to serialise the wrapper against the *reader swap* in 5.4. Put per-repo lock files in the repo's common git dir (`$(git rev-parse --git-common-dir)/repo-sync.lock`), which git already treats as private state, keeps the lock next to the thing it protects, and works correctly when the same repo is reached via a linked worktree path.

### 5.3 Wrapper-vs-human: git's own locks

Git protects its own data structures with per-file lock files created by an atomic `open(O_CREAT|O_EXCL)`: `.git/index.lock` while the index is being written, `.git/refs/heads/<branch>.lock` while a loose ref is being updated, `.git/packed-refs.lock` while the packed-refs file is rewritten, and `.git/config.lock` for config writes. The behaviour that matters for a concurrent wrapper is *what happens on contention*, and it differs by file. From [Documentation/config/core.adoc](https://github.com/git/git/blob/master/Documentation/config/core.adoc):

| Lock | Config | Doc wording | Consequence |
|---|---|---|---|
| individual ref (`refs/heads/main.lock`) | `core.filesRefLockTimeout` | "The length of time, in milliseconds, to retry when trying to lock an individual reference. Value 0 means not to retry at all; -1 means to try indefinitely. Default is 100." | A wrapper `fetch origin main:main` colliding with the human's `git commit` on `main` retries for only 100 ms, then fails with "cannot lock ref". Rare (the commit holds the ref lock for microseconds), and a failed fetch-into-branch is a harmless skip; the next run catches up. |
| `packed-refs` | `core.packedRefsTimeout` | "The length of time, in milliseconds, to retry when trying to lock the `packed-refs` file. Value 0 means not to retry at all; -1 means to try indefinitely. Default is 1000." | `fetch --prune` deletes refs, which rewrites `packed-refs`; a concurrent `git gc`/`pack-refs` (e.g. from `git maintenance`) can hold it longer than a ref lock. 1 s of retry is normally enough; raise per repo (`git config core.packedRefsTimeout 5000`) if the log shows "Unable to create '.../packed-refs.lock'". |
| `index.lock` | none — **no retry** | not configurable | Any command that writes the index (`merge`, `checkout`, `reset`, `stash`, and by default `status`) fails *immediately* with "fatal: Unable to create '.../index.lock': File exists. Another git process seems to be running in this repository". This is the lock the wrapper is most likely to hit *and to cause*: see below. |

Rules that follow:

1. **Never take the index lock when you do not need it.** `git --no-optional-locks status` (Section 3.1) is the concrete instance: without the flag, the wrapper's dirty check can make the human's `git commit` fail with the index.lock error at the exact moment they press Enter. The same applies to `git diff` (use `--no-optional-locks` or `git diff-index` plumbing) and to `git stash` (which always writes the index — another reason Section 3.4 rules it out).
2. **Treat "cannot lock ref" and "index.lock ... File exists" as retryable, not fatal.** Classify them as `FAILED reason=lock` in the summary (4.4) and let the next scheduled run retry; do not loop-retry inside the job, because a *stale* `index.lock` left by a crashed editor plugin would then hang the sweep. Never delete `index.lock` from the wrapper: it may belong to a live human process.
3. **Ref updates are individually atomic.** A loose-ref write is "write to `.lock`, `rename(2)` over the ref", so a reader (or the human's `git log`) never sees a torn ref. But, as Section 1.5 quoted, a multi-ref transaction is *not* atomic from a reader's point of view: "a concurrent reader may still see a subset of the modifications." Consistency across branches for the agents comes from 5.4, not from git.
4. **Reflog is the audit trail.** `core.logAllRefUpdates`: "Enable the reflog. Updates to a ref <ref> is logged to the file `$GIT_DIR/logs/<ref>`." It is on by default in non-bare repos, so every fast-forward the wrapper performs is listed in `git reflog show main` with the `-m "repo-sync: ..."` message from Section 1.5; a human who suspects the sync moved something can find and undo it with `git reset --keep main@{1}`.
5. **Hooks.** `core.hooksPath`: "By default Git will look for your hooks in the `$GIT_DIR/hooks` directory." The wrapper's `merge --ff-only` and `checkout` fire `post-merge`/`post-checkout` hooks the human (or their IDE) installed. Run wrapper git commands with `-c core.hooksPath=/dev/null` so an unattended job never executes user hooks that may prompt, open GUIs, or take minutes.

Git's `--no-optional-locks` flag is the only cross-command switch; everything else is per-command discipline. A one-line audit of the wrapper is therefore: *grep the script for `git` calls that are not `fetch`, `for-each-ref`, `rev-parse`, `merge-base`, `update-ref`, `ls-remote`, `symbolic-ref`, or `--no-optional-locks status`; each remaining call is one that can contend with the human, and must be justified.*

### 5.4 Wrapper-vs-reader: atomic swap so an agent never sees a half-updated tree

`git checkout`/`merge --ff-only` rewrite the working tree *file by file*. A reader that opens `src/a.py` and then `src/b.py` during that window can get `a.py` from the old commit and `b.py` from the new one. Git offers no snapshot isolation for the working tree, so the wrapper must build it. Three patterns, in increasing strength:

#### 5.4.1 Lock handshake (weakest, zero copies)

The wrapper holds an exclusive `zsystem flock` (or `flock`) on `<reader>/.sync.lock` while it mutates the reader worktree; agents take a *shared* lock (`zsystem flock -r`) for the duration of a read. Readers never block each other; the writer waits for readers to finish and readers wait for the writer. Cost: every agent must cooperate, and a long-running agent read starves the writer. Suitable when the agents are your own code and reads are short.

#### 5.4.2 Symlink flip (recommended)

Keep two script-owned detached worktrees per repo (policy C, Section 3.5) and publish one of them through a stable symlink that agents always open:

```
readers/app/
  slot-a/        ← detached worktree at origin/main@<sha1>
  slot-b/        ← detached worktree at origin/main@<sha2>
  current -> slot-b        ← the only path agents are told about
```

Each run updates the *inactive* slot with `git checkout --detach origin/main` (readers are on the other one), then flips the symlink. The flip must be a single `rename(2)`, because from the [rename(2) man page](https://keith.github.io/xcode-man-pages/rename.2.html): "The rename() system call guarantees that an instance of new will always exist, even if the system should crash in the middle of the operation." and "If the final component of old is a symbolic link, the symbolic link is renamed, not the file or directory to which it points." Readers therefore see either the old target or the new one, never a missing path.

GNU coreutils spells this `ln -sfn slot-a current.tmp && mv -T current.tmp current`; macOS `mv` has no `-T`, and a bare `mv current.tmp current` would move the temp link *into* the directory `current` points at. The macOS-safe form:

```zsh
# $readers/app: publish slot-a atomically. `-h` makes mv treat the existing symlink as a file, not follow it.
ln -sfn slot-a "$readers/app/current.tmp"        # create/replace the temp link (points to relative name)
mv -h "$readers/app/current.tmp" "$readers/app/current"   # rename(2) of a symlink over a symlink: atomic
```

`mv -h` is what makes this work on macOS. From the [macOS mv(1) man page](https://keith.github.io/xcode-man-pages/mv.1.html): synopsis `mv [-f | -i | -n] [-hv] source target`, and `-h`: "If the target operand is a symbolic link to a directory, do not follow it." Without it, when `current` already exists as a symlink to a directory, `mv` resolves it and places `current.tmp` inside `slot-b/`. The same page notes that `-h`, `-n` and `-v` "are non-standard extensions and not recommended for portable scripts" — fine here, because the wrapper is macOS-specific by design; a Linux port would use `mv -T`. It also documents the cross-filesystem fallback — "rm -f destination_path && cp -pRP source_file destination && rm -rf source_file" — which is emphatically *not* atomic; that is the second reason (after `EXDEV`) to keep slots and symlink on one volume, since `mv` will silently degrade to copy-and-delete rather than fail. Alternatively, skip `ln`+`mv` and use the platform primitive directly: macOS `renameatx_np(2)` with `RENAME_SWAP` will "cause the source and target to be atomically swapped. Source and target need not be of the same type", which swaps two *directories* in one syscall — but there is no stock CLI for it, so from a shell the symlink flip is the practical route. Use a **relative** symlink target (`slot-a`, not `/Users/...`) so the reader tree can be moved or synced without breaking the link.

Two constraints from the same man page shape the fallback when the slots are not symlinks but directories: "old is a directory, but new is not a directory" → `ENOTDIR`, "new is a directory and is not empty" → `ENOTEMPTY`. So `mv slot-new current` over an existing populated directory fails; a directory rename can only replace an *empty* directory, which is why the two-slot symlink is the design rather than `mv`ing trees over each other. And `EXDEV` ("The link named by new and the file named by old are on different logical devices") means the slots and the symlink must live on the same volume; keep `readers/` on the same APFS volume as the repos, not on an external disk.

Reader-side contract that makes this safe: an agent must `realpath` the `current` link **once** at the start of a job and then read everything through the resolved `slot-*` path. If it re-reads through `current` mid-job it can straddle a flip. Because the wrapper only ever writes to the inactive slot, a job that resolved `slot-b` keeps a consistent view until the *next* flip after that one (two runs later); make the run cadence and the maximum agent job length compatible, or add a third slot.

#### 5.4.3 Fresh worktree per run (strongest, most disk)

`git worktree add --detach "$readers/app/<sha>" origin/main`, flip `current` to it, and `git worktree remove` slots older than N runs (Section 1.7: "Only clean worktrees ... can be removed" gives a free guard against deleting a tree an agent wrote into). Every published snapshot is immutable for its lifetime, so no reader can ever straddle an update. Disk grows with N × tree size; `git worktree prune` after removal keeps `.git/worktrees` tidy. Prefer this when agents run for hours or when auditability ("which exact tree did the agent read?") matters — the path *is* the commit SHA.

#### 5.4.4 What the swap does and does not cover

- Covered: any reader that opens files under `current/` sees exactly one commit's tree.
- Not covered: readers that use `git` *commands* against the repo (`git log`, `git show origin/main:path`) see refs as they move, individually atomically (5.3 rule 3). For multi-branch consistency in ref-space, have the wrapper record `origin/main`, `origin/release/*` SHAs in a manifest file inside the slot (`current/.repo-sync.json`) at swap time, and have agents read those SHAs rather than the live refs.
- Not covered: the human's own checkout, which policy A/C deliberately leave to git's per-file semantics; agents should not read it.

## 6. What gh / glab add beyond plain git

Plain git can refresh a repo it already knows about. What it cannot do is answer "which repos *should* this machine be syncing", "is this repo archived / renamed / moved to another group", or "is my credential still valid" without a network error surfacing mid-run. Those are forge questions, and the two CLIs answer them with one authenticated call each. Everything in this section is **discovery-time** (run daily or on demand to regenerate the inventory file of 4.1) and **pre-flight** (run once per sweep), never per-repo-per-run.

### 6.1 Pre-flight: `gh auth status`, `gh auth token`, `glab auth status`

An unattended sweep should fail *once, up front, loudly* on a dead credential rather than 40 times quietly inside per-repo fetches. The CLIs give a one-call health check per forge.

**`gh auth status`** ([manual](https://cli.github.com/manual/gh_auth_status)): "Display active account and authentication state on each known GitHub host." It actually tests the token against the API, and "Each host section will indicate the active account, which will be used when targeting that host." Behaviour the wrapper relies on:

- Exit code: when any host has a problem "the command will exit with 1 and output to stderr." So `gh auth status -h github.com >/dev/null 2>&1 || fail "gh: not authenticated"` is a complete pre-flight for GitHub.
- `--json hosts` exists, but note the documented inversion: "when using the `--json` option, the command will always exit with zero regardless of any authentication issues, unless there is a fatal error." With `--json`, parse the output instead of trusting the exit code.
- `--hostname <string>` scopes the check to one host (needed when GitHub Enterprise is also configured); `--active` shows only the account that will be used; `--show-token`/`-t` prints the token (never put this in a log).

**`gh auth token`** ([manual](https://cli.github.com/manual/gh_auth_token)): "This command outputs the authentication token for an account on a given GitHub host." and "Without the `--hostname` flag, the default host is chosen. Without the `--user` flag, the active account for the host is chosen." Flags: `-h, --hostname <string>` "The hostname of the GitHub instance authenticated with"; `-u, --user <string>` "The account to output the token for". This is how the wrapper can hand git an HTTPS credential in a `launchd` context where no SSH agent exists (Section 4.6 rule 6), without ever writing the token to disk or to the process list:

```zsh
# Feed gh's token to git for HTTPS remotes via GIT_ASKPASS (token never appears in argv or a file)
askpass=$(mktemp "${TMPDIR:-/tmp}/repo-sync-askpass.XXXXXX")
print -r -- '#!/bin/sh
case "$1" in *sername*) echo x-access-token ;; *) exec gh auth token --hostname github.com ;; esac' > "$askpass"
chmod 700 "$askpass"
GIT_ASKPASS=$askpass GIT_TERMINAL_PROMPT=0 git -C "$repo" fetch --prune origin
```

Simpler alternative when the human has run `gh auth setup-git` once: gh registers itself as git's credential helper for `github.com`, and every git HTTPS call resolves the token through gh automatically — nothing for the wrapper to do. Check with `git config --get-all credential.https://github.com.helper`. Whichever route is used, `gh auth token` output must never reach the per-repo log (4.4); the `GIT_ASKPASS` indirection keeps it out of `set -x` traces as well.

**`glab auth status`** performs the same role for GitLab ([gitlab-org/cli, docs/source/auth/status.md](https://gitlab.com/gitlab-org/cli/-/raw/main/docs/source/auth/status.md), verified 2026-09-07): its one-line description is "View authentication status". By default it checks the instance in the current context (derived from the `git remote`, the `GITLAB_HOST` environment variable, or the config); `-a, --all` checks every configured instance; `--hostname string` checks one named instance — note there is **no** `-h` short form, since `-h` is `--help`; `-t, --show-token` will "Display the authentication token" (never in a log). Two things the page does **not** document: the exit code on an invalid token, and the exact fields printed (scopes, API/git protocol). The pre-flight below treats any non-zero exit as "not authenticated" and discards the output. That is only sufficient if glab really exits non-zero on a rejected token, which the docs do not promise — so confirm once locally with `GITLAB_TOKEN=bogus glab auth status --hostname <host>; echo $?`. If it exits 0 on a bad token, grep the output for the error marker instead of trusting the exit code.

Pre-flight block:

```zsh
repo_sync_preflight() {
  local rc=0
  if (( $+commands[gh] )) && [[ -n $REPO_SYNC_GITHUB_HOSTS ]]; then
    for h in ${(s: :)REPO_SYNC_GITHUB_HOSTS}; do
      gh auth status --hostname "$h" >/dev/null 2>&1 || { print -u2 "gh: not authenticated to $h"; rc=1; }
    done
  fi
  if (( $+commands[glab] )) && [[ -n $REPO_SYNC_GITLAB_HOSTS ]]; then
    for h in ${(s: :)REPO_SYNC_GITLAB_HOSTS}; do
      glab auth status --hostname "$h" >/dev/null 2>&1 || { print -u2 "glab: not authenticated to $h"; rc=1; }
    done
  fi
  return $rc     # caller maps non-zero to wrapper exit 2 (configuration error, nothing touched)
}
```

Both checks cost one API request each and are skipped entirely when the machine only uses SSH remotes and the operator does not want a forge dependency; in that case `git ls-remote --exit-code <first-repo> HEAD` (Section 2.1 layer 3) is the transport-level equivalent.

### 6.2 Enumerating repos to auto-discover the inventory — GitHub

`gh repo list [<owner>] [flags]` — "List repositories owned by a user or organization." ([gh repo list manual](https://cli.github.com/manual/gh_repo_list)). Flags that matter for building a sync inventory:

| Flag | Doc wording | Use |
|---|---|---|
| `--limit <int>` | "Maximum number of repositories to list" — **default 30** | Always pass a large value (`--limit 1000`); the default silently truncates an org list. |
| `--no-archived` | "Omit archived repositories" | Archived repos never change; syncing them is wasted fetches. |
| `--source` / `--fork` | "Show only non-forks" / "Show only forks" | Usually `--source`; forks under the org are rarely knowledge-base material. |
| `--visibility {public\|private\|internal}` | filter by visibility | e.g. exclude `public` mirrors. |
| `--language`, `--topic <strings>` | filter by primary language / topic | `--topic knowledge-base` is a clean way to let repo owners opt in to being indexed. |
| `--json <fields>` | machine output; fields include `nameWithOwner`, `name`, `defaultBranchRef`, `isArchived`, `isFork`, `isPrivate`, `visibility`, `url`, `diskUsage`, `owner`, `primaryLanguage`, `createdAt`, and ~40 more | `--json` disables the human table; combine with `--jq`. |
| `--jq <expr>` | "Filter JSON output using a jq expression" | Built-in jq; no external `jq` dependency. |

The command is scoped to *owned* repos of one owner; it does not cross owners, so an estate spread over several orgs needs one call per org.

```zsh
# Inventory candidates: active, non-fork repos with their default branch and SSH URL
gh repo list ORG --limit 1000 --no-archived --source \
  --json nameWithOwner,defaultBranchRef,sshUrl,diskUsage \
  --jq '.[] | [.nameWithOwner, .defaultBranchRef.name, .sshUrl, .diskUsage] | @tsv'
# my-org/api	main	git@github.com:my-org/api.git	48211
```

`defaultBranchRef.name` is the forge's answer to Section 2's question for every repo in one call, and `diskUsage` (KiB) lets the wrapper flag monorepos that deserve a lower parallelism or a `--filter=blob:none` partial clone.

Pagination and cost: `gh repo list` is a GraphQL query under the hood and pages automatically up to `--limit`; each page is one request against the GraphQL rate limit (6.4). For a few hundred repos this is a handful of requests, far below any limit.

_[gh api fallback and glab enumeration to follow]_

### 6.3 Enumerating repos — GitLab (`glab repo list`, subgroups)

`glab repo list` — "Get list of repositories." ... "By default, lists the projects you own. Use `--all` to list every project on the instance, `--group` to scope to one group, or `--user` to list another user's projects." ([glab docs source, `docs/source/repo/list.md`](https://gitlab.com/gitlab-org/cli/-/blob/main/docs/source/repo/list.md)). Flags, quoted:

| Flag | Doc wording | Consequence for inventory building |
|---|---|---|
| `-g, --group` | "Return repositories in only the given group." | Pass the full group path (`platform/backend`), URL-encoding is handled by glab. |
| `-G, --include-subgroups` | "Include projects in subgroups of this group. Default is false." | **The subgroup trap.** Without `-G`, only direct children of the group are listed; a `platform/backend/services/api` project is invisible when listing `platform`. Always pass `-G` for an inventory. |
| `-P, --per-page` | "Number of items to list per page. (default 30)" | GitLab's API caps a page at 100, so `--per-page 100` plus a `--page` loop is required for larger groups; glab does *not* auto-paginate here, unlike `gh repo list --limit`. |
| `-p, --page` | "Page number. (default 1)" | loop until a page returns fewer than `per-page` items |
| `-a, --all` | "List all projects on the instance. Results are still paginated." | Useful on a small self-managed instance; on gitlab.com it is meaningless (millions of projects). |
| `-m, --mine` / `--member` / `--starred` | "List only projects you own. Default if no filters are provided." / "... of which you are a member." / "... starred projects." | `--member` is the right filter for "everything I can read across groups" when the estate is not group-scoped. |
| `--archived` | "Limit by archived status. Use 'false' to exclude archived repositories." | `--archived=false` mirrors `gh --no-archived`. |
| `--order`, `--sort` | order by "id, name, path, created_at, updated_at, similarity, star_count, last_activity_at. (default 'last_activity_at')"; sort "asc or desc" | `--order last_activity_at --sort desc` lists the repos most worth syncing first. |
| `-F, --output` | "Format output as: text, json. (default 'text')" | `-F json` returns the raw GitLab REST project objects, so fields are the REST names: `path_with_namespace`, `default_branch`, `ssh_url_to_repo`, `archived`, `namespace.full_path`, `last_activity_at`. |

There is **no** `--visibility`, `--source`, or `--fork` flag on `glab repo list` (checked against the docs source); filter forks with `jq 'select(.forked_from_project == null)'` on the JSON output, or use `glab api` directly (below).

```zsh
# All active projects under a group and its subgroups, paged; emits TSV path<TAB>default_branch<TAB>ssh_url
glab_repo_inventory() {
  local group=$1 page=1 n
  while :; do
    n=$(glab repo list -g "$group" -G --archived=false -P 100 -p $page -F json \
        | jq -r '.[] | select(.forked_from_project == null)
                     | [.path_with_namespace, .default_branch, .ssh_url_to_repo] | @tsv' \
        | tee -a "$1.inventory.tsv" | wc -l)
    (( n < 100 )) && break; (( page++ ))
  done
}
```

**`glab api` for anything the list command lacks.** `glab api <endpoint>` calls the authenticated REST API and prints JSON; it accepts `--paginate` to follow `Link` headers, and `-X`, `-F/-f` for method and fields, mirroring `gh api`. The group-projects endpoint has server-side filters the CLI flags do not expose:

```zsh
# Group (and subgroups) projects, server-side: no forks... GitLab has no 'exclude forks' filter,
# but 'simple=true' shrinks payloads and 'include_subgroups=true' replaces -G. Path must be URL-encoded.
glab api --paginate "groups/$(printf %s "$group" | sed 's|/|%2F|g')/projects?include_subgroups=true&archived=false&simple=true&per_page=100" \
  | jq -r '.[] | [.path_with_namespace, .default_branch // "main", .ssh_url_to_repo] | @tsv'
```

GitLab-specific nuances to encode in the wrapper:

1. **Nested namespaces in local paths.** `path_with_namespace` is `group/subgroup/project`; mirror it as the on-disk layout (`~/src/group/subgroup/project`) so the inventory can be regenerated deterministically and the `find -maxdepth` scan (4.2) has a known depth — or flatten to `basename` and accept collision risk between `platform/api` and `data/api`.
2. **Project transfer / rename.** GitLab redirects git operations from an old path for a period after a move, but not forever; a repo whose `ssh_url_to_repo` in the fresh inventory differs from `git remote get-url origin` should be flagged `RENAMED` in the summary and have `git remote set-url origin <new>` applied on the next run (a reversible, one-line change worth doing automatically).
3. **`default_branch` can be null** for empty projects (the `// "main"` fallback above); skip empty projects instead of syncing them.
4. **URL-encoding** of `/` in project and group paths (`%2F`) is mandatory for `glab api` endpoints but handled for you by the `glab repo` subcommands.
5. **Self-managed instances.** `glab` uses the host configured in `~/.config/glab-cli/config.yml`; `GITLAB_HOST=gitlab.example.com` overrides per call, which is how one wrapper serves both gitlab.com and a company instance.

### 6.4 Rate limits

The forge APIs are only touched at discovery and pre-flight time, so the wrapper is nowhere near any limit in normal operation. The numbers still matter for two reasons: to size how often discovery may run, and to recognise a 403/429 in the log as "throttled, back off" rather than "auth broken".

**GitHub** ([Rate limits for the REST API](https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api)):

| Limit | Value (quoted) | Relevance |
|---|---|---|
| Primary, authenticated user (PAT / `gh auth login`) | "5,000 requests per hour" | `gh repo list` of a 1,000-repo org is ~10 GraphQL pages; `gh repo view` per repo would be 1,000 requests — hence Section 2's rule to do this at discovery time only. |
| Primary, unauthenticated | "60 requests per hour" | never run discovery unauthenticated |
| GitHub App installation | "5,000 requests per hour" baseline, up to "15,000 requests per hour" for Enterprise Cloud | only if the wrapper is later moved to an App token |
| `GITHUB_TOKEN` in Actions | "1,000 requests per hour per repository" | if discovery is ever run from a CI job instead of the workstation, this is the tighter bucket |
| Secondary: concurrency | "100 concurrent requests" across REST + GraphQL | the wrapper's `-P 4..8` git fetches are not API requests; irrelevant unless the per-repo job also calls `gh api` |
| Secondary: REST | "900 points per minute" | mostly GET = 1 point each; discovery stays far below |
| Secondary: GraphQL | "2,000 points per minute" | `gh repo list` pages are GraphQL |
| Secondary: content creation | "80 content-generating requests per minute and no more than 500" per hour | wrapper never creates content |

Mechanics: every response carries `x-ratelimit-limit`, `x-ratelimit-remaining`, `x-ratelimit-used`, `x-ratelimit-reset` (UTC epoch seconds) and `x-ratelimit-resource` (which bucket). `GET /rate_limit` "doesn't count against your primary limit", so the wrapper can check headroom for free before a discovery sweep: `gh api rate_limit --jq '.resources.core.remaining, .resources.graphql.remaining'`. On a secondary-limit hit GitHub returns a `retry-after` header; honour it verbatim instead of retrying on a fixed schedule.

**Git-over-SSH/HTTPS fetches are not API calls** and are not subject to these limits. GitHub does not publish a numeric limit for git transport; in practice the constraint on a sweep is the forge's per-connection throughput and the local disk, which is why 4.3.5 sizes parallelism empirically rather than from a quota.

**GitLab.com** ([GitLab.com settings — rate limits](https://docs.gitlab.com/user/gitlab_com/)). Unlike GitHub, GitLab publishes limits for git transport too, and the API limits are per *minute* with endpoint-specific buckets:

| Limit | Value (quoted) | Relevance |
|---|---|---|
| "Authenticated API traffic for a user" | "2,000 requests each minute" | overall API ceiling for `glab api` / `glab repo list`; effectively unreachable for discovery |
| "Unauthenticated traffic from an IP address" | "500 requests each minute" | never run discovery unauthenticated |
| "Authenticated Git HTTPS traffic for a user" | "10,000 requests each minute" | a sweep of hundreds of repos at `-P 8` is well inside this |
| "Git SSH operations for a user, project, and Git command" | "600 operations each minute" | per *project* and command, so a single repo fetched in a tight retry loop is the only realistic way to hit it; do not loop-retry inside the job (5.3 rule 2) |
| "Projects list requests (`/api/v4/projects`)" | "2,000 requests every 10 minutes" | the instance-wide list endpoint; `glab repo list --all` |
| "Groups list requests (`/api/v4/groups`)" | "200 requests each minute" | `glab api groups` enumeration of subgroups |
| "Single project requests (`/api/v4/projects/:id`)" / "Single group requests (`/api/v4/groups/:id`)" | "400 requests each minute" | the `default_branch` lookup of Section 2.4 hits this bucket; 400/min means a 1,000-repo per-run lookup *would* throttle — another reason to keep layer 4 at discovery time only |
| Throttled response | "GitLab responds with a `429` status code" | classify 429 as `THROTTLED`, sleep, retry next run; note that for the Projects, Groups and Users APIs the 429 responses "do not include informational headers", so the wrapper cannot read a remaining-count for those endpoints and must simply back off |

The group-projects endpoint used in 6.3 (`/groups/:id/projects`) is not separately listed on that page; treat it as falling under the general 2,000/min authenticated bucket, and remember that its page size is capped at 100 items by the API, so the per-page loop in 6.3 is required regardless of quota. Self-managed GitLab instances have their own administrator-configurable limits (the page documents gitlab.com's values only); when the wrapper targets a company instance, ask the admins or probe with `glab api --include user 2>&1 | grep -i ratelimit` to read the `RateLimit-*` headers the general API does return.

**Budgeting rule of thumb:** discovery = O(repos/100) list calls + 0 per-repo calls; pre-flight = 2 calls; per-run sync = 0 API calls. On either forge the wrapper could run discovery every minute and still use under 5% of the tightest bucket that applies. If a future change adds a per-repo forge call inside the sweep, GitLab's 400/min single-project bucket is the first limit that will bite.

### 6.5 Turning discovery into the inventory file

The two enumerations (6.2, 6.3) produce the same three columns: `forge path`, `default branch`, `ssh url`. Discovery writes them to `~/.config/repo-sync/discovered.tsv`; the human-maintained `repos` file (4.1) stays the source of truth for *what is synced*, and a small reconcile step reports the difference rather than acting on it:

```zsh
repo_sync_discover() {
  local out=${XDG_CONFIG_HOME:-$HOME/.config}/repo-sync/discovered.tsv tmp=$out.tmp
  : > "$tmp"
  for org in ${(s: :)REPO_SYNC_GITHUB_ORGS}; do
    gh repo list "$org" --limit 1000 --no-archived --source \
      --json nameWithOwner,defaultBranchRef,sshUrl \
      --jq '.[] | [.nameWithOwner, .defaultBranchRef.name, .sshUrl] | @tsv' >> "$tmp"
  done
  for grp in ${(s: :)REPO_SYNC_GITLAB_GROUPS}; do
    glab api --paginate "groups/${grp//\//%2F}/projects?include_subgroups=true&archived=false&simple=true&per_page=100" \
      | jq -r '.[] | select(.default_branch != null) | [.path_with_namespace, .default_branch, .ssh_url_to_repo] | @tsv' >> "$tmp"
  done
  sort -u "$tmp" > "$out" && rm -f "$tmp"       # atomic replace via rename(2); readers never see a partial file

  # Reconcile against what is actually cloned; report, do not act.
  comm -13 <(repo_sync_inventory | xargs -n1 -I{} git -C {} remote get-url origin | sort -u) \
           <(cut -f3 "$out" | sort -u) | sed 's/^/NOT CLONED: /'
  comm -23 <(repo_sync_inventory | xargs -n1 -I{} git -C {} remote get-url origin | sort -u) \
           <(cut -f3 "$out" | sort -u) | sed 's/^/NOT ON FORGE (archived, moved, or access lost): /'
}
```

What the forge layer adds, summarised against the plain-git baseline:

| Capability | Plain git | With gh / glab |
|---|---|---|
| Refresh a known repo, FF-only, safely | yes (Sections 1-5) | no change |
| Know the default branch | yes, via `origin/HEAD` / `ls-remote --symref` (Section 2) | also yes, in bulk, one call per org/group |
| Discover repos not yet cloned | no | `gh repo list`, `glab repo list -G`, `glab api --paginate` |
| Detect archived / moved / renamed repos | only as a fetch failure after the fact | `isArchived`/`archived`, changed `sshUrl`/`ssh_url_to_repo`, before the run |
| Validate credentials up front | only by attempting a fetch | `gh auth status`, `glab auth status` — one call, clear exit code |
| Supply an HTTPS token to git in a headless job | needs a credential helper configured by hand | `gh auth token` via `GIT_ASKPASS`, or `gh auth setup-git` once |
| Rate-limit exposure of the per-run sync | none (git transport) | still none, as long as forge calls stay in discovery/pre-flight |

The design consequence is a clean separation: **git owns the sync loop; the forge CLIs own the inventory and the pre-flight.** Neither the reading agents nor the per-repo refresh path ever depend on `gh` or `glab` being installed, authenticated, or under quota.

## Verification pass (2026-09-07)

Second pass over the two items this file had marked as unfetchable. Each was resolved on the first URL tried; the rendered `docs.gitlab.com/cli/` pages were not needed.

| # | Item | Outcome | Source |
|---|---|---|---|
| 1 | `glab repo view` flags and JSON output (Section 2.4) | **Resolved.** Synopsis "Display the description and README of a project, or open it in the browser." Flags: `-b, --branch string` ("View a specific branch of the repository."), `-w, --web` ("Open a project in the browser."), `-F, --output string` ("Format output as: text, json. (default "text")"), `--jq string` ("Filter JSON output with a jq expression."). Repository argument accepts none (current git dir), `user/repo`, `group/namespace/repo`, SSH URL, HTTPS URL. So a JSON output flag exists; Section 2.4 was rewritten to use `-F json --jq .default_branch` with the `glab api` route kept as the fallback for older releases. The JSON field names are not listed on the page, so `default_branch` is inferred from the REST project object and flagged for a one-time local check. | [gitlab-org/cli, docs/source/repo/view.md](https://gitlab.com/gitlab-org/cli/-/raw/main/docs/source/repo/view.md) |
| 2 | `glab auth status` behaviour and exit codes (Section 6.1) | **Partly resolved.** Description "View authentication status"; checks the current-context instance (from `git remote`, `GITLAB_HOST`, or config) by default; flags `-a, --all`, `--hostname string` (no `-h` short form — `-h` is help, which corrected an error in the earlier text), `-t, --show-token` ("Display the authentication token"). **Exit codes are not documented** on the page, nor is the exact field list printed. Section 6.1 now says so and tells the operator to confirm the exit code once with a bogus `GITLAB_TOKEN` before relying on it in `repo_sync_preflight`. | [gitlab-org/cli, docs/source/auth/status.md](https://gitlab.com/gitlab-org/cli/-/raw/main/docs/source/auth/status.md) |

Still unverified after this pass: the exit code of `glab auth status` on a rejected token (not in the docs; needs a local run), and the JSON key names emitted by `glab repo view -F json` (needs a local run).

### Local verification on the target machine (2026-09-07)

Run on the user's Mac (Darwin 25.6, `git 2.50.1 (Apple Git-155)`, `zsh 5.9`, `glab 1.112.0`, `gh` present, `gitup` absent). These are observations from the shell, not documentation quotes, so they settle the "needs a local run" items above for this machine only.

| Item | Observation |
|---|---|
| `git fetch --atomic --porcelain` | Accepted by the installed git (`--dry-run` exit 0), so no minimum-version concern here (Section 1). |
| `git stash push` on a clean tree | Prints nothing to stdout, exits **0**, stash list unchanged (Section 3 "observed behaviour" now confirmed locally). |
| `refs/remotes/origin/HEAD` | Present in this clone (`refs/remotes/origin/main`); existence must still be checked per repo (Section 2). |
| zsh `wait -n` | **Unsupported** in zsh 5.9: `zsh:wait:1: job not found: -n`, exit 127. Do not depend on it (Section 4). |
| `zsystem flock` | Available after `zmodload zsh/system` (Section 5). |
| `flock(1)` / `shlock(1)` / `mv -h` | `flock` not installed; `/usr/bin/shlock` present; `mv` usage line shows `-h` (Section 5). |
| `/etc/zprofile` | Lines 10-11 call `/usr/libexec/path_helper -s`, confirming the `zsh -f`/non-login PATH caveat (Section 4.6). |
| `glab repo view -F json` | Emits the GitLab Projects API object; the key **`default_branch`** is present (`glab repo view gitlab-org/cli -F json` → `main`), so `--jq .default_branch` is correct (Section 2.4). |
| `glab auth status` exit code | Exits **1** when any configured host fails (`--all` with one host returning 401 → exit 1 even though the other host is logged in), and exits 1 with `GITLAB_TOKEN=bogus`. Consequence: a stale token for an unrelated host makes the pre-flight fail; scope pre-flight with `--hostname` (Section 6.1). |
| `glab repo list` | `-F json`, `--jq`, `-G/--include-subgroups` (default false), `-P/--per-page` default **30**, `-p/--page` — matches Section 6.3. |
| `glab auth git-credential` | Exists; `--help` documents no flags beyond `-h`, so the helper line remains `credential.helper = !glab auth git-credential` by analogy with `gh`, unconfirmed by glab docs. |
