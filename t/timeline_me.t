use strict;
use warnings;
use Path::Tiny;
use App::txtnix::Cmd::timeline;
use Test::More;
use Test::Output;
use Mojolicious::Lite;
use Mojo::UserAgent::Server;

$ENV{TZ} = 'UTC';

# Silence
app->log->level('fatal');

get '/bob.txt' => { text => "2016-02-03T00:00:00Z\tWhoo!" };
get '/alice.txt' => { text =>
"2016-02-02T00:00:00Z\tTweet to @<charlie https://example.com/charlie.txt>"
};

my $app = App::txtnix::Cmd::timeline->new(
    config    => Path::Tiny->tempfile,
    twtfile   => Path::Tiny->tempfile,
    twturl    => 'https://example.com/charlie.txt',
    nick      => 'charlie',
    template  => 'simple',
    me        => 1,
    following => { alice => '/alice.txt', bob => '/bob.txt' },
);

$app->twtfile->spew_utf8("2016-02-01T00:00:00Z\tHi");

stdout_is( sub { $app->run }, <<'EOF');
2016-02-02 00:00 alice: Tweet to @charlie
2016-02-01 00:00 charlie: Hi
EOF

done_testing;
