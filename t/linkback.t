use strict;
use warnings;
use Path::Tiny;
use Test::More;
use Test::Output;
use App::txtnix;
use App::txtnix::Plugin::LinkBack;
use Mojolicious::Lite;
use Mojo::Loader qw(data_section);
use Mojo::UserAgent::Server;
use OptArgs 'class_optargs';

$ENV{TZ} = 'UTC';

my $config  = Path::Tiny->tempfile;
my $twtfile = Path::Tiny->tempfile;

$config->spew_utf8( data_section( 'main', 'config.txt' ) );

my $app = App::txtnix->new(
    config         => $config,
    twtfile        => $twtfile,
    display_format => 'simple',
    use_pager      => 0,
    use_colors     => 0,
    following      => { bob => '/bob.txt', alice => '/alice.txt' },
);

# Silence
app->log->level('fatal');

get '/bob.txt'     => { text => "2016-02-03T00:00:00Z#linkback /bob.php" };
get '/charlie.txt' => { text => "2016-02-03T00:00:00Z#linkback /charlie.php" };
post '/bob.php'    => { text => "2016-02-03T00:00:00Z#linkback /bob.php" };

stderr_is(
    sub {
        $app->emit(
            'post_tweet',
            App::txtnix::Tweet->new(
                text => "2016-02-03T00:00:00Z\tHi @<bob /bob.txt>"
            )
        );
    },
    <<EOF );
Cannot send ping back without twturl.
EOF

$app->twturl('/alice.txt');

stderr_is(
    sub {
        $app->emit(
            'post_tweet',
            App::txtnix::Tweet->new(
                text => "2016-02-03T00:00:00Z\tHi @<bob /bob.txt>"
            )
        );
    },
    <<EOF );
Send ping back to /bob.php.
EOF

stderr_is(
    sub {
        $app->emit(
            'post_tweet',
            App::txtnix::Tweet->new(
                text => "2016-02-03T00:00:00Z\tHi @<charlie /charlie.txt>"
            )
        );
    },
    <<EOF );
Couldn't ping back to /charlie.php: 404 response: Not Found
EOF

done_testing;

__DATA__

@@ config.txt

[LinkBack]
enabled = 1
