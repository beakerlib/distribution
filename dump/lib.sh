#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2015 Red Hat, Inc.
#
#   This program is free software: you can redistribute it and/or
#   modify it under the terms of the GNU General Public License as
#   published by the Free Software Foundation, either version 2 of
#   the License, or (at your option) any later version.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE.  See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program. If not, see http://www.gnu.org/licenses/.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   library-prefix = distribution_dump__
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

#
# Helpers for dumping files to log
#
# This module provides several functions to enable showing
# contents of (supposedly small) files or command outputs directly
# inside beakerlib log.
#
# This can be very helpful, especially if you know you are dealing
# with relatively small files or to provide generic diagnostic
# data.
#
# For example:
#
#     some_command >out 2>err
#     rlRun "grep foo out"
#     rlRun "grep bar out" 1
#     rlRun "test -s err" 1
#     distribution_dump__file out err
#
# Here, if your asserts fail, it will be very useful to see the content
# right in the log.
#
# Another example (from real life):
#
#     rlPhaseStartTest infodump
#         ps -C cimserver -o euser,ruser,suser,fuser,f,comm,label \
#           | distribution_dump__pipe PS_SECINFO
#         ps -C cimserver -f \
#           | distribution_dump__pipe PS_F
#         ps -C cimserver -Lf \
#           | distribution_dump__pipe PS_THREADS
#         ps -ef \
#           | distribution_dump__pipe PS_EF
#         distribution_dump__file /etc/passwd /etc/group
#     rlPhaseEnd
#
# Here, in one phase -- without getting in the way of other code
# we can get reasonable profile of the cimserver process and
# basic system setup.
#

#
# Pipe via hexdump before printing?
#
# `always` to enforce all files through hexdump, `never` to disable
# hexdump, `auto` to have the filetype detected.
#
distribution_dump__hexmode=${distribution_dump__hexmode:-auto}


#
# Command to use for hex dumping
#
distribution_dump__hexcmd=${distribution_dump__hexcmd:-hexdump -C}


#
# Limit in lines before rlFileSubmit is used instead of printing
#
distribution_dump__limit_l=${distribution_dump__limit_l:-100}


#
# Limit in bytes before rlFileSubmit is used instead of printing
#
distribution_dump__limit_b=${distribution_dump__limit_b:-10000}


#
# Function to use for logging
#
distribution_dump__dmpfun=${distribution_dump__dmpfun:-rlLogInfo}

#
# Submitting policy
#
# If 'auto', file is submitted only if it exceeds logging limits
# set by $distribution_dump__limit_l and $distribution_dump__limit_b.
#
# If 'files' or 'pipes', files coming from distribution_dump__file()
# or distribution_dump__pipe(), respectively, are submitted always
# regardless of size.
#
# If 'always', all files are always submitted.
#
# If 'never', file is never submitted.
#
distribution_dump__submit=${distribution_dump__submit:-auto}


