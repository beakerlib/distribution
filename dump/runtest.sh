#!/bin/bash
#shellcheck disable=SC1091
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

# Include Beaker environment
. /usr/share/beakerlib/beakerlib.sh || exit 1


normal() {
    echo "this is a normal plain text file"
    echo "that can be totally normally printed"
    echo "or dumped to log"
    echo ""
    echo "baseline: there's absolutely nothing wrong with this file"
}


manylines() {
    local i
    for i in $(seq 1 20);
    do
        echo "words come"
        echo "lines go"
        echo "a bug"
        echo "seen but"
        echo "never understood"
        echo
    done
}


manybytes() {
    local line1="in this plain text file and there are not many lines"
    local line2="those that are here are somewhat longer which turns out to be"
    local line3="still pretty inconvenient to just dump inside logs"
    local line4="although in this case as well the actual culprit as is"
    local line5="could be the fact that I can't concentrate very well"
    local joint="... i mean ..."
    local i
    for i in $(seq 1 30); do echo -n "$line1 $joint"; done; echo
    for i in $(seq 1 30); do echo -n "$line2 $joint"; done; echo
    for i in $(seq 1 30); do echo -n "$line3 $joint"; done; echo
    for i in $(seq 1 30); do echo -n "$line4 $joint"; done; echo
    for i in $(seq 1 30); do echo -n "$line5 $joint"; done; echo
}

manyboth() {
    local line1="well if you think you have seen a big text file"
    local line2="think again since the most devastating and ugly"
    local line3="effect an engineer can see, is a really verbose"
    local line4="never ending file, dumped right into their face"
    local line5="especially if most lines do not truly bring any"
    local line6="useful information--*and* are rather repetitive"
    local line7="::::::::::::::::x:k:c:d:.:2:7:6::::::::::::::::"
    local joint=":::"
    local i
    for i in $(seq 1 20);
    do
        for j in $(seq 1 3); do echo -n "$line1$joint"; done; echo
        for j in $(seq 1 3); do echo -n "$line2$joint"; done; echo
        for j in $(seq 1 3); do echo -n "$line3$joint"; done; echo
        for j in $(seq 1 3); do echo -n "$line4$joint"; done; echo
        for j in $(seq 1 3); do echo -n "$line5$joint"; done; echo
        for j in $(seq 1 3); do echo -n "$line6$joint"; done; echo
        for j in $(seq 1 3); do echo -n "$line7$joint"; done; echo
        : "$j"  # make friends with ShellCheck
    done
}

binary() {
    local string1="To quote the prophet Jerematic: 1000101010101"
    local string2="010110101000111111110100001100101110101010100"
    local string3="000010010111101111010111010101010101010101010"
    local string4="101111101100010111010011111010101110010100000"
    local string5="001011011010111111010110101111110001001011001"
    local i
    for i in $(seq 1 1);
    do
        printf '\0%s\0' "$string1"
        printf '\0%s\0' "$string2"
        printf '\0%s\0' "$string3"
        printf '\0%s\0' "$string4"
        printf '\0%s\0' "$string5"
        printf '2 \2Amen.\0\1\0 '
    done
}

binarybig() {
    local string1="To quote the prophet Jerematic: 1000101010101"
    local string2="010110101000111111110100001100101110101010100"
    local string3="000010010111101111010111010101010101010101010"
    local string4="101111101100010111010011111010101110010100000"
    local string5="001011011010111111010110101111110001001011001"
    local i
    for i in $(seq 1 10);
    do
        printf '\0%s\0' "$string1"
        printf '\0%s\0' "$string2"
        printf '\0%s\0' "$string3"
        printf '\0%s\0' "$string4"
        printf '\0%s\0' "$string5"
        printf '2 \2Amen.\0\1\0 '
    done
}

empty() {
    echo -n ""
}

noeofnl() {
    echo -n "too ENOLA to print NL at EOF"
}

eofnl() {
    echo "not too ENOLA to print NL at EOF"
}



rlJournalStart
    rlPhaseStartSetup
        . lib.sh
