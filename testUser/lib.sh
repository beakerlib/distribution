#!/bin/bash
# Authors: 	Dalibor Pospíšil	<dapospis@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2021 Red Hat, Inc. All rights reserved.
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
#   library-prefix = testUser
#   library-version = 10
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<'=cut'
=pod

=head1 NAME

BeakerLib library testUser

=head1 DESCRIPTION

This library provide s function for maintaining testing users.

=head1 USAGE

To use this functionality you need to import library distribution/testUser and add
following line to Makefile.

	@echo "RhtsRequires:    library(distribution/testUser)" >> $(METADATA)

=head1 VARIABLES

=over

=item testUser

Array of testing user login names.

=item testUserDefaultName

A name of the user account which will be used while creating users,
a number will be added at the end.

Needs to be set before the user accounts are created.

Defaut is 'testuser'.

=item testUserPasswd

Array of testing users passwords.

=item testUserDefaultPasswd

A password of the user account which will be used while creating users.

Needs to be set before the user accounts are created.

Defaut is 'foobar'.

=item testUserUID

Array of testing users UIDs.

=item testUserGID

Array of testing users primary GIDs.

=item testUserGroup

Array of testing users primary group names.

=item testUserGIDs

Array of space separated testing users all GIDs.

=item testUserGroups

Array of space separated testing users all group names.

=item testUserGecos

Array of testing users gecos fields.

=item testUserHomeDir

Array of testing users home directories.

=item testUserShell

Array of testing users default shells.

=back

=head1 FUNCTIONS

=cut

echo -n "loading library testUser... "

: <<'=cut'
=pod

=head3 testUserSetup, testUserCleanup

Creates/removes testing user(s).

    rlPhaseStartSetup
        testUserSetup [--fast] [NUM]
    rlPhaseEnd

    rlPhaseStartCleanup
        testUserCleanup
    rlPhaseEnd

=over

=item --fast

Use newusers, mkdir, chmod, and chown for user(s) creation.
And direct home dir removal, edit of /etc/passwd, /etc/shadow, /etc/group,
and /etc/gshadow/ for user(s) removal.

This will be automatically propagated to testUserAdd and testUserDel is called
separately.

=item NUM

Optional number of user to be created. If not specified one user is created.

=back

Returns 0 if success.

=cut


testUserDefaultName="testuser"
testUserDefaultPasswd="foobar"
__INTERNAL_testUser_fast=0


testUserSetup() {
  [[ "$1" == '--fast' ]] && {
    __INTERNAL_testUser_fast=1
  }
  testUserAdd "$@"
}


: <<'=cut'
=pod

=head3 testUserAdd, testUserDel

Creates/removes further testing user(s).

    testUserAdd [--fast] [NUM]
    testUserDel [--fast] [USERNAME]
    testUserDel [--fast]

=over

=item --fast

Use newusers, mkdir, chmod, and chown for user(s) creation.
And direct home dir removal, edit of /etc/passwd, /etc/shadow, /etc/group,
and /etc/gshadow/ for user(s) removal.

=item NUM

Optional number of user to be created. If not specified one user is created.

=item USERNAME

A user to be deleted.

=back

Returns 0 if success.

=cut

__INTERNAL_testUser_index=0

testUserAdd() {
  # parameter dictates how many users should be created, defaults to 1
  local res count_created count_wanted newUser newUserPasswd
  local fast=0
  [[ "$1" == '--fast' || $__INTERNAL_testUser_fast -eq 1 ]] && {
    fast=1
    shift
  }
  res=0
  count_created=0
  count_wanted=${1:-"1"}
  (( $count_wanted < 1 )) && return 1

  while (( $count_created != $count_wanted )) ; do
    let __INTERNAL_testUser_index++
    newUser="$testUserDefaultName${__INTERNAL_testUser_index}"
    newUserPasswd="$testUserDefaultPasswd"
    id "$newUser" &> /dev/null && continue # if user with the name exists, try again

    # create
    LogDebug -f "creating first user $newUser"
    useradd --no-log-init -m $newUser >&2 || ((res++))
    echo "$newUserPasswd" | passwd --stdin $newUser || ((res++))

    # save the users array
    testUser+=($newUser)
    testUserPasswd+=($newUserPasswd)
    ((count_created++))
    [[ $fast -eq 1 ]] && break
  done

  __INTERNAL_testUserRefillInfo || ((res++))

  [[ $count_wanted -eq 1 ]] || [[ $fast -eq 0 ]] && {
    [[ $res -eq 0 ]]
    return $?
  }

  while (( $count_created != $count_wanted )) ; do
    let __INTERNAL_testUser_index++
    newUser="$testUserDefaultName${__INTERNAL_testUser_index}"
    newUserPasswd="$testUserDefaultPasswd"
    id "$newUser" &> /dev/null && continue # if user with the name exists, try again

    # save the users array
    testUser+=($newUser)
    testUserPasswd+=($newUserPasswd)
    ((count_created++))
  done

  LogInfo "creating $((count_wanted-1)) users in a batch"
  local i
  local home="$(dirname "$testUserHomeDir")"
  local usersI=( ${!testUser[@]} )

  # process all users but the first one
  for i in ${usersI[@]:1}; do
    echo "${testUser[$i]}:${testUserPasswd[$i]}::::$home/${testUser[$i]}:$testUserShell"
  done | newusers

  __INTERNAL_testUserRefillInfo || ((res++))

  # process all users but the first one
  for i in ${usersI[@]:1}; do
    mkdir -p "${testUserHomeDir[$i]}"
    chown -R ${testUser[$i]}:${testUserGroup[$i]} "${testUserHomeDir[$i]}"
    chmod 755 "${testUserHomeDir[$i]}"
  done

  [[ $res -eq 0 ]]
}


