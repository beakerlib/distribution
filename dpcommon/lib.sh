#!/bin/bash
# Authors: 	Dalibor Pospíšil	<dapospis@redhat.com>
#   Author: Dalibor Pospisil <dapospis@redhat.com>
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
#   library-prefix = dpcommon
#   library-version = 19
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
: <<'=cut'
=pod

=head1 NAME

BeakerLib library dpcommon

=head1 DESCRIPTION

This is a meta-library containing just dependencies.

=head1 USAGE

To use this functionality you need to import library distribution/dpcommon and add
following line to Makefile.

	@echo "RhtsRequires:    library(distribution/dpcommon)" >> $(METADATA)

=cut


rlFetchRpmForInstalled(){
  local PKGNAME=$1 RPM
  if ! RPM=$(rpm -q ${PKGNAME})
  then
    rlLogError "The package is not installed, can't download the RPM"
    return 1
  fi
  rlLog "Fetching rpm for installed $PKGNAME"

  rlLogInfo "Installed $PKGNAME version: $RPM"
  rlRpmDownload `rpm -q --qf '%{name} %{version} %{release} %{arch}' $PKGNAME`
}


rlDownload() {
  local QUIET
  [[ "$1" == "--quiet" ]] && { QUIET=1; shift; }
  local FILE="$1"
  local URL="$2"
  local res=0
  if which wget &> /dev/null; then
    rlLogDebug "$FUNCNAME(): using wget for download"
    QUIET="${QUIET:+--quiet}"
    wget $QUIET -t 3 -T 180 -w 20 --waitretry=30 --no-check-certificate --progress=dot:giga -O $FILE $URL || let res++
  elif which curl &> /dev/null; then
    rlLogDebug "$FUNCNAME(): using curl for download"
    QUIET="${QUIET:+--silent}"
    [[ -t 2 ]] || QUIET="${QUIET:---silent --show-error}"
    curl $QUIET --location --retry-connrefused --retry-delay 3 --retry-max-time 3600 --retry 3 --connect-timeout 180 --max-time 1800 --insecure -o $FILE "$URL" || let res++
  else
    rlLogError "$FUNCNAME(): no tool for downloading web content is available"
    let res++
  fi
  return $res
}

KernelWhichBootloader() {
  local CONF_NAME BASE
  BLOADER_CONF_FILE=''
  BLOADER=''
  tcfChk "Determine bootloader" && {
    case `rlGetArch` in
      i386|x86_64)
        if rlIsRHEL '<7'; then
          CONF_NAME="grub.conf"
          BLOADER="GRUB"
        else
          CONF_NAME="grub.cfg"
          BLOADER="GRUB2"
        fi
      ;;
      ia64)
        CONF_NAME="elilo.conf)"
        BLOADER="ELILO"
      ;;
      ppc|ppc64)
        if rlIsRHEL '<7'; then
          CONF_NAME="yaboot.conf"
          BLOADER="YABOOT"
        else
          CONF_NAME="grub.cfg"
          BLOADER="GRUB2"
        fi
      ;;
      s390|s390x)
        CONF_NAME="zipl.conf"
        BLOADER="ZIPL"
      ;;
      *) rlLogFatal "No suitable arch found!" ; rlNOK
      ;;
    esac
    LogDebug -f "current architecture in `rlGetArch`"
    LogDebug -f "CONF_NAME='$CONF_NAME'"
    LogDebug -f "BLOADER='$BLOADER'"
    tcfTry &&{
      for BASE in /etc /boot; do
        [ ! -f "$BLOADER_CONF_FILE" ] && BLOADER_CONF_FILE=$(find $BASE -name $CONF_NAME)
      done
      BLOADER_CONF_FILE=$(readlink -f $BLOADER_CONF_FILE)
      [ -f "$BLOADER_CONF_FILE" ]; tcfE2R
      if tcfRES; then
        LogDebug -f "Bootloader configuration file: $BLOADER_CONF_FILE"
      else
        rlLogFatal "No bootloader found!"
      fi
      LogDebug -f "tcfRES='`tcfRES -p`'"
      tcfRES
    tcfFin;}
  tcfFin --no-assert;}
}


