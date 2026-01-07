#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   lib.sh of /distribution/Library/collection
#   Description: Collection filelist helpers
#   Author: Lukas Zachar <lzachar@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2013 Red Hat, Inc. All rights reserved.
#
#   This copyrighted material is made available to anyone wishing
#   to use, modify, copy, or redistribute it subject to the terms
#   and conditions of the GNU General Public License version 2.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE. See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public
#   License along with this program; if not, write to the Free
#   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
#   Boston, MA 02110-1301, USA.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   library-prefix = collection
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

true <<'=cut'
=pod

=head1 NAME

distribution/collection - Collection filelist helpers

=head1 DESCRIPTION

This is a trivial example of a BeakerLib library. It's main goal
is to provide a minimal template which can be used as a skeleton
when creating a new library. It implements function fileCreate().
Please note, that all library functions must begin with the same
prefix which is defined at the beginning of the library.

=cut

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   Variables
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

true <<'=cut'
=pod

=head1 VARIABLES

Below is the list of global variables. When writing a new library,
please make sure that all global variables start with the library
prefix to prevent collisions with other libraries.

=over

=item collectionCOMMIT

Commit to be checked-out. Can be branch, tag or commit id.
Defaults to HEAD.

=back

=cut

collectionCOMMIT="${collectionCOMMIT:-HEAD}"

true <<'=cut'
=pod

=over

=item collectionGIT

Address of the Git.
Defaults to https://gitlab.cee.redhat.com/platform-eng-core-services/RH_Software_Collections.git

=back

=cut

collectionGIT="${collectionGIT:-https://gitlab.cee.redhat.com/platform-eng-core-services/RH_Software_Collections.git}"

true <<'=cut'
=pod

=over

=item collectionDISTRO

Filter package list for this distro.
Automatically detected if not specified.

=back

=cut

if [[ -z $collectionDISTRO ]]; then
    if rlIsRHEL; then
        collectionDISTRO="rhel-$(rlGetDistroRelease | sed 's/\.[0-9]\+//')"
    fi
fi

true <<'=cut'
=pod

=over

=item collectionPOSSIBLE_DISTROS

Extended RE for all possible distros used in filtering.
Defaults to "rhel-[0-9]".

=back

=cut

if [[ -z $collectionPOSSIBLE_DISTROS ]]; then
    collectionPOSSIBLE_DISTROS='rhel-[0-9]'
fi


true <<'=cut'
=pod

=over

=item LOOKASIDE

Lookaside location, defaults to http://download.lab.bos.redhat.com/qa/rhts/lookaside/.
It is used to download prepared git tarball from $LOOKASIDE/collection/<name of tarball>

=back

=cut

LOOKASIDE="${LOOKASIDE:-http://download.lab.bos.redhat.com/qa/rhts/lookaside/}"

## private use variables
collection_TEMP_DIR=
collection_GIT_DIR=

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   Functions
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

true <<'=cut'
=pod

=head1 FUNCTIONS

=head2 collectionMain

Create a new file, name it accordingly and make sure (assert) that
the file is successfully created.

    collectionMain collection_name output_filename

=over

=item collection_name

Name of the collection to get the package list of main for.
It is filtered according to the collectionDISTRO.

=item output_filename

Filename of where to write final package list.

=back

Returns 0 when successful, non-zero otherwise.

=cut

collectionMain() {
    local collection_name=$1
    local output_file=$2

    if [ -z $collection_name -o -z $output_file ];then
        rlLogError "collectionMain needs collection_name output_file arguments"
        return 1
    fi

    if [[ -z $collectionDISTRO ]]; then
        rlLogError "collectionMain needs to have collectionDISTRO"
        return 1
    fi

    #filter
    collection_filter_for $collection_name main  $output_file || return 1

    return 0
}

true <<'=cut'
=pod

=head2 collectionAll

Create a new file, name it accordingly and make sure (assert) that
the file is successfully created.

    collectionAll collection_name output_filename

=over

=item collection_name

Name of the collection to get the package list of main for.
It is filtered according to the collectionDISTRO.

=item output_filename

Filename of where to write final package list.

=back

Returns 0 when successful, non-zero otherwise.

=cut

collectionAll() {
    local collection_name=$1
    local output_file=$2

    if [ -z $collection_name -o -z $output_file ];then
        rlLogError "collectionAll needs collection_name output_file arguments"
        return 1
    fi

    if [[ -z $collectionDISTRO ]]; then
        rlLogError "collectionAll needs to have collectionDISTRO"
        return 1
    fi

    #filter
    collection_filter_for $collection_name all $output_file || return 1

    return 0
}

