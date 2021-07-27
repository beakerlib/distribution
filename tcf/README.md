# NAME

BeakerLib library Try-Check-Final

# DESCRIPTION

This file contains functions which gives user the ability to define blocks of
code where some of the blocks can be automatically skipped if some of preceeding
blocks failed.

ATTENTION
This plugin modifies some beakerlib functions! If you suspect that it breakes
some functionality set the environment variable TCF\_NOHACK to nonempty value.

# USAGE

To use this functionality you need to import library distribution/tcf and add
following line to Makefile.

        @echo "RhtsRequires:    library(distribution/tcf)" >> $(METADATA)

# FUNCTIONS

## Block functions

### tcfTry

Starting function of block which will be skipped if an error has been detected
by tcfFin function occurent before.

    tcfTry ["title"] [-i|--ignore] [--no-assert] [--fail-tag TAG] && {
      <some code>
    tcfFin; }

If title is omitted than noting is printed out so no error will be reported (no
Assert is executed) thus at least the very top level tcfTry should have title.

tcfTry and tcfChk blocks are stackable so you can organize them into a hierarchy
structure.

Note that tcfFin has to be used otherwise the overall result will not be
accurate.

- title

    Text which will be displayed and logged at the beginning and the end (in tcfFin
    function) of the block.

- -i, --ignore

    Do not propagate the actual result to the higher level result.

- -n, --no-assert

    Do not log error into the journal.

- -f, --fail-tag TAG

    If the result of the block is FAIL, use TAG instead ie. INFO or WARNING.

Returns 1 if and error occured before, otherwise returns 0.

### tcfChk

Starting function of block which will be always executed.

    tcfChk ["title"] [-i|--ignore] [--no-assert] [--fail-tag TAG] && {
      <some code>
    tcfFin; }

If title is omitted than noting is printed out so no error will be reported (no
Assert is executed) thus at least the very top level tcfChk should have title.

tcfTry and tcfChk blocks are stackable so you can organize them into a hierarchy
structure.

Note that tcfFin has to be used otherwise the overall result will not be
accurate.

For details about arguments see tcfTry.

Returns 0.

### tcfFin

Ending function of block. It does some evaluation of previous local and global
results and puts it into the global result.

    tcfTry ["title"] && {
      <some code>
    tcfFin [-i|--ignore] [--no-assert] [--fail-tag TAG]; }

Local result is actualy exit code of the last command int the body.

Global result is an internal varibale hodning previous local results.
Respectively last error or 0.

For details about arguments see tcfTry.

Returns local result of the preceeding block.

## Functions for manipulation with the results

### tcfRES

Sets and return the global result.

    tcfRES [-p|--print] [number]

- -p --print

    Also print the result value.

- number

    If present the global result is set to this value.

Returns global result.

### tcfOK

Sets the global result to 0.

    tcfOK

Returns global result.

### tcfNOK

Sets the global result to 1 or given number.

    tcfNOK [number]

- number

    If present the global result is set to this value.

Returns global result.

### tcfE2R

Converts exit code of previous command to local result if the exit code is not 0
(zero).

    <some command>
    tcfE2R [number]

- number

    If present use it instead of exit code.

Returns original exit code or given number.

## Functions for manipulation with the exit codes

### tcfNEG

Negates exit code of previous command.

    <some command>
    tcfNEG

Returns 1 if original exit code was 0, otherwise returns 0.

### tcfRun

Simmilar to rlRun but it also annouces the beginnign of the command.

    tcfRun [--fail-tag|-f TAG] command [exp_result [title]]

Moreover if 'command not found' appears on STDERR it should produce WARNING.

- command

    Command to execute.

- exp\_result

    Specification of expect resutl.

    It can be a list of values or intervals or \* for any result. Also negation (!) can be used.

        Example:

           <=2,7,10-12,>252,!254 means following values 0,1,2,7,10,11,12,253,255

- title

    Text which will be displayed and logged at the beginning and the end of command execution.

- --fail-tag | -f

    If the command fails use TAG instead of FAIL.

Returns exit code of the executed command.

## Functions for logging

### tcfCheckFinal

Check that all tcfTry / tcfChk functions have been close by tcfFin.

    tcfCheckFinal

## Self check functions

### tcfSelfCheck

Does some basic functionality tests.

    tcfSelfCheck

The function is called also by the following command:

    ./lib.sh selfcheck

# AUTHORS

- Dalibor Pospisil <dapospis@redhat.com>
