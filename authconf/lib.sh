#!/bin/bash
# Authors: 	Dalibor Pospíšil	<dapospis@redhat.com>
#   Author: Dalibor Pospisil <dapospis@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2019 Red Hat, Inc. All rights reserved.
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
#   library-prefix = ac
#   library-version = 5
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<'=cut'
=pod

=head1 NAME

BeakerLib library authconf

=head1 DESCRIPTION

This library is meant to provide an easy to use interface to configure
different authentitation backends.

=head1 USAGE

To use this functionality you need to import library distribution/authconf and
add following line to Makefile.

	@echo "RhtsRequires:    library(distribution/authconf)" >> $(METADATA)

=cut


acSetup() {
  local res=0
  rlFileBackup --namespace acLib --clean /etc/nsswitch.conf \
                                         $(readlink -m /etc/nsswitch.conf) \
                                         /etc/pam.d/ \
                                         $(readlink -m /etc/pam.d/*) \
                                         /etc/sssd \
                                         $(readlink -m /etc/sssd/*) \
                                         /etc/ldap.conf \
                                         $(readlink -m /etc/ldap.conf) \
                                         /etc/nslcd.conf \
                                         $(readlink -m /etc/nslcd.conf) \
                                         || let res++
  return $res
}

acCleanup() {
  local res=0
  rlFileRestore --namespace acLib || let res++
  return $res
}

acSwitchUserAuth() {
  optsBegin
  optsAdd 'ldapHost' -m
  optsAdd 'ldapURI' -m
  optsAdd 'ldapBaseDN' -m
  optsDone; eval "${optsCode}"

  local res=0
  local backend
  case $1 in
    sss*)
      LogInfo "switching to sss"
      tcfChk "check for the requirements" && {
        rlCheckRequirements sssd-ldap || {
          rlRun "yum install -y sssd-ldap"
        }
      tcfFin; }
      tcfChk "enable sss in nsswitch.conf" && {
        grep -E '^(passwd|shadow|group):' /etc/nsswitch.conf
        rlRun "sed -r -i 's/(passwd:.*)ldap/\1/g;s/(passwd:.*)sss/\1/g;s/passwd:/\0 sss /' /etc/nsswitch.conf"
        rlRun "sed -r -i 's/(shadow:.*)ldap/\1/g;s/(shadow:.*)sss/\1/g;s/shadow:/\0 sss /' /etc/nsswitch.conf"
        rlRun "sed -r -i 's/(group:.*)ldap/\1/g;s/(group:.*)sss/\1/g;s/group:/\0 sss /' /etc/nsswitch.conf"
        grep -E '^(passwd|shadow|group):' /etc/nsswitch.conf
      tcfFin; }
      tcfChk "setup PAM" && {
        rlRun "pamDeleteServiceModuleRule system-auth auth pam_ldap.so"
        rlRun "pamDeleteServiceModuleRule system-auth account pam_ldap.so"
        rlRun "pamDeleteServiceModuleRule system-auth password pam_ldap.so"
        rlRun "pamDeleteServiceModuleRule system-auth session pam_ldap.so"
        rlRun "pamDeleteServiceModuleRule system-auth auth pam_sss.so"
        rlRun "pamDeleteServiceModuleRule system-auth account pam_sss.so"
        rlRun "pamDeleteServiceModuleRule system-auth password pam_sss.so"
        rlRun "pamDeleteServiceModuleRule system-auth session pam_sss.so"
        rlRun "pamInsertServiceRuleBefore system-auth auth pam_deny.so '' sufficient pam_sss.so"
        rlRun "pamInsertServiceRuleBefore system-auth account pam_permit.so '' '[default=bad success=ok user_unknown=ignore]' pam_sss.so"
        rlRun "pamInsertServiceRuleBefore system-auth password pam_deny.so '' sufficient pam_sss.so 'use_authtok'"
        rlRun "pamInsertServiceRule system-auth session optional pam_sss.so '' -1"
      tcfFin; }
      tcfChk "show  PAM" && {
        rlRun "pamGetServiceRules --prefix system-auth auth"
        rlRun "pamGetServiceRules --prefix system-auth account"
        rlRun "pamGetServiceRules --prefix system-auth session"
        rlRun "pamGetServiceRules --prefix system-auth password"
      tcfFin; }
      tcfChk "setup sssd config" && {
        cat >/etc/sssd/sssd.conf<<EOF
[sssd]
config_file_version = 2
domains             = LDAP
services            = nss, pam
#debug_level         = 0xFFFF

[nss]
filter_groups       = root
filter_users        = root
#debug_level         = 0xFFFF

[pam]
#debug_level         = 0xFFFF

[domain/LDAP]
cache_credentials   = False
id_provider         = ldap
auth_provider       = ldap
#debug_level         = 0xFFFF
ldap_uri            = $ldapURI
ldap_id_use_start_tls = false

entry_cache_nowait_percentage       = 0
entry_cache_timeout                 = 1
EOF
        [[ -n "$SSSD_DEBUG" ]] && sed -i -r 's/^#(debug_level.*)/\1/' /etc/sssd/sssd.conf
        chmod 0600 /etc/sssd/sssd.conf
        cat /etc/sssd/sssd.conf
      tcfFin; }
      rlRun "rlServiceStart sssd"
      ;;
    ldap)
      LogInfo "switching to ldap"
      tcfChk "check for the requirements" && {
        rlCheckRequirements nss-pam-ldapd || {
          rlRun "yum install -y nss-pam-ldapd"
        }
      tcfFin; }
      tcfChk "enable ldap in nsswitch.conf" && {
        grep -E '^(passwd|shadow|group):' /etc/nsswitch.conf
        rlRun "sed -r -i 's/(passwd:.*)ldap/\1/g;s/(passwd:.*)sss/\1/g;s/passwd:/\0 ldap /' /etc/nsswitch.conf"
        rlRun "sed -r -i 's/(shadow:.*)ldap/\1/g;s/(shadow:.*)sss/\1/g;s/shadow:/\0 ldap /' /etc/nsswitch.conf"
        rlRun "sed -r -i 's/(group:.*)ldap/\1/g;s/(group:.*)sss/\1/g;s/group:/\0 ldap /' /etc/nsswitch.conf"
        grep -E '^(passwd|shadow|group):' /etc/nsswitch.conf
      tcfFin; }
      tcfChk "setup PAM" && {
        rlRun "pamDeleteServiceModuleRule system-auth auth pam_ldap.so"
        rlRun "pamDeleteServiceModuleRule system-auth account pam_ldap.so"
        rlRun "pamDeleteServiceModuleRule system-auth password pam_ldap.so"
        rlRun "pamDeleteServiceModuleRule system-auth session pam_ldap.so"
        rlRun "pamDeleteServiceModuleRule system-auth auth pam_sss.so"
        rlRun "pamDeleteServiceModuleRule system-auth account pam_sss.so"
        rlRun "pamDeleteServiceModuleRule system-auth password pam_sss.so"
        rlRun "pamDeleteServiceModuleRule system-auth session pam_sss.so"
        rlRun "pamInsertServiceRuleBefore system-auth auth pam_deny.so '' sufficient pam_ldap.so"
        rlRun "pamInsertServiceRuleBefore system-auth account pam_permit.so '' '[default=bad success=ok user_unknown=ignore]' pam_ldap.so"
        rlRun "pamInsertServiceRuleBefore system-auth password pam_deny.so '' sufficient pam_ldap.so 'use_authtok'"
        rlRun "pamInsertServiceRule system-auth session optional pam_ldap.so '' -1"
      tcfFin; }
      tcfChk "show  PAM" && {
        rlRun "pamGetServiceRules --prefix system-auth auth"
        rlRun "pamGetServiceRules --prefix system-auth account"
        rlRun "pamGetServiceRules --prefix system-auth session"
        rlRun "pamGetServiceRules --prefix system-auth password"
      tcfFin; }
      if rlIsRHEL '<6'; then
        # RHEL<6
        tcfChk "setup ldap client config" && {
          cat <<EOF >/etc/ldap.conf
host $ldapHost
BASE $ldapBaseDN
URI $ldapURI
ldap_version 3
bind_timelimit 5
bind_policy soft
ssl no
EOF
          cat /etc/ldap.conf
        tcfFin; }
      else
        # RHEL>=6
        tcfChk "setup nslcd config" && {
          cat <<EOF >/etc/nslcd.conf
uid nslcd
gid ldap
uri $ldapURI
timelimit 120
bind_timelimit 120
idle_timelimit 3600
ssl no
EOF
          cat /etc/nslcd.conf
        tcfFin; }
      fi
      rlRun "rlServiceStart nslcd"
      ;;
    files)
      LogInfo "switching to files"
      tcfChk "enable ldap in nsswitch.conf" && {
        grep -E '^(passwd|shadow|group):' /etc/nsswitch.conf
        rlRun "sed -r -i 's/(passwd:.*)ldap/\1/g;s/(passwd:.*)sss/\1/g;s/(passwd:.*)files/\1/g;s/passwd:/\0 files /' /etc/nsswitch.conf"
        rlRun "sed -r -i 's/(shadow:.*)ldap/\1/g;s/(shadow:.*)sss/\1/g;s/(shadow:.*)files/\1/g;s/shadow:/\0 files /' /etc/nsswitch.conf"
        rlRun "sed -r -i 's/(group:.*)ldap/\1/g;s/(group:.*)sss/\1/g;s/(group:.*)files/\1/g;s/group:/\0 files /' /etc/nsswitch.conf"
        grep -E '^(passwd|shadow|group):' /etc/nsswitch.conf
      tcfFin; }
      tcfChk "setup PAM" && {
        rlRun "pamDeleteServiceModuleRule system-auth auth pam_sss.so"
        rlRun "pamDeleteServiceModuleRule system-auth account pam_sss.so"
        rlRun "pamDeleteServiceModuleRule system-auth password pam_sss.so"
        rlRun "pamDeleteServiceModuleRule system-auth session pam_sss.so"
        rlRun "pamDeleteServiceModuleRule system-auth auth pam_ldap.so"
        rlRun "pamDeleteServiceModuleRule system-auth account pam_ldap.so"
        rlRun "pamDeleteServiceModuleRule system-auth password pam_ldap.so"
        rlRun "pamDeleteServiceModuleRule system-auth session pam_ldap.so"
      tcfFin; }
      tcfChk "show  PAM" && {
        rlRun "pamGetServiceRules --prefix system-auth auth"
        rlRun "pamGetServiceRules --prefix system-auth account"
        rlRun "pamGetServiceRules --prefix system-auth session"
        rlRun "pamGetServiceRules --prefix system-auth password"
      tcfFin; }
      ;;
    *)
      ;;
  esac

  return $res
}

acLibraryLoaded() {
    return 0
}

: <<'=cut'
=pod

=head1 AUTHORS

=over

=item *

Dalibor Pospisil <dapospis@redhat.com>

=back

=cut