true <<'=cut'
=pod

=head2 collectionCleanup

Clean all files used by this library

    collectionCleanup

=cut

function collectionCleanup(){
    if ! [[ -z $collection_TEMP_DIR ]]; then
        rm -r $collection_TEMP_DIR
    fi
}

## private functions

# used to get working git checkout
collection_init() {
    local ret_code=0
    local cur_dir=`pwd`
    # temp_dir name should exist
    if [[ -z $collection_TEMP_DIR ]]; then
        collection_TEMP_DIR=$(mktemp -d) || return 1
    fi

    # dir should exists
    if ! [[ -d $collection_TEMP_DIR ]]; then
        mkdir $collection_TEMP_DIR
    fi

    rlLogDebug "collection_TEMP_DIR=$collection_TEMP_DIR"

    cd $collection_TEMP_DIR

    # we can have it already checked-out
    if [ -z "$collection_GIT_DIR" -a -d $collection_TEMP_DIR/*/.git ]; then
        export collection_GIT_DIR=$(echo $collection_TEMP_DIR/*/.git | sed 's@/.git$@@')
    fi

    # git should be cloned
    if ! [[ -d $collection_GIT_DIR/.git ]]; then
        tries=2
        while ! rlWatchdog "GIT_SSL_NO_VERIFY=true git clone --quiet $collectionGIT" 300; do
            rlLog "distgit might be down, taking another attempt"
            sleep 5
            ((tries--))
            if [ $tries -le 0 ]; then
                break
            fi
        done

        if ! [ -d */.git ]; then
            ret_code=1
            # let's hope for freezed version on LOOKASIDE
            local lookaside_url="$LOOKASIDE/collection/$(basename $collectionGIT).tgz"
            if wget $lookaside_url; then
                rlLog "Downloaded $lookaside_url instead of fresh git"
                tar xzf $(basename $lookaside_url) && ret_code=0

            fi
        fi
        collection_GIT_DIR=$(echo $collection_TEMP_DIR/*/.git | sed 's@/.git$@@')
        rlLogDebug "collection_GIT_DIR=$collection_GIT_DIR"
    fi

    cd $collection_GIT_DIR

    # git should be checked-out to correct branch
    git reset --hard $collectionCOMMIT || ret_code=2
    rlLog "$(git show --quiet HEAD)"

    cd $cur_dir

    return $ret_code
}

# used to print filtered list
collection_filter_for(){
    local collection_name=$1
    local file_name=$2
    local output=$3

    if [ -z "$collection_name" -o -z "$file_name" -o -z "$output" ]; then
        rlLogError "collection_filter_for needs collection and file name"
        return 1
    fi


    # safe check
    collection_init || return 1

    # collection exists
    if ! [ -d $collection_GIT_DIR/PackageLists/$collection_name ]; then
     rlLog "No collection $collection_name"
         return 1
    fi

    # file to grep exists
    if ! [ -f $collection_GIT_DIR/PackageLists/$collection_name/$file_name ]; then
     rlLog "No file $file_name"
         return 1
    fi

    # the filtering itself
    if [ -n "$collectionPOSSIBLE_DISTROS" -a -n "$collectionDISTRO" ]; then
        grep -E -v "$collectionPOSSIBLE_DISTROS" $collection_GIT_DIR/PackageLists/$collection_name/$file_name > filter_for.tmp
        grep "$collectionDISTRO" $collection_GIT_DIR/PackageLists/$collection_name/$file_name | sed 's/\s.\+//' >> filter_for.tmp
    else
        rlLog "collection_filter_for without distro filtering"
        cp $collection_GIT_DIR/PackageLists/$collection_name/$file_name filter_for.tmp
    fi

    # print the result (delete empty lines, sort & uniq)
    sed '/^$/d' filter_for.tmp | sort -u > $output

    # cleanup
    rm filter_for.tmp
    return 0
}


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   Verification
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   This is a verification callback which will be called by
#   rlImport after sourcing the library to make sure everything is
#   all right. It makes sense to perform a basic sanity test and
#   check that all required packages are installed. The function
#   should return 0 only when the library is ready to serve.

collectionLibraryLoaded() {
    for what in git grep; do
        if ! which git &>/dev/null; then
            rlLogDebug "Library distribution/collection needs $what"
            return 1
        fi
    done
    return 0
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   Authors
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

true <<'=cut'
=pod

=head1 AUTHORS

=over

=item *

Lukas Zachar <lzachar@redhat.com>

=back

=cut
