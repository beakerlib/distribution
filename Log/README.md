# NAME

BeakerLib library Log

# DESCRIPTION

This library provide logging capability which does not rely on beakerlib so it
can be used standalone.

If it is used within beakerlib it automatically bypass all messages to the
beakerlib.

Also this library provide journaling feature so the summary can be printed out
at the end.

# USAGE

To use this functionality you need to import library distribution/Log and add
following line to Makefile.

        @echo "RhtsRequires:    library(distribution/Log)" >> $(METADATA)

# FUNCTIONS

### LogReport

Prints final report similar to breakerlib's rlJournalPrintText. This is useful
mainly if you use TCF without beakerlib.

    LogReport

# AUTHORS

- Dalibor Pospisil <dapospis@redhat.com>
