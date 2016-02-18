use strict;
use warnings;
use Test::More;
use App::txtwat;
use FindBin qw($Bin);

my $twtxt = App::txtwat->new( config_file => "$Bin/config" );

is( $twtxt->ua->transactor->name, "txtwat/$App::txtwat::VERSION" );

$twtxt =
  App::txtwat->new( config_file => "$Bin/config", disclose_identity => 1 );

is( $twtxt->ua->transactor->name,
"txtwat/$App::txtwat::VERSION (+http://www.domgoergen.com/twtxt.txt; \@mdom)"
);

done_testing;