KernelAppendBootOpt() {
  [ -z "$BLOADER" ] && KernelWhichBootloader
  [ -z "$BLOADER_CONF_FILE" ] && KernelWhichBootloader
  tcfChk "Append boot parameters" && {
    case "$BLOADER" in
      GRUB)
        ReplaceInFile -e -a '^[[:space:]]\+kernel' "$" " $1"  $BLOADER_CONF_FILE
      ;;
      GRUB2)
        ReplaceInFile -e -a '^[[:space:]]\+linux' "$" " $1"  $BLOADER_CONF_FILE
      ;;
      ELILO|YABOOT)
        ReplaceInFile -e -a '^[[:space:]]\+append' '"$' " ${1}\"" $BLOADER_CONF_FILE
      ;;
      ZIPL)
        ReplaceInFile -e -a '^[[:space:]]\+parameters' '"$' " ${1}\"" $BLOADER_CONF_FILE
        /sbin/zipl; tcfE2R; LogDebug -f "/sbin/zipl returned -> $?"
      ;;
    esac
  tcfFin --no-assert;}
}


ReplaceInFile() {
  local addr="" multi=0 sed_opts="" addr2=''
  while [ -n "$1" ]; do
    case $1 in
    --)
      shift
      break
      ;;
    -a|--addr|--address)
      addr="/$2/ "
      addr2="$2"
      shift
      ;;
    -m|--multi|--multi-line)
      multi=1
      ;;
    -*)
      sed_opts="$sed_opts $1"
      ;;
    *)
      break
      ;;
    esac
    shift
  done
  if [ $multi -eq 0 ]; then
    local opts=$(cat $3 | grep -e "$1")
    [ -n "$addr" ] && opts=$(echo "$opts" | grep -e "$addr2")
    LogDebug -f "previous kernel params $opts"
    sed -i ${sed_opts} "${addr}s/$1/$2/g" $3
    local opts=$(cat $3 | grep -e "$1")
    [ -n "$addr" ] && opts=$(echo "$opts" | grep -e "$addr2")
    LogDebug -f "new kernel params $opts"
  else
    true
  fi
}

value_difference_percentage() {
  local a="scale=10; h=($1); l=($2); if ( h < l ) { a=h; h=l; l=a; }; d=h-l; if (h<0) h=-h; if (l<0) l=-l; if ( h < l ) { a=h; h=l; l=a; }; if ( l != 0 ) d/l*100 else 1000000000000000000000000000"
  rlLogDebug "value diff: $a"
  echo $a | bc | sed -e 's/^\./0\0/'
}

compare_with_tolerance() {
  rlLog "check that $1 and $2 does not differ more than $3%"
  local v=$(value_difference_percentage $1 $2 |cut -d . -f 1)
  rlLog "values differ by $v%"
  [ $v -le $3 ]
}

LOOKASIDE="${LOOKASIDE:-http://porkchop.redhat.com/qa/rhts/lookaside}"
rlDownloadFromLookaside() {
  local file="$1"
  rlLog "downloading file '$file' from '$LOOKASIDE'"
  __INTERNAL_WGET "$file" "$LOOKASIDE/$file"
}

debugPrompt() {
  local DEBUG=1
  echo >&2
  rlLogDebug "now, you are in the debug shell, exit to continue the test"
  PS1='$? [test \u@\h \W]# ' bash
}

