# Agent 3: Remote invocation and agent-facing operation

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

## 1. Trigger channels

**Context for this section.** The refresh script itself is owned by another agent. What matters here is *who* may cause it to run, *when*, and *with what privileges*. Six channels are realistic for a single developer's Mac; they are not mutually exclusive, and the recommendation at the end of the section combines two of them.

### 1.1 SSH forced command (`authorized_keys` `command=`)

This is the simplest remote trigger: another machine holds a dedicated SSH key, and the Mac's `~/.ssh/authorized_keys` pins that key to exactly one command.

How the mechanism works, quoting the OpenBSD `sshd(8)` manual ([sshd(8), AUTHORIZED_KEYS FILE FORMAT](https://man.openbsd.org/sshd.8)):

- `command="command"` — "Specifies that the command is executed whenever this key is used for authentication. The command supplied by the user (if any) is ignored." The consequence: the remote caller cannot run anything else with that key, even if the key leaks.
- The caller's requested command is still visible: "The command originally supplied by the client is available in the `SSH_ORIGINAL_COMMAND` environment variable." This lets one key dispatch a small allowlist (`refresh all`, `refresh repo-x`, `status`) inside a wrapper script, instead of one key per verb.
- `restrict` — "Enable all restrictions, i.e. disable port, agent and X11 forwarding, as well as disabling PTY allocation and execution of ~/.ssh/rc." Use `restrict` rather than enumerating `no-pty,no-port-forwarding,no-agent-forwarding,no-X11-forwarding` individually, because `restrict` also covers restrictions added in future OpenSSH releases.
- `from="pattern-list"` — "either the canonical name of the remote host or its IP address must be present in the comma-separated list of patterns." Adds a network-origin check on top of the key.
- `environment="NAME=value"` — lets the key line inject a fixed `PATH` or a `REFRESH_PROFILE=...` variable, which matters because a forced-command shell is non-interactive and will not source `.zshrc` (see the PATH discussion under cron/launchd below).

A minimal line therefore looks like:

```
restrict,from="10.0.0.0/8",command="/Users/me/bin/repo-refresh-dispatch" ssh-ed25519 AAAA... trigger@laptop
```

Trade-offs:

| Aspect | Assessment |
|---|---|
| Setup cost | Lowest of all channels: one key, one `authorized_keys` line, macOS Remote Login toggle. |
| Attack surface | One pinned command; `restrict` blocks forwarding and PTY. The wrapper must still validate `SSH_ORIGINAL_COMMAND` against an allowlist and never pass it to a shell unquoted. |
| Reach | Requires network reachability to the Mac (LAN, VPN, or Tailscale-style overlay). No inbound reachability means this channel is dead; pair it with a timer. |
| Concurrency | Two callers can connect at once, so the dispatched script must take a lock (Section 3). |
| Login-session dependence | None. `sshd` runs as a system daemon, so this works while the user is logged out, unlike a LaunchAgent. The caveat is FileVault: after a reboot, no user volume is unlocked until someone logs in at the console, so the repos are unreadable until then. |

**Verdict:** the best *on-demand* channel for a personal setup. It should not be the *only* channel, because it depends on the other machine remembering to call it.

### 1.2 launchd on macOS (LaunchAgent vs LaunchDaemon)

launchd is the native scheduler; cron on macOS is a compatibility shim that itself runs under launchd. Apple's Daemons and Services Programming Guide ([Creating Launch Daemons and Agents](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingLaunchdJobs.html)) gives the operative distinctions:

- Three plist locations: `/Library/LaunchDaemons` (system-wide, runs at boot as root or a configured user, no GUI session needed), `/Library/LaunchAgents` (per-user, for every user who logs in), and `~/Library/LaunchAgents` (per-user, only the owning user). The guide states that user agents run when the user is logged in, which is the whole trade-off: an agent in `~/Library/LaunchAgents` sees your keychain and your `ssh-agent`, but stops existing when you log out; a LaunchDaemon survives logout but has no login keychain or agent socket (see Section 4).
- `StartInterval` is an integer number of seconds; the guide's example uses `300` for a five-minute cadence.
- `StartCalendarInterval` is a dictionary of `Minute`/`Hour`/`Day`/`Weekday`/`Month`; keys left out are treated as wildcards, so `{Minute: 0}` means "every hour on the hour".
- `KeepAlive` controls "whether your daemon launches on-demand or must always be running". For a refresh job you do *not* want `KeepAlive` true — that is for long-running listeners (the webhook receiver in 1.5), not for a run-to-completion fetch script.
- `WorkingDirectory`, `StandardOutPath`, `StandardErrorPath` and `EnvironmentVariables` are the keys you will need, because a launchd job inherits almost no environment: no `~/.zshrc`, no Homebrew `PATH`, no `SSH_AUTH_SOCK` for a daemon. The guide defers full key semantics to `launchd.plist(5)`; those are added below.

The `launchd.plist(5)` manual ([launchd.plist(5), Xcode man pages mirror](https://keith.github.io/xcode-man-pages/launchd.plist.5.html)) settles the scheduling semantics that decide which key to use:

- `StartInterval`: "If the system is asleep during the time of the next scheduled interval firing, that interval will be missed due to shortcomings in kqueue(3). If the job is running during an interval firing, that interval firing will likewise be missed." Consequence: a laptop that sleeps overnight silently skips refreshes, and a slow fetch that overlaps the next tick drops that tick rather than queuing it. The second property is useful (free overlap protection); the first is a liability.
- `StartCalendarInterval`: "Unlike cron which skips job invocations when the computer is asleep, launchd will start the job the next time the computer wakes up. If multiple intervals transpire before the computer is woken, those events will be coalesced into one event upon wake from sleep." Consequence: for a laptop, prefer `StartCalendarInterval` (e.g. every 30 minutes via an array of `{Minute: 0}` and `{Minute: 30}`) over `StartInterval`, so the first wake after sleep triggers exactly one catch-up refresh.
- `KeepAlive`: "The default is false and therefore only demand will start the job... Jobs that exit quickly and frequently when configured to be kept alive will be throttled... The use of this key implicitly implies RunAtLoad." Leave it unset for the refresh job; set it (with `SuccessfulExit: false` or plain `true`) only for a long-lived webhook listener.
- `RunAtLoad`: "This key should be avoided, as speculative job launches have an adverse effect on system-boot and user-login scenarios." A one-off refresh at login is nonetheless a reasonable use of it here, because the whole point is catching up after the machine was off.
- `ThrottleInterval`: "by default, jobs will not be spawned more than once every 10 seconds." Irrelevant for a 30-minute cadence, relevant if a webhook listener respawns the refresh per event.
- `ProcessType`: "If left unspecified, the system will apply light resource limits to the job, throttling its CPU usage and I/O bandwidth." Set `ProcessType` to `Background` for the refresh (it is exactly a background job and the throttling is acceptable), or `Standard` if fetches of large repos are visibly slow.
- `EnvironmentVariables` and `WorkingDirectory` are the only environment knobs; nothing sources your shell rc files. The man page does not describe the inherited environment, so the practical rule is: set `PATH` explicitly to include `/opt/homebrew/bin` (or `/usr/local/bin`), and never rely on aliases or zsh functions inside the job.
- `LimitLoadToSessionType` "only applies to jobs which are agents. There are no distinct sessions in the privileged system context." An agent limited to `Aqua` (the GUI session) will not run over an SSH-only login; `Background` session type is the one that runs whenever the user has any session.

Trade-offs for launchd as the trigger:

| Aspect | LaunchAgent (`~/Library/LaunchAgents`) | LaunchDaemon (`/Library/LaunchDaemons`) |
|---|---|---|
| Runs while logged out | No | Yes (but the user's home volume may be locked under FileVault until first login) |
| Has login keychain / `SSH_AUTH_SOCK` | Yes | No; must use a key file or token in a file (Section 4) |
| Needs `sudo` to install | No | Yes, and the plist must be root-owned |
| Sleep behaviour | `StartCalendarInterval` catches up on wake | Same |
| Fits the "personal Mac" case | Best default | Only if the Mac is a headless always-on box |

**Verdict:** a `~/Library/LaunchAgents` plist with `StartCalendarInterval` is the baseline *unattended* channel. It is local-only; it does not by itself satisfy "triggerable remotely", so it is paired with the SSH forced command from 1.1 (both call the same script, which takes the same lock).

### 1.3 cron on macOS

cron still exists on macOS but is a second-class citizen, and two macOS-specific problems make it a worse choice than launchd for this job:

1. **Full Disk Access (TCC).** Since Mojave/Catalina, the `cron` daemon is subject to the privacy sandbox (TCC). Jobs that touch protected locations (Desktop, Documents, Downloads, `~/Library`, removable volumes) fail with `Operation not permitted` until you add `/usr/sbin/cron` itself to *System Settings > Privacy & Security > Full Disk Access* — the binary, not your script ([OS X Daily, Fix Cron Permission Issues](https://osxdaily.com/2020/04/27/fix-cron-permissions-macos-full-disk-access/); [Nono Martínez Alonso, Operation not permitted on Sonoma](https://nono.ma/operation-not-permitted-macos-sonoma)). Apple Developer Forums threads confirm this persists on Sonoma and that even with Full Disk Access some per-user locations such as `~/.Trash` remain blocked for the daemon ([Apple Developer Forums thread 745692](https://developer.apple.com/forums/thread/745692); [thread 118508, daemons unable to access files](https://developer.apple.com/forums/thread/118508)). If your repos live under `~/Documents` (as this workshop does), a cron job cannot read them without the FDA grant. A `~/Library/LaunchAgents` job runs in the user's own session and inherits the user's TCC grants, which is why launchd sidesteps most of this.
2. **PATH and shell.** cron runs jobs with a minimal `PATH` (`/usr/bin:/bin`) and does not source `~/.zshrc`, so `git` from Homebrew, `glab`, and `gh` are not found unless the crontab sets `PATH=` explicitly or the script uses absolute paths. Since Catalina the login shell is zsh, so environment set up for bash is not visible either ([Apple Community thread 254531320](https://discussions.apple.com/thread/254531320)).

cron also inherits the sleep behaviour launchd documents against it: "cron ... skips job invocations when the computer is asleep" ([launchd.plist(5)](https://keith.github.io/xcode-man-pages/launchd.plist.5.html)).

**Verdict:** use cron on macOS only for portability with a Linux box that runs the same script. Otherwise launchd wins on sleep handling and TCC.

### 1.4 systemd timers on Linux

(Relevant only if one of the repo hosts is a Linux box, or the trigger machine is Linux and runs the SSH call from 1.1 on a timer.)

systemd timers are the Linux analogue of `StartCalendarInterval`, and they have two properties launchd lacks, per the `systemd.timer(5)` manual ([systemd.timer(5), man7.org mirror](https://man7.org/linux/man-pages/man5/systemd.timer.5.html)):

- `Persistent=`: "If true, the time when the service unit was last triggered is stored on disk." With `Persistent=true`, a timer that was due while the machine was off fires once on the next boot — the same catch-up semantics launchd gives `StartCalendarInterval` on wake, but also covering full power-off, which launchd does not.
- Overlap protection is built in: "in case the unit to activate is already active at the time the timer elapses it is not restarted, but simply left running." A `.service` that is still fetching when the next tick lands is left alone, so the service itself needs a lock only to guard against *other* triggers (SSH, webhook), not against its own timer.
- `RandomizedDelaySec=` "Delay the timer by a randomly selected, evenly distributed amount of time between 0 and the specified time value. Defaults to 0." Useful when several machines poll the same GitLab instance so they do not all hit it at :00.
- `AccuracySec=` "Defaults to 1min." A 30-minute cadence does not care; a "refresh 1 minute after the hour so CI has pushed" schedule does, so set `AccuracySec=1s` in that case.
- `WakeSystem=` can resume a suspended machine; pointless for a repo mirror and a battery drain on a laptop — leave it false.
- `OnCalendar=` takes calendar expressions such as `*:0/30` (every 30 minutes) — the direct equivalent of the two-dictionary `StartCalendarInterval` array.

One operational caveat not in the man page excerpt: a *user* timer (`~/.config/systemd/user/`) only runs while that user has a session unless lingering is enabled with `loginctl enable-linger <user>`. This is the exact analogue of the LaunchAgent-vs-LaunchDaemon split in 1.2.

**Verdict:** if the refresh ever runs on Linux, use a `.timer` with `Persistent=true` plus a `Type=oneshot` `.service`; you get free overlap protection and boot catch-up. On macOS, launchd is the equivalent and there is no reason to port systemd concepts across.

### 1.5 Forge push webhooks to a small listener

Instead of polling on a timer, the forge tells you when a major branch moved. This is event-driven and near-instant, but it requires a listener process reachable from GitLab/GitHub, which for a laptop behind NAT means a tunnel (Cloudflare Tunnel, Tailscale Funnel, ngrok) or a relay host that in turn calls the SSH forced command of 1.1.

GitLab project webhooks, per the official docs ([GitLab Docs, Webhooks](https://docs.gitlab.com/user/project/integrations/webhooks/)):

- Authentication is a shared secret: the `X-Gitlab-Token` header is "Secret token for the webhook, sent as plain text. Included only when a secret token is configured." The listener must compare it in constant time and reject everything else; because it is plain text, the endpoint must be HTTPS.
- Event type is in `X-Gitlab-Event`, "Corresponds to event types in the format `<EVENT> Hook`" — so `Push Hook` is what the listener filters on.
- Push events can be limited server-side to the branches you care about: "wildcard patterns (e.g., `*-stable`), regular expressions (RE2 syntax), or 'All branches'". Configure the filter as a regex such as `^(main|master|release.*)$` so feature-branch pushes never reach the listener at all.
- Failure handling is aggressive: temporary disable "after 4 consecutive failures; initially disabled for one minute, extending to 24 hours on subsequent failures", and permanent disable "after 40 consecutive failures; webhooks do not auto-re-enable." Failures include 4xx/5xx responses and timeouts. Consequence: a laptop that is asleep half the day will get its webhook permanently disabled within a couple of weeks unless the listener lives on an always-on host. This is the single strongest argument against pointing GitLab directly at the Mac.
- GitLab's own guidance is to decouple receipt from work: "Respond quickly with a `200` or `201` status... Avoid processing webhooks in the same request. Use a queue to handle webhooks after receiving them." For our case the "queue" can be as small as touching a `refresh-requested` marker file that the launchd job (1.2) picks up on its next tick, or immediately invoking the refresh script in the background with the same lock everything else uses.

GitHub's equivalent, per its webhook best-practices page ([GitHub Docs, Best practices for using webhooks](https://docs.github.com/en/webhooks/using-webhooks/best-practices-for-using-webhooks)):

- Deadline: "Your server should respond with a 2XX response within 10 seconds of receiving a webhook delivery." A `git fetch` of a large repo does not fit in 10 seconds, which is the same "ack then work" constraint GitLab states.
- "Your server can respond when it receives the webhook, and then process the payload in the background without blocking future webhook deliveries."
- Idempotency: "You can use the `X-GitHub-Delivery` header to ensure that each delivery is unique per event", and redeliveries keep the same GUID. The listener should remember recent GUIDs so a manual redelivery from the GitHub UI does not trigger a second refresh (harmless with fast-forward-only, but wasteful).
- Authentication uses a webhook secret; GitHub signs each payload and the receiver validates the signature (the `X-Hub-Signature-256` HMAC-SHA-256 header, documented on GitHub's separate "Validating webhook deliveries" page, which this fetch did not cover). Unlike GitLab's plain-text token, the secret never travels on the wire.

The architectural conclusions are identical to GitLab's: ack fast, enqueue, and keep the receiver on a host that is always up.

**Verdict:** webhooks are the only channel that gives sub-minute freshness, but the disable-on-failure policy makes them a poor fit for a machine that sleeps. If you want them, run the receiver on an always-on relay (a $5 VPS, a home server, or a GitLab CI scheduled job) that records "repo X changed" and lets the Mac pull that state on its own schedule or via the SSH trigger. For a personal knowledge-base use case, a 15–30 minute timer is usually good enough and avoids the whole listener.

### 1.6 Claude Code scheduling: `/loop`, `/schedule` routines, and Desktop scheduled tasks

Claude Code now has three scheduling surfaces, and only one of them can touch the Mac's filesystem. The distinction matters because "the agent refreshes the repos itself" sounds attractive but mostly does not work for this use case.

- **`/loop`** re-runs a prompt or slash command on an interval inside the *current* session. It is session-bound: it stops when the terminal session ends ([wmedia.es, /schedule vs /loop vs cron](https://wmedia.es/en/tips/claude-code-schedule-vs-loop-vs-cron)). It runs locally, so it *can* call the refresh script, but it is only alive while you have Claude Code open — it is a convenience for an active work session, not an unattended mechanism.
- **`/schedule` / routines** create schedule-triggered routines that run on Anthropic-managed cloud infrastructure, triggered by a cron schedule, an HTTP API call, or a GitHub event ([Anthropic blog, Introducing routines in Claude Code](https://claude.com/blog/introducing-routines-in-claude-code); [Builder.io, Claude Code Routines Tutorial](https://www.builder.io/blog/claude-code-routines)). Two facts disqualify them as the refresh trigger for local checkouts: they run in the cloud against repositories cloned there, not against `~/Documents/...` on your Mac, and the minimum interval is one hour with schedules evaluated in UTC ([makerkit, Claude Code Routines guide](https://makerkit.dev/blog/tutorials/claude-code-routines-guide)). They *are* a fit for the relay role from 1.5: a routine with a GitHub-event trigger could, on push to `main`, call your SSH forced command or hit a small "refresh requested" endpoint — but that is a roundabout way to get what a webhook gives directly, and it only covers GitHub, not GitLab.
- **Desktop scheduled tasks** are machine-bound and require the Mac to be powered on ([wmedia.es](https://wmedia.es/en/tips/claude-code-schedule-vs-loop-vs-cron)). Functionally they are a launchd job with an LLM in the loop; for a deterministic `git fetch` you do not want an LLM in the loop, both for cost and because a hallucinated `git reset --hard` is exactly the failure mode this whole design exists to prevent.

**Verdict:** none of the Claude Code scheduling features should *perform* the refresh. The right relationship is inverted: the refresh runs on launchd/SSH, and Claude Code sessions *consume* the freshness contract from Section 3. `/loop` is fine as a manual "poll status every 5 minutes while I work" aid.

### 1.7 Exposing the refresh as an MCP tool (on-demand from agents)

Agents that build the knowledge base (Claude Code sessions, codebase-memory-mcp) sometimes know they want fresh data *now* — for example just before `index_repository`. Exposing `refresh_repos` and `refresh_status` as tools on a tiny local MCP server (stdio transport, launched by Claude Code itself) gives them that without granting shell access.

What the MCP specification requires of such a server, and how it shapes the design ([MCP Specification 2025-06-18, Tools](https://modelcontextprotocol.io/specification/2025-06-18/server/tools)):

- Tools are "model-controlled, meaning that the language model can discover and invoke tools automatically", but "there **SHOULD** always be a human in the loop with the ability to deny tool invocations." In Claude Code this is the permission prompt. A `refresh_repos` tool is safe to allowlist, because the underlying script is fast-forward-only and never touches the human's working tree; a hypothetical `reset_repo` tool would not be.
- Each tool carries an `inputSchema` (JSON Schema), optional `outputSchema`, and optional `annotations`. If an `outputSchema` is provided, "Servers **MUST** provide structured results that conform to this schema" and return them in `structuredContent`, with the same JSON serialised in a text block for backward compatibility. This is where the freshness JSON from Section 3 should be returned verbatim: define `refresh_status`'s `outputSchema` as the contract schema, and agents get typed data instead of parsing prose.
- Two error channels: protocol errors (JSON-RPC `error`, for unknown tool or invalid arguments) versus "Tool Execution Errors: Reported in tool results with `isError: true`" for things like "API failures... Business logic errors". A repo that could not be fast-forwarded (diverged branch, auth failure) is a *tool execution* result — `isError: true` with the per-repo detail in the content — not a protocol error, because the call itself was valid and the other repos may have succeeded.
- Servers "**MUST**: Validate all tool inputs, Implement proper access controls, Rate limit tool invocations, Sanitize tool outputs." For us: validate `repos` against the configured allowlist (never accept arbitrary paths), and rate-limit by simply reusing the refresh lock — a second `refresh_repos` while one is running should return the in-progress status, not start another fetch.
- Clients "**MUST** consider tool annotations to be untrusted unless they come from trusted servers", so `readOnlyHint`/`destructiveHint` annotations on `refresh_status` (read-only) and `refresh_repos` (non-destructive but not read-only) are useful documentation but not a security boundary.
- `notifications/tools/list_changed` exists but is irrelevant here; the tool list is static.

Proposed tool surface (two tools, both thin wrappers around the same script the launchd job and SSH forced command call):

| Tool | Input | Output | Notes |
|---|---|---|---|
| `refresh_status` | `{ repos?: string[] }` | The Section 3 status document, `structuredContent` conforming to its schema | Read-only; safe to auto-allow. This is what `detect_changes` callers should read first. |
| `refresh_repos` | `{ repos?: string[], wait?: boolean }` | Same status document after the run (or immediately with `state: "running"` if `wait` is false or a run is in progress) | Non-destructive (fast-forward-only). Returns `isError: true` if any requested repo failed, with per-repo detail. |

Note that codebase-memory-mcp already exposes `index_repository` and `detect_changes`; the refresh server is deliberately separate so the memory server never needs network credentials. Agents compose them: `refresh_repos` → read status → `detect_changes` → `index_repository` where needed.

**Verdict:** worth building only once the launchd + SSH path works. It is a convenience layer for agents, not a trigger channel the human relies on.

### 1.8 Channel comparison and recommendation

| Channel | Unattended | Remote trigger | Works logged out | Freshness | Setup | Main risk |
|---|---|---|---|---|---|---|
| SSH forced command (1.1) | No (needs a caller) | Yes | Yes (`sshd` is a daemon) | On demand | Low | Needs network path to the Mac |
| LaunchAgent + `StartCalendarInterval` (1.2) | Yes | No | No | Cadence you choose; catch-up on wake | Low | Skips while logged out |
| LaunchDaemon (1.2) | Yes | No | Yes | Same | Medium (root, no keychain) | Auth without login keychain |
| cron (1.3) | Yes | No | Yes | Skips during sleep | Low, but TCC grant needed | FDA for `/usr/sbin/cron`, bare PATH |
| systemd timer (1.4) | Yes | No | With linger | Catch-up on boot (`Persistent=`) | Low | Linux only |
| Forge webhook → listener (1.5) | Yes | Yes (forge-initiated) | Listener must be always-on | Seconds | High (tunnel/relay, HTTPS, secret) | Auto-disable after 4/40 failures if the host sleeps |
| Claude Code `/loop`, routines (1.6) | Routines yes, `/loop` no | Routines via API/GitHub event | Cloud only | ≥1 hour (routines) | Low | Cannot touch local disk; LLM in the loop |
| MCP tool (1.7) | No (agent-initiated) | Only from agents on this machine | Only while a client is attached | On demand | Medium | Not a trigger for humans |

**Recommendation for the stated setup (one macOS laptop, GitLab primary, agents reading locally):**

1. Baseline: a `~/Library/LaunchAgents` job on a `StartCalendarInterval` every 15–30 minutes, `ProcessType=Background`, explicit `PATH`, logging to `~/Library/Logs/repo-refresh/`. This covers "unattended".
2. Remote trigger: a dedicated SSH key with `restrict,command=` pointing at the same dispatcher script, reachable over your VPN/overlay network. This covers "triggerable remotely from another machine" with a one-line change and no listener.
3. Agent on-demand: the two-tool MCP server from 1.7, once the contract in Section 3 exists.
4. Skip webhooks unless you already run an always-on host; if you do, have it record "changed" and call channel 2, rather than pointing GitLab at the laptop.

All four entry points call one script that takes one lock, so the concurrency story is identical regardless of who triggered the run.

## 2. Mirror architecture for agents

**Context for this section.** The human already has a normal clone of each repo with in-progress work in it. The agents want a checkout of `main`/`master`/`release*` that is (a) never half-updated when they read it and (b) never the same working tree the human is editing. The question is how many copies of the objects and the files that costs, and which git primitive gives the cleanest separation. Four layouts are compared; the recommendation is at 2.6.

### 2.1 The primitives, from git's own documentation

All of the layouts below are built from a handful of `git clone` options. Their exact semantics, quoted from the `git-clone(1)` manual ([git-scm.com, git-clone](https://git-scm.com/docs/git-clone)), decide which layout is safe:

- `--bare`: "make the *<directory>* itself the `$GIT_DIR`... the branch heads at the remote are copied directly to corresponding local branch heads, without mapping them to `refs/remotes/origin/`. When this option is used, neither remote-tracking branches nor the related configuration variables are created." Consequence: a bare clone has *no* working tree, so there is nothing for a human to edit and nothing for an agent to read directly — it is a pure object-and-ref store.
- `--mirror`: "implies `--bare`. Compared to `--bare`, `--mirror` not only maps local branches of the source to local branches of the target, it maps all refs (including remote-tracking branches, notes etc.) and sets up a refspec configuration such that all these refs are overwritten by a `git remote update` in the target repository." Consequence: a mirror is *by design* overwritten on update — that is what makes it a faithful copy of the forge, and also what makes it unsuitable as anything a human commits into. The overwrite-all refspec is exactly the property the human's working clone must never have; keeping the mirror as a separate directory is what isolates the two.
- `--reference=<repository>`: "automatically setup `.git/objects/info/alternates` to obtain objects from the reference *<repository>*. Using an already existing repository as an alternate will require fewer objects to be copied from the repository being cloned, reducing network and local storage costs." `--reference-if-able` degrades gracefully: "a non existing directory is skipped with a warning instead of aborting the clone."
- `--shared`: "instead of using hard links, automatically setup `.git/objects/info/alternates` to share the objects with the source repository. The resulting repository starts out without any object of its own." The manual then warns: "this is a possibly dangerous operation... If you clone your repository using this option and then delete branches (or use any other Git command that makes any existing commit unreferenced) in the source repository, some objects may become unreferenced (or dangling). These objects may be removed by normal Git operations (such as `git commit`) which automatically call `git maintenance run --auto`... If these objects are removed and were referenced by the cloned repository, then the cloned repository will become corrupt." Consequence: alternates are only safe when the *source* of the objects is a repository whose refs only ever move forward and never get deleted — which is true of a fast-forward-only mirror of protected branches, and false of the human's working clone, where feature branches are deleted every week.
- `--dissociate`: "Borrow the objects from reference repositories specified with the `--reference` options only to reduce network transfer, and stop borrowing from them after a clone is made by making necessary local copies of borrowed objects." Consequence: this is the escape hatch — network savings without the corruption coupling — at the price of a full second copy of the objects on disk.
- `--local` (default for a path source): "clones the repository by making a copy of `HEAD` and everything under objects and refs directories. The files under `.git/objects/` directory are hardlinked to save space when possible." The manual adds: "this operation can race with concurrent modification to the source repository, similar to running `cp -r <src> <dst>` while modifying <src>." Consequence: a local clone taken *from* the mirror must happen while the mirror is not mid-fetch — another reason the refresh lock from Section 3 covers clone/worktree creation, not only fetch.
- The `--shared` section also documents the maintenance rule that governs long-lived alternates: "running `git repack` without the `--local` option in a repository cloned with `--shared` will copy objects from the source repository into a pack in the cloned repository, removing the disk space savings... It is safe, however, to run `git gc`, which uses the `--local` option by default." Consequence: if the agent checkouts borrow from the mirror, never run `git repack -a` inside them (it silently duplicates the store); `git gc` is fine.

### 2.2 Layout A — plain checkout per repo (the baseline)

The simplest thing: a second ordinary clone per repo, in a directory the human never opens, updated with a fast-forward-only pull of each major branch. Objects are stored twice (human clone + agent clone), the working tree is stored twice, and the update is a fetch followed by an in-place checkout move.

When it is enough: repos are small (tens of MB), only one branch per repo matters to agents, and the "never half-updated" requirement is satisfied by the contract in Section 3 (lock + status file) rather than by the filesystem layout. The weakness is that the in-place `checkout`/`merge --ff-only` rewrites files under a reader's feet; git updates the index and working tree file-by-file, so a reader that walks the tree during the update sees a mix of old and new files. That is tolerable if readers check the status file first and re-run when the run id changed, and intolerable if readers are dumb (a grep over a directory).

### 2.3 Layout B — one bare mirror per repo, one linked worktree per major branch

This is the layout the rest of the document assumes. Per repo: `~/mirrors/<repo>.git` (a `--mirror` clone, or a `--bare` clone with an explicit `+refs/heads/main:refs/heads/main`-style refspec restricted to the major branches) plus `~/mirrors/<repo>/main`, `~/mirrors/<repo>/release-2026.09`, etc., each created with `git worktree add`.

What `git-worktree(1)` guarantees about that arrangement ([git-scm.com, git-worktree](https://git-scm.com/docs/git-worktree)):

- "A git repository can support multiple working trees, allowing you to check out more than one branch at a time... The new worktree is linked to the current repository, sharing everything except per-worktree files such as `HEAD`, `index`, etc." Consequence: N branches of one repo cost one object store plus N working trees. There is no second copy of history, and a fetch into the bare repo makes the new commits visible to every worktree at once.
- A bare repository can own linked worktrees: "A repository has one main worktree (if it's not a bare repository) and zero or more linked worktrees." So the mirror stays bare — no working tree anyone could accidentally edit — and every checkout agents read is a linked worktree.
- The one-branch-one-worktree rule: "`add` refuses to create a new worktree when *<commit-ish>* is a branch name and is already checked out by another worktree", with `--force` and `--detach` as the escape hatches. Consequence: for agent consumption, create the worktrees **detached** (`--detach`) at the branch tip rather than checking the branch out. Detaching avoids the collision when two agents want their own `main` snapshot, and it stops the worktree from having a branch that a stray `git pull` inside it could move; the refresh job moves the detached HEAD to the new tip after the fetch.
- Per-worktree metadata lives in `$GIT_DIR/worktrees/<name>`, with `$GIT_COMMON_DIR` pointing back at the bare repo. Deleting a worktree directory by hand leaves that metadata behind; it is "eventually removed automatically (see `gc.worktreePruneExpire`)", or immediately with `git worktree prune`. A refresh job that recreates worktrees should run `prune` first so names are stable.
- `--lock`/`--reason` at `add` time "is the equivalent of `git worktree lock` after `git worktree add`, but without a race condition", and the lock file is plain text: "The file contains the reason in plain text." Consequence: this is a cheap way to tag agent worktrees with *why* they exist (`--reason "codebase-memory-mcp index of main"`) and to protect them from being pruned if they live on a volume that is sometimes unmounted ("If a working tree is stored on a portable device or network share which is not always mounted, you can prevent its administrative files from being pruned").
- `git worktree repair` exists because "if the main worktree (or bare repository) is moved, linked worktrees will be unable to locate it." Consequence: the mirror root must be treated as a fixed path in the contract (Section 3); moving `~/mirrors` means running `repair` for every worktree, so do not put the mirror under a directory that gets renamed.

Trade-offs:

| Aspect | Assessment |
|---|---|
| Disk | One object store per repo (shared by all branches) + one working tree per branch. For a repo whose `.git` is larger than its checkout, this roughly halves the cost of a per-branch plain clone. |
| Isolation from the human | Complete: different directory, bare store, detached HEADs. The human's clone and the mirror never share a `.git`. |
| Atomicity of the update | Not provided by git itself — `git checkout --detach <new-tip>` inside a worktree still rewrites files in place. Atomicity comes from Section 2.5 (snapshot directories) or the Section 3 lock. |
| Second fetch of the same objects | Yes: the human's clone and the mirror both fetch from the forge. Bandwidth is doubled but the two are decoupled, which is the point. See 2.4 for reclaiming the disk half of that cost. |

### 2.4 Layout C — sharing objects between the mirror and other clones (alternates)

`objects/info/alternates` is a list of other object directories git will consult when it cannot find an object locally. Two directions are possible and only one is safe:

1. **Human clone borrows from the mirror** (`git clone --reference ~/mirrors/<repo>.git <url>` for new clones, or adding the mirror's `objects` path to an existing clone's `objects/info/alternates`). The mirror only ever fast-forwards protected branches and never deletes refs, so its objects are never unreferenced and the `--shared` corruption warning quoted in 2.1 does not bite. The human's clone becomes small (it holds only feature-branch objects the mirror has not seen) and its fetches become fast because git skips objects already reachable via the alternate. This is how Sourcegraph, GitLab (via Gitaly object pools) and the `repo` tool amortise objects across many checkouts — see Section 5.
2. **Mirror borrows from the human clone.** Unsafe, for the exact reason the manual gives: the human deletes merged branches, `git maintenance run --auto` prunes, and the mirror's history is corrupted with no error until an agent reads it.

Rules that keep direction 1 safe, both from the `--shared` text in 2.1: never run `git repack -a` inside the borrowing clone (it copies the borrowed objects in, silently discarding the savings, though it is not dangerous); `git gc` is fine because it uses `--local`. And never delete or rewrite the mirror without first running `git repack -a` (or `git clone --dissociate`) in every clone that borrows from it.

**Honest assessment for one developer:** the disk saved is one copy of `.git` per repo. Unless the repos are multi-gigabyte monoliths (the case Sourcegraph and Gitaly optimise for), the coupling is not worth it: a broken alternate produces "fatal: bad object" errors in the *human's* repo, which is a worse failure than the extra disk. Recommendation: use `--reference --dissociate` only for the *initial* clone of a large repo to save network time, then let the two stores stand alone.

### 2.5 Layout D — read-only snapshot directories with an atomic pointer flip

If the readers cannot be trusted to check a status file (plain `grep -r`, an indexer that walks the tree, an editor that watches files), the only way to guarantee they never see a half-updated tree is to never modify a tree they might be reading. Instead:

1. Fetch into the bare mirror (invisible to readers; only the object store and refs change).
2. Create a *new* worktree at the new tip in a fresh directory named by the commit or a run id, e.g. `~/mirrors/<repo>/.snapshots/main@<sha>`.
3. Flip a symlink `~/mirrors/<repo>/main -> .snapshots/main@<sha>` with a `rename(2)` of a temporary symlink over the old one. POSIX `rename` on the same filesystem replaces the target atomically, so a reader that resolves `main` sees either the old or the new snapshot, never a mixture; a reader already *inside* the old directory keeps a consistent view until it finishes, because that directory is untouched.
4. Delete snapshots older than the current and previous one, after a grace period long enough for an in-flight `index_repository` to finish (Section 3 makes the grace period explicit).

This is precisely the pattern the kubernetes `git-sync` sidecar implements (details in Section 5.6). The cost is a second working tree per repo for the duration of the grace period, and a worktree create/remove per refresh instead of an in-place checkout. On APFS, worktree creation is dominated by writing the checkout — there is no copy-on-write shortcut for git's object-to-file materialisation — so for a repo with a 1 GB working tree, each refresh writes 1 GB. For repos with checkouts in the tens of MB (most service repos) this is negligible.

One subtlety for agents: `codebase-memory-mcp` and Claude Code record *paths*. If the recorded path is the symlink `~/mirrors/<repo>/main`, the agent always follows the latest flip, which is desired for `detect_changes`. If a tool canonicalises the path (`realpath`), it will record `.snapshots/main@<sha>` and hold on to a snapshot that is due for deletion. The contract in Section 3 therefore publishes both the stable path and the resolved snapshot path, and the deletion grace period exists for exactly this case.

### 2.6 When a plain checkout is enough, and the recommendation

| Situation | Layout |
|---|---|
| A few small repos, readers always consult the status file, single agent at a time | **A** (plain second clone) — least moving parts. |
| Several branches per repo matter (`main` + `release*`), or several agents read concurrently | **B** (bare mirror + detached worktrees) — one store, N trees. |
| Multi-GB repos where a second `.git` hurts | **B + C** in direction 1 only, with the dissociate caveat. |
| Readers are dumb (filesystem walkers, watchers), or "never half-updated" is a hard requirement rather than a convention | **B + D** — snapshot worktrees behind a symlink flip. |

Recommendation for the stated setup: **B + D**. The bare mirror is the only thing that fetches, so credentials (Section 4) are needed in exactly one place; detached worktrees mean no branch can be accidentally moved by a reader; the symlink flip is what makes "never half-updated" true regardless of who is reading, rather than true only for readers that follow the contract. Layout A is acceptable as a first iteration if the snapshot step is added later — the status file in Section 3 is designed so readers cannot tell the difference.

## 3. Consistency contract

**Context for this section.** Layout B+D from Section 2 makes each *tree* consistent. It does not tell an agent which tree is current, whether a refresh is running, when the last one succeeded, or what changed since the agent last looked. That is what the contract is for: a small amount of metadata, written by exactly one process (the refresh script) and read by everyone else. The section first collects the evidence git and prior art already give, then proposes the contract.

### 3.1 The reference implementation of "never half-updated": kubernetes/git-sync

git-sync's README states the problem in one sentence and its solution in one paragraph, both worth quoting because they are the design this document copies ([kubernetes/git-sync README](https://github.com/kubernetes/git-sync/blob/master/README.md)):

- The problem: "git checkouts are not 'atomic' operations. If you look at the repository while a checkout is happening, you might see data that is neither exactly the old revision nor the new."
- The solution: git-sync "fetches data without checking it out, creates a new worktree, then updates the symlink". Inside `--root`, "Multiple worktrees exist as subdirectories, each named by the git hash of its revision", and "A symlink (controlled by `--link`...) points to the current worktree", so "The symlink target's basename indicates the currently synced commit hash."

Three further behaviours of git-sync map directly onto contract fields:

- **Freshness signal to consumers is push, not poll.** `--exechook-command` "Executes after syncing a new hash, with the synced repo as working directory" and "Sets `$GITSYNC_HASH` environment variable"; `--webhook-url` sends an HTTP request "after sync completion" with header `Gitsync-Hash`. Both are "Invoked even if correct hash already present at startup; must be idempotent", and "Both hooks execute asynchronously and are not guaranteed exactly-once delivery per hash." Consequence for us: the refresh script should offer a post-success hook (touch a marker, call `detect_changes`, or POST to a local endpoint), and consumers must treat it as at-least-once — idempotency comes from keying on the commit hash, not on the event.
- **Stale snapshot retention is a tunable, not an afterthought.** `--stale-worktree-timeout`: "Duration before removing worktrees no longer targeted by the symlink. Defaults to 0 (immediate removal)." Immediate removal is fine for a sidecar whose only reader is the same pod; for our multi-agent case a non-zero grace period is required because an indexer may still be walking the previous snapshot (see 2.5). The contract exposes this as `retain_previous_for_seconds`.
- **Failure policy is explicit.** `--max-failures`: "Consecutive failures allowed before aborting; negative values retry indefinitely (defaults to 0, terminating on any failure)", with `--sync-timeout` "Total time allowed per complete sync (... defaults to '120s')". Consequence: our status document records `consecutive_failures` per repo so agents can distinguish "stale because the laptop was asleep" from "stale because auth has been broken for three days".

The README also notes the symlink basename *is* the commit hash, which means a reader can learn the current revision with a single `readlink` and no git invocation — a property worth preserving in our directory naming (`.snapshots/main@<sha>`).

### 3.2 What git itself records, and why it is not enough

Git leaves evidence of every fetch, and it is tempting to let agents read that instead of a custom status file. The `git-fetch(1)` manual ([git-scm.com, git-fetch](https://git-scm.com/docs/git-fetch)) describes what is available:

- `FETCH_HEAD`: "The names of refs that are fetched, together with the object names they point at, are written to `.git/FETCH_HEAD`. This information may be used by scripts or other git commands." It is written by default (`--write-fetch-head`... "This is the default"), and "Under `--dry-run` option, the file is never written." Consequence: the file's mtime is a usable "last fetch *attempted and reached the ref-listing stage*" timestamp, and its contents tell you which refs were fetched. It does **not** tell you whether the worktrees were subsequently updated, whether the fast-forward check passed, or whether the run completed — a fetch that succeeded followed by a worktree step that crashed leaves a fresh `FETCH_HEAD` and a stale checkout.
- `--atomic`: "Use an atomic transaction to update local refs. Either all refs are updated, or on error, no refs are updated." Consequence: the refresh should fetch all major branches of one repo in a single `--atomic` fetch so the mirror's refs never show `main` at the new tip and `release-x` at the old one. This is atomicity of *refs*, though, not of *files*; the working tree still needs Section 2.5.
- `--porcelain` output is "machine-parseable": `<flag> <old-object-id> <new-object-id> <local-reference>`. Consequence: the refresh script gets old and new SHAs per ref for free and can write them into the status document, which is exactly the `previous_commit`/`commit` pair `detect_changes` wants.
- Fast-forward enforcement is a refspec property: "Whether an update is allowed without `--force` depends on... whether the update is considered to be a fast-forward", and "All of the rules described above about what's not allowed as an update can be overridden by adding an optional leading `+` to a refspec (or using the `--force` command line option)." Consequence: a `--mirror` clone's default refspec is `+refs/*:refs/*` — the plus sign means it *will* accept a force-pushed `main`. If the contract promises fast-forward-only, the mirror must use a refspec without `+` for the protected branches (or the script must compare old/new with `git merge-base --is-ancestor` and record `diverged: true` instead of updating). The manual's note on rebased branches ("its new tip will not be a descendant of its previous tip... You would want to use the `+` sign") is the case we explicitly refuse for major branches.
- `--prune` "remove[s] any remote-tracking references that no longer exist on the remote" — relevant for `release*` branches that get deleted after a release is superseded. Pruning changes the set of worktrees the contract lists, so a pruned branch must appear in the status document as `state: "removed"` for one cycle before its worktree and snapshots are deleted, giving indexers a chance to drop the project.

The reflog is the other native record: every ref update in the mirror appends a line with old SHA, new SHA, timestamp and message, provided reflogs are enabled. Whether they are enabled by default in a bare repository is a configuration question; the rendered `git-config(1)` page on git-scm.com is too long to fetch in one piece (the fetch truncated before the `core.*` variables), so the answer below is taken from git's own documentation source tree instead.

`core.logAllRefUpdates`, per git's config documentation source ([git/git, Documentation/config/core.adoc](https://github.com/git/git/blob/master/Documentation/config/core.adoc)): "Updates to a ref *<ref>* is logged to the file `$GIT_DIR/logs/<ref>`, by appending the new and old SHA-1, the date/time and the reason of the update, but only when the file exists. If this configuration variable is set to `true`, missing `$GIT_DIR/logs/<ref>` file is automatically created for branch heads (i.e. under `refs/heads/`), remote refs..., note refs..., and the symbolic ref `HEAD`. If it is set to `always`, then a missing reflog is automatically created for any ref under `refs/`." And the default that matters here: "This value defaults to true in repositories with working directories and false in bare repositories."

Consequence: **a bare mirror has no reflog unless you turn it on.** Set `core.logAllRefUpdates=true` in the mirror at creation time; the refresh then gets, for free, an append-only per-branch history of `<old> <new> <timestamp> <reason>` that an agent can read with `git reflog show refs/heads/main` to answer "what did `main` point to when I indexed last Tuesday?" without any custom bookkeeping. It costs one small file per branch. This is the audit trail; the status document below is the *current-state* view. The two are complementary — the reflog cannot say whether the worktree flip completed, and the status document does not keep history.

Summary of why git's native records are evidence but not the contract:

| Native record | Answers | Cannot answer |
|---|---|---|
| `FETCH_HEAD` mtime + contents | when refs were last listed from the forge; which refs | whether the fast-forward check passed; whether worktrees were updated; whether the run finished |
| Mirror reflog (`logs/refs/heads/*`) | full history of tip movements with timestamps | whether a *reader-visible* snapshot exists for that tip; whether a run is in progress |
| `readlink` on the snapshot symlink | the SHA readers currently see, with no git call | when it was made; whether a newer fetch already succeeded but the flip is pending |
| Lock file presence | a run is in progress | how far along it is; which repos are done |

### 3.3 Locking

All four entry points from Section 1 call one script, so the script needs exclusive execution per repo (and ideally a global lock for the whole run, to keep the status document's `run_id` coherent). Requirements the lock must meet on macOS:

- **Stale-safe.** A refresh killed by sleep, a crashed terminal, or `kill -9` must not leave the mirror locked forever. A lock file containing a PID is not enough on its own (PIDs are reused); `flock(2)`-style advisory locks are released by the kernel when the holder dies, which is why they are preferred. macOS ships `flock(2)` as a syscall but not the `flock(1)` utility from util-linux; the practical options are `shlock`, a `mkdir`-based lock with a stale-age check, or a tiny Python/`perl -MFcntl` one-liner around `flock`. The choice is the other agent's (shell syntax); the *contract* only requires that a reader can tell "locked" from "abandoned", which is why the status document carries `run.started_at` and `run.pid` and readers treat a lock older than `2 × expected_duration` with a dead PID as abandoned.
- **Scoped per repo, held across fetch *and* flip.** Section 2.1 quoted the `--local` clone race ("similar to running `cp -r <src> <dst>` while modifying <src>") and Section 2.3 noted `git worktree add` reads the object store. The lock therefore wraps the whole sequence *fetch → verify fast-forward → create snapshot worktree → flip symlink → write status → prune old snapshots*, not just the fetch.
- **Readers never take the lock.** Agents read the status document and the symlinked snapshot; they must not block the refresh. The symlink flip is what makes lock-free reading safe (a reader inside an old snapshot keeps a consistent tree until the grace period ends).
- **Second trigger while running returns, does not queue.** launchd already drops overlapping `StartInterval` firings (Section 1.2), systemd leaves the running unit alone (1.4), and the MCP tool returns `state: "running"` (1.7). The script should do the same: if the lock is held, exit 0 with the current status document on stdout. A "run again after this one" flag is a reasonable extension but not required — the next timer tick covers it.

### 3.4 What the consumers actually accept

Before proposing fields, it is worth pinning down what the two consumers can *use*, taken from the tool schemas `codebase-memory-mcp` exposes to this Claude Code session (read from the live MCP tool definitions, not from documentation):

- `index_repository` requires `repo_path` and accepts `mode` (`full` | `moderate` | `fast` | `cross-repo-intelligence`, default `full`), `name` ("Override the derived project name"), `persistence` (default `false`; "Write compressed artifact to `.codebase-memory/graph.db.zst` for team sharing"), and `target_projects` for the cross-repo mode, whose description warns "Ensure target projects have fresh indexes first."
- `detect_changes` requires `project` and accepts `since` ("Git ref or tag to compare from (e.g. `HEAD~5`, `v0.5.0`). Diffs `<ref>...HEAD`."), `base_branch` (default `main`), `depth` (default 2) and `scope`.
- `index_status` takes `project` and reports the index state.

Three consequences shape the contract:

1. **The project name must be explicit.** The server derives a project name from `repo_path` when `name` is omitted. With Layout B+D, `repo_path` is either the stable symlink `~/mirrors/<repo>/main` — whose basename is `main` for *every* repo, so all repos would collide on one project — or the resolved `.snapshots/main@<sha>`, whose basename changes on every refresh and would create a new project per commit. The contract therefore carries a `project` field per branch (e.g. `orders-service@main`), and agents always pass it as `name` to `index_repository` and as `project` to `detect_changes`/`index_status`.
2. **`since` wants a git ref, and the contract can supply one that is guaranteed to resolve.** `detect_changes` diffs `<since>...HEAD` inside the checkout. Because the snapshot worktree is detached at the branch tip, `HEAD` is the current tip, and any SHA the mirror has ever fetched is in the shared object store, so passing the SHA recorded at the previous successful index works. The contract records `commit` (current tip) and `previous_commit` (tip before this run) per branch; the *agent* additionally remembers `last_indexed_commit` in its own state and passes that as `since`, falling back to `previous_commit` if it has none. Relative refs like `HEAD~5` are a poor fit here because the number of new commits per refresh is unknown.
3. **`persistence: true` writes into the checkout.** The artifact goes to `<repo_path>/.codebase-memory/graph.db.zst`, i.e. *inside* the snapshot directory, which is untracked, per-SHA, and deleted when the snapshot is rotated. Either leave `persistence` off for mirror-backed indexing, or point the indexer at the stable symlink and accept that the artifact vanishes on the next flip. The contract does not try to solve this; it flags it as `notes.persistence_unsafe: true` so an agent does not waste an index run.

### 3.5 The proposed minimal contract

**Location.** One JSON document per mirror root at `~/mirrors/.status/refresh.json`, written atomically (write to `refresh.json.tmp`, `fsync`, `rename` over the old file — the same POSIX guarantee the symlink flip relies on, so a reader never sees a truncated file). Optionally one `~/mirrors/<repo>/.status.json` per repo with the same per-repo object, for agents that only care about one repo. A `~/mirrors/.status/refresh.lock` sits beside it while a run is in progress.

**Writer.** Only the refresh script, and only while holding the lock. Nothing else — not the MCP wrapper from 1.7, not agents — writes to this file. The MCP `refresh_status` tool returns its contents verbatim as `structuredContent`.

**Readers.** Claude Code sessions (via `cat`, or via the MCP tool), `codebase-memory-mcp` callers deciding between `detect_changes` and `index_repository`, and humans debugging.

**Fields.**

```json
{
  "schema_version": 1,
  "mirror_root": "/Users/me/mirrors",
  "run": {
    "run_id": "2026-09-07T10:30:02Z-7f3a",
    "state": "idle | running | failed",
    "trigger": "launchd | ssh | mcp | manual",
    "started_at": "2026-09-07T10:30:02Z",
    "finished_at": "2026-09-07T10:30:41Z",
    "pid": 48213,
    "expected_duration_seconds": 45
  },
  "last_success_at": "2026-09-07T10:30:41Z",
  "retain_previous_for_seconds": 1800,
  "repos": {
    "orders-service": {
      "remote": "git@gitlab.example.com:group/orders-service.git",
      "mirror": "/Users/me/mirrors/orders-service.git",
      "fetched_at": "2026-09-07T10:30:11Z",
      "state": "ok | unchanged | diverged | auth_failed | network_failed | removed",
      "consecutive_failures": 0,
      "error": null,
      "branches": {
        "main": {
          "project": "orders-service@main",
          "path": "/Users/me/mirrors/orders-service/main",
          "snapshot_path": "/Users/me/mirrors/orders-service/.snapshots/main@9c1e...",
          "commit": "9c1e...",
          "previous_commit": "4b77...",
          "committed_at": "2026-09-07T09:58:13Z",
          "changed": true,
          "fast_forward": true,
          "notes": { "persistence_unsafe": true }
        },
        "release-2026.09": { "...": "..." }
      }
    }
  }
}
```

Field semantics that matter for correctness:

- `run.state` is `running` from lock acquisition to lock release; readers that find `running` should use the *previous* `repos` data (which the writer leaves intact until the run completes — the document is rewritten once at the end, not incrementally) and re-check after `expected_duration_seconds`. A `running` state whose `pid` is dead and whose `started_at` is older than twice `expected_duration_seconds` is treated as `failed` by readers; the next run overwrites it.
- `last_success_at` is the field a Claude Code session should compare against its own idea of "fresh enough". It moves only when *every* repo in the run reached `ok` or `unchanged`; per-repo `fetched_at` moves whenever that repo's fetch succeeded, so a single broken repo does not make the others look stale.
- `repos.*.state = diverged` means the forge's tip is not a descendant of the mirror's tip (someone force-pushed a protected branch). The mirror is **not** updated, the old snapshot stays current, and `consecutive_failures` increments. This is the fast-forward-only guarantee made visible; a human decides how to resolve it.
- `branches.*.changed` is `commit != previous_commit` for this run. An agent that indexes on every run can skip `detect_changes` entirely when it is `false`.
- `branches.*.path` is the stable symlink; `snapshot_path` is what it currently resolves to. Agents pass `path` to `index_repository` (so re-indexing later follows the flip) but may log `snapshot_path` for reproducibility. `retain_previous_for_seconds` is the promise that `snapshot_path` stays readable for at least that long after the next flip.
- `state = removed` appears for one run after a `release*` branch disappears upstream (Section 3.2, `--prune`); the following run deletes the worktree and the entry. Agents seeing `removed` should drop or archive the project.

**Decision rule for agents** (the whole point of the contract):

```
read refresh.json
if run.state == running and not abandoned → wait expected_duration_seconds, re-read
for each repo/branch of interest:
  if state in {auth_failed, network_failed, diverged} → use existing index, surface the error, do not re-index
  if index_status(project) says never indexed → index_repository(repo_path=path, name=project)
  elif changed → detect_changes(project, since=<my last_indexed_commit or previous_commit>)
                 then index_repository(..., mode=fast|moderate) if the change set is large
  else → nothing; index is current
record last_indexed_commit = commit
```

For `cross-repo-intelligence` mode, whose schema says "Ensure target projects have fresh indexes first", the rule is: run it only when `last_success_at` is newer than every target project's last index time, otherwise refresh the stale ones first.

**What the contract deliberately leaves out.** No history (the mirror reflog has it, Section 3.2), no per-file change lists (`detect_changes` computes those from git), no scheduling information (Section 1 owns cadence), no credentials or remote URLs beyond the read-only `remote` string for identification. Keeping it to one writer and one rename-replaced file is what makes it trustworthy.

### 3.6 One refresh run, end to end

The sequence below is the whole design in execution order, with the section that justifies each step. It is what every trigger channel in Section 1 ends up running, and what every reader in Section 3.5 relies on.

```
trigger (launchd tick | ssh forced cmd | mcp refresh_repos | manual)       — 1.1, 1.2, 1.7
  → acquire ~/mirrors/.status/refresh.lock; if held → print refresh.json, exit 0   — 3.3
  → write refresh.json with run.state=running (rename-replace)                — 3.5
  → read manifest (repo list, branch patterns, groups)                        — 5.2
  → for each repo (honouring backoff; SSH/MCP triggers skip backoff):         — 5.1
      → git fetch --atomic --porcelain, non-'+' refspecs for main|master|release*   — 3.2
          credentials: core.sshCommand + deploy key | '!' helper + GIT_TERMINAL_PROMPT=0   — 4.3, 4.6
      → per branch: old/new SHA from porcelain output
          new not descendant of old → state=diverged, keep old snapshot, failures++   — 3.5, 5.4
          new == old                → state=unchanged
          else                      → git worktree add --detach .snapshots/<branch>@<sha>   — 2.3
                                      (git lfs fetch/checkout if repo uses LFS)          — 5.4
                                      rename tmp symlink over <branch> link               — 2.5, 3.1
                                      state=ok, changed=true
      → ref pruned upstream → state=removed for one run, delete next run     — 3.2
  → delete snapshots older than previous, past retain_previous_for_seconds   — 3.1, 3.5
  → write refresh.json with run.state=idle, last_success_at if all ok         — 3.5
  → post-success hook (touch marker | POST | notify), idempotent by SHA       — 3.1
  → release lock

reader (Claude Code session | codebase-memory-mcp caller)
  → read refresh.json (or mcp refresh_status)                                 — 1.7, 3.5
  → running and not abandoned → wait expected_duration_seconds, re-read
  → per project: never indexed → index_repository(path, name=project)
                 changed        → detect_changes(project, since=<last_indexed_commit>)
                 else           → nothing                                      — 3.4
  → record last_indexed_commit = commit
```

Two invariants hold at every point in that sequence. A reader following `<branch>` sees either the previous complete snapshot or the new complete snapshot, never a partial one, because the only mutation of the visible path is a `rename(2)` of a symlink. The human's clone is never referenced by any step, because the mirror has its own object store and its own credential; there is no code path from this script into the human's working tree.

## 4. Unattended auth

**Context for this section.** The refresh runs from launchd (Section 1.2) or an SSH forced command (1.1), i.e. in a shell that is non-interactive, has no TTY, may have no GUI login session, and — for a LaunchDaemon or a fresh SSH login — has no `ssh-agent` and no unlocked login keychain. Whatever credential the mirror fetch uses must (a) work under those conditions, (b) be read-only, and (c) be scoped to as few repos as possible, because it will sit on disk for a year. The section compares the credential *types* first (4.1–4.3), then where to store them on macOS (4.4), then the mechanics of making git and the forge CLIs find them without a human (4.5–4.7).

### 4.1 GitLab: project and group access tokens

GitLab's project access tokens are the intended credential for "a machine reads this project", per the official page ([GitLab Docs, Project access tokens](https://docs.gitlab.com/user/project/settings/project_access_tokens/)):

- Identity: "GitLab creates a bot user and associates it with the token." The bot is "non-billable" and does not count against seats; on expiry or revocation the bot is "retained for 30 days" before deletion. Consequence: pushes and fetches show up in audit logs as the bot, not as you, which is exactly what you want for an unattended job — a leak is distinguishable from your own activity.
- Lifetime: "If you do not enter a date, the expiry date is set to 365 days from today", and "By default, the expiry date cannot be more than 365 days from today" (administrators can raise this from GitLab 17.6, and a feature flag allows 400 days). Tokens "expire at midnight UTC on the expiry date." Consequence: the refresh **will** stop working once a year with no warning other than `auth_failed` in the status document (Section 3.5). Record the expiry date in the same secret store entry and have the script emit a warning when it is within 14 days.
- Git usage over HTTPS: "Use: Any non-blank value as a username. The project access token as the password." Consequence: the remote URL can be `https://oauth2@gitlab.example.com/group/repo.git` (or any placeholder user) with the token supplied by a credential helper (4.5) — never embedded in the URL, which would land it in `.git/config` and in `ps` output.
- Availability: "Tier: Free, Premium, Ultimate" for self-managed and Dedicated; on GitLab.com project access tokens require Premium or Ultimate. Consequence: on a Free GitLab.com namespace, fall back to a deploy token (4.2) or an SSH deploy key (4.3).
- Scope selection is required ("Select one or more project access token scopes"). The scope reference ([GitLab Docs, Access token scopes](https://docs.gitlab.com/security/tokens/access_token_scopes/)) gives the one we want: `read_repository` — "Grants read access (pull) to repositories" via Git-over-HTTP or the repository files API, available on personal, group and project tokens. Its neighbours show what *not* to grant: `write_repository` "Grants read and write access (pull and push)"; `api` "Grants complete read and write access to the API"; `read_api` "Grants read access to the API for the token's scope". Consequence: the refresh token needs `read_repository` **only**. Do not add `read_api` "in case `glab` needs it" — `glab` is not required for a fetch (Section 4.6), and a fetch-only token cannot be turned into an API scraper if it leaks. `self_rotate` ("Grants permission to rotate this token. Cannot rotate other tokens") is the one optional addition worth considering, because it lets the refresh script rotate its own token before expiry without a human and without a broader `api` scope.

Rotation is atomic on the server side, per the personal-access-token page whose rules apply to project and group tokens as well ([GitLab Docs, Personal access tokens](https://docs.gitlab.com/user/profile/personal_access_tokens/)): "Rotate a token to create a new token with the same permissions and scope as the original. The original token becomes inactive immediately", and "Tools that rely on a rotated access token will stop working until you reference your new token." Consequence: rotation must be a two-step operation on your side — write the new token into the secret store *first*, then rotate on the forge — or the refresh fails for the interval between the two, showing up as `auth_failed` in the status document. The same page confirms the HTTPS username rule: "Can be any string value. Must not be an empty string."

Group access tokens are the same mechanism one level up: one bot, one token, every project in the group. For a knowledge base spanning a whole team's services that is the right granularity — one secret to rotate instead of one per repo — at the cost of a wider blast radius if it leaks. The read-only scope makes that radius "someone can read our source", which is the same radius as any developer's laptop.

### 4.2 GitLab: deploy tokens (the Free-tier, HTTPS, read-only answer)

Deploy tokens are the narrower, older sibling of project access tokens and, for a fetch-only mirror, arguably the better fit. From the official page ([GitLab Docs, Deploy tokens](https://docs.gitlab.com/user/project/deploy_tokens/)):

- Scope: `read_repository` — "Read-only access to the repository using `git clone`." The other scopes are all registry-related (`read_registry`, `write_registry`, `read_package_registry`, `write_package_registry`); there is no `api` and no `write_repository` scope at all. Consequence: even a mis-scoped deploy token cannot push code or call the API — "Deploy tokens can't be used with the GitLab public API." The worst case of a leak is read access to that one project.
- Expiry: "By default, a deploy token does not expire." "Deploy tokens expire on the date you define at 00:00 UTC", and from GitLab 18.3 project owners get email "at 60, 30, and 7 days before expiration". Consequence: this is the only GitLab credential type here that does not force an annual rotation; set an expiry anyway (two years is a reasonable compromise) so a forgotten token does not live forever.
- Tier: "Free, Premium, Ultimate" on GitLab.com, self-managed and Dedicated. Consequence: this is the credential to use on a Free GitLab.com namespace where project access tokens are unavailable (4.1).
- Identity: username defaults to `gitlab+deploy-token-{n}`; a custom username is allowed at creation. Consequence: pick a descriptive username (`mirror-refresh-macbook`) so the audit log is readable.
- Transport: "Deploy tokens do not support SSH authentication." HTTPS only, which means a credential helper (4.5) rather than an SSH key.
- Two caveats: deploy tokens "become unusable if external authorization is enabled" (an enterprise policy-server setting; if your instance uses it, use 4.1 or 4.3 instead), and they are per-project or per-group only — no cross-group token exists.

The documented clone form embeds the token in the URL (`https://<username>:<deploy_token>@gitlab.example.com/...`). Do not copy that into the mirror's `remote.origin.url`: it persists in `~/mirrors/<repo>.git/config` in plain text and appears in process listings during fetch. Configure the URL without the secret and let the credential helper supply it.

**Choosing between 4.1 and 4.2:** same scope name, same read-only guarantee. Deploy token wins on tier availability and absence of forced expiry; project/group access token wins if you also want a token that can `self_rotate` or if group-wide coverage matters and the group has many projects. For a personal knowledge base over one group on a paid tier, a group access token with `read_repository` is the least maintenance; on Free, one deploy token per project.

### 4.3 SSH: per-machine deploy keys versus agent forwarding

**Deploy keys.** GitLab's deploy keys are SSH public keys bound to a project rather than a user ([GitLab Docs, Deploy keys](https://docs.gitlab.com/user/project/deploy_keys/)): "In most cases, you use deploy keys to access a repository from an external host, like a build server or Continuous Integration (CI) server" — a description that fits an unattended mirror exactly. Properties that matter:

- Read-only by default: "A read-only deploy key can only read from the repository. A read-write deploy key can read from, and write to, the repository", with write access an explicit opt-in checkbox ("Grant write permissions to this key"). Consequence: a key added without that checkbox physically cannot push, which is a stronger guarantee than a token whose scope someone might later widen.
- Two scopes: a project deploy key ("Access is limited to the selected project") and a public deploy key ("Access can be granted to any project in a GitLab instance", "Shareable between multiple projects, even those in different groups"). Consequence: one key pair on the Mac, enabled on each repo the mirror covers — no per-repo secret sprawl — while still leaving the human's own SSH key out of the unattended path entirely.
- Expiry is optional ("Optional. Update the Expiration date"), so a deploy key can be the one credential here that does not have to be rotated on a calendar; the trade-off is that a stolen private key file is valid until you notice.
- Tier "Free, Premium, Ultimate"; adding one needs "the Maintainer or Owner role" on the project.
- The docs' comparison table draws the line with deploy tokens: deploy keys reach the "Git repository over SSH", deploy tokens the "Git repository over HTTP, package registry, and container registry." Consequence: the transport decides. If the Mac already reaches GitLab over SSH (typical for developers), a deploy key reuses that path and needs no credential helper; if only HTTPS is allowed through a proxy, use a token.

**Why not just forward the human's `ssh-agent`?** The human's key is loaded into `ssh-agent` in the GUI session, and a `~/Library/LaunchAgents` job (Section 1.2) inherits `SSH_AUTH_SOCK`, so a plain `git fetch` from launchd *usually* works while you are logged in. It is the wrong design for three reasons: (1) it is only present in a login session, so a LaunchDaemon or a post-reboot SSH trigger has no agent and the refresh silently fails until you log in; (2) the human's key can push to every repo they own, so a bug in the refresh script (or an agent that talks its way into running `git push` from the mirror) has write access it never needed; (3) the SSH forced-command channel (1.1) is created with `restrict`, which disables agent forwarding, so the remote trigger cannot bring an agent with it anyway. Agent forwarding *from the remote machine* into the Mac is likewise disabled by `restrict` and would only move the problem.

**`GIT_SSH_COMMAND`.** Git honours `GIT_SSH_COMMAND` (and the `core.sshCommand` config) as the program used for SSH transport ([git-scm.com, git(1) Environment Variables](https://git-scm.com/docs/git#Documentation/git.txt-codeGITSSHCOMMANDcode)). The refresh should set it — or `core.sshCommand` in each mirror's config, which survives being invoked from any channel — to something like `ssh -i ~/.ssh/mirror_deploy_ed25519 -o IdentitiesOnly=yes -o IdentityAgent=none -o BatchMode=yes`. Each option closes a specific unattended failure mode: `-i` plus `IdentitiesOnly=yes` stops ssh from offering the human's keys first (GitLab counts failed key offers and a forwarded agent with many keys can trip "Too many authentication failures"); `IdentityAgent=none` guarantees the run behaves identically with and without a login session; `BatchMode=yes` makes ssh fail immediately instead of hanging on a passphrase or host-key prompt that nobody will ever answer — the hang would otherwise hold the Section 3 lock until the sync timeout. The deploy key must therefore have **no passphrase**; its protection is file permissions and FileVault, discussed in 4.6.

### 4.4 GitHub: fine-grained personal access tokens with `contents: read`

GitHub's equivalent of a read-only project token is a fine-grained personal access token restricted to selected repositories and the `Contents` permission at read level. From the official page ([GitHub Docs, Managing your personal access tokens](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens)):

- Scoping model: "Each token is limited to access resources owned by a single user or organization", "Each token can be further limited to only access specific repositories", and "Each token is granted specific, fine-grained permissions." The guidance is explicit: "Under Repository access, select which repositories you want the token to access. You should choose the minimal repository access that meets your needs." Consequence: one token per owner (your user, or each organisation), listing exactly the mirrored repos, with `Contents: Read-only` and nothing else. `Metadata: Read-only` is added automatically because `Contents` depends on it.
- Classic tokens are the wrong tool: they "Grant access to all repositories within organizations you belong to", cannot be limited to a repo list, and GitHub notes "Only personal access tokens (classic) have write access for public repositories" — a capability the mirror does not need.
- Lifetime: "Infinite lifetimes are allowed but may be blocked by a maximum lifetime policy set by your organization or enterprise owner." Consequence: unlike GitLab (365-day cap by default, 4.1), GitHub lets you choose no expiry; the same advice applies — set one anyway and record it beside the secret. Classic tokens are separately garbage-collected: "GitHub automatically removes personal access tokens that haven't been used in a year", which does not affect a token used every 30 minutes.
- Organisation gate: "Organization owners can require approval for any fine-grained personal access tokens that can access resources in the organization." Consequence: for an org that has this enabled, the token does not work until approved — budget for that in setup, and prefer a GitHub deploy key (an SSH key added under the repo's Deploy keys settings, read-only by default, one per repo) if approval is slow.
- Git usage: the token is the password and "the username is not used to authenticate you." Same rule as GitLab: any placeholder username, token supplied by the credential helper.

For GitHub as the *secondary* forge in this setup, the pragmatic choice is: if the mirrored GitHub repos are all yours or in one organisation, one fine-grained token with `Contents: read`; if they span several organisations with approval policies, an SSH deploy key per repo using the same `GIT_SSH_COMMAND` mechanics as 4.3.

### 4.5 `gh` and `glab` in a non-interactive shell

The refresh does not *need* either CLI: a bare mirror is updated with `git fetch`, and the credential is supplied by git's own machinery (4.6). The CLIs matter in two secondary roles — discovering the repo list (`glab repo list` for a group) and answering "is my token still valid" for the health check — and both roles run under launchd or a forced command where nothing can answer a prompt.

`gh` first, from its environment reference ([GitHub CLI manual, gh help environment](https://cli.github.com/manual/gh_help_environment)):

- `GH_TOKEN` / `GITHUB_TOKEN`: "an authentication token that will be used when a command targets either `github.com` or a subdomain of `ghe.com`. Setting this avoids being prompted to authenticate and takes precedence over previously stored credentials." Consequence: under launchd, export `GH_TOKEN` from the secret store (4.7) at the start of the script and `gh` never consults its own config or keychain entry. The variable wins even if you are also logged in interactively with a different, broader token — which is exactly what you want, because the unattended run then uses the narrow read-only token, not your personal one.
- `GH_PROMPT_DISABLED`: "set to any value to disable interactive prompting in the terminal." Consequence: set it unconditionally in the launchd `EnvironmentVariables` dictionary (Section 1.2) so a mis-configured `gh` fails fast with a non-zero exit rather than blocking on a hidden prompt and holding the refresh lock.
- `GH_NO_UPDATE_NOTIFIER`: disables the check `gh` otherwise performs "once every 24 hours" for new versions. Set it; an unattended job should not make an extra outbound request per run or print an upgrade banner into the log.
- `GH_CONFIG_DIR`: defaults, in order, to `$XDG_CONFIG_HOME/gh`, `$AppData/GitHub CLI`, or `$HOME/.config/gh`. Consequence: a LaunchDaemon running as a different user, or an SSH session with a minimal environment, may resolve a different `$HOME`; pinning `GH_CONFIG_DIR` (or, better, using `GH_TOKEN` and never touching stored config) avoids the "works in my terminal, `gh` is logged out under launchd" surprise.
- `GH_HOST`: "specify the GitHub hostname for commands where a hostname has not been provided, or cannot be inferred from the context of a local Git repository." Consequence: a bare mirror has no `remote.origin` in the form `gh` expects from a working clone, so commands run from `~/mirrors/<repo>.git` should pass `--repo owner/name` explicitly or set `GH_HOST`.

`gh auth token` prints the token `gh` would use for a host; it exists so *other* tools can reuse `gh`'s stored login. In this design that direction is reversed — the secret store is the source of truth and `gh` is a consumer via `GH_TOKEN` — so `gh auth token` is not part of the unattended path. The manual page fetched does not describe `gh auth setup-git`; its documented purpose (configuring `gh` as a git credential helper) is noted here as an alternative to 4.6 for GitHub-only setups, but it stores the token in `gh`'s own config file in plain text unless a keyring is configured, which is why 4.6 prefers git's native helpers.

`glab` next. (The raw docs index in the `gitlab-org/cli` repository returned 404 at fetch time, and the older `editor_extensions/gitlab_cli/` page is a redirect stub stating the document "was moved to another location", pointing at `https://docs.gitlab.com/cli/`; the facts below come from that page.)

From the GitLab CLI overview ([GitLab Docs, GitLab CLI](https://docs.gitlab.com/cli/)):

- `GITLAB_TOKEN`: "An authentication token for API requests. Set this variable to avoid prompts to authenticate." Consequence: same pattern as `GH_TOKEN` — export it from the secret store at script start and `glab` never reads its stored login. Because deploy tokens "can't be used with the GitLab public API" (4.2), the token behind `GITLAB_TOKEN` must be a project/group/personal access token if `glab` is used at all; a fetch-only deploy token is enough for `git fetch` but not for `glab repo list`. This is the one place the "read_repository only" rule from 4.1 bends: repo discovery needs `read_api`. Recommendation: keep discovery **out** of the unattended job — maintain the repo list as a checked-in file the human edits — so the unattended credential stays `read_repository`-only and `glab` is not needed at run time.
- `GLAB_NO_PROMPT`, `GLAB_CHECK_UPDATE`, `GLAB_CONFIG_DIR`, `GITLAB_HOST`/`GL_HOST`, `GLAB_DEBUG`, `NO_COLOR` are the documented environment knobs. Consequence: `GLAB_NO_PROMPT` and `GLAB_CHECK_UPDATE` play the same role as `GH_PROMPT_DISABLED` and `GH_NO_UPDATE_NOTIFIER` above; `GITLAB_HOST` is required for a self-managed instance when running outside a working clone (a bare mirror has no `origin` in the form `glab` inspects). Set all of them in the launchd `EnvironmentVariables` dictionary.
- Where `glab` stores a token entered via `glab auth login`, and whether it can use the macOS keychain: **I don't know** from the fetched page — it does not document the config path or a keyring option. Treat the stored login as opaque and do not rely on it under launchd; `GITLAB_TOKEN` is the documented non-interactive path. `glab auth status` is likewise not described on the overview page; its role in the health check (verify the token is accepted) can be replaced by a `git ls-remote` against one mirror, which exercises exactly the credential and scope the refresh uses.

The shared conclusion for both CLIs: **the unattended path needs neither.** `git fetch` plus a credential helper (4.6) or an SSH deploy key (4.3) covers the mirror; the CLIs are for the human's interactive setup and for optional health checks, and when they do run unattended they take their token from an environment variable populated from the secret store, never from their own login state.

### 4.6 Getting the token into `git fetch` over HTTPS: credential helpers, and why `osxkeychain` is a trap under launchd

When the mirror's remote is HTTPS (deploy token or access token), git obtains the password through the credential subsystem described in `gitcredentials(7)` ([git-scm.com, gitcredentials](https://git-scm.com/docs/gitcredentials)). The mechanics that decide the unattended design:

- **Prompt chain.** Git tries `GIT_ASKPASS`, then `core.askPass`, then `SSH_ASKPASS`, and "Otherwise, the user is prompted directly on the terminal." Under launchd there is no terminal; git's terminal prompt fails, and a fetch that reached this point hangs or errors depending on the transport. Consequence: set `GIT_TERMINAL_PROMPT=0` in the job environment so a missing credential is an immediate, logged failure (`auth_failed` in Section 3.5) rather than a stuck lock.
- **Helper chain.** "When multiple `credential.helper` instances are configured, each helper is tried in turn. Once Git acquires both a username and a non-expired password, no more helpers are tried." And the reset idiom: `git config credential.helper ""` empties the list "overriding lower-priority config files", after which you add your own. Consequence: the mirror repos should reset the helper list in their *own* `config` and then name exactly one helper, so a global `osxkeychain` or Git Credential Manager entry configured for the human's interactive use cannot be consulted (and cannot pop a GUI dialog) during the unattended run.
- **Scoping by URL.** `credential.<url>.*` matching requires "Protocol and host must match exactly", hostname comparison is exact ("`foo.example.com` will not match `example.com`"), and a path in the pattern "must match as a prefix". By default git "does not consider the 'path' component of an HTTP URL when matching credentials", so "a credential stored for `https://example.com/foo.git` will also be used for `https://example.com/bar.git`" unless `credential.useHttpPath = true`. Consequence: with a *group* access token (4.1) one credential covers every project under the host — leave `useHttpPath` off. With per-project *deploy* tokens (4.2), each project has a different token, so set `useHttpPath = true` for that host or the first project's token is offered to the second and fails.
- **Shell-snippet helpers.** A helper "prefixed with `!` ... is treated as a shell snippet", and the manual's own example is a read-only helper that answers only the `get` operation: `helper = "!f() { test \"$1\" = get && echo \"password=$(cat $HOME/.secret)\"; }; f"`. Helpers receive one of `get`, `store`, `erase`. Consequence: this is the cleanest unattended helper — a few lines that answer `get` by reading the token from the secret store (4.7) and ignore `store`/`erase` so git never writes a credential anywhere. It has no GUI dependency and no keychain unlock requirement.
- **Platform helpers.** The manual lists `git-credential-osxkeychain` as the macOS helper with "secure persistent storage". It stores items in the login keychain via the Security framework. The behaviour that matters for this document is what happens to that keychain when there is no GUI login session, which is addressed next.

### 4.7 Secret storage on macOS, and keychain behaviour without a login session

The `security(1)` command is the scriptable face of the keychain ([security(1), Xcode man pages mirror](https://keith.github.io/xcode-man-pages/security.1.html)); its options show both why the keychain is attractive and where it fails unattended:

- Reading a secret is one call: `find-generic-password -s <service> -a <account> -w` where `-w` means "Display the password(only) for the item found". A `!`-prefixed credential helper (4.6) can be exactly this command.
- Access control is per item: `add-generic-password -T <appPath>` lets you "Specify an application which may access this item (multiple `-T` options are allowed)"; "By default, the application which creates an item is trusted to access its data without warning." `-A` means "Allow any application to access this item without warning (insecure, not recommended!)". Consequence: create the item from the command line with `-T /usr/bin/security` (and `-T` for the exact `git-remote-https`/`git` binary if you use `osxkeychain`), never `-A`. Note that when a *different* binary asks, the keychain answers with a **GUI dialog** asking to allow access — under launchd with no GUI, or over SSH, that dialog cannot be shown and the call fails; this is the usual cause of "`osxkeychain` works in Terminal, fails from launchd".
- Lock behaviour: `set-keychain-settings -l` "Lock keychain when the system sleeps", `-u` "Lock keychain after timeout interval", `-t` sets the seconds. `unlock-keychain` exists, with the curious note that "Unlocking the login keychain might succeed when an incorrect password is presented, if other unlock factors are available." Consequence: a keychain the refresh depends on must **not** have `-l` or `-u` set, or the 03:00 run after the laptop slept finds it locked. And `unlock-keychain -p <password>` in a script is a non-solution: it puts the login password on disk to protect a token that is less sensitive than the login password.
- Search list: `list-keychains` and `default-keychain` control which keychains are consulted. A dedicated keychain file (e.g. `~/Library/Keychains/mirror-refresh.keychain-db`) with its own password, no auto-lock, added to the search list, is the middle ground: it is not the login keychain, so its password is not the login password, and it can be unlocked independently.

**When is the login keychain available?** It is unlocked as a side effect of GUI login with the account password, and stays unlocked for the login session unless the settings above lock it. Three situations in this design lack that unlock: a LaunchDaemon (no user session), an SSH forced-command login on a Mac where nobody is logged in at the console, and the first minutes after a reboot before anyone logs in (FileVault keeps the whole volume locked in that case, Section 1.1). A `~/Library/LaunchAgents` job during a normal logged-in day *does* see the unlocked login keychain, which is why the keychain "works" in testing and then fails from the SSH trigger at night.

**Storage options, compared for the unattended case:**

| Option | Survives no-GUI session | Survives reboot without login | Scoped access | Notes |
|---|---|---|---|---|
| Login keychain via `osxkeychain` helper | No (locked; access-allow dialog cannot show) | No | Per-item ACL | Right for the *human's* interactive clones, wrong for the mirror. |
| Dedicated keychain file, no auto-lock, `security find-generic-password -w` in a `!` helper | Yes, once unlocked; stays unlocked until reboot | No — must be unlocked once after boot (manually, or by the LaunchAgent at login) | Per-item ACL, `-T /usr/bin/security` | Best balance for a laptop that reboots rarely. The "unlock once after reboot" step can be the human's normal login if the file's password equals the login password *and* it is in the search list — but that re-couples it to the login session. |
| Plain file `chmod 600` under `~/.config/repo-refresh/` on the FileVault volume | Yes | Yes (after the volume is unlocked at first login) | POSIX perms only | What most CI systems do. Acceptable because the token is `read_repository`-only (4.1/4.2) and the disk is encrypted at rest; unacceptable for a token with wider scope. |
| SSH deploy key file, no passphrase (4.3) | Yes | Yes (same FileVault caveat) | POSIX perms; read-only at the forge | Same security posture as the plain file, with the forge enforcing read-only regardless of what the file can do. |
| 1Password/Bitwarden CLI, `op read` etc. | Only if a service account token is on disk — which is the plain-file case one level up | Same | Vault-level | Adds a network dependency to every fetch; not recommended for the unattended path. |

**Recommendation.** For GitLab primary over SSH: a passphrase-less ed25519 deploy key file (read-only, enabled on each mirrored project, or a public deploy key for many), used via `core.sshCommand` in each mirror with `IdentitiesOnly`/`IdentityAgent=none`/`BatchMode` (4.3). For HTTPS-only environments and for GitHub tokens: a `read_repository` / `contents:read` token in a `chmod 600` file, served by a `!` helper that answers only `get` and with `GIT_TERMINAL_PROMPT=0` set. Reserve the keychain for the human's own credentials. Whatever is chosen, record the expiry date next to the secret and have the refresh emit a warning in the status document 14 days before it, because the failure mode of every option here is the same silent `auth_failed`.

Apple's own troubleshooting guidance confirms the two lock triggers relied on above, without documenting the unlock-at-login mechanism itself ([Apple Support, If your Mac keeps asking for the login keychain password](https://support.apple.com/guide/keychain-access/if-your-mac-keeps-asking-for-the-login-keychain-password-kyca1242/mac)): "Your keychain may be locked automatically if your computer has been inactive for a period of time or your user password and keychain password are out of sync." The page points at Keychain Access settings for the inactivity timer — the GUI equivalent of `set-keychain-settings -u -t`. The statement that the login keychain is unlocked automatically at GUI login is not on that page; it follows from the man page's treatment of the login keychain as a special case ("Unlocking the login keychain might succeed... if other unlock factors are available") and from the observed behaviour that `osxkeychain` works in a logged-in Terminal without a prompt. **I do not have an Apple document that states it verbatim**, so the design above does not depend on it: every recommended option in the table works whether or not the login keychain is unlocked.

### 4.8 Section summary

| Concern | Choice for this setup |
|---|---|
| Credential type, GitLab | SSH deploy key (read-only, passphrase-less, per-machine) if SSH reaches the forge; otherwise group access token or deploy token with `read_repository` only |
| Credential type, GitHub | Fine-grained token, selected repos, `Contents: read`; or per-repo deploy key |
| Transport wiring | `core.sshCommand` per mirror with `-i`, `IdentitiesOnly=yes`, `IdentityAgent=none`, `BatchMode=yes`; or a `!` credential helper answering `get` only, `GIT_TERMINAL_PROMPT=0` |
| Storage | `chmod 600` file on the FileVault volume; keychain reserved for the human |
| CLIs | Not on the unattended path; if used, `GH_TOKEN`/`GITLAB_TOKEN` from the file, prompts and update checks disabled via env |
| Rotation | Write new secret first, then rotate at the forge; expiry date stored beside the secret; warning in the status document at T-14 days |

## 5. Prior art at scale

**Context for this section.** Every system below keeps many git repositories fresh for machine readers rather than humans. None of them is the right tool for one laptop — they assume a server, a database, or a fleet — but each solved one of our four problems (scheduling, dedup, atomic visibility, freshness signalling) in a way a small setup can copy in a few lines. The subsections state what each system does, cite it, and end with the one thing to copy.

### 5.1 Sourcegraph gitserver and repo-updater: adaptive fetch scheduling

(The rendered page at `sourcegraph.com/docs/admin/repo/update_frequency` returned HTTP 403 to this fetch, and the guessed path in the `sourcegraph-public-snapshot` repository returned 404; the facts below come from the same document at its `docs.sourcegraph.com` address and from Sourcegraph's engineering handbook, as surfaced by web search.)

Sourcegraph keeps a bare mirror of every repository on its `gitserver` nodes and lets a separate service, `repo-updater`, decide when each one is fetched. The scheduling rules, from the update-frequency document ([Sourcegraph docs, Repository update frequency](https://docs.sourcegraph.com/admin/repo/update_frequency)):

- Adaptive backoff: "The frequency at which Sourcegraph polls the code host for updates is determined by a smart heuristic based on past commit frequency in the repository. For example, if a repository's last commit was 8 hours ago, then the next sync will be scheduled 4 hours from now. If after 4 hours, there are still no new commits, then the next sync will be scheduled 6 hours from then." Consequence: a repo that goes quiet is polled less, and a repo that just moved is polled soon — the interval is a function of the repo's own history, not a global constant.
- Bounds: "Repositories will never be updated more frequently than 45 seconds, and no less frequently than every 8 hours."
- Overrides: `gitUpdateInterval` "is a JSON array of repo name patterns and update intervals (in minutes)"; "If a repo matches a pattern in `gitUpdateInterval`, the associated interval will be used. If it matches no patterns a default backoff heuristic will be used, with pattern matches attempted in the order they are provided." A second knob, `repoListUpdateInterval`, "controls how frequently we check the code host for new repositories in minutes (default 1)" ([Sourcegraph docs, Site configuration](https://docs.sourcegraph.com/admin/config/site_config)). Consequence: discovery of *which* repos exist is a separate, more frequent loop from fetching *contents*, which is the same split recommended in 4.5 (keep the repo list as a human-edited file; fetch contents on a timer).
- Mechanism: "Repo-updater has an update scheduler that places repositories onto the `updateQueue` when it thinks it should be updated. This is what paces out updates for a repository. It contains heuristics such that recently updated repositories are more frequently checked" ([Sourcegraph handbook, How repo-updater works](https://handbook.sourcegraph.com/departments/engineering/teams/source/how-repo-updater-works/)). Webhooks from the code host, when configured, enqueue a repo immediately instead of waiting for its scheduled slot ([Sourcegraph docs, Repository webhooks](https://docs.sourcegraph.com/admin/repo/webhooks)).

**What a personal setup should copy.** Not the two services. The idea worth ten lines of shell is *per-repo backoff with bounds*: record `committed_at` of the newest fetched commit in the status document (Section 3.5), and on each timer tick skip repos whose `committed_at` is older than N × the time since the last fetch, subject to a floor (every tick for repos that changed within the last day) and a ceiling (at least once a day for everything). The timer still fires every 15–30 minutes; most repos are skipped on most ticks, so the GitLab instance sees far fewer `ls-remote`/fetch requests and the run finishes faster. The remote SSH trigger (1.1) bypasses the backoff by design — "I want it now" is the point of an on-demand channel.

### 5.2 Google `repo`: a declarative manifest of repos, paths and revisions

Android's `repo` tool solves "many repos, one consistent tree" with an XML manifest checked into its own git repository. The element set that matters, from the manifest-format reference ([git-repo, docs/manifest-format.md](https://gerrit.googlesource.com/git-repo/+/HEAD/docs/manifest-format.md)):

- `<remote fetch="…">`: "Git URL prefix for all projects which use this remote." One line per forge/group, so project entries stay short.
- `<default remote= revision= sync-j= sync-c=>`: fallbacks for every project — the default branch to track, the number of parallel sync jobs (`sync-j`), and `sync-c` ("Default single-branch sync behavior").
- `<project name= path= remote= revision= groups= clone-depth= sync-c=>`: `name` is "appended to remote fetch URL"; `path` is the "checkout location relative to repo root", defaulting to the name; `revision` is the "Git branch, tag, or commit SHA-1 to track", inherited from `<default>` when absent; `groups` lets a sync select a subset ("All projects auto-join 'all' group plus 'name:*' and 'path:*' variants"); `sync-c` restricts the fetch to "only specified revision instead of entire ref space"; `clone-depth` "Overrides `repo init --depth` for this project only."
- `<include>` "Incorporates external manifest file with optional groups and revision scoping", so a personal manifest can include a team one.
- `<manifest-server>` (an XML-RPC "smart sync" service) and `<superproject>` exist for Google-scale consistency across thousands of projects; both are irrelevant here.

The fetched document does not describe `repo`'s on-disk object layout (`.repo/projects` and `.repo/project-objects`), so that dedup mechanism is not cited here; the manifest design is what is worth copying.

**What a personal setup should copy.** The manifest, in a smaller format. The refresh script's repo list should be a checked-in file — YAML, TOML, or one-line-per-repo — with exactly `repo`'s fields: a remote prefix per forge, a default branch pattern (`main|master|release*`), and per-repo overrides for `path`, `revision`/branch pattern, `groups` (so an agent can ask for "only the payments services") and `depth`. Two consequences: the human edits a file instead of the script (4.5 recommended keeping discovery out of the unattended job for credential reasons; the manifest is the mechanism), and the same manifest is what the status document's `repos` map should be keyed by, so agents and humans use the same names. `sync-c`'s single-branch idea also maps onto the Section 3.2 advice to fetch only the major branches with an explicit refspec rather than mirroring every ref.

### 5.3 Backstage software catalog: refresh without cloning, and orphan handling

Backstage's catalog is the opposite design to ours — it deliberately does *not* keep checkouts — and is included because of how it handles two problems we share: staggering refresh load and deciding what to do with entries whose source disappeared. From the catalog configuration reference ([Backstage docs, Software Catalog configuration](https://backstage.io/docs/features/software-catalog/configuration/)):

- Refresh is a loop over registered entities, not a git operation: "The processing loop is responsible for running your registered processors on all entities, on a certain interval", governed by `catalog.processingInterval`. The catalog reads files through URL readers ("The `url` type locations are handled by a standard processor included with the catalog (`UrlReaderProcessor`)"), i.e. via the forge's raw-file API rather than a clone. Consequence: for a *metadata-only* consumer, a clone is unnecessary; our consumers (`index_repository` parsing whole trees, cross-repo call resolution) need the files on disk, which is why Section 2 keeps checkouts. The Backstage approach is the right model for a lightweight "which repos exist and who owns them" layer above the mirrors.
- Jitter is built in: for `processingInterval`, "the catalog will scale up this number by a small factor and choose random numbers in that range to spread out the load." Consequence: the same idea systemd exposes as `RandomizedDelaySec=` (Section 1.4). launchd has no equivalent, so a personal setup gets it by sleeping a random 0–60 s at the start of the script — worthwhile only if several machines poll the same GitLab instance.
- Static locations are pinned: "The locations added through static configuration cannot be removed through the catalog locations API." The analogue is the manifest of 5.2 being the single source of truth.
- Allow-listing is the default: "By default, the catalog will only allow the ingestion of entities with the kind `Component`, `API`, and `Location`", extended via `catalog.rules`. The analogue is the branch allowlist (`main|master|release*`) — nothing not matched is ever fetched or exposed.
- Orphans: the default "removes orphaned entities automatically", with `catalog.orphanStrategy: keep` to disable cleanup. Consequence: Backstage chose delete-by-default with an opt-out. Section 3.5 chose the softer path for branches that vanish upstream (`state: removed` for one cycle, then delete), because an index that silently loses a project is worse for an agent than one that reports a removal.

Scheduler details for entity providers (`frequency`, `timeout`, `initialDelay`) live on the individual provider pages and are not on the fetched configuration page; they are not needed for the comparison.

**What a personal setup should copy.** Two things: jitter before fetching when more than one machine shares a forge, and a *visible* orphan state rather than silent deletion.

### 5.4 GitLab pull mirroring: a forge-side implementation of the same contract

GitLab's built-in pull mirroring is a server-side version of what this document specifies for a laptop, and its documented rules read like a checklist of decisions we have made ([GitLab Docs, Pull from a remote repository](https://docs.gitlab.com/user/project/repository/mirror/pull/)):

- Tier: "Premium, Ultimate" — it is a paid feature, and even on those tiers it mirrors *into* GitLab, not from GitLab onto your disk, so it does not replace the local refresh. It is relevant as design precedent and as an option for consolidating GitHub repos into the primary GitLab instance so the Mac has one forge and one credential to deal with.
- Cadence: "Automatically, 30 minutes after a previous pull. This cannot be disabled." Manual updates via UI/API are "subject to default pull mirroring intervals of 5 minutes". Consequence: GitLab itself considers 30 minutes an acceptable staleness for a mirror and 5 minutes the floor for on-demand refreshes. A personal setup polling every 15–30 minutes (Section 1.8) is in line with the forge's own defaults, and a rate limit of one on-demand run per few minutes on the SSH/MCP channels is reasonable rather than paranoid.
- Divergence: "By default, GitLab halts updates when branches diverge to prevent data loss." The opt-in "Overwrite diverged branches" option "results in the loss of local changes." Consequence: this is exactly the `state: diverged` behaviour in Section 3.5 — stop, keep the old snapshot, report — with the destructive alternative behind an explicit switch that our design does not offer at all.
- Scope: an option to "Only mirror protected branches". Consequence: the same narrowing as our `main|master|release*` allowlist, and a hint that "protected branches" is the forge-native vocabulary for "branches worth mirroring". If the team's protection rules match the pattern, the refresh could read the protected-branch list from the API once and generate the refspecs — an optional enhancement that would need `read_api` (4.5), so it is deliberately not on the unattended path.
- Failure policy: "After 14 failures, a mirror is marked as a hard failure and is no longer enqueued for updates", and an administrator must force an update to resume. Consequence: the `consecutive_failures` counter in Section 3.5 exists for the same reason; unlike GitLab, our design keeps retrying on the timer (a laptop's failures are usually transient network) but should *alert* — a warning line in the status document and the log — once the count passes a threshold of the same order, so a dead token does not go unnoticed for weeks.
- "Trigger pipelines for mirror updates" is a reminder that the mirror's post-update hook runs with the mirror creator's credentials and is therefore a security surface; our equivalent (the post-success hook in 3.1, e.g. calling `detect_changes`) runs as the user with read-only tokens, which is the correct posture.

**What a personal setup should copy.** The 30-minute default, the halt-on-divergence default, the protected-branches-only scope, and the hard-failure counter. All four are already in Sections 1 and 3; GitLab's implementation is the evidence that they are the conventional choices.

**GitHub's position.** GitHub has no server-side pull-mirror feature; its documentation describes mirroring as something you run yourself ([GitHub Docs, Duplicating a repository](https://docs.github.com/en/repositories/creating-and-managing-repositories/duplicating-a-repository)). The recipe is `git clone --mirror`, then periodically `git fetch -p origin` (and `git push --mirror` if the goal is a second remote), with the key property stated plainly: "all local references will be overwritten each time you fetch, so it will always be the same as the original." Two consequences for us. First, that sentence is the same warning Section 2.1 drew from `git-clone(1)`: a `--mirror` clone's refspec is `+refs/*:refs/*`, so it accepts force-pushes — fine for a faithful mirror, wrong for a fast-forward-only contract, hence the explicit non-`+` refspecs for the major branches in Section 3.2. Second, GitHub's guidance for LFS mirrors (`git lfs fetch --all`, `git lfs push --all`) is a reminder that the bare mirror does not contain LFS objects; a worktree created from it will hold LFS pointer files unless `git lfs fetch`/`checkout` is run per snapshot. If any mirrored repo uses LFS, the snapshot step in Section 2.5 must include an LFS fetch for the branch tip, and the token or deploy key must be allowed to read LFS (for GitLab, `read_repository` covers it; for a GitHub fine-grained token, `Contents: read` does as well).

### 5.5 Gitea / Forgejo mirrors: the self-hostable middle layer

Gitea (and its fork Forgejo, which inherits the feature) offers pull and push mirrors on every tier because there are no tiers. From the usage guide ([Gitea docs, Repository mirror](https://docs.gitea.com/usage/repo-mirror)):

- A pull mirror is created at migration time ("Select New Migration in the Create… menu" and check "This repository will be a mirror"); afterwards "The repository now gets mirrored periodically from the remote repository", with a manual "Synchronize Now" button. The constraint "You can only set up pull mirroring for repos that don't exist yet on your instance" matches our own Layout B: the mirror is a fresh, dedicated repository, never an existing working clone converted in place.
- Push mirrors live under Settings > Repository > Mirror Settings, optionally with "Sync when new commits are pushed" (Gitea 1.18+), and carry the warning: "This will force push to the remote repository. This will overwrite any changes in the remote repository!" Consequence: Gitea's push direction is force-by-design, the same `--mirror` semantics GitHub and `git-clone(1)` describe; pull direction is the one that fits a read-only knowledge base.
- Authentication for the upstream is a stored username plus "the requested password can also be your access token", i.e. Gitea stores the read token for you — the credential-storage problem of Section 4 moved onto a server you control.

The usage page does not give the sync interval defaults or the `[mirror]` configuration keys. The rendered configuration cheat sheet truncated before its `[mirror]` section in this fetch, and the `app.example.ini` in Gitea's source tree ([go-gitea/gitea, custom/conf/app.example.ini](https://github.com/go-gitea/gitea/blob/main/custom/conf/app.example.ini)) confirmed only that a `[cron.update_mirrors]` task exists with `SCHEDULE`, `ENABLED`, `RUN_AT_START`, `NOTICE_ON_SUCCESS`, `PULL_LIMIT` and `PUSH_LIMIT` keys; the fetch did not return their values or the `[mirror]` `DEFAULT_INTERVAL`/`MIN_INTERVAL` keys. **The numeric interval defaults are therefore not recorded here — I don't know them from a source I could fetch.** What the key names alone establish is the architecture: a single cron task walks all mirrors on a schedule, with a per-run cap on how many pull and push mirrors it processes (`PULL_LIMIT`/`PUSH_LIMIT`), and `RUN_AT_START` performs a catch-up pass when the server boots.

**Where Gitea/Forgejo fits a personal setup.** As the always-on relay that Section 1.5 wanted and Section 1.8 said to skip unless you already have one. A Forgejo instance on a home server or small VPS can pull-mirror the GitLab and GitHub repos on its own schedule, hold the forge credentials (4.1–4.4) so the laptop never needs them, and serve the laptop a single SSH endpoint with a single read-only deploy key. The laptop's refresh then fetches from Forgejo over the LAN or overlay network. The costs are a second hop of staleness (Forgejo's interval plus the laptop's) and one more service to run. It is worth it when there are two forges with different credential regimes, or when several machines need the mirrors; for one laptop and one GitLab group it is not.

**What a personal setup should copy.** The `PULL_LIMIT` idea — cap the number of repos fetched per tick so one slow forge cannot make a run overshoot the next timer firing — and `RUN_AT_START` as a catch-up pass at login, which is Section 1.2's `RunAtLoad`.

### 5.6 kubernetes/git-sync: the atomic visibility pattern, restated

git-sync was covered as evidence in Section 3.1, so only the design summary is repeated here for the comparison table ([kubernetes/git-sync README](https://github.com/kubernetes/git-sync/blob/master/README.md)). One bare repo per synced source; per revision, a worktree in a directory named by its hash; a single symlink (`--link`) that is repointed to the new worktree after the checkout completes; old worktrees removed after `--stale-worktree-timeout`; freshness pushed to consumers via `--exechook-command` (with `$GITSYNC_HASH`) or `--webhook-url` (with a `Gitsync-Hash` header), both at-least-once and idempotent-by-hash. The README's one-sentence justification — "git checkouts are not 'atomic' operations" — is the requirement this whole document was written to satisfy.

**What a personal setup should copy.** Everything in that paragraph. It is the only system in this section whose *consumer* is, like ours, a process reading files off a disk rather than a UI or an API, and it is the only one that made "the reader never sees a partial tree" a stated design goal. Section 2.5 and 3.5 are a direct transcription, with two adjustments for the multi-agent case: a non-zero retention grace period (git-sync defaults to immediate removal), and a status document beside the symlink because our readers want more than the current hash (previous hash, failure state, run in progress).

### 5.7 Synthesis: what each system contributes

| System | Its consumer | Problem it solved well | Copy into the personal setup |
|---|---|---|---|
| Sourcegraph gitserver / repo-updater (5.1) | Search index, web UI | Adaptive per-repo fetch scheduling with 45 s floor and 8 h ceiling; discovery loop separate from fetch loop | Per-repo backoff keyed on last commit age, bounded; keep repo discovery out of the fetch job |
| Google `repo` (5.2) | Build system | Declarative manifest of remotes, paths, branches, groups, depth | A checked-in repo manifest that both the script and the status document key on |
| Backstage catalog (5.3) | Developer portal | Jittered refresh; explicit orphan strategy | Random start delay when multiple machines poll; visible `removed` state, not silent deletion |
| GitLab pull mirroring (5.4) | Another GitLab project | 30-min default, halt on divergence, protected-branches-only scope, hard-fail counter | All four; they are the conventional defaults, adopted in Sections 1 and 3 |
| GitHub duplicating docs (5.4) | A second remote | Honest about `--mirror` overwriting refs; LFS needs separate handling | Non-`+` refspecs for fast-forward-only branches; LFS fetch per snapshot if any repo uses LFS |
| Gitea / Forgejo mirrors (5.5) | Self-hosted forge | Credentials held server-side; per-tick pull limit; catch-up at start | Optional always-on relay when two forges or several machines are involved; cap repos per tick |
| kubernetes/git-sync (5.6) | Files on a pod's disk | Atomic symlink flip over hash-named worktrees; hash-keyed idempotent hooks | The core of Sections 2.5 and 3 |

The pattern across all seven is that none of them lets a reader look at a tree that is being written, none of them lets the mirror job write into a tree a human is editing, and all of them treat divergence as a stop-and-report condition rather than something to resolve automatically. A personal script that keeps those three properties — bare mirror, snapshot-and-flip, fast-forward-or-halt — and publishes one small status document is doing what the large systems do, at the scale of one laptop.
