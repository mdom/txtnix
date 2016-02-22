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
    following   => { bob => '/bob.txt', alice => '/alice.txt' }
);

# Silence
app->log->level('fatal');

get '/bob.txt'   => { text => "20160203\tWhoo!" };
get '/alice.txt' => { text => "20160202\tTweet!" };

my @tweets;

@tweets = $app->get_tweets;
is( @tweets,          2 );
is( $tweets[0]->text, 'Whoo!' );

@tweets = $app->get_tweets('alice');
is( @tweets,          1 );
is( $tweets[0]->text, 'Tweet!' );

done_testing;