distribution_dump__file() {
    #
    # Dump contents of given file(s) using rlLogInfo
    #
    # Usage:
    #
    #     distribution_dump__file [options] FILE...
    #
    # Description:
    #
    # Print contents of given file(s) to the main TESTOUT.log
    # using rlLog* functions and adding BEGIN/END delimiters.
    # If a file is too big, use rlFileSubmit instead.  If a file
    # is binary, pipe it through `hexdump -C`.
    #
    # Options:
    #
    #   *  -h, --hex
    #   *  -H, --no-hex
    #               enforce or ban hexdump for all files
    #   *  -b BYTES, --max-bytes BYTES
    #   *  -l LINES, --max-lines LINES
    #               set limit to lines or bytes; if file is bigger,
    #               use rlFileSubmit instead
    #   *  -I, --info
    #   *  -E, --error
    #   *  -D, --debug
    #   *  -W, --warning
    #               use different level of rlLog* (Info by default)
    #   *  -s, --skip-empty
    #               do not do anything if file is empty
    #   *  -S, --skip-missing
    #               do not do anything if file is missing
    #   *  -u, --submit
    #   *  -U, --no-submit
    #               enforce or ban submission of all files
    #
    local hexmode=$distribution_dump__hexmode
    local limit_b=$distribution_dump__limit_b
    local limit_l=$distribution_dump__limit_l
    local dmpfun="$distribution_dump__dmpfun"
    local skip_empty=false
    local skip_missing=false
    local subpol=$distribution_dump__submit
    while true; do case "$1" in
        -h|--hex)        hexmode=always;      shift 1 ;;
        -H|--no-hex)     hexmode=never;       shift 1 ;;
        -b|--max-bytes)  limit_b=$2;          shift 2 ;;
        -l|--max-lines)  limit_l=$2;          shift 2 ;;
        -I|--info)       dmpfun=rlLogInfo;    shift 1 ;;
        -E|--error)      dmpfun=rlLogError;   shift 1 ;;
        -D|--debug)      dmpfun=rlLogDebug;   shift 1 ;;
        -W|--warning)    dmpfun=rlLogWarning; shift 1 ;;
        -s|--skip-empty) skip_empty=true;     shift 1 ;;
        -S|--skip-missing) skip_missing=true; shift 1 ;;
        -u|--submit)     subpol=always;       shift 1 ;;
        -U|--no-submit)  subpol=never;        shift 1 ;;
        *) break ;;
    esac done

    local fpath     # path to original file
    local hexdump   # path to hexdumped file, if needed

    for fpath in "$@";
    do

        # skipping logic
        ! test -e "$fpath" && $skip_missing && continue
        test -e "$fpath" || { rlLogWarning "no such file: $fpath"; continue; }
        test -f "$fpath" || { rlLogWarning "not a file: $fpath"; continue; }
        ! test -s "$fpath" && $skip_empty && continue

        if __distribution_dump__use_hex "$hexmode" "$fpath";
        then
            hexdump=$(__distribution_dump__mkhexdump < "$fpath")
            __distribution_dump__logobj FHEX "$subpol" "$hexdump" "$fpath" "$fpath"
            rm "$hexdump"
        else
            __distribution_dump__logobj FILE "$subpol" "$fpath" "$fpath"
        fi

    done
}

distribution_dump__mkphase() {
    #
    # Make a dump phase incl. beakerlib formalities
    #
    # Usage:
    #     distribution_dump__mkphase [-n NAME] FILE...
    #
    # Create a separate Cleanup phase called NAME ('dump' by
    # default) and dump all listed files there.
    #
    local name="dump"           # phase name, should you not like dump
    while true; do case "$1" in
        -n|--name) name=$2; shift 2 ;;
        *) break ;;
    esac done
    rlPhaseStartCleanup "$name"
        distribution_dump__file "$@"
    rlPhaseEnd
}

distribution_dump__pipe() {
    #
    # Dump contents passed to stdin using rlLogInfo
    #
    # Usage:
    #
    #     some_command | distribution_dump__pipe [options] [NAME]
    #
    # Description:
    #
    # Cache contents of stream given on STDIN and print them to
    # the main TESTOUT.log using rlLog* functions and adding
    # BEGIN/END delimiters.  If the content is too big, use
    # rlFileSubmit instead.  If the content is binary, pipe it
    # through `hexdump -C`.
    #
    # NAME will appear along with pipe content delimiters,  and
    # if a limit is reached, will be used as name for file to
    # store using rlFileSubmit.  NAME will be generated if
    # omitted.
    #
    # Options:
    #
    #   *  -h, --hex
    #   *  -H, --no-hex
    #               enforce or ban hexdump for all files
    #   *  -b BYTES, --max-bytes BYTES
    #   *  -l LINES, --max-lines LINES
    #               set limit to lines or bytes; if file is bigger,
    #               use rlFileSubmit instead
    #   *  -I, --info
    #   *  -E, --error
    #   *  -D, --debug
    #   *  -W, --warning
    #               use different level of rlLog* (Info by default)
    #   *  -u, --submit
    #   *  -U, --no-submit
    #               enforce or ban submission of all files
    #
    local hexmode=$distribution_dump__hexmode
    local limit_b=$distribution_dump__limit_b
    local limit_l=$distribution_dump__limit_l
    local dmpfun="$distribution_dump__dmpfun"
    local cache
    local subpol=$distribution_dump__submit
    while true; do case "$1" in
        -h|--hex)        hexmode=always;      shift 1 ;;
        -H|--no-hex)     hexmode=never;       shift 1 ;;
        -b|--max-bytes)  limit_b=$2;          shift 2 ;;
        -l|--max-lines)  limit_l=$2;          shift 2 ;;
        -I|--info)       dmpfun=rlLogInfo;    shift 1 ;;
        -E|--error)      dmpfun=rlLogError;   shift 1 ;;
        -D|--debug)      dmpfun=rlLogDebug;   shift 1 ;;
        -W|--warning)    dmpfun=rlLogWarning; shift 1 ;;
        -u|--submit)     subpol=always;       shift 1 ;;
        -U|--no-submit)  subpol=never;        shift 1 ;;
        *) break ;;
    esac done
    local name="$1"

    # cache the stream
    cache=$(mktemp -t distribution_dump-cache.XXXXXXXXXX)
    cat > "$cache"

    # make up name if not given (re-use XXXXXXXXXX from $cache)
    test -n "$name" || name="ANONYMOUS.$$.${cache##*.}"

    if __distribution_dump__use_hex "$hexmode" "$cache";
    then
        hexdump=$(__distribution_dump__mkhexdump < "$cache")
        __distribution_dump__logobj PHEX "$subpol" "$hexdump" "$name" "$cache"
        rm "$hexdump"
    else
        __distribution_dump__logobj PIPE "$subpol" "$cache" "$name"
    fi

    rm "$cache"
}

