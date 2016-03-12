#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use Test::Output;
use App::txtnix::Cmd::tweet;
use App::txtnix::Cmd::follow;
use Mojo::Loader qw(data_section);
use Path::Tiny;

my $config_file = Path::Tiny->tempfile;
my $twtfile     = Path::Tiny->tempfile;

$config_file->append( data_section( 'main', 'config.txt' ) );

my $cmd =
  App::txtnix::Cmd::tweet->new( config => $config_file, twtfile => $twtfile );

$cmd->text('Hello World!');

stdout_is( sub { $cmd->run() }, <<EOF);
foo
quux
EOF

$cmd = App::txtnix::Cmd::follow->new(
    config   => $config_file,
    twtfile  => $twtfile,
    nickname => 'foo',
    url      => 'http://example.com/foo.txt'
);

stdout_is( sub { $cmd->run() }, <<EOF);
You're now following foo.
fubar
EOF

done_testing;

__DATA__

@@ config.txt

[ShellExec]
enabled = 1
post_tweet_cmd = echo quux
post_follow_cmd = echo fubar

[twtxt]
pre_tweet_hook = echo foo
post_tweet_hook = echo bar
