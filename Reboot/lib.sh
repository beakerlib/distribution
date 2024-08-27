#!/bin/bash
# Authors: 	Dalibor Pospíšil	<dapospis@redhat.com>
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2012 Red Hat, Inc. All rights reserved.
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
#   library-prefix = Reboot
#   library-version = 11
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
__INTERNAL_Reboot_LIB_NAME='distribution/Reboot'
__INTERNAL_Reboot_LIB_VERSION=11

: <<'=cut'
=pod

=head1 NAME

library(distribution/Reboot) - functions supporting reboot

=head1 DESCRIPTION

This library presents helper functions for developing and execute tests which
require rebooting. It also works with localy (manualy) executed tests as well as
in beaker environment.

=cut


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   Initialize
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


echo -n "loading library $__INTERNAL_Reboot_LIB_NAME v$__INTERNAL_Reboot_LIB_VERSION... "

__INTERNAL_Reboot_BEAKERLIB_DIR_FILE="$__INTERNAL_PERSISTENT_TMP/beaker-BEAKERLIB_DIR"
__INTERNAL_Reboot_COUNT_FILE=''

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   Functions
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

__INTERNAL_Reboot_COUNT_SETUP() {
  if [ -z "$__INTERNAL_Reboot_COUNT_FILE" ]; then
    __INTERNAL_Reboot_COUNT_FILE="$BEAKERLIB_DIR/REBOOT_COUNT"
    [ ! -s "$__INTERNAL_Reboot_COUNT_FILE" ] && {
      RebootSetCount 0
    }
  fi
}


: <<'=cut'
=pod

=head1 FUNCTIONS

=cut


: <<'=cut'
=pod

=head2 Rebooted

Checks if or how manytimes the system was rebooted.

    Rebooted [number ...]

=over

=item number

If present check against the given reboot count. It can be a list of numbers
with operators '!<=>'.

=back

Return 0 if at least one argument matched the reboot count; 1 otherwise.

Example:

    rlJournalStart && {
      rlRun "rlImport distribution/Reboot" || rlDie 'could not load library Reboot'
      if ! Rebooted; then
        rlPhaseStartSetup && {
          ...
        rlPhaseEnd; }
        RebootNow
      elif Rebooted 1; then
        rlPhaseStartTest && {
          ...
        rlPhaseEnd; }
        RebootNow
      elif Rebooted 2; then
        RebootCountReset
        rlPhaseStartCleanup && {
          ...
        rlPhaseEnd; }
      fi
      rlJournalPrintText
    rlJournalEnd; }

=cut

Rebooted() {
  local rc=$(RebootGetCount)
  local sign val
  if [ -z "$1" ]; then
    return $([ $rc -ne 0 ])
  else
    for val in $(echo "$*" | tr ',' ' '); do
      sign=$(echo $val |grep -Eo '^(!)?[<=>]+')
      [ -z "$sign" ] && {
        sign='='
      } || {
        val=$(echo $val |sed -e 's/^\(!\)?[<=>]\+//')
      }
      expr "$rc" "$sign" "$val" >& /dev/null && return 0
    done
  fi
  return 1
}; # end of Rebooted


: <<'=cut'
=pod

=head2 RebootNow

Increase reboot counter and reboot the system.

    RebootNow

See example in Rebooted.

=cut

RebootNow(){
  local rc=$(RebootGetCount)
  RebootSetCount $((++rc))
  rlLogDebug "Saving BEAKERLIB_DIR='$BEAKERLIB_DIR' to $__INTERNAL_Reboot_BEAKERLIB_DIR_FILE"
  echo $BEAKERLIB_DIR >$__INTERNAL_Reboot_BEAKERLIB_DIR_FILE
  # compatibility with Cleanup library: prevent cleanup before reboot
  declare -F CleanupTrapUnhook > /dev/null && CleanupTrapUnhook
  rlLogInfo "rebooting now"
  rhts-reboot
  sleep 3600
}; # end of RebootNow


: <<'=cut'
=pod

=head2 RebootCountReset

Reset reboot counter. Call this function in the last phase of the test.

    RebootCountReset

See example in Rebooted.

=cut

RebootCountReset(){
  __INTERNAL_Reboot_COUNT_SETUP
  [ -n "$__INTERNAL_Reboot_COUNT_FILE" ] && {
    rm -f $__INTERNAL_Reboot_COUNT_FILE
    unset __INTERNAL_Reboot_COUNT_FILE
  }
}; # end of RebootCountReset


: <<'=cut'
=pod

=head2 RebootGetCount

Prints current number of reboots.

    count=$(RebootGetCount)

=cut

RebootGetCount() {
  __INTERNAL_Reboot_COUNT_SETUP
  cat $__INTERNAL_Reboot_COUNT_FILE
}; # end of GetRebootCount


: <<'=cut'
=pod

=head2 RebootSetCount

Sets current number of reboots.

    RebootSetCount <number>

=cut

RebootSetCount() {
  __INTERNAL_Reboot_COUNT_FILE="$BEAKERLIB_DIR/REBOOT_COUNT"
  echo -n $1 >$__INTERNAL_Reboot_COUNT_FILE
}; # end of RebootSetCount


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   Verification
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

RebootLibraryLoaded() {
    cat > $BEAKERLIB/plugins/RebootLibrary.sh <<EOF
[ -z "\$BEAKERLIB_DIR" ] && [ -r "$__INTERNAL_Reboot_BEAKERLIB_DIR_FILE" ] && [ -s "$__INTERNAL_Reboot_BEAKERLIB_DIR_FILE" ] && {
  export BEAKERLIB_DIR=\$(cat "$__INTERNAL_Reboot_BEAKERLIB_DIR_FILE")
  echo -e "\nlibrary(distribution/Reboot): changing BEAKERLIB_DIR to '\$BEAKERLIB_DIR'"
}
rm -f "$__INTERNAL_Reboot_BEAKERLIB_DIR_FILE" "$BEAKERLIB/plugins/RebootLibrary.sh"
EOF
    rlLog "reboot count: $(RebootGetCount)"
    if rpm=$(rpm -q coreutils); then
        rlLogDebug "Library $__INTERNAL_Reboot_LIB_NAME running with $rpm"
        return 0
    else
        rlLogError "Package coreutils not installed"
        return 1
    fi
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   Authors
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

echo "done."


: <<'=cut'
=pod

=head1 AUTHORS

=over

=item *

Dalibor Pospisil <dapospis@redhat.com>

=back

=cut
