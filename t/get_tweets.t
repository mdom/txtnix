use strict;
use warnings;
use Mojo::UserAgent::Server;
use App::txtnix;
use Path::Tiny;
use Test::More;
use Mojolicious::Lite;

my $config  = Path::Tiny->tempfile;
my $twtfile = Path::Tiny->tempfile;
my $app     = App::txtnix->new(
    config_file => $config,
    twtfile     => $twtfile,
    following   => { bob => '/bob.txt' }
);

# Silence
app->log->level('fatal');

get '/bob.txt' => { text => "20160202\tWhoo!" };

my @tweets = $app->get_tweets;

is( $tweets[0]->text, 'Whoo!' );

done_testing;