#       rlRun "rlImport distribution/dump"
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        #shellcheck disable=SC2154
        rlRun "pushd $TmpDir"
        rlRun "mkdir sub"
    rlPhaseEnd

    rlPhaseStartTest "variables"
        #shellcheck disable=SC2034
        {
            myvar="content of myvar"
            hisvar="content of hisvar"
            hervar="content of hervar"
            itsvar="content of itsvar"
            avariable="content of avariable"
        }
        rlRun "distribution_dump__var var"
        rlRun "distribution_dump__var 'var$'"
        rlRun "distribution_dump__var its"
    rlPhaseEnd

    rlPhaseStartSetup "create files"
        rlRun "normal       > normal"
        rlRun "manylines    > manylines"
        rlRun "manybytes    > manybytes"
        rlRun "manyboth     > manyboth"
        rlRun "binary       > binary"
        rlRun "binarybig    > binarybig"
        rlRun "normal       > sub/normal"
        rlRun "manyboth     > sub/manyboth"
        rlRun "binary       > sub/binary"
        rlRun "binarybig    > sub/binarybig"
        rlRun "empty        > empty"
        rlRun "noeofnl      > noeofnl"
        rlRun "eofnl        > eofnl"
    rlPhaseEnd

    rlPhaseStartTest "hardly even files"
        rlRun "distribution_dump__file empty"
        rlRun "distribution_dump__file noeofnl"
        rlRun "distribution_dump__file eofnl"
    rlPhaseEnd

    rlPhaseStartTest "varying sizes"
        rlRun "distribution_dump__file normal"
        rlRun "distribution_dump__file manylines"
        rlRun "distribution_dump__file manybytes"
        rlRun "distribution_dump__file manyboth"
        rlRun "distribution_dump__file binary"
        rlRun "distribution_dump__file binarybig"
    rlPhaseEnd

    rlPhaseStartTest "from sub-folder"
        rlRun "distribution_dump__file sub/normal"
        rlRun "distribution_dump__file sub/manyboth"
        rlRun "distribution_dump__file sub/binary"
        rlRun "distribution_dump__file sub/binarybig"
    rlPhaseEnd

    rlPhaseStartTest "from absolute path"
        rlRun "distribution_dump__file $(readlink -f sub/normal)"
        rlRun "distribution_dump__file $(readlink -f sub/manyboth)"
        rlRun "distribution_dump__file $(readlink -f sub/binary)"
        rlRun "distribution_dump__file $(readlink -f sub/binarybig)"
    rlPhaseEnd

    rlPhaseStartTest "anonymous pipe"
        rlRun "normal    | distribution_dump__pipe"
        rlRun "manylines | distribution_dump__pipe"
        rlRun "manybytes | distribution_dump__pipe"
        rlRun "manyboth  | distribution_dump__pipe"
        rlRun "binary    | distribution_dump__pipe"
        rlRun "binarybig | distribution_dump__pipe"
    rlPhaseEnd

    rlPhaseStartTest "pipe with name"
        rlRun "normal    | distribution_dump__pipe Normal"
        rlRun "manylines | distribution_dump__pipe Manylines"
        rlRun "manybytes | distribution_dump__pipe Manybytes"
        rlRun "manyboth  | distribution_dump__pipe Manyboth"
        rlRun "binary    | distribution_dump__pipe Binary"
        rlRun "binarybig | distribution_dump__pipe Binarybig"
    rlPhaseEnd

    rlPhaseStartTest "multiple files in one call"
        rlRun "distribution_dump__file normal manylines manybytes manyboth"
    rlPhaseEnd

    rlPhaseStartTest "binary detection"
        rlRun "distribution_dump__file    normal binary" 0 "autodetect, plain then bin"
        rlRun "distribution_dump__file    binary normal" 0 "autodetect, bin then plain"
        rlRun "distribution_dump__file -h normal binary" 0 "all hex, plain then bin"
        rlRun "distribution_dump__file -h binary normal" 0 "all hex, bin then plain"
        rlRun "distribution_dump__file -H normal binary" 0 "no hex, plain then bin"
        rlRun "distribution_dump__file -H binary normal" 0 "no hex, bin then plain"
    rlPhaseEnd

    rlPhaseStartTest "override limits"
        rlRun "distribution_dump__file -l 4            normal"    0 "less lines"
        rlRun "distribution_dump__file        -b 10    normal"    0 "less bytes"
        rlRun "distribution_dump__file -l 4   -b 10    normal"    0 "less lines and bytes"
        rlRun "distribution_dump__file -l 150          manylines" 0 "more lines"
        rlRun "distribution_dump__file        -b 11000 manybytes" 0 "more bytes"
        rlRun "distribution_dump__file -l 150 -b 22000 manyboth"  0 "more lines and bytes"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "popd"
        rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
