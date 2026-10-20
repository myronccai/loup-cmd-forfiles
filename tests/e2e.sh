#!/usr/bin/env bash
# End-to-end tests: run the built binary and compare its standard output
# (byte for byte), and where given its standard error, and exit status with
# the expected ones. The cases run inside a fixture tree built under $TMP.
#
# usage: tests/e2e.sh BINARY

set -u
BIN=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
pass=0
fail=0

# check_file NAME STATUS EXPECTED_FILE [ARGS...]
# Runs BINARY ARGS... with standard input from the file named by $IN
# (default: /dev/null) and compares standard output with EXPECTED_FILE.
# If $WANT_ERR is set, standard error must equal it too.
check_file() {
    local name=$1 want_status=$2 want_file=$3
    shift 3
    "$BIN" "$@" < "${IN:-/dev/null}" > "$TMP/out" 2> "$TMP/err"
    local status=$?
    local err_ok=1
    if [ -n "${WANT_ERR+set}" ]; then
        printf '%s' "$WANT_ERR" > "$TMP/want_err"
        cmp -s "$TMP/want_err" "$TMP/err" || err_ok=0
    fi
    if [ "$status" -eq "$want_status" ] && cmp -s "$want_file" "$TMP/out" && [ "$err_ok" -eq 1 ]; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $name (exit $status, expected $want_status)"
        diff <(od -c "$want_file") <(od -c "$TMP/out") | sed 's/^/    /' | head -20
        if [ "$err_ok" -eq 0 ]; then
            diff <(od -c "$TMP/want_err") <(od -c "$TMP/err") | sed 's/^/    stderr /' | head -20
        fi
        sed 's/^/    stderr: /' "$TMP/err" | head -5
    fi
}

# check NAME STATUS EXPECTED_STDOUT [ARGS...]
# As check_file, with the expected output given as a string. Bash strings
# cannot hold NUL bytes; use check_file for output that contains them.
check() {
    local name=$1 want_status=$2
    printf '%s' "$3" > "$TMP/want"
    shift 3
    check_file "$name" "$want_status" "$TMP/want" "$@"
}

# check_both NAME STATUS EXPECTED_STDOUT EXPECTED_STDERR [ARGS...]
check_both() {
    local name=$1 want_status=$2 want_out=$3
    local WANT_ERR=$4
    shift 4
    check "$name" "$want_status" "$want_out" "$@"
}

# The fixture tree. forfiles lists names in NTFS order (upper-case form).
W="$TMP/w"
mkdir -p "$W/sub/deep" "$W/Other"
printf 'alpha\n' > "$W/a.txt"
printf 'bb\n' > "$W/B.TXT"
printf 'readme\n' > "$W/README"
printf 'tar' > "$W/a.tar.gz"
printf 'p' > "$W/.profile"
: > "$W/my file.txt"
printf 'sub c\n' > "$W/sub/c.txt"
printf 'deep d\n' > "$W/sub/deep/d.log"
HELP="$(cd "$(dirname "$0")" && pwd)/fixtures/help.txt"
cd "$W"

usage_hint='Type "FORFILES /?" for usage.'
no_files=$'ERROR: No files found with the specified search criteria.\n'

# Help and version.
WANT_ERR='' check_file "/? help"   0 "$HELP"                    '/?'
check_file "-? help"                0 "$HELP"                   -s '-?'
check_file "--help"                 0 "$HELP"                   --help
check      "--version"              0 $'forfiles (loup-cmd-forfiles) 0.1.0\n' --version

# Selection. Output starts with the empty line Windows prints.
check_both "default: every entry"   0 \
    $'\n".profile"\n"a.tar.gz"\n"a.txt"\n"B.TXT"\n"my file.txt"\n"Other"\n"README"\n"sub"\n' ''
check      "mask ignores case"      0 $'\n"a.txt"\n"B.TXT"\n"my file.txt"\n' /M '*.TXT'
check      "-m and colon value"     0 $'\n"a.txt"\n"B.TXT"\n"my file.txt"\n' -m:'*.txt'
check      "literal mask"           0 $'\n"README"\n'                   /m readme
check      "*. no extension"        0 $'\n"Other"\n"README"\n"sub"\n'   /M '*.'
check      "a?.txt"                 0 $'\n"a.txt"\n'                    /M 'a?.txt'
check      "/S"                     0 $'\n"a.txt"\n"B.TXT"\n"my file.txt"\n"c.txt"\n' /S /M '*.txt'
check      "/S order"               0 $'\n"c.txt"\n"deep"\n"d.log"\n'   /P sub /S
check      "/P backslash"           0 $'\n"d.log"\n'                    /P 'sub\deep\'
check      "/P absolute"            0 $'\n"c.txt"\n"deep"\n'            /P "$W/sub"

# Variables.
check      "@relpath"               0 $'\n"./a.txt"\n"./B.TXT"\n"./my file.txt"\n"./sub/c.txt"\n' \
    /S /M '*.txt' /C 'cmd /c echo @relpath'
