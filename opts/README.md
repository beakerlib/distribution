# NAME

BeakerLib library opts

# DESCRIPTION

This library provides simple way for defining script's or function's option
agruments including help.

# USAGE

To use this functionality you need to import library distribution/opts and add
following line to Makefile.

        @echo "RhtsRequires:    library(distribution/opts)" >> $(METADATA)

**Code example**

        testfunction() {
          optsBegin -h "Usage: $0 [options]
        
          options:
        "
          optsAdd 'flag1' --flag
          optsAdd 'optional1|o' --optional
          optsAdd 'Optional2|O' "echo opt \$1" --optional --long --var-name opt
          optsAdd 'mandatory1|m' "echo man \$1" --mandatory
          optsDone; eval "${optsCode}"
          echo "$optional1"
          echo "$opt"
          echo "$mandatory1"
        }

# FUNCTIONS

# AUTHORS

- Dalibor Pospisil <dapospis@redhat.com>
