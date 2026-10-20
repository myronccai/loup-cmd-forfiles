# Design: forfiles

## Overview

`main()` passes `runtime.args()` to `cli.app.run`, which parses them with the
shared switch parser (`win.switches`), handles `/?` and `--version`, and
calls `commands.forfiles.run_forfiles`. That checks the start directory,
selects the entries (a list of `Entry` values: directory relative to the
start, name, whether it is a directory), and then, for each entry,
substitutes the variables into the command, turns it into a `/bin/sh`
script, and runs it with `execShell`, which inherits standard input, output
and error.

## Modules

| Module | Contents |
|---|---|
| `source/main.loup` | entry point: `run(runtime.args())` |
| `source/appinfo.loup` | name, version, summary, exit statuses (0 and 1) |
| `source/cli/args.loup` | `Options`, `forfiles_switches()`, `parse_args` with forfiles' own error messages |
| `source/cli/usage.loup` | `usage()` (a short help text in this project's own words), `version_line()` |
| `source/cli/app.loup` | `run()`: parse, help/version, run, exceptions to status 1 |
| `source/commands/forfiles.loup` | `start_dir`, `start_error`, `select_entries`, `absolute_dir`, `find_program`, `shell_script`, `run_forfiles` |
| `source/commands/substitution.loup` | `Entry`, `expand_hex`, `name_stem`, `name_ext`, `variable_value`, `substitute` |
| `source/commands/cmdline.loup` | `is_cmd_line`, `cmd_body`, `cmd_to_sh`, `split_args`, `exec_line`, `sh_quote` |
| `source/win/` | the shared Windows code: switches, wildcards, paths, messages |

(The substitution module is not called `template`: that is a reserved word
in Loup.)

### Command line

`/P`, `/M` and `/C` are declared as `required_value` switches (`/P dir`,
`/P:dir`), `/S` as a flag, and `/D` as a `required_value` so that `/D -30`
is one unit that is then refused. A switch given twice, any operand, and
`/D` are errors in forfiles' wording (`ERROR: Invalid syntax. ...` or
`ERROR: Invalid argument/option - '...'.`, then
`Type "FORFILES /?" for usage.`), checked in that order after the parse.

### Selection

`select_entries(start, mask, recurse)` walks with an explicit stack of
relative directories: for each directory it appends
`win.wildcard.list_matches(dir, mask, MATCH_ALL)` (files and directories,
NTFS order, Win32 wildcard rules), then pushes the subdirectories in
reverse so that they come off in name order. That gives `DIR /S` order: a
directory's matches, then each subdirectory's tree. The walk stops at
`MAX_DEPTH` (symlink loops cannot be detected without `lstat`).

### Substitution

`expand_hex` runs once on the command: each `0xHH` (not `00`) becomes
`char.of(HH)`. Then, per entry, `substitute` scans for `@`, tries the
variable names longest first, without regard to case, and inserts
`variable_value`: `@file`, `@fname`, `@ext` (split at the last dot),
`@path` (absolute: the start directory resolved once by
`cd DIR && pwd` in `sh`, since Loup 1.26.0 has no `getcwd`), `@relpath`
(`./` + path from the start directory), all quoted; `@isdir` and `@fsize`
(read from the file's bytes; Loup 1.26.0 has no `stat`) unquoted. Unknown
`@` words are left alone.

### Running

`shell_script(line, dir)` starts with `cd -- 'DIR' || exit 1` and then:

- for `cmd [/x ...] /c LINE` (`/k` too, any case, `cmd.exe`): `cmd_to_sh`
  translates LINE. It walks the characters with a "command position" flag.
  At a command position, `@` is dropped, `(` opens a group, and an `echo`
  word becomes `printf '%s\n' 'TEXT'`, where TEXT runs to the first unquoted
  operator (`&`, `|`, `<`, `>`, or `)` inside a group) with the one
  delimiter after `echo` removed, carets resolved, quotes kept and a digit
  before `>` given to the redirection (cmd's rule). Elsewhere: `"..."` is
  single-quoted for sh; `^x` is a literal `x`; `&` becomes `;`; `&&`, `||`
  and `|` stay; a redirection keeps its operator and handle and its target
  is quoted, with `nul` mapped to `/dev/null`; `%NAME%` is replaced when the
  variable is set; every other character goes through `sh_char`, which
  backslash-escapes anything sh would interpret.
- otherwise: `split_args` splits the line Windows-style (quotes group, `\"`
  is a quote), `find_program` looks the program up (a name with `/`
  relative to the entry's directory, else on `PATH`), and `exec_line`
  single-quotes every argument after `exec`. A program that cannot be found
  gives an empty script and the error.

`run_forfiles` prints one empty line before the first command (Windows
does), runs every script, ignores their statuses, and returns 0.

## Differences from the original

- `@path` and `@relpath` use `/` (`"./sub/a.txt"`), because the values go
  to Linux programs; Windows gives `".\sub\a.txt"` and `"C:\dir\a.txt"`.
- Commands run under `/bin/sh`. `cmd /c` lines are translated, with only
  the cmd features listed above: no `if`, `for`, `set`, `type`, `dir` and
  other built-ins (they reach sh as plain commands), no `%~` modifiers and
  no `cmd /c` quote stripping. Without `cmd /c` the program runs directly,
  as on Windows, but it is a Linux program found on `PATH`.
- No `/D` (Loup 1.26.0 cannot read file dates), so no `@fdate` and
  `@ftime` either. `@fsize` reads the file
  to count its bytes.
- `0xHH` above `0x7F` gives the Unicode character U+00HH (UTF-8), not a
  code-page character.
- File names are case-sensitive on Linux; masks ignore case. No 8.3 short
  names.
- Messages end with LF, not CRLF.
- The `/?` text is a short summary in this project's own words.
- `--help` and `--version` (alone) are series conventions.

## Error handling

Command-line errors, a bad `/P`, no match and a missing program are
reported on standard error with status 1. A command's own failure is its
business: forfiles still exits 0. An unexpected exception is printed as
`ERROR: message` with status 1.

## Testing

- `tests/args_test.loup`: switches, values, every command-line error.
- `tests/substitution_test.loup`: hex escapes, name parts, each variable,
  case-insensitive substitution, unknown `@` words.
- `tests/cmdline_test.loup`: `cmd /c` detection, echo, operators,
  redirections, literal characters, `%VAR%`, Windows-style splitting.
- `tests/forfiles_test.loup`: selection order with and without `/S`,
  start-directory errors, program lookup, the generated scripts.
- `tests/app_test.loup`: exit statuses through `run()`.
- `tests/win_*_test.loup`: the shared Windows code.
- `tests/e2e.sh`: runs the native binary in a fixture tree under `$TMP` and
  compares standard output byte for byte, standard error and the status.
