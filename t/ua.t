use strict;
use warnings;
use Test::More;
use App::twtxtpl;
use FindBin qw($Bin);

my $twtxt = App::twtxtpl->new( config_file => "$Bin/config" );

is( $twtxt->ua->transactor->name, "twtxtpl/$App::twtxtpl::VERSION" );

$twtxt =
  App::twtxtpl->new( config_file => "$Bin/config", disclose_identity => 1 );

is( $twtxt->ua->transactor->name,
"twtxtpl/$App::twtxtpl::VERSION (+http://www.domgoergen.com/twtxt.txt; \@mdom)"
);

done_testing;