distribution_dump__var() {
    #
    # Dump contents of given variables using rlLogInfo
    #
    # Usage:
    #
    #     distribution_dump__var [options] RE...
    #
    # Description:
    #
    # Print contents of all variable(s) matching regex RE to the main
    # TESTOUT.log using jat__log* functions.  Regex is an extended
    # regular expression (ERE, or grep -E) matched without anchors
    # (ie. add `^` or `$` to # match against whole name).
    #
    # Options:
    #
    #   *  -I, --info
    #   *  -E, --error
    #   *  -D, --debug
    #   *  -W, --warning
    #               use different level of rlLog* (Info by default)
    #   *  -S, --skip-missing
    #               do not do anything if variable is missing
    #
    local re
    local dmpfun="$distribution_dump__dmpfun"
    local skip_missing=false
    local matches=()
    local varname
    local mbuff
    while true; do case "$1" in
        -I|--info)       dmpfun=rlLogInfo;    shift 1 ;;
        -E|--error)      dmpfun=rlLogError;   shift 1 ;;
        -D|--debug)      dmpfun=rlLogDebug;   shift 1 ;;
        -W|--warning)    dmpfun=rlLogWarning; shift 1 ;;
        -S|--skip-missing) skip_missing=true; shift 1 ;;
        *) break ;;
    esac done
    mbuff=$(mktemp -t distribution_dump__var.XXXXXXXXXX)
    for re in "$@";
    do
        matches=()
        __distribution_dump__vngrep "$re" >"$mbuff"
        mapfile -t matches <"$mbuff"
        if test "${#matches[@]}" -eq 0;
        then
            $skip_missing || rlLogWarning "no variables matching: $re"
            $skip_missing && continue
        else
            rlLogInfo "variables matching: $re"
            for varname in "${matches[@]}"; do
                $dmpfun "    $varname='${!varname}'"
            done
        fi
    done
    rm "$mbuff"
}


##                    ## starts behind this strip                           ##
## museum of INTERNAL ## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ##
##           '''''''' ## no admission; you can steal but not touch anything ##

__distribution_dump__count() {
    #
    # Count sizes, compare to limits and print problem report if any
    #
    #inherits: limit_l limit_b
    local file="$1"
    local sizes size_b size_l
    local over_b over_l many
    sizes="$(wc -lc <"$file")"      # [newline] [bytes]
    sizes="$(eval "echo $sizes")"   # squash + trim whites
    size_b="${sizes##* }"
    size_l="${sizes%% *}"
    test "$size_b" -gt "$limit_b"; over_b=$?
    test "$size_l" -gt "$limit_l"; over_l=$?
    case "$over_b:$over_l" in
        1:1) many=""                                    ;;
        1:0) many="lines ($size_l)"                     ;;
        0:1) many="bytes ($size_b)"                     ;;
        0:0) many="lines ($size_l) and bytes ($size_b)" ;;
        *)   rlFail "panic: $FUNCNAME"                  ;;
    esac
    echo "$many"
    test -z "$many"
}