check      "@path"                  0 $'\n"'"$W"$'/sub/deep/d.log"\n' /S /M '*.log' /C 'cmd /c echo @path'
check      "@fname @ext"            0 $'\n".profile" "" "profile"\n"a.tar.gz" "a.tar" "gz"\n"Other" "Other" ""\n"README" "README" ""\n' \
    /M '*r*' /C 'cmd /c echo @file @fname @ext'
check      "@isdir @fsize of a file" 0 $'\n"a.txt" FALSE 6\n'       /M a.txt /C 'cmd /c echo @FILE @IsDir @fsize'
check      "@isdir @fsize of dirs"  0 $'\n"Other" TRUE 0\n"sub" TRUE 0\n' \
    /M '?????' /C 'cmd /c echo @file @isdir @FSIZE'
check      "unknown @ words"        0 $'\n@fdate x@y "a.txt"s\n'        /M a.txt /C 'cmd /c echo @fdate x@y @files'
check      "0xHH escapes"           0 $'\n["a"]\t"txt"\n'                 /M a.txt /C 'cmd /c echo [0x40fname]0x09@ext'

# Running commands: in the entry's directory, status ignored.
check      "runs in the entry dir"  0 $'\nalpha\nbb\nsub c\n'          /S /M '?.txt' /C 'cmd /c cat @file'
check      "direct program"         0 $'\n[a.txt][x y]'               /M a.txt /C 'printf [%s] @file "x y"'
check      "status ignored"         0 $'\n'                             /M a.txt /C 'sh -c "exit 3"'
check_both "program not found"      1 $'\n' $'ERROR: The system cannot find the file specified.\n' \
    /M a.txt /C 'loup-forfiles-no-such-program @file'

# cmd /c translation.
check      "echo keeps quotes"      0 $'\n"a.txt"\n'                    /M a.txt
check      "& and trailing space"   0 $'\none \ntwo\n'                  /M a.txt /C 'cmd /c echo one & echo two'
check      "&& and ||"              0 $'\nfailed\n'                     /M a.txt /C 'cmd /c false && echo no || echo failed'
check      "pipe"                   0 $'\nALPHA\n'                      /M a.txt /C 'cmd /c cat @file | tr a-z A-Z'
check      "literal characters"     0 $'\n$HOME * `x` \'q\' ;\n'        /M a.txt /C "cmd /c echo \$HOME * \`x\` 'q' ;"
check      "caret escape"           0 $'\na&b|c\n'                      /M a.txt /C 'cmd /c echo a^&b^|c'
LOUP_FF_TEST=value check "%VAR%"    0 $'\n<value> %LOUP_FF_UNSET%\n'   /M a.txt /C 'cmd /c echo ^<%LOUP_FF_TEST%^> %LOUP_FF_UNSET%'
check      "ECHO is on."            0 $'\nECHO is on.\n'                /M a.txt /C 'cmd /c echo'
check      "echo."                  0 $'\n\n'                           /M a.txt /C 'cmd /c echo.'
check      "redirect to nul"        0 $'\n'                             /M a.txt /C 'cmd /c echo hidden>nul'
check      "redirect to a file"     0 $'\n'                             /M '*.txt' /C "cmd /c echo @file>>$TMP/list.out"
printf '"a.txt"\n"B.TXT"\n"my file.txt"\n' > "$TMP/list.want"
if cmp -s "$TMP/list.want" "$TMP/list.out"; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: contents of the >> file"; fi
check      "cmd.exe /C, any case"   0 $'\nok\n'                         /M a.txt /C 'CMD.EXE /Q /C echo ok'

# Errors (ERRORLEVEL 1, messages on stderr).
check_both "no match"               1 '' "$no_files"                    /M '*.none'
check_both "/S no match"            1 '' "$no_files"                    /S /M '*.none'
check_both "/P missing"             1 '' $'ERROR: The system cannot find the file specified.\n' /P nodir
check_both "/P is a file"           1 '' $'ERROR: The directory name is invalid.\n' /P a.txt
check_both "operand"                1 '' "ERROR: Invalid argument/option - 'a.txt'."$'\n'"$usage_hint"$'\n' a.txt
check_both "unknown switch"         1 '' "ERROR: Invalid argument/option - '/x'."$'\n'"$usage_hint"$'\n' /x
check_both "missing value"          1 '' "ERROR: Invalid syntax. Value expected for '/m'."$'\n'"$usage_hint"$'\n' /m
check_both "value then switch"      1 '' "ERROR: Invalid syntax. Value expected for '/P'."$'\n'"$usage_hint"$'\n' /P /S
check_both "repeated switch"        1 '' "ERROR: Invalid syntax. '/s' option is not allowed more than '1' time(s)."$'\n'"$usage_hint"$'\n' /S /M a /s
check_both "/D not supported"       1 '' "ERROR: Invalid argument/option - '/D'."$'\n'"$usage_hint"$'\n' /D -30
check_both "-- ends switches"       1 '' "ERROR: Invalid argument/option - '/S'."$'\n'"$usage_hint"$'\n' -- /S

echo "e2e: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
