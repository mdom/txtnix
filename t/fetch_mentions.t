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

my $data = {
    tweets => [
        [
            '@<bob https://example.com/bob.txt>',
            '2016-02-09T12:42:12.000Z',
            'Good Morning, twtxt-world!'
        ]
    ],
};

get '/api/plain/mentions' => sub {
    my $c     = shift;
    my $query = $c->param('q');
    my @data  = @{ $data->{tweets} };
    if ($query) {
        for my $datum (@data) {
            return $c->render( text => join( "\t", @$datum ) )
              if $datum->[0] =~ /\@<\w+ $query>/;
        }
        return $c->render( text => '' );
    }
    return $c->render( text => join( "\n", map { join( "\t", @$_ ) } @data ) );
};

my $app = App::txtnix::Cmd::timeline->new(
    config   => Path::Tiny->tempfile,
    twtfile  => Path::Tiny->tempfile,
    twturl   => 'https://example.com/bob.txt',
    registry => '/',
    template => 'simple',
);

stdout_is( sub { $app->run }, <<EOF);
2016-02-09 12:42 bob: Good Morning, twtxt-world!
EOF

done_testing;
