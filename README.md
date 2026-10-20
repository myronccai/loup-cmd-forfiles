# loup-cmd-forfiles

The Windows `forfiles` command recreated in [Loup](https://code-craft.ai/references/loup):
run a command for each file that matches a mask, in a folder or a whole
tree, with `@file`, `@path` and the other variables filled in, on Linux.

Part of the **loup-cmd** series of example applications: classic Linux and
Windows commands, and projects for each Loup execution mode, each in its own
repository under [myronccai](https://github.com/myronccai?tab=repositories&q=loup-cmd).
This one is `host.dual` Loup built as a native binary. It shows template
substitution, running processes with `execShell`, and a small translator
from cmd.exe command lines to `sh`, on top of the shared Windows code in
[`source/win/`](source/win/) (switch parser, wildcard matcher, paths,
messages).

## Requirements

- Loup 1.26.0 or later:

  ```sh
  curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.sh | sh
  ```

- `make`, and `clang` 17 or later for the native build.

## Usage

```sh
make build                     # native binary: build/forfiles
make ci                        # check, unit tests, build, end-to-end tests
make run ARGS="/M '*.md'"      # run from source (Stage0: loup-bootstrap run)
```

```text
FORFILES [/P pathname] [/M searchmask] [/S] [/C command]
```

Quote masks and the command so that the Linux shell passes them through:
cmd does not expand wildcards, forfiles does. Like the original, forfiles
prints one empty line before the first command's output.

```text
$ build/forfiles /P demo

"data.tar.gz"
"intro.txt"
"logs"
"notes.txt"
$ build/forfiles /P demo /S /M '*.log' /C 'cmd /c echo @relpath'

"./logs/app.log"
"./logs/old/app.LOG"
$ build/forfiles /P demo /M '*.gz' /C 'cmd /c echo @file @fname @ext @isdir @fsize'

"data.tar.gz" "data.tar" "gz" FALSE 1
$ build/forfiles /P demo /M '*.txt' /C 'cmd /c echo @fname0x09@isdir & cat @file'

"intro"	FALSE 
Read me first.
"notes"	FALSE 
Second file.
$ build/forfiles /P demo /S /M '*.log' /C 'wc -l @file'

1 app.log
1 app.LOG
$ build/forfiles /P demo /M '*.doc'; echo "ERRORLEVEL $?"
ERROR: No files found with the specified search criteria.
ERRORLEVEL 1
$ build/forfiles /P nowhere; echo "ERRORLEVEL $?"
ERROR: The system cannot find the file specified.
ERRORLEVEL 1
$ build/forfiles /P demo /X; echo "ERRORLEVEL $?"
ERROR: Invalid argument/option - '/X'.
Type "FORFILES /?" for usage.
ERRORLEVEL 1
$ build/forfiles --version
forfiles (loup-cmd-forfiles) 0.1.0
```

(The space after `FALSE` is cmd's: `echo` prints everything up to the `&`.)

### Switches

| Switch | Meaning |
|---|---|
| `/P path` | where to start (default: the current directory); `\` or `/` |
| `/M mask` | which names to select (default `*`): Windows wildcards, case-insensitive; directories match too |
| `/S` | also search every subdirectory: a folder's matches, then each subfolder, depth first |
| `/C command` | the command to run for each match (default `cmd /c echo @file`) |
| `/?` | help |

Switches start with `/` or `-` in any case; a value is the next argument or
follows a `:` (`/M:*.txt`).

### The command

| Variable | Value for `sub/a.tar.gz` searched from `/w` |
|---|---|
| `@file` | `"a.tar.gz"` |
| `@fname` | `"a.tar"` |
| `@ext` | `"gz"` |
| `@path` | `"/w/sub/a.tar.gz"` |
| `@relpath` | `"./sub/a.tar.gz"` |
| `@isdir` | `FALSE` (`TRUE` for a directory) |
| `@fsize` | the size in bytes (`0` for a directory) |

Variable names ignore case. `0xHH` in the command is the character with that
code (`0x09` tab, `0x22` `"`). Each command runs in the directory that holds
the file, with the terminal's standard input and output.

- `cmd /c LINE` runs LINE as cmd would, translated to `sh`: `echo` prints
  its text literally (quotes included; `ECHO is on.` when empty; `echo.`
  an empty line); `&`, `&&`, `||`, `|`, `>`, `>>`, `<`, `2>nul`, `2>&1`
  and `( ... )` work; `nul` is `/dev/null`; `^` escapes; `%NAME%` is an
  environment variable. Everything else is literal (no `$`, `*` or `'`
  expansion by sh).
- Anything else names a program, run directly with the arguments split the
  Windows way (`"a b"` is one argument). A program that is not on `PATH`
  gives `ERROR: The system cannot find the file specified.`

Exit status (ERRORLEVEL): `0` if at least one file matched (whatever the
commands returned), `1` for no match, a bad `/P`, a missing program or a
command-line error.

## Differences from the original

- `@path` and `@relpath` use `/` (`"./sub/a.txt"`, `"/w/sub/a.txt"`): the
  values are handed to Linux programs. Windows gives `".\sub\a.txt"` and
  `"C:\w\sub\a.txt"`.
- Commands run under `/bin/sh`, not cmd.exe. `cmd /c` lines get only the
  translation above: cmd built-ins other than `echo` (`type`, `dir`, `if`,
  `for`, `set`, ...) are passed to sh as ordinary commands, and `%~`
  modifiers and cmd's quote-stripping rules are not reproduced. Without
  `cmd /c` the program is a Linux program found on `PATH`.
- No `/D` date filter and no `@fdate` / `@ftime`: Loup 1.26.0 cannot read
  file dates (no `stat()`). `/D` is refused as an invalid option.
  `@fsize` reads the whole file to count its bytes.
- `0xHH` codes above `0x7F` give the Unicode character U+00HH (as UTF-8),
  not a character of the console code page.
- File names are case-sensitive on Linux (`/M` masks ignore case); there
  are no 8.3 short names.
- Messages end with LF, not CRLF.
- The `/?` text is a short summary written for this project, not Windows' help.
- `--help` and `--version` as the only argument are series conventions.

## Layout

```text
source/main.loup                 # entry point
source/appinfo.loup              # name, version, exit statuses
source/cli/args.loup             # /P /M /S /C via win.switches, forfiles' error messages
source/cli/usage.loup            # /? and --version text
source/cli/app.loup              # run(): parse, dispatch, exit status
source/commands/forfiles.loup    # select the entries, build and run the scripts
source/commands/substitution.loup # 0xHH escapes and @ variables (`template` is a Loup reserved word)
source/commands/cmdline.loup     # cmd /c → sh translation, Windows-style argument splitting
source/win/                      # shared Windows code (a copy of loup-cmd-type's)
tests/*_test.loup                # unit tests (make test)
tests/e2e.sh                     # end-to-end tests of build/forfiles (make e2e)
specs/forfiles/                  # requirements, design, tasks
```

[AGENTS.md](AGENTS.md) has every build and test command and the conventions
for changing the code.