__distribution_dump__is_binary() {
    #
    # Check if file is binary
    #
    local path="$1"
    test -s "$path"     || return 1
    grep -qI . "$path"  && return 1
    return 0
}

__distribution_dump__logobj() {
    #
    # Dump the object type $1 with submission policy $2 from $3, or save it under name $4
    #
    # Type can be FILE, FHEX, PIPE or PHEX.  If object is too big to dump
    # to log, it will be submitted using rlFileSubmit. in that case
    # $3 may be specified as alternative name.
    #
    # In case of FHEX or PHEX, path to original file must be specified
    # as $5, since in case file is too big, we want to submitt *both*
    # the original and the hexdump (suffixed with .hex).
    #
    # FIXME: no way of dumping ?HEX without supplying alternate name
    #
    # In case of PIPE that needs to be submitted, suffiix ".pipe" is added
    # to the filename.
    #
    # FIXME: Account for PIPE that gets HEXdumped (now be treated as file)
    #
    local otype=$1              # PIPE|PHEX|FILE|FHEX
    local subpol=$2             # local submission policy
    local opath=$3              # printable data
    local oname=${4:-$opath}    # chosen name
    local oorig=$5              # original file in case of ?HEX
    local bloat=""              # human description of limit excess; empty
                                # .. means OK to dump to log; else use rlFileSubmit
    local lline=""              # logged line
    local submit=false

    oname="$(tr / - <<<"$oname")"
    bloat="$(__distribution_dump__count "$opath")"

    rlLogDebug "$FUNCNAME:otype='$otype'"
    rlLogDebug "$FUNCNAME:opath='$opath'"
    rlLogDebug "$FUNCNAME:oname='$oname'"
    rlLogDebug "$FUNCNAME:oorig='$oorig'"
    rlLogDebug "$FUNCNAME:bloat='$bloat'"

    # start outputting
    if test -z "$bloat";
    then
        test -s "$opath" || {
            case $dmpfun in
                rlLogDebug) rlLogDebug "=====EMPTY $otype $oname=====" ;;
                *)          rlLogInfo  "=====EMPTY $otype $oname=====" ;;
            esac
            return
        }
        {
            echo "=====BEGIN $otype $oname====="
            cat "$opath"
            test -n "$(tail -c 1 "$opath")" \
             && echo "=====NO_NEWLINE_AT_EOF====="
            echo  "=====END $otype $oname====="
        } \
          | while IFS= read -r lline; do
                $dmpfun "$lline"
            done
    else
        case $otype in
            FILE)    rlLogInfo "not dumping, file has too many $bloat: $opath" ;;
            PIPE)    rlLogInfo "not dumping, pipe has too many $bloat: $oname" ;;
            ?HEX)    rlLogInfo "not dumping, hexdump is too long for: $oorig" ;;
        esac
    fi
    case $otype:$subpol:$bloat in
        *:never:*)       submit=false ;;
        *:always:*)      submit=true ;;
        FILE:files:*)    submit=true ;;
        FHEX:files:*)    submit=true ;;
        *:files:*)       submit=false ;;
        PIPE:pipes:*)    submit=true ;;
        PHEX:pipes:*)    submit=true ;;
        *:pipes:*)       submit=false ;;
        *:auto:)         submit=false ;;
        *:auto:*)        submit=true ;;
    esac
    if $submit; then
        case $otype in
            FILE)
                rlFileSubmit -- "$opath" "$oname" >&2
                ;;
            PIPE)
                rlFileSubmit -- "$opath" "$oname.pipe" >&2
                ;;
            ?HEX)
                rlFileSubmit -- "$opath" "$oname.hex" >&2
                rlFileSubmit -- "$oorig" "$oname" >&2
                ;;
        esac
    fi
}

__distribution_dump__mkhexdump() {
    #
    # Create hexdump (as tempfile) from stdin and echo path to it
    #
    local hdtmp
    hdtmp=$(mktemp -t distribution_dump-hex.XXXXXXXXXX)
    $distribution_dump__hexcmd > "$hdtmp"
    echo "$hdtmp"
}

