#!/bin/bash
#
#   Author: Ondrej Moris <omoris@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2023 Red Hat, Inc. All rights reserved.
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
#   library-prefix = fipsWrapper
#   library-version = 1
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
__INTERNAL_fips_wrapper_LIB_VERSION=1
__INTERNAL_fips_wrapper_LIB_NAME='distribution/fips'
: <<'=cut'
=pod

=head1 NAME

BeakerLib library distribution/fips

=head1 DESCRIPTION

This is a compatibility layer to overcome a transitional phase from
distribution/fips to crypto/fips.

=cut
echo -n "loading library $__INTERNAL_fips_wrapper_LIB_NAME v$__INTERNAL_fips_wrapper_LIB_VERSION... "

fipsWrapperLibraryLoaded() {
  rlRun "rlImport crypto/fips" || rlDie 'could not import library(crypto/fips)'
}

: <<'=cut'
=pod

=head1 AUTHORS

=over

=item *

Ondrej Moris <omoris@redhat.com>

=back

=cut
