# Requirements: forfiles

## Introduction

`forfiles` is the Windows command that selects files in a directory (or a
directory tree) by a wildcard mask and runs a command for each one, with
`@file`, `@path` and other variables replaced by the file's details. This
repository recreates it in Loup for Linux, keeping Windows' switch syntax
(`/P`, `/M`, `/S`, `/C`, `/?`), messages and ERRORLEVELs. The command runs
through `/bin/sh`; a command that starts with `cmd /c` is translated from
cmd.exe syntax first, so the classic `forfiles /C "cmd /c echo @file"`
works and prints what Windows prints.

## Requirements

### Requirement 1: Select files

**User Story:** As a cmd user, I want to pick files by folder and mask so
that I can act on each of them.

#### Acceptance Criteria

1. WHEN `/P path` is given, THE program SHALL search that directory
   (either separator accepted); otherwise the current directory.
2. WHEN `/M mask` is given, THE program SHALL select the entries whose name
   matches the mask under Windows wildcard rules (case-insensitive, `*.*`
   matching every name); otherwise the mask is `*`.
3. THE program SHALL select directories as well as files, never `.` or `..`,
   in NTFS name order.
4. WHEN `/S` is given, THE program SHALL also search every subdirectory: the
   matches of a directory first, then each subdirectory in name order, depth
   first.
5. WHEN nothing matches, THE program SHALL print
   `ERROR: No files found with the specified search criteria.` on standard
   error and exit with status 1.

### Requirement 2: Run the command

**User Story:** As a script author, I want a command run for every selected
file, with the file's details substituted.

#### Acceptance Criteria

1. WHEN `/C command` is given, THE program SHALL run it once per selected
   entry, in order; otherwise it SHALL run `cmd /c echo @file`.
2. THE program SHALL replace, case-insensitively, `@file` (the name),
   `@fname` (the name without its extension), `@ext` (the extension without
   the dot), `@path` (the absolute path) and `@relpath` (the path relative to
   the start directory, starting with `./`), each in double quotes, and
   `@isdir` (`TRUE` or `FALSE`) and `@fsize` (the size in bytes, `0` for a
   directory), without quotes.
3. THE program SHALL replace `0xHH` (two hexadecimal digits, not `00`) with
   the character of that code before the variables are replaced.
4. THE program SHALL run each command with the current directory set to the
   directory that holds the entry, with standard input, output and error
   inherited.
5. WHEN at least one entry is selected, THE program SHALL print one empty
   line to standard output before the first command, as Windows does.
6. WHEN the command starts with `cmd /c` (or `cmd.exe`, `/k`, any case), THE
   program SHALL translate the rest from cmd syntax to `sh`: `echo` prints
   its text literally (quotes included, `ECHO is on.` when empty, `echo.` an
   empty line); `&` runs commands in sequence, `&&`, `||`, `|`, `>`, `>>`,
   `<` and handle redirections keep their meaning; `nul` is `/dev/null`;
   `^` escapes a character; `"..."` quotes; `%NAME%` is the environment
   variable when it is set; every other character is literal.
7. WHEN the command does not start with `cmd`, THE program SHALL split it
   into arguments (double quotes group, `\"` is a quote) and run the program
   directly; WHEN the program cannot be found, THE program SHALL print
   `ERROR: The system cannot find the file specified.` and stop with status 1.
8. WHEN at least one entry was selected and the commands ran, THE program
   SHALL exit with status 0, whatever the commands returned.

### Requirement 3: Command line and errors

**User Story:** As a cmd user, I want Windows' switch syntax and messages.

#### Acceptance Criteria

1. THE program SHALL accept the switches `/P`, `/M`, `/S`, `/C` with `/` or
   `-` in any case; values follow as the next argument or after `:`.
2. WHEN `/?` or `-?` is given, THE program SHALL print the help text and exit 0.
3. WHEN a switch value is missing, THE program SHALL print
   `ERROR: Invalid syntax. Value expected for '/X'.` and
   `Type "FORFILES /?" for usage.` on standard error and exit 1.
4. WHEN a switch is given twice, THE program SHALL print
   `ERROR: Invalid syntax. '/X' option is not allowed more than '1' time(s).`
   and the usage line, and exit 1.
5. WHEN any other argument is given (forfiles has no operands), or `/D`,
   THE program SHALL print `ERROR: Invalid argument/option - 'ARG'.` and the
   usage line, and exit 1.
6. WHEN the `/P` directory does not exist, THE program SHALL print
   `ERROR: The system cannot find the file specified.`; WHEN it is a file,
   `ERROR: The directory name is invalid.`; and exit 1.
7. WHEN `--version` is the only argument, THE program SHALL print
   `forfiles (loup-cmd-forfiles) 0.1.0`; `--help` alone SHALL print the help.
