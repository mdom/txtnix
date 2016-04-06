use strict;
use warnings;
use Path::Tiny;
use Test::More;
use Test::Output;
use App::txtnix;
use Mojolicious::Lite;
use Mojo::UserAgent::Server;
use OptArgs 'class_optargs';
use POSIX qw();

$ENV{TZ} = 'UTC';

POSIX::tzset;

my $config  = Path::Tiny->tempfile;
my $twtfile = Path::Tiny->tempfile;

sub run {
    my ( $class, $opts ) = class_optargs( 'App::txtnix::Cmd', @_ );
    $opts = {
        config         => $config,
        twtfile        => $twtfile,
        display_format => 'simple',
        use_pager      => 0,
        use_colors     => 0,
        following      => { bob => '/bob.txt', alice => '/alice.txt' },
        nick           => 'test_runner',
        %$opts,
    };
    $class->new($opts)->run();
}

# Silence
app->log->level('fatal');

get '/alice.txt' => sub {
    my $self = shift;
    $self->res->code(301);
    return $self->redirect_to('/alice2.0.txt');
};

get '/bob.txt'      => { text => "2016-02-03T00:00:00Z\tWhoo!" };
get '/alice2.0.txt' => { text => "2016-02-02T00:00:00Z\tTweet!" };

output_like(
    sub { run('timeline') },
    undef,
qr{Rewrite url from http://127.0.0.1:[\d]+/alice.txt to /alice2.0.txt after 301.}
);

stdout_is( sub { run( 'timeline', '--ascending' ) }, <<'EOO');
2016-02-02 00:00 alice: Tweet!
2016-02-03 00:00 bob: Whoo!
EOO

stdout_is( sub { run( 'timeline', '--descending' ) }, <<'EOO');
2016-02-03 00:00 bob: Whoo!
2016-02-02 00:00 alice: Tweet!
EOO

run( 'tweet', 'Hello World @bob' );
like( $twtfile->slurp_utf8, qr/[\d:TZ-]+\tHello World \@<bob \/bob.txt>$/ );

$twtfile->spew('');
run( 'tweet', '--created-at', '2016-02-03T00:00:00Z', 'Hello World' );
is( $twtfile->slurp_utf8, "2016-02-03T00:00:00Z\tHello World\n" );

stdout_is( sub { run('following') }, <<EOF );
alice @ /alice2.0.txt
bob @ /bob.txt
EOF

stdout_is( sub { run( 'following', 'bob' ) }, <<EOF );
bob @ /bob.txt
EOF

stdout_is(
    sub { run( 'follow', 'bob', '/bob.txt' ) },
    qq{You're already following bob.\n}
);

stdout_is(
    sub { run( 'follow', 'bob', '/bob2.0.txt' ) },
    qq{You're already following bob under a differant url.\n}
);

stdout_is( sub { run( 'unfollow', 'bob' ) }, qq{You've unfollowed bob.\n} );

stdout_is(
    sub { run( 'unfollow', 'charlie' ) },
    qq{You're not following charlie.\n}
);

stdout_is( sub { run('following') }, qq{alice @ /alice2.0.txt\n} );

stdout_is( sub { run( 'follow', 'bob', '/bob.txt' ) },
    qq{You're now following bob.\n} );

stdout_is(
    sub { run( 'follow', 'test_runner', '/test_runner.txt' ) },
    qq{Your nickname is also test_runner. Please choose a different nick.\n}
);

stdout_is(
    sub { run( 'config', 'get', 'disclose_identity' ) },
    qq{The configuration key disclose_identity is unset.\n}
);

stdout_is( sub { run( 'config', 'set', 'disclose_identity', 1 ) }, qq{} );

stdout_is( sub { run( 'config', 'get', 'disclose_identity' ) }, qq{1\n} );

stdout_is( sub { run( 'config', 'remove', 'disclose_identity' ) }, qq{} );

stdout_is(
    sub { run( 'config', 'get', 'disclose_identity' ) },
    qq{The configuration key disclose_identity is unset.\n}
);

get '/eve.txt' => sub {
    my $self = shift;
    $self->res->code(410);
    return $self->render( text => 'GONE' );
};

run follow => eve => '/eve.txt';

stderr_like( sub { run('timeline') },
    qr/Unfollow user eve after 410 response/ );

is( App::txtnix->new( config => $config )->following->{eve}, undef );

done_testing;
