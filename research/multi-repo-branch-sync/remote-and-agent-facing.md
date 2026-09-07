# Agent 3: Remote invocation and agent-facing operation

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

[To be filled by research agent]

## 3. Consistency contract

[To be filled by research agent]

## 4. Unattended auth

[To be filled by research agent]

## 5. Prior art at scale

[To be filled by research agent]
