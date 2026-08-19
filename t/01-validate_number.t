#!/usr/bin/perl

# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;

use Test::More tests => 3;
use Test::NoWarnings;

my $lib = '/var/lib/koha/kohadev/plugins';

unshift( @INC, $lib );
unshift( @INC, '/kohadevbox/koha/' );
unshift( @INC, '/kohadevbox/koha/misc/translator/' );
unshift( @INC, '/kohadevbox/koha/t/lib/' );

use_ok('Koha::Plugin::Com::ByWaterSolutions::LabelMaker');

subtest 'validate_number() tests' => sub {
    plan tests => 10;

    my $validate = \&Koha::Plugin::Com::ByWaterSolutions::LabelMaker::validate_number;

    is( $validate->( 'Starting label', undef, 100 ), undef, 'undef is allowed, the caller defaults it to 1' );
    is( $validate->( 'Starting label', q{},   100 ), undef, 'an empty value is allowed' );
    is( $validate->( 'Starting label', 1,     100 ), undef, 'the lowest value is allowed' );
    is( $validate->( 'Starting label', 50,    100 ), undef, 'a value in range is allowed' );
    is( $validate->( 'Starting label', 100,   100 ), undef, 'the maximum is allowed' );

    is(
        $validate->( 'Starting label', 101, 100 ),
        'Starting label must be a whole number from 1 to 100.',
        'a value over the maximum is rejected'
    );

    is(
        $validate->( 'Starting label', 33159050647283, 100 ),
        'Starting label must be a whole number from 1 to 100.',
        'a scanned barcode is rejected'
    );

    is(
        $validate->( 'Starting label', 0, 100 ),
        'Starting label must be a whole number from 1 to 100.',
        'zero is rejected'
    );

    is(
        $validate->( 'Starting label', -5, 100 ),
        'Starting label must be a whole number from 1 to 100.',
        'a negative value is rejected'
    );

    is(
        $validate->( 'Quantity', 'abc', 100 ),
        'Quantity must be a whole number from 1 to 100.',
        'a value that is not a number is rejected, and the name is used in the message'
    );
};
