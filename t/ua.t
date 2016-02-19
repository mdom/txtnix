use strict;
use warnings;
use Test::More;
use App::txtnix;
use FindBin qw($Bin);

my $twtxt = App::txtnix->new( config_file => "$Bin/config" );

is( $twtxt->ua->transactor->name, "txtnix/$App::txtnix::VERSION" );

$twtxt =
  App::txtnix->new( config_file => "$Bin/config", disclose_identity => 1 );

is( $twtxt->ua->transactor->name,
"txtnix/$App::txtnix::VERSION (+http://www.domgoergen.com/twtxt.txt; \@mdom)"
);

done_testing;
