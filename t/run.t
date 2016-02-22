use strict;
use warnings;
use Path::Tiny;
use App::txtnix;
use Test::More;
use Test::Output;
use Mojolicious::Lite;
use Mojo::UserAgent::Server;

my $config  = Path::Tiny->tempfile;
my $twtfile = Path::Tiny->tempfile;

my $app = App::txtnix->new(
    config_file => $config,
    twtfile     => $twtfile,
    use_pager   => 0,
    following   => { bob => '/bob.txt', alice => '/alice.txt' }
);

# Silence
app->log->level('fatal');

get '/bob.txt'   => { text => "20160203\tWhoo!" };
get '/alice.txt' => { text => "20160202\tTweet!" };

stdout_is( sub { $app->run('timeline') }, <<'EOO');
1970-08-22 08:03 bob: Whoo!
1970-08-22 08:03 alice: Tweet!
EOO

$app->run( 'tweet', 'Hello World' );
like( $twtfile->slurp_utf8, qr/[\d:TZ-]+\tHello World/ );

stdout_is( sub { $app->run( 'follow', 'bob', '/bob.txt' ) },
    qq{You're already following bob.\n} );

stdout_is(
    sub { $app->run( 'follow', 'bob', '/bob2.0.txt' ) },
    qq{You're already following bob under a differant url.\n}
);

stdout_is( sub { $app->run( 'unfollow', 'bob' ) },
    qq{You've unfollowed bob.\n} );

stdout_is(
    sub { $app->run( 'unfollow', 'charlie' ) },
    qq{You're not following charlie.\n}
);

stdout_is( sub { $app->run('following') }, qq{alice @ /alice.txt\n} );

stdout_is( sub { $app->run( 'follow', 'bob', '/bob.txt' ) },
    qq{You're now following bob.\n} );

stdout_is(
    sub { $app->run( 'config', 'get', 'disclose_identity' ) },
    qq{The configuration key disclose_identity is unset.\n}
);

ok( not exists $app->config->read_file->{twtxt}->{disclose_identity} );

stdout_is( sub { $app->run( 'config', 'set', 'disclose_identity', 1 ) }, qq{} );

is( $app->config->read_file->{twtxt}->{disclose_identity}, 1 );

stdout_is( sub { $app->run( 'config', 'get', 'disclose_identity' ) }, qq{1\n} );

stdout_is( sub { $app->run( 'config', 'remove', 'disclose_identity' ) }, qq{} );

stdout_is(
    sub { $app->run( 'config', 'get', 'disclose_identity' ) },
    qq{The configuration key disclose_identity is unset.\n}
);

done_testing;
