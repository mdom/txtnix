#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use App::txtnix::Tweet;
use Mojo::Date;

my $tweet = App::txtnix::Tweet->from_string(
    '2016-03-04T12:00:00Z#follow bob http://example.com/bob.txt');

ok( $tweet->is_metadata );
is_deeply( $tweet->command, [qw(follow bob http://example.com/bob.txt)] );

$tweet = App::txtnix::Tweet->from_string(
    '2016-03-04T12:00:00Z follow bob http://example.com/bob.txt');

ok( !$tweet->is_metadata );
is( $tweet->text, 'follow bob http://example.com/bob.txt' );

$tweet->timestamp( Mojo::Date->new(0) );
like( $tweet->strftime('relative'), qr/^\d+\w\d+\w ago$/ );

done_testing;
