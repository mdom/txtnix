#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use App::txtnix::Tweet;
use Mojo::Date;

my $t =
  App::txtnix::Tweet->new( text => '// follow bob http://example.com/bob.txt' );

ok( $t->is_metadata );
is_deeply( $t->command, [qw(follow bob http://example.com/bob.txt)] );

$t = App::txtnix::Tweet->new( text => 'follow bob http://example.com/bob.txt' );

ok( !$t->is_metadata );
is_deeply( $t->command, [] );

$t->timestamp( Mojo::Date->new(0) );
like( $t->strftime('relative'), qr/^\d+\w\d+\w ago$/ );

done_testing;
