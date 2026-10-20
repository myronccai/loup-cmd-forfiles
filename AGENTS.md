# AGENTS.md

This repository recreates the Windows `forfiles` command in the Loup
programming language, as part of the loup-cmd series of example
applications. The program is `host.dual` Loup built as a native executable
for Linux, with cmd's switch, wildcard, path and message conventions. It
runs the `/C` command through `/bin/sh`, translating `cmd /c` command lines
from cmd syntax. `source/win/` is a copy of the shared Windows code
(master: loup-cmd-type).

## Skills

| Skill | Location | Use it when |
|-------|----------|-------------|
| `loup-programmer` | [skills/loup-programmer/SKILL.md](skills/loup-programmer/SKILL.md) | Writing, reviewing, debugging or explaining Loup code: `.lpscr`, `.loup`, `.lphc`, `.lpweb` or `.lpfree` source files, `.lppkg` manifests, `@mode(...)` directives, or the `loup` / `loup-bootstrap` commands. |

Read `skills/loup-programmer/SKILL.md` before writing or changing any Loup code
in this repository. It links to detailed references under
`skills/loup-programmer/references/` for syntax, types and ownership, execution
modes and projects, errors and diagnostics, the standard library, and common
mistakes. Load those only as needed.

## Code layout

```text
.
├── package.lppkg                # Loup manifest: name, version, toolchain, [build] entry, [test] pattern
├── Makefile                     # run, check, test, build, e2e, ci, clean
├── source/                      # all Loup code; modules import each other by path from here
│   ├── main.loup                # entry point: func main() calls run(runtime.args())
│   ├── appinfo.loup             # APP_NAME, APP_VERSION, APP_SUMMARY, exit statuses
│   ├── cli/
│   │   ├── args.loup            # struct Options, forfiles_switches(), parse_args() and its ERROR messages
│   │   ├── usage.loup           # usage() (short /? text), version_line()
│   │   └── app.loup             # run(): parse, /? and --version, run_forfiles, exit status
│   ├── commands/
│   │   ├── forfiles.loup        # start_error(), select_entries(), shell_script(), run_forfiles()
│   │   ├── substitution.loup    # Entry, expand_hex(), variable_value(), substitute()
│   │   └── cmdline.loup         # cmd /c detection, cmd_to_sh(), split_args(), exec_line()
│   └── win/                     # shared Windows code (a copy; master in loup-cmd-type)
│       ├── switches.loup        # cmd switch parser: /S -s /A:H /T 10 /S/Q /? --
│       ├── wildcard.loup        # Win32 wildcard matcher, list_matches(), subdirectories()
│       ├── paths.loup           # fs_path(), display_path(), split/join helpers
│       └── messages.loup        # Windows message texts
├── tests/
│   ├── *_test.loup              # unit tests: func test_*(): void (win_*_test.loup test source/win/)
│   ├── e2e.sh                   # end-to-end tests of the native binary (fixture tree under $TMP)
│   └── fixtures/help.txt        # the expected /? output
├── specs/forfiles/              # requirements.md, design.md, tasks.md
├── skills/loup-programmer/      # the Loup skill and its references
├── .github/workflows/ci.yml     # installs Loup and runs `make ci`
└── build/                       # build output (git-ignored); unit tests write fixtures to build/tmp/
```

The substitution module is not called `template`: that is a reserved word
in Loup and cannot appear in an import path.

## Build, run and test

Prerequisites: Loup 1.26.0 (`loup` and `loup-bootstrap` on `PATH`), `make`,
and `clang` 17 or later for native builds.

