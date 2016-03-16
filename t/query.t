use strict;
use warnings;
use Path::Tiny;
use Test::More;
use Test::Output;
use Mojolicious::Lite;
use Mojo::UserAgent::Server;
use OptArgs qw(class_optargs);

$ENV{TZ} = 'UTC';

my $config = Path::Tiny->tempfile;

sub run {
    my ( $class, $opts ) = class_optargs( 'App::txtnix::Cmd', @_ );
    $opts = {
        config         => $config,
        twtfile        => Path::Tiny->tempfile,
        display_format => 'simple',
        use_pager      => 0,
        use_colors     => 0,
        following      => { bob => '/bob.txt', alice => '/alice.txt' },
        nick           => 'test_runner',
        registry       => '/',
        %$opts,
    };
    $class->new($opts)->run();
}

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
            'Do we need an IRC channel for #twtxt, @<bob /bob.txt>?'
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
    my $query = $c->param('url');
    return $c->render( status => 400, text => '`url` must be provided.' )
      if !$query;
    for my $datum ( @{ $data->{tweets} } ) {
        return $c->render( text => join( "\t", @$datum ) )
          if $datum->[2] =~ /\@<\w+ $query>/;
    }
    return $c->render( text => '' );
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

post '/users' => sub {
    my $c = shift;
    my ( $url, $nick ) = ( $c->param('url'), $c->param('nickname') );
    return $c->render( text => 'Oops.', status => 400 )
      if !$url || !$nick || $url eq '/evil';
    return $c->render( text => 'Ok.', status => 200 );
};

stdout_is( sub { run( 'query', 'users' ) }, <<EOF);
example @ https://example.org/twtxt.txt
example42 @ https://example.org/42.twtxt.txt
EOF

stdout_is( sub { run( 'query', 'users', 'example' ) }, <<EOF);
example @ https://example.org/twtxt.txt
EOF

stdout_is( sub { run( 'query', 'users', '--unfollowed' ) }, <<EOF);
example @ https://example.org/twtxt.txt
example42 @ https://example.org/42.twtxt.txt
EOF

run(qw(follow example https://example.org/twtxt.txt));

stdout_is( sub { run( 'query', 'users', '--unfollowed' ) }, <<EOF);
example42 @ https://example.org/42.twtxt.txt
EOF

stdout_is( sub { run( 'query', 'tweets' ) }, <<EOF);
2016-02-09 12:42 buckket: Do we need an IRC channel for #twtxt, \@bob?
2016-02-09 12:42 buckket: Good Morning, twtxt-world!
EOF

stdout_is( sub { run( 'query', 'tweets', 'Morning' ) }, <<EOF);
2016-02-09 12:42 buckket: Good Morning, twtxt-world!
EOF

stdout_is( sub { run( 'query', 'mentions', 'bob' ) }, <<EOF);
2016-02-09 12:42 buckket: Do we need an IRC channel for #twtxt, \@bob?
EOF

stdout_is( sub { run( 'query', 'mentions', 'alice' ) }, <<EOF);
EOF

stdout_is( sub { run( 'query', 'tags', 'twtxt' ) }, <<EOF);
2016-02-09 12:42 buckket: Do we need an IRC channel for #twtxt, \@bob?
EOF

done_testing;
