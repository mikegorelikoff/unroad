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
| `--no-skills` | install only the engine |
| `--no-agents-md` | do not add the unroad section to your agents' global instructions |
| `--uninstall` | remove `ur`, the web app and the skills; keep progress |
| `--purge` | with `--uninstall`, also delete `~/.unroad` |

Environment variables: `UR_VERSION`, `UR_INSTALL_DIR`, `UNROAD_HOME` (default `~/.unroad`). On Windows set `UR_VERSION`, `UR_INSTALL_DIR`, `UR_AGENT`, `UR_NO_WEB=1` or `UR_NO_AGENTS_MD=1` before running the PowerShell command.

### The managed instructions section

So that every agent session knows how to work with unroad, the installer adds a short section to your agents' global instructions (`~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`), and `/ur-start` adds the same section to your lab project's `AGENTS.md` (with an `@AGENTS.md` import in `CLAUDE.md` so Claude Code reads it). The section sits between `<!-- unroad:begin -->` and `<!-- unroad:end -->` markers. Everything you wrote outside the markers stays untouched; the section is refreshed on update and removed on uninstall. `/ur-doctor` tells you if it is missing or outdated.

Supported platforms: macOS (Apple Silicon and Intel), Linux (x86_64 and arm64, any distribution: the binary is static), Windows x64.

## How the mentor works

unroad runs its skills through a small harness:

- **One step at a time.** A skill is a short list of steps. Your agent only ever sees the current step, so it cannot skip the quiz or rush the lab.
- **Done is decided in code.** Each step lists gates. When the step is finished, the engine (`ur`, which your agent runs) checks the gates itself: a quiz answer was correct, a lab file has no placeholders left, a command exits 0. If a gate fails, the step stays open and you see why.
- **Progress lives in files.** Your state is in `~/.unroad/state.json` and an append-only log. Close the session, come back tomorrow, switch agents: `/ur-learn` resumes where you stopped.
- **Questions pause the run.** When something needs your decision, the run pauses and waits for you; you answer and it continues.

The skills and the curriculum are built into the engine binary and installed from it, so nobody can quietly change the lessons or the checks: `/ur-doctor` reports any edited skill file, and the progress log is hash-chained, so edits to your history are detectable.

## A topic, step by step

| Step | You | The mentor | Checked in code |
|---|---|---|---|
| Lesson | answer one check question | explains each point with an example from your project | the lesson was shown |
| Quiz | pick A, B or C | asks one question at a time, never hints the answer | every answer is correct |
| Lab | change real files | coaches; writes only if you ask (pair mode) | the lab's gates on disk |
| Reflection | say what you did and learned | condenses it in your words | at least 30 characters |
| Review | confirm each item honestly | revisits anything you cannot confirm | every item checked |

Lab files go to `.unroad/labs/<topic>/` in your repository unless the lab works on your real files (for example `AGENTS.md`, `.claude/settings.json`, `docs/adr/`, `.github/workflows/`). Commit them if you like: they are a record of what you learned.

## Using the roadmap app

Type `/ur-gui` in your agent. It starts the app in the background on `http://127.0.0.1:4317` (the next free port if that one is taken) and opens your browser. Ask your agent to stop it when you are done.

Pages: the roadmap, each stage, each topic (the full interactive lesson), your progress with recent activity and a copyable report, onboarding, and how it works. Changes you make in your agent appear in the browser within a few seconds and the other way round.

## Customising

Ask your agent in plain words: "teach me context engineering next", "let me type in labs only when I ask", "show only foundation topics". The skills turn that into settings for the current run.

For lasting changes, each skill reads settings from files, so a team can share them without editing the skills:

- for a team, in the project: `.agents/custom/<skill>.toon` (commit it);
- for yourself: `.agents/custom/<skill>.user.toon`.

Each skill's `customize.toon` lists every setting with a comment saying what it does, for example `coach_mode` (coach or pair) and `min_reflection_chars` in `ur-learn`.

## For agents and contributors

The skills call the engine `ur` with commands such as `ur start ur-learn`, `ur done`, `ur resume`, `ur lab --check` and `ur gui --detach`; exit code 2 means a gate failed. You can read every command with `ur --help`, but you should not need to: the skills are the interface.

## Troubleshooting

| Problem | Fix |
|---|---|
| Your agent says `ur` is not found | add `~/.local/bin` to your PATH (the installer prints the exact line for your shell) and restart the agent |
| The agent does not know `/ur-start` | restart the agent so it loads new skills; run the installer again with `--agent claude` or `--agent codex` |
| `/ur-gui` says Node.js is missing | install Node.js 20 or newer |
| A lab check keeps failing | ask your agent which check fails; each one names the file and the reason |
| `/ur-doctor` reports edited skill files | run the install command again; your progress is kept |
| Anything else | `/ur-doctor` finds each problem and its fix |

## Privacy

unroad has no server, no account and no telemetry. All state is local: `~/.unroad/` and your repository. The web app binds to `127.0.0.1` and only accepts requests from its own pages.