progressHeader() {
  __INTERNAL_progress_refresh=''
  [[ "$1" == "-r" ]] && { __INTERNAL_progress_refresh='1'; shift; }
  __INTERNAL_progress_pattern=""
  __INTERNAL_progress_pattern_fill=""
  __INTERNAL_progress_max=$1
  __INTERNAL_progress_min=${2:-0}
  __INTERNAL_progress_size=$(($__INTERNAL_progress_max-$__INTERNAL_progress_min))
  [[ $__INTERNAL_progress_size -eq 0 ]] && __INTERNAL_progress_size=1
  __INTERNAL_progress_width=${3:-70}
  __INTERNAL_progress_prev=-1
  [[ -n "$DEBUG" ]] && declare -p __INTERNAL_progress_max __INTERNAL_progress_min __INTERNAL_progress_size __INTERNAL_progress_width __INTERNAL_progress_prev
  #echo -n '|' >&2
  local prev i header_pattern cur next
  header_pattern=""
  for ((i=1;i<__INTERNAL_progress_width;i++)); do
    cur=$((10*i/__INTERNAL_progress_width))
    next=$((10*(i+1)/__INTERNAL_progress_width))
    next2=$((10*(i+2)/__INTERNAL_progress_width/10))
    if [[ $next -ne $cur ]]; then
      header_pattern+="_|"
      #__INTERNAL_progress_pattern+="$((cur+1))0"
      #__INTERNAL_progress_pattern_fill+="$((cur+1))0"
      let i++
    else
      header_pattern+="_"
      __INTERNAL_progress_pattern+="#"
      __INTERNAL_progress_pattern_fill+=" "
    fi
    prev=$cur
  done
  [[ -n "$__INTERNAL_progress_refresh" ]] && {
    __INTERNAL_progress_pattern_fill=${header_pattern//_/#}
    __INTERNAL_progress_pattern=${header_pattern//_/ }
    progressDraw $__INTERNAL_progress_min
    return
  }
  echo -e "$header_pattern" >&2
}

progressDraw() {
  local cur p i
  p=$1
  [[ $p -lt $__INTERNAL_progress_min ]] && p=$__INTERNAL_progress_min
  [[ $p -gt $__INTERNAL_progress_max ]] && p=$__INTERNAL_progress_max
  cur=$(( $__INTERNAL_progress_width * ($p-$__INTERNAL_progress_min) / $__INTERNAL_progress_size))
  if [[ $cur -gt $__INTERNAL_progress_prev ]]; then
    if [[ -n "$__INTERNAL_progress_refresh" ]]; then
      let i=$cur-2
      [[ $i -lt 0 ]] && i=0
      [[ $p -eq $__INTERNAL_progress_max ]] && p="${__INTERNAL_progress_pattern_fill}" || \
      p="${__INTERNAL_progress_pattern_fill:0:$i}##"
      echo -en "\r" >&2
      echo -n "${p:0:$cur}${__INTERNAL_progress_pattern:$cur}" >&2
    else
      for ((i=__INTERNAL_progress_prev; i<cur; i++)); do
        echo -n '^' >&2
      done
    fi
    __INTERNAL_progress_prev=$cur
  fi
}

progressFooter() {
  progressDraw $__INTERNAL_progress_max
  echo >&2
}


sleepWithProgress() {
  local sec=$1 i p wholesec
  p=$( sleep $sec >/dev/null & echo $! )
  wholesec=${sec/.*}
  rlLog "waiting for $sec seconds"
  local endtime currentime
  currentime=$(date +%s.%N | sed -r 's/([0-9]+)\.(..).*/\1\2/')
  endtime=$(($currentime+$wholesec*100))
  progressHeader $endtime $currentime
  while currentime=$(date +%s.%N | sed -r 's/([0-9]+)\.(..).*/\1\2/'); [[ $currentime -lt $endtime ]]; do
    kill -s 0 "$p" &>/dev/null || break
    sleep 0.25
    progressDraw $currentime
  done
  tail --pid=$p -f -s 0.1 /dev/null
  progressFooter
}

# dpcommonLibraryLoaded ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ {{{
dpcommonLibraryLoaded() {
  return 0
}; # end of dpcommonLibraryLoaded }}}


: <<'=cut'
=pod

=head1 AUTHORS

=over

=item *

Dalibor Pospisil <dapospis@redhat.com>

=back

=cut

