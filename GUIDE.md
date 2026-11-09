# unroad guide

Everything beyond the [README](README.md): install options, how the mentor works, customising, troubleshooting.

## Install options

Pass options to the installer after `sh -s --`:

```bash
curl -fsSL https://github.com/mikegorelikoff/unroad/releases/latest/download/install.sh | sh -s -- --agent all --no-web
```

| Option | Does |
|---|---|
| `--version <tag>` | install a specific release, for example `v0.1.1` (default: latest) |
| `--agent claude\|codex\|all` | which agents get the skills (default: every agent found) |
| `--target <dir>` | install the skills into this folder instead, for example a project's `.agents/skills` |
| `--bin <dir>` | where to put `ur` (default: `~/.local/bin`) |
| `--no-web` | skip the web app |
| `--no-skills` | install only the `ur` command |
| `--uninstall` | remove `ur`, the web app and the skills; keep progress |
| `--purge` | with `--uninstall`, also delete `~/.unroad` |

Environment variables: `UR_VERSION`, `UR_INSTALL_DIR`, `UNROAD_HOME` (default `~/.unroad`). On Windows set `UR_VERSION`, `UR_INSTALL_DIR`, `UR_AGENT` or `UR_NO_WEB=1` before running the PowerShell command.

Supported platforms: macOS (Apple Silicon and Intel), Linux (x86_64 and arm64, any distribution: the binary is static), Windows x64.

## How the mentor works

unroad is built the way [unhooked](https://www.unmerged.tech/) runs agent skills:

- **One step at a time.** A skill is a short list of steps. Your agent only ever sees the current step, so it cannot skip the quiz or rush the lab.
- **Done is decided in code.** Each step lists gates. When the agent runs `ur done`, `ur` checks the gates itself: a quiz answer was correct, a lab file has no placeholders left, a command exits 0. If a gate fails, the step stays open and you see why.
- **Progress lives in files.** Your state is in `~/.unroad/state.json` and an append-only log. Close the session, come back tomorrow, switch agents: `/ur-learn` resumes where you stopped.
- **Questions pause the run.** When something needs your decision, the run halts with `ur ask` and waits for you; you answer and it continues.

The skills and the curriculum are built into the `ur` binary and installed from it. `ur verify --integrity` tells you if an installed skill file was changed, and the event log is hash-chained, so edits to your history are detectable with `ur verify`.

## A topic, step by step

| Step | You | The mentor | Checked by `ur` |
|---|---|---|---|
| Lesson | answer one check question | explains each point with an example from your project | the lesson was shown |
| Quiz | pick A, B or C | asks one question at a time, never hints the answer | every answer is correct |
| Lab | change real files | coaches; writes only if you ask (pair mode) | the lab's gates on disk |
| Reflection | say what you did and learned | condenses it in your words | at least 30 characters |
| Review | confirm each item honestly | revisits anything you cannot confirm | every item checked |

Lab files go to `.unroad/labs/<topic>/` in your repository unless the lab works on your real files (for example `AGENTS.md`, `.claude/settings.json`, `docs/adr/`, `.github/workflows/`). Commit them if you like: they are a record of what you learned.

## Using the roadmap app

`ur gui` starts the app in the background on `http://127.0.0.1:4317` (the next free port if that one is taken) and opens your browser. `ur gui --status` shows whether it runs, `ur gui --stop` stops it.

Pages: the roadmap, each stage, each topic (the full interactive lesson), your progress with recent activity and a copyable report, onboarding, and how it works. Changes you make in your agent appear in the browser within a few seconds and the other way round.

## Customising

Every skill has settings with defaults in its `customize.toon`. Override them without editing the skill:

- for a team, in the project: `.agents/custom/<skill>.toon` (commit it);
- for yourself: `.agents/custom/<skill>.user.toon`;
- for one run: `ur start <skill> --set workflow.<key>=<value>`.

Examples:

```bash
ur start ur-learn --set workflow.topic=context-engineering    # learn a specific topic
ur start ur-learn --set workflow.coach_mode=pair              # let the mentor type in labs when you ask
ur explain ur-learn min_reflection_chars                      # show a setting and where it comes from
```

## Commands

| Command | Does |
|---|---|
| `ur` | progress, the open run and the next command |
| `ur start <skill>`, `ur resume`, `ur done` | run a skill step by step |
| `ur ask "<question>"`, `ur reply C\|E\|X` | pause a run with a question; continue, edit or cancel |
| `ur list`, `ur known <topic>`, `ur skip <topic>`, `ur reset <topic>` | topics and placement |
| `ur answer <n> <letter>`, `ur lab --scaffold`, `ur lab --check`, `ur reflect "<text>"`, `ur check <n>` | inside a topic |
| `ur report`, `ur stats` | your progress as Markdown, local activity numbers |
| `ur gui` | the roadmap app |
| `ur doctor`, `ur verify --integrity` | health and integrity checks |
| `ur install --target <dir>`, `ur uninstall --target <dir>` | install the skills into another agent folder |

Exit codes: 0 ok, 1 error, 2 a gate failed, 3 a run halted after the repair limit.

## Troubleshooting

| Problem | Fix |
|---|---|
| `ur: command not found` | add `~/.local/bin` to your PATH; the installer prints the exact line for your shell |
| The agent does not know `/ur-start` | restart the agent so it loads new skills; check with `ur where` that the skills are in its folder |
| `ur gui` says Node.js is missing | install Node.js 20 or newer |
| A lab gate keeps failing | run `ur lab --check`; each failing gate prints the file and the reason |
| `ur verify --integrity` reports edited files | reinstall with the install command; your progress is kept |
| Anything else | `ur doctor` prints each problem with its fix |

## Privacy

unroad has no server, no account and no telemetry. All state is local: `~/.unroad/` and your repository. The web app binds to `127.0.0.1` and only accepts requests from its own pages.
