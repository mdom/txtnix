use strict;
use warnings;
use Test::More;
use App::txtnix;
use Path::Tiny;
use Mojo::Loader qw(data_section);

my $empty_config = Path::Tiny->tempfile;

my ( $app, @tweets );

$app = App::txtnix->new( config => "$empty_config" );

@tweets = $app->parse_twtfile( 'mdom', data_section( 'main', 'empty' ) );

is( @tweets, 0, 'parse empty twtfile' );

@tweets = $app->parse_twtfile( 'mdom', data_section( 'main', 'basic' ) );

is( @tweets, 1, 'parse one line twtfile' );

done_testing;

__DATA__

@@ empty

@@ basic
2016-02-22T12:56:48+0100	foo