__INTERNAL_testUserDel() {
  local res
  local fast=$1
  shift
  if [[ $fast -eq 0 ]]; then
    userdel -rf ${testUser[$1]}
    res=$?
  else
    sed -r -i "/^${testUser[$1]}:/d" /etc/passwd || let res++
    sed -r -i "/^${testUser[$1]}:/d" /etc/shadow || let res++
    sed -r -i "/^${testUserGroup[$1]}:/d" /etc/group || let res++
    sed -r -i "/^${testUserGroup[$1]}:/d" /etc/gshadow || let res++
    sed -r -i "s/\<${testUser[$1]},//;s/,${testUser[$1]}\>//" /etc/group || let res++
    rm -rf "${testUserHomeDir[$1]}" || let res++
  fi

  unset \
    testUser[$1] \
    testUserPasswd[$1] \
    testUserUID[$1] \
    testUserGID[$1] \
    testUserGecos[$1] \
    testUserHomeDir[$1] \
    testUserShell[$1] \
    testUserGroup[$1] \
    testUserGIDs[$1] \
    testUserGroups[$1] \

  return $res
}


testUserDel() {
  local res count_deleted count_wanted i j users
  local fast=0
  [[ "$1" == '--fast' || $__INTERNAL_testUser_fast -eq 1 ]] && {
    fast=1
    shift
    rlLogInfo "Using fast removal approach"
  }
  res=0
  [[ -z "$1" ]] && {
    users=("${testUser[@]}")
  } || {
    users=("$@")
  }
  for i in "${!testUser[@]}"; do
    for j in "${!users[@]}"; do
      if [[ "${testUser[$i]}" == "${users[$j]}" ]]; then
        LogDebug -f "deleting user ${testUser[$i]}"
        __INTERNAL_testUserDel $fast $i || let res++
        unset users[$j]
        break
      fi
    done
  done
  [[ $res -eq 0 ]]
}


__INTERNAL_testUserRefillInfo() {
  local res user A B i ent_passwd users_id
  res=0

  for i in ${!testUser[@]}; do
    user=${testUser[$i]}
    if [[ -z "${testUserUID[$i]}" ]]; then
      LogDebug -f "processing user $user"
      ent_passwd=$(getent passwd ${user}) || ((res++))
      IFS=: read -r A B testUserUID[$i] testUserGID[$i] testUserGecos[$i] testUserHomeDir[$i] testUserShell[$i] <<< "$ent_passwd"

      users_id="$(id ${user})" || ((res++))
      testUserGroup[$i]="$(echo "$users_id" | sed -r 's/.*gid=[[:digit:]]+\(([^)]+)\).*/\1/')"
      testUserGIDs[$i]="$(echo "$users_id" | sed -r 's/.*groups=(\S+).*/\1/;s/\([^\)]+\)//g;s/\)//g;s/,/ /g')"
      testUserGroups[$i]="$(echo "$users_id" | sed -r 's/.*groups=(\S+).*/\1/;s/[[:digit:]]+\(//g;s/\)//g;s/,/ /g')"
    fi
  done

  set | grep -E "^(__INTERNAL_testUser_fast|__INTERNAL_testUser_index|testUser|testUserPasswd)="> $__INTERNAL_testUser_users_file

  [[ $res -eq 0 ]]
}


testUserCleanup() {
  local res
  res=0
  testUserDel || ((res++))
  rm -f $__INTERNAL_testUser_users_file >&2 || ((res++))

  [[ $res -eq 0 ]]
}



# testUserLibraryLoaded ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
testUserLibraryLoaded() {
  local res=0
  # necessary init steps
  __INTERNAL_testUser_users_file="$BEAKERLIB_DIR/users"

  # try to fill in users array with previous data
  [[ -f ${__INTERNAL_testUser_users_file} ]] && . ${__INTERNAL_testUser_users_file} >&2
  __INTERNAL_testUserRefillInfo >&2 || ((res++))

  [[ $res -eq 0 ]]
}; # end of testUserLibraryLoaded }}}


: <<'=cut'
=pod

=head1 AUTHORS

=over

=item *

Dalibor Pospisil <dapospis@redhat.com>

=back

=cut

echo "done."

