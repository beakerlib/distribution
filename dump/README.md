# NAME

distribution/dump - Helpers for dumping files to log

# DESCRIPTION

Helpers for dumping files to log

This module provides several functions to enable showing
contents of (supposedly small) files or command outputs directly
inside beakerlib log.

This can be very helpful, especially if you know you are dealing
with relatively small files or to provide generic diagnostic
data.

For example:

    some_command >out 2>err
    rlRun "grep foo out"
    rlRun "grep bar out" 1
    rlRun "test -s err" 1
    distribution_dump__file out err

Here, if your asserts fail, it will be very useful to see the content
right in the log.

Another example (from real life):

    rlPhaseStartTest infodump
        ps -C cimserver -o euser,ruser,suser,fuser,f,comm,label \
          | distribution_dump__pipe PS_SECINFO
        ps -C cimserver -f \
          | distribution_dump__pipe PS_F
        ps -C cimserver -Lf \
          | distribution_dump__pipe PS_THREADS
        ps -ef \
          | distribution_dump__pipe PS_EF
        distribution_dump__file /etc/passwd /etc/group
    rlPhaseEnd

Here, in one phase -- without getting in the way of other code
we can get reasonable profile of the cimserver process and
basic system setup.

# VARIABLES

- _$distribution\_dump\_\_hexmode_

    Pipe via hexdump before printing?

    \`always\` to enforce all files through hexdump, \`never\` to disable
    hexdump, \`auto\` to have the filetype detected.

- _$distribution\_dump\_\_hexcmd_

    Command to use for hex dumping

- _$distribution\_dump\_\_limit\_l_

    Limit in lines before rlFileSubmit is used instead of printing

- _$distribution\_dump\_\_limit\_b_

    Limit in bytes before rlFileSubmit is used instead of printing

- _$distribution\_dump\_\_dmpfun_

    Function to use for logging

- _$distribution\_dump\_\_submit_

    Submitting policy

    If 'auto', file is submitted only if it exceeds logging limits
    set by $distribution\_dump\_\_limit\_l and $distribution\_dump\_\_limit\_b.

    If 'files' or 'pipes', files coming from distribution\_dump\_\_file()
    or distribution\_dump\_\_pipe(), respectively, are submitted always
    regardless of size.

    If 'always', all files are always submitted.

    If 'never', file is never submitted.

# FUNCTIONS

- _distribution\_dump\_\_file()_

    Dump contents of given file(s) using rlLogInfo

    Usage:

        distribution_dump__file [options] FILE...

    Description:

    Print contents of given file(s) to the main TESTOUT.log
    using rlLog\* functions and adding BEGIN/END delimiters.
    If a file is too big, use rlFileSubmit instead.  If a file
    is binary, pipe it through \`hexdump -C\`.

    Options:

        *  -h, --hex
        *  -H, --no-hex
                    enforce or ban hexdump for all files
        *  -b BYTES, --max-bytes BYTES
        *  -l LINES, --max-lines LINES
                    set limit to lines or bytes; if file is bigger,
                    use rlFileSubmit instead
        *  -I, --info
        *  -E, --error
        *  -D, --debug
        *  -W, --warning
                    use different level of rlLog* (Info by default)
        *  -s, --skip-empty
                    do not do anything if file is empty
        *  -S, --skip-missing
                    do not do anything if file is missing
        *  -u, --submit
        *  -U, --no-submit
                    enforce or ban submission of all files

- _distribution\_dump\_\_mkphase()_

    Make a dump phase incl. beakerlib formalities

    Usage:
        distribution\_dump\_\_mkphase \[-n NAME\] FILE...

    Create a separate Cleanup phase called NAME ('dump' by
    default) and dump all listed files there.

- _distribution\_dump\_\_pipe()_

    Dump contents passed to stdin using rlLogInfo

    Usage:

        some_command | distribution_dump__pipe [options] [NAME]

    Description:

    Cache contents of stream given on STDIN and print them to
    the main TESTOUT.log using rlLog\* functions and adding
    BEGIN/END delimiters.  If the content is too big, use
    rlFileSubmit instead.  If the content is binary, pipe it
    through \`hexdump -C\`.

    NAME will appear along with pipe content delimiters,  and
    if a limit is reached, will be used as name for file to
    store using rlFileSubmit.  NAME will be generated if
    omitted.

    Options:

        *  -h, --hex
        *  -H, --no-hex
                    enforce or ban hexdump for all files
        *  -b BYTES, --max-bytes BYTES
        *  -l LINES, --max-lines LINES
                    set limit to lines or bytes; if file is bigger,
                    use rlFileSubmit instead
        *  -I, --info
        *  -E, --error
        *  -D, --debug
        *  -W, --warning
                    use different level of rlLog* (Info by default)
        *  -u, --submit
        *  -U, --no-submit
                    enforce or ban submission of all files

- _distribution\_dump\_\_var()_

    Dump contents of given variables using rlLogInfo

    Usage:

        distribution_dump__var [options] RE...

    Description:

    Print contents of all variable(s) matching regex RE to the main
    TESTOUT.log using rlLog\* functions.  Regex is a basic regular
    expression (BRE) and is matched against whole name (ie. you
    don't need to add \`^\` and \`$\` anchors).

    Options:

        *  -I, --info
        *  -E, --error
        *  -D, --debug
        *  -W, --warning
                    use different level of rlLog* (Info by default)
        *  -S, --skip-missing
                    do not do anything if variable is missing

- _distribution\_dump\_\_LibraryLoaded()_

    Do nothing (handler required by rlImport)
