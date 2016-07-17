#!/usr/bin/perl

use strict;
use warnings;

use App::txtnix;
use Path::Tiny;
use Test::More;
use Test::Output;
use Mojolicious::Lite;
use Mojo::Loader qw(data_section);
use Mojo::UserAgent::Server;

app->log->level('fatal');

post '/gists' => sub {
    my $c = shift;
    return $c->render( status => 401, text => 'Go away!' )
      if $c->req->headers->header('Authorization') ne 'Basic Ym9iOnMzY3IzdA==';
    ok($c);
    $c->render( code => 200, json => { id => 1 } );
};

my $config_file = Path::Tiny->tempfile;

$config_file->spew_utf8( data_section( 'main', 'config.txt' ) );

my $app = App::txtnix->new(
    config  => $config_file,
    twtfile => Path::Tiny->tempfile,
);

$app->twtfile->touch;

my ($plugin) = grep { $_->name eq 'GistStore' } @{ $app->plugins };

$plugin->url('/gists');

$app->emit('post_tweet');

$plugin->config->{user} = 'alice';

stderr_is( sub { $app->emit('post_tweet') }, <<EOF );
Error while uploading gist: 401 Unauthorized
EOF

$plugin->config->{user} = undef;

stderr_is( sub { $app->emit('post_tweet') }, <<EOF );
Missing parameter access_token or user for GistStore.
EOF

$plugin->config->{user}         = 'bob';
$plugin->config->{access_token} = undef;

stderr_is( sub { $app->emit('post_tweet') }, <<EOF );
Missing parameter access_token or user for GistStore.
EOF

$plugin->config->{user} = undef;

stderr_is( sub { $app->emit('post_tweet') }, <<EOF );
Missing parameter access_token or user for GistStore.
EOF

done_testing;

__DATA__

@@ config.txt
[GistStore]
enabled = 1
user = bob
access_token = s3cr3t