__distribution_dump__use_hex() {
    #
    # True if we need to use hexdump
    #
    local hexmode="$1"
    local fpath="$2"
    case "$hexmode" in
        always) return 0 ;;
        never)  return 1 ;;
        auto)   __distribution_dump__is_binary "$fpath"; return $? ;;
        *)      rlFail "bad value of distribution_dump__hexmode: $hexmode" ;;
    esac
}

__distribution_dump__vngrep() {
    #
    # Print global variable names matching regex $1
    #
    local re=$1
    set \
      | grep '^[[:alpha:]_][[:alnum:]_]*[^=]=' \
      | cut -d= -f1 \
      | grep -Ee "$re" \
      | sort
}

distribution_dump__LibraryLoaded() {
    #
    # Do nothing (handler required by rlImport)
    #
    :
}

#----- SFDOC EMBEDDED POD BEGIN -----#
#
# This part is automatically generated by extracting POD page from rest of
# the code by sfdoc and embedding it using an experimental utility.
#
# In other words, do not edit any code between this comment and line
# containing SFDOC EMBEDDED POD END or YOUR CHANGES WILL BE LOST.
#

true <<'=cut'
=pod

=encoding utf8

=head1 NAME

distribution/dump - Helpers for dumping files to log

=head1 DESCRIPTION

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


=head1 VARIABLES

=over 8


=item I<$distribution_dump__hexmode>

Pipe via hexdump before printing?

`always` to enforce all files through hexdump, `never` to disable
hexdump, `auto` to have the filetype detected.


=item I<$distribution_dump__hexcmd>

Command to use for hex dumping


=item I<$distribution_dump__limit_l>

Limit in lines before rlFileSubmit is used instead of printing


=item I<$distribution_dump__limit_b>

Limit in bytes before rlFileSubmit is used instead of printing


=item I<$distribution_dump__dmpfun>

Function to use for logging


=item I<$distribution_dump__submit>

Submitting policy

If 'auto', file is submitted only if it exceeds logging limits
set by $distribution_dump__limit_l and $distribution_dump__limit_b.

If 'files' or 'pipes', files coming from distribution_dump__file()
or distribution_dump__pipe(), respectively, are submitted always
regardless of size.

If 'always', all files are always submitted.

If 'never', file is never submitted.

=back


=head1 FUNCTIONS

=over 8


=item I<distribution_dump__file()>

Dump contents of given file(s) using rlLogInfo

Usage:

    distribution_dump__file [options] FILE...

Description:

Print contents of given file(s) to the main TESTOUT.log
using rlLog* functions and adding BEGIN/END delimiters.
If a file is too big, use rlFileSubmit instead.  If a file
is binary, pipe it through `hexdump -C`.

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


=item I<distribution_dump__mkphase()>

Make a dump phase incl. beakerlib formalities

Usage:
    distribution_dump__mkphase [-n NAME] FILE...

Create a separate Cleanup phase called NAME ('dump' by
default) and dump all listed files there.


=item I<distribution_dump__pipe()>

Dump contents passed to stdin using rlLogInfo

Usage:

    some_command | distribution_dump__pipe [options] [NAME]

Description:

Cache contents of stream given on STDIN and print them to
the main TESTOUT.log using rlLog* functions and adding
BEGIN/END delimiters.  If the content is too big, use
rlFileSubmit instead.  If the content is binary, pipe it
through `hexdump -C`.

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


=item I<distribution_dump__var()>

Dump contents of given variables using rlLogInfo

Usage:

    distribution_dump__var [options] RE...

Description:

Print contents of all variable(s) matching regex RE to the main
TESTOUT.log using rlLog* functions.  Regex is a basic regular
expression (BRE) and is matched against whole name (ie. you
don't need to add `^` and `$` anchors).

Options:

  *  -I, --info
  *  -E, --error
  *  -D, --debug
  *  -W, --warning
              use different level of rlLog* (Info by default)
  *  -S, --skip-missing
              do not do anything if variable is missing


=item I<distribution_dump__LibraryLoaded()>

Do nothing (handler required by rlImport)

=back

=cut
#----- SFDOC EMBEDDED POD END -----#
