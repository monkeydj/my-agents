# Agent 1: Off-the-shelf multi-repo sync CLIs

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

## 1. Landscape inventory

**Context for this section.** The requirement is a tool that, from one command, fetches and fast-forwards the major branches (`main`/`master`/`release*`) of a fixed set of local git checkouts on macOS, non-interactively. This inventory lists every candidate found; the later sections judge them against that requirement. Facts marked "(not verified)" could not be confirmed from the tool's own docs during this research pass and should be treated as unknown, not as true.

A first landscape search ([LibHunt gita alternatives](https://www.libhunt.com/r/gita), [frontaid/git-cli-tools list](https://github.com/frontaid/git-cli-tools)) confirms the field splits into three families, and that split matters more than any single feature:

1. **Registered-list / directory-scan runners** (gita, mu-repo, gitup, gitbatch, gws, git-bulk, gr, mani) — they operate on repos you already have, which is exactly the "set of local git repo directories" the developer has. Best natural fit.
2. **Manifest / workspace tools** (myrepos, tsrc, vcstool, Google repo, west, meta, mgit) — they own the checkout layout from a manifest file; they can update existing checkouts but expect to have cloned them.
3. **Forge-driven bulk tools** (ghorg, git-xargs, all-repos) — they enumerate repos from GitHub/GitLab APIs and clone/patch them; primarily for org-wide clone or org-wide code changes, not for keeping hand-chosen local checkouts fresh.

Summary from the same search: gita shows a consolidated status view and batch-executes git commands over registered repos, including recursive directory add and auto-grouping ([nosarthur/gita README](https://github.com/nosarthur/gita)); mu-repo "helps you execute the same commands in multiple git repositories" ([fabioz/mu-repo](https://github.com/fabioz/mu-repo)); git-xargs is a Gruntwork tool that applies a script across many GitHub repos in parallel via goroutines and opens PRs ([git-xargs](https://github.com/gruntwork-io/git-xargs)).

### 1.1 Inventory table

Columns: language; macOS install route; last release / commit signal; stars or maintenance signal; config style. Each row is refined below as tool docs are fetched.

| Tool | Language | macOS install | Last release / activity | Stars / maintenance signal | Config style |
|---|---|---|---|---|---|
| gita | Python 3.6+ | `pipx install gita`, `uv tool install gita`, or `pip3 install -U gita` ([README](https://github.com/nosarthur/gita)) | v0.16.8.2 released 2025-11-17 ([PyPI](https://pypi.org/project/gita/)); requires Python 3.8+ per PyPI (README still says 3.6+) | ~1.9k stars, ~495 commits ([README](https://github.com/nosarthur/gita)) | registered list: `gita add <paths>`, `gita add -r` (recursive), `gita add -a` (recursive + auto-groups), `gita add -b` (bare repos); state kept in `$XDG_CONFIG_HOME/gita`; user-defined commands in `cmds.json` |
| mu-repo | Python | `pipx install mu-repo` (PyPI name `mu-repo`; docs index links an Install page but does not inline the command) ([docs](https://fabioz.github.io/mu-repo/)) | latest listed version 1.8.0; no release date shown on docs index ([docs](https://fabioz.github.io/mu-repo/)) | maintenance signal pending (PyPI check below) | registered list: `mu register repo1 repo2` writes a `.mu_repo` file in the current dir; serial vs parallel toggled via `.mu_repo` or `MU_REPO_SERIAL=True\|False` env var ([docs](https://fabioz.github.io/mu-repo/)) |
| myrepos (mr) | Perl (single script) | `brew install myrepos` (Homebrew formula exists; site's Install page not fetched) | v1.20180726, released 2018-07-26; last site news item 2020-04-23 — effectively dormant ([myrepos](https://myrepos.branchable.com/)) | maintenance signal: no release in 8 years; still packaged in Debian/Homebrew | registered list: run `mr register` inside each repo, which appends a `[path]` section to `~/.mrconfig` (INI-style, `[DEFAULT]` for globals, per-repo command overrides) ([myrepos](https://myrepos.branchable.com/)) |
| ghorg | Go | `brew install ghorg` ([README](https://github.com/gabrie30/ghorg)) | ~1,022 commits on master; actively maintained (exact latest tag not captured) | ~2.1k stars, Apache-2.0 ([README](https://github.com/gabrie30/ghorg)) | forge API enumeration: `ghorg clone <org-or-group> --scm=gitlab --base-url=...`; GitLab groups and subgroups supported; tokens via `GHORG_GITLAB_TOKEN` / `GHORG_GITHUB_TOKEN` env or `--token=<file>` ([README](https://github.com/gabrie30/ghorg)) |
| git-xargs | Go | `brew install git-xargs` ([README](https://github.com/gruntwork-io/git-xargs)) | GitHub page partially failed to load; release date **not verified** | ~1.1k stars ([README](https://github.com/gruntwork-io/git-xargs)) | forge API enumeration (GitHub / GitHub Enterprise only — no GitLab mentioned); clones each repo into `/tmp`, runs a script, commits, opens PRs; `--max-concurrent-clones` default 4; `--dry-run`, `--skip-pull-requests` ([README](https://github.com/gruntwork-io/git-xargs)) |
| meta | JavaScript (Node) | `npm i -g meta` | pending | pending | `.meta` manifest JSON |
| tsrc | Python | `pipx install tsrc` (install page not fetched; PyPI name `tsrc`) | version/date pending (CLI reference fetched below) | maintenance signal pending | manifest repo: a `manifest.yml` kept in its own git repo, `repos:` list of `dest`/`url` (+ optional `branch`, groups, multiple remotes, fixed refs); `tsrc init <manifest url>` then `tsrc sync` ([tsrc docs](https://your-tools.github.io/tsrc/)) |
| mani | Go | `brew tap alajmo/mani && brew install mani` ([README](https://github.com/alajmo/mani)) | releases exist on the GitHub releases page; exact latest tag/date pending (checked below) | ~761 stars ([README](https://github.com/alajmo/mani)) | `mani.yaml` manifest of projects + tasks; `mani init` auto-discovers `.git` dirs beneath cwd to seed the manifest (`--auto-discovery=false` to disable); `mani exec --all <cmd>` and `--parallel`; `--output table` ([README](https://github.com/alajmo/mani)) |
| gitbatch | Go | `brew install gitbatch` | pending | pending | directory scan, TUI |
| vcstool | Python | `pipx install vcstool` | pending | pending | `.repos` YAML manifest + directory scan |
| all-repos | Python | `pipx install all-repos` | pending | pending | `all-repos.json` config + forge source plugins |
| Google repo | Python | `brew install repo` | pending | pending | XML manifest in a manifest git repo |
| gr (git-run) | JavaScript (Node) | `npm i -g git-run` | pending | pending | tags on registered paths (`~/.grconfig.json`) |
| gitup (git-repo-updater) | Python 3.10+ | `brew install gitup`, `pipx install gitup`, `uv tool install gitup`, `pip install gitup` ([README](https://github.com/earwig/git-repo-updater)) | ~170 commits on main; PyPI page failed to load during this pass (client error), and the GitHub Releases page says "There aren't any releases here" ([releases](https://github.com/earwig/git-repo-updater/releases)) — the project ships via PyPI/Homebrew without GitHub releases, so the exact latest release date is **not verified**; the Python 3.10+ floor in the README implies activity no older than late 2021 | ~839 stars ([README](https://github.com/earwig/git-repo-updater)) | hybrid: positional dirs (`gitup ~/repos/foo`), directory scan with `--depth` (default 3), and persistent bookmarks (`gitup --add ~/repos/foo`, then bare `gitup`) ([README](https://github.com/earwig/git-repo-updater)) |
| gws | Bash | git clone / AUR | pending | pending | `.projects.gws` manifest in a workspace dir |
| git-bulk | Bash (git-extras) | `brew install git-extras` | pending | pending | registered "workspaces" in git config |
| west | Python | `pipx install west` | pending | pending | `west.yml` manifest (Zephyr) |
| mgit | Go (Vanderbilt/Go) or Python (several projects share the name) | varies | pending | pending | varies; see note |

Further candidates surfaced by the search and worth a row once verified: `git-plus` (Python, `git multi`), `mgitstatus` (Bash, status-only), `gitman`, `uncommitted`, `repo-sync`. These are lower priority because they either do not pull or do not target fixed local sets.

## 2. Default-branch handling

**Why this section matters.** The requirement has four hard parts: (a) pick the right major branch per repo (`main` vs `master` vs `release/*`), (b) fast-forward only, (c) never touch a dirty working tree, (d) ideally update branches that are not currently checked out (so the human can stay on a feature branch while `main` is refreshed). Almost every tool below only does "run `git pull` in each repo on whatever branch is checked out", which fails (a), (c) and (d) by construction. Findings per tool follow.

### 2.1 Per-tool notes (running list)

**mu-repo.** The commands page documents `mu upd` as "Fetches changes for the current branch and compares the current branch with the fetched changes (using WinMerge or meld)" — a preview/diff tool aimed at an interactive GUI merge, not an unattended updater ([mu-repo commands](https://fabioz.github.io/mu-repo/commands/)). Serial vs parallel is a setting (`mu set-var serial=0|1`). No documented fast-forward-only mode, no documented dirty-tree guard, and update scope is the current branch only. Everything else (`mu up`, `mu pull`) is a pass-through of the same git subcommand to every registered repo, so any FF-only or dirty-skip behaviour must come from git itself (e.g. `mu pull --ff-only`), and git's own `pull --ff-only` will still refuse (non-zero exit) rather than skip when the tree is dirty and a merge is needed. Verdict on (a)/(c)/(d): no / no / no.

**myrepos (mr).** `mr update` runs "the default `git pull`" for git repos, and the update command is overridable per repo in `.mrconfig` (e.g. `update = git pull --ff-only` or any shell snippet) ([myrepos](https://myrepos.branchable.com/)). Because the per-repo `update` action is arbitrary shell, mr *can* be configured to fetch and then `git fetch origin main:main` for a non-checked-out branch — but that logic is yours to write; mr provides only the loop, the `-j` parallelism, and the "remember actions that failed offline, retry later" queue ([myrepos](https://myrepos.branchable.com/)). Verdict: (a) only via hand-written config; (b) only if you write `--ff-only`; (c) no built-in guard; (d) possible via custom `update` command. Net: mr is a scheduler for your own script, not a solution by itself, and it has had no release since 2018.

**gitup (git-repo-updater).** This is the only tool in the set whose documented default behaviour matches the requirement almost exactly. Per its README: it "will fetch all remotes in a repository" (or only the current branch's upstream with `--current-only`/`-c`), then "will try to fast-forward all branches that have upstreams configured", and it skips any branch where a fast-forward is not possible — the README names "dirty working directory" and "merge/rebase needed" as the skip reasons ([README](https://github.com/earwig/git-repo-updater)). Merges and rebases are never performed. `--fetch-only`/`-f` skips the fast-forward step; `--prune`/`-p` deletes stale remote-tracking refs ([README](https://github.com/earwig/git-repo-updater)).
Mapping to the four hard parts: (a) it does not *pick* `main`/`master`/`release*` — it fast-forwards *every* local branch with an upstream, which is a superset (feature branches with upstreams also get fast-forwarded, harmless because FF-only cannot lose commits); (b) yes, FF-only by design; (c) yes for the checked-out branch — a dirty tree causes a skip, not a stash or a merge; (d) yes — non-checked-out branches with upstreams are fast-forwarded directly (the README describes updating all upstream-tracking branches, which necessarily includes ones not checked out). Open questions to verify by reading source or testing: whether a *diverged* non-checked-out branch is silently skipped (expected) and what the process exit code is when some branches skip (README does not state it).

**ghorg.** Disqualifying by default for this use case. When the target directory already exists, `ghorg clone` runs `git pull` **and then `git clean`**, and the README warns in its own words: "All local changes in the cloned directory by default will be overwritten by what's on GitHub" ([README](https://github.com/gabrie30/ghorg)). `--no-clean` suppresses the clean step, but the underlying update is still a plain `git pull` on the checked-out branch — no FF-only guarantee, no dirty-tree skip, no non-checked-out branch update. `--branch` sets one branch name for the whole run, which cannot express "main here, master there, release/* over there". Verdict: (a) no, (b) no, (c) **actively destructive unless `--no-clean`**, (d) no. ghorg's real strength — enumerating a whole GitLab group including subgroups over the API and cloning it with `--concurrency` (default 25) — is a *bootstrap* capability, not a refresh capability.

**git-xargs.** Out of scope by design: it clones every target repo fresh into `/tmp`, runs a script, commits, and opens a pull request; it has no mode for operating on existing local checkouts, and its docs mention only GitHub and GitHub Enterprise, not GitLab ([README](https://github.com/gruntwork-io/git-xargs)). Verdict: not applicable to (a)–(d). Ruled out for this requirement (kept in the inventory because it is frequently named alongside the others).

**mani.** The README and the docs introduction describe `mani sync` only as "clone all repositories" / "Clone multiple repositories with a single command" with the completion line "All projects synced" ([README](https://github.com/alajmo/mani), [manicli.com](https://manicli.com/)). Neither page documents any pull or fast-forward step for repos that already exist, so mani's built-in sync does not satisfy the update requirement on its own. What mani does offer is a clean *runner*: `mani exec --all <shell>` / `mani run <task>` with `--parallel`, project tags/paths for filtering, and a manifest that `mani init` can seed by scanning for `.git` folders ([README](https://github.com/alajmo/mani)). So mani, like myrepos, is a candidate host for a custom per-repo update snippet (e.g. a task that runs `git fetch --prune && git fetch origin main:main`), not a solution by itself. Verdict: (a)–(d) only via a user-written task. Error/exit-code semantics are not documented on the pages fetched — **not verified**.

**tsrc.** The CLI reference documents `tsrc sync` as: "If any of the repositories is not on the configured branch, but it is clean and the `--no-correct-branch` flag is NOT set, then the branch is changed to the configured one and then the repository is updated" ([tsrc CLI reference](https://your-tools.github.io/tsrc/ref/cli/)). Two consequences for this requirement. First, (a) is handled: the manifest carries a per-repo `branch`, so `main` here and `master` there is expressible, and `release/*` can be written as an explicit branch per repo (no glob). Second, (c) is handled defensively: a dirty repo on the wrong branch is left alone rather than switched. However the default behaviour *checks out* the manifest branch on a clean repo — which is precisely the "moves the human off their branch" behaviour the requirement forbids; `--no-correct-branch` disables the switch, but then the update happens only if the repo is already on the configured branch. (d) — updating a non-checked-out branch — is not supported: tsrc updates the checked-out branch. Whether the update is FF-only or a merge, and the exact exit code on partial failure, is not stated on the reference page — **not verified**. `tsrc foreach` runs a command in every repo and "report[s] failures at the end" rather than aborting on the first failure ([tsrc CLI reference](https://your-tools.github.io/tsrc/ref/cli/)). Verdict: (a) yes via manifest, (b) not verified, (c) yes (skips dirty), (d) no.

## 3. Parallelism, speed, and failure reporting

[To be filled by research agent]

## 4. Unattended and remote fit

[To be filled by research agent]

## 5. Fit scoring and shortlist

[To be filled by research agent]
