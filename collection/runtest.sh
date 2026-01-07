#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
. /usr/bin/rhts-environment.sh || exit 1
. /usr/share/beakerlib/beakerlib.sh || exit 1


rlJournalStart
    rlPhaseStartTest
        rlRun "rlImport distribution/collection"
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        rlRun "pushd $TmpDir"
        rlLog "$collectionDISTRO"
        rlLog "$collectionGIT"
        rlRun "collectionMain thermostat1 some_file"
        rlRun "collectionAll thermostat1" 1 #missing file parameter
        rlRun "collectionMain nonexistent file" 1 "collection doesn't exist"
        rlRun "collection_filter_for thermostat1 fake out_file" 1 
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "popd"
        rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
