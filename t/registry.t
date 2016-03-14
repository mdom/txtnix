use strict;
use warnings;
use Path::Tiny;
use Test::More;
use Test::Output;
use App::txtnix::Registry;
use Mojolicious::Lite;
use Mojo::IOLoop::Delay;
use Mojo::UserAgent;
use Mojo::UserAgent::Server;
use OptArgs 'class_optargs';

$ENV{TZ} = 'UTC';

# Silence
app->log->level('fatal');

under '/api/plain/';

my $data = {
    users => [
        [
            'https://example.org/twtxt.txt', '2016-02-09T12:42:26.000Z',
            'example'
        ],
        [
            'https://example.org/42.twtxt.txt', '2016-02-10T13:20:10.000Z',
            'example42'
        ]
    ],
    tweets => [
        [
            '@<buckket https://buckket.org/twtxt.txt>',
            '2016-02-09T12:42:26.000Z',
            'Do we need an IRC channel for #twtxt?'
        ],
        [
            '@<buckket https://buckket.org/twtxt.txt>',
            '2016-02-09T12:42:12.000Z',
            'Good Morning, twtxt-world!'
        ]
    ],
};

get '/users' => sub {
    my $c     = shift;
    my $query = $c->param('q');
    my @data  = @{ $data->{users} };
    if ($query) {
        for my $datum (@data) {
            return $c->render( text => join( "\t", @$datum ) )
              if $datum->[2] eq $query;
        }
        return $c->render( text => '' );
    }
    return $c->render( text => join( "\n", map { join( "\t", @$_ ) } @data ) );
};

get '/tweets' => sub {
    my $c     = shift;
    my $query = $c->param('q');
    my @data  = @{ $data->{tweets} };
    if ($query) {
        for my $datum (@data) {
            return $c->render( text => join( "\t", @$datum ) )
              if $datum->[2] =~ $query;
        }
        return $c->render( text => '' );
    }
    return $c->render( text => join( "\n", map { join( "\t", @$_ ) } @data ) );
};

get '/mentions' => sub {
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

get '/tags/#q' => sub {
    my $c     = shift;
    my $query = $c->param('q');
    my @data  = @{ $data->{tweets} };
    if ($query) {
        for my $datum (@data) {
            return $c->render( text => join( "\t", @$datum ) )
              if $datum->[2] =~ /#$query/;
        }
        return $c->render( text => '' );
    }
    return $c->render( text => join( "\n", map { join( "\t", @$_ ) } @data ) );
};

my $registry = App::txtnix::Registry->new(
    ua  => Mojo::UserAgent->new,
    url => '/',
);

is( ( $registry->get_users )[0]->[2], 'example' );
is( ( $registry->get_users('example42') )[0]->[2], 'example42' );
is( $registry->get_users('example23'), 0 );

is( $registry->get_tags('twtxt'), 1 );
eval { $registry->get_tags };
like( $@, qr/Parameter tag must be provided for get_tag\./ );

is( $registry->get_mentions('https://buckket.org/twtxt.txt'), 2 );
eval { $registry->get_mentions };
like( $@, qr/Parameter url must be provided for get_mentions\./ );

is( $registry->get_tweets,            2 );
is( $registry->get_tweets('Morning'), 1 );
is( $registry->get_tweets('bob'),     0 );

my @tweets;

my $delay = Mojo::IOLoop::Delay->new;
my $end   = $delay->begin;
$registry->get_tweets( undef, sub { is( @_, 2 ); $end->() } );
$delay->wait;

done_testing;
