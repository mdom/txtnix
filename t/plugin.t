#!/usr/bin/perl
use strict;
use warnings;
use App::txtnix;
use Mojo::Loader qw(data_section);
use Path::Tiny;
use Test::More;

my $config = Path::Tiny->tempfile;
$config->spew_utf8( data_section( 'main', 'config.txt' ) );

my $app = App::txtnix->new( config => $config );

ok($app);

is( $app->plugins->[-1]->name, 'LinkBack' );

$config = Path::Tiny->tempfile;
$config->spew_utf8( data_section( 'main', 'config2.txt' ) );

$app = App::txtnix->new( config => $config );

ok($app);

is( $app->plugins->[-1]->name, 'ShellExec' );

done_testing;

__DATA__

@@ config.txt

[ LinkBack ]
priority = 15

[ ShellExec ]
priority = 5

@@ config2.txt

[ LinkBack ]
priority = 5

[ ShellExec ]
priority = 15
