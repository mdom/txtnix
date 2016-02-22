use strict;
use warnings;
use Test::More;
use App::txtnix;
use FindBin qw($Bin);
use Path::Tiny;

my $empty_config = Path::Tiny->tempfile;

my ( $app, @tweets );

$app = App::txtnix->new( config_file => "$empty_config" );

@tweets =
  $app->parse_twtfile( 'mdom', path("$Bin/twtfiles/empty")->slurp_utf8 );

is( @tweets, 0, 'parse empty twtfile' );

@tweets =
  $app->parse_twtfile( 'mdom', path("$Bin/twtfiles/basic")->slurp_utf8 );

is( @tweets, 1, 'parse one line twtfile' );

done_testing;
