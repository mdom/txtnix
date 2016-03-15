#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use App::txtnix;

my $app = App::txtnix->new;

my %table = (
    'https://example.org'            => 'http://example.org',
    'http://example.org:80'          => 'http://example.org',
    'https://example.org:443'        => 'http://example.org',
    'http://example.org/'            => 'http://example.org',
    'http://example.org/bar/'        => 'http://example.org/bar',
    'http://example.org/bar'         => 'http://example.org/bar',
    'http://example.org/bar/../quux' => 'http://example.org/quux',
    'http://example.org/b%61r'       => 'http://example.org/bar',
    'http://example.org/b%6F%6f'     => 'http://example.org/boo',
    'http://bob:s3cr3t@example.org/' => 'http://example.org',
);

while ( my ( $from, $to ) = each %table ) {
    is( $app->normalize_url($from), $to );
}

done_testing;