Loup Lite comes from <https://github.com/code-craft-ai-company/loup-releases>;
[README.md](README.md#installing-loup-lite) has the install commands.

| Task | Command | Notes |
|------|---------|-------|
| Run from source | `make run ARGS="/M '*.md'"` | `loup-bootstrap run source/main.loup -- ARGS` (the self-hosted `loup run` has no `execShell`) |
| Type-check | `make check` | checks `source/main.loup` and every module it imports; tests are not checked |
| Run all tests | `make test` | every `tests/*_test.loup`, one at a time (`--no-parallel`) |
| Run matching tests | `make test TEST_ARGS="--filter echo"` | tests whose name contains `echo` |
| Run one test file | `make test TEST_ARGS="--file tests/cmdline_test.loup"` | |
| Build | `make build` | native binary at `build/forfiles` |
| Run the binary | `build/forfiles /S /M '*.md'` | quote `\`, `*`, `?`, `/?` and the `/C` command in the shell |
| End-to-end tests | `make e2e` | runs `tests/e2e.sh build/forfiles`: stdout byte for byte, stderr exactly |
| Everything CI runs | `make ci` | check, test, build, e2e, then `build/forfiles --version` |
| Clean | `make clean` | removes `build/`, `.temp/` and `.loup-cache/` |

Run `make ci` before reporting a change as done. `loup run` and the native
build do not support the same things, so a change can pass `make test` and
still fail `make build`.

Do not call `loup test` or `loup check` directly on Linux x86-64. There `loup`
is the self-hosted driver: it refuses `check`, and its test runner cannot
resolve this project's imports. The Makefile uses `loup-bootstrap` (Stage0) for
both, and sets `LOUPPATH=source` for tests. Keep `--no-parallel`: Stage0's
parallel test runner fails these tests at random.

## Making a change

1. Update the spec in `specs/forfiles/` (see [specs/README.md](specs/README.md)).
2. Change the code under `source/`.
3. Add or update unit tests in `tests/` and cases in `tests/e2e.sh`.
4. Run `make ci`.
5. Tick the finished tasks in the spec's `tasks.md`.

Keep behaviour in pure functions that return values (`select_entries`,
`substitute`, `cmd_to_sh` and `shell_script` return values) so unit tests
can check them; only `run_forfiles` prints and runs commands.

`source/win/` is a copy of the shared Windows code: do not change it here
alone. Improvements go to the master copy in loup-cmd-type and to
`ccai-examples/shared/windows/`, and are then copied back.

## Conventions

- Every source file is `@mode(host.dual)` with the `.loup` extension. Only
  `source/main.loup` has a `main()`.
- Modules import each other by path from `source/`:
  `from win.switches import (parse_switches);`. Tests import them the same
  way. Do not use relative imports (`from .args import ...`): the
  self-hosted `loup run` on Linux x86-64 fails on them.
- Windows conventions: switches via `win.switches`; the `/P` value goes
  through `fs_path()` before file access; messages use Windows' wording
  (`ERROR: ...` for forfiles); usage errors are ERRORLEVEL 1. The `@path`
  and `@relpath` values keep `/`, since Linux programs consume them.
- Struct fields read from another module must be `pub`.
- The native build supports less than `loup run` does. For example,
  `list.is_empty()` fails native codegen (`E-CODEGEN-UNHANDLED-METHOD`; use
  `len() == 0`), a `sort` comparator that captures a list of structs crashes,
  `system.text.parseInt` does not link, and `IoError` cannot be caught: check
  `isFile`/`isDir` before reading. `exec()`'s `ProcResult` must be read in
  the function that called `exec` (see `absolute_dir`); `execShell` runs a
  script through `/bin/sh` with inherited standard streams. A struct is
  built only in its own module (`make_entry`), and a `match` expression
  whose arms build strings must be written in statement form.
- Keep `APP_VERSION` in `source/appinfo.loup` equal to `version` in
  `package.lppkg`.
- The skill's examples use the `loup init` layout (`src/`, `tests/`, and
  `from ..src.x import` in tests). This project uses `source/` and
  `tests/` with plain imports; follow this file.
- The skill documents toolchain 1.25.1; this template targets 1.26.0. When
  they disagree, trust the toolchain's behaviour.
