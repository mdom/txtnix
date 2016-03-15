#!/usr/bin/perl
use strict;
use warnings;
use Path::Tiny;
use App::txtnix::Cmd::tweet;
use Test::More;
use Test::Output;
use Mojo::Util 'monkey_patch';
use FindBin '$Bin';

$ENV{TZ} = 'UTC';

monkey_patch 'App::txtnix::Cmd::tweet', is_interactive => sub { return 1 };

my $app = App::txtnix::Cmd::tweet->new(
    config  => Path::Tiny->tempfile,
    twtfile => Path::Tiny->tempfile,
    hooks   => 0,
);

$app->twtfile->touch;

$ENV{EDITOR} = "$Bin/bin/mock_editor";

$app->run;

like(
    $app->twtfile->slurp_utf8, qr/
	\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ      \t Foo\n
        \d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d+Z \t Bar\n
     /smx
);

monkey_patch 'App::txtnix::Cmd::tweet', is_interactive => sub { return 0 };

*STDIN = *DATA;

$app->twtfile->spew('');

$app->run;

like(
    $app->twtfile->slurp_utf8, qr/
	\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ      \t Foo\n
        \d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d+Z \t Quux\n
     /smx
);

done_testing;

__DATA__
Foo
Quux
