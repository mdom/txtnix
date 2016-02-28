package App::txtnix::Registry;
use Mojo::Base -base;
use Mojo::UserAgent;
use Mojo::URL;
use Mojo::ByteStream 'b';
use Carp;

has [ 'url', 'ua' ];

sub get_users {
    my ( $self, $user, $cb ) = @_;
    my $query = Mojo::URL->new( $self->url )->path('/api/plain/users')
      ->query( q => $user || '' );
    return $self->query_endpoint( $query, $cb );
}

sub get_tweets {
    my ( $self, $text, $cb ) = @_;
    my $query = Mojo::URL->new( $self->url )->path('/api/plain/tweets')
      ->query( q => $text || '' );
    return $self->query_endpoint( $query, $cb );
}

sub get_tag {
    my ( $self, $tag, $cb ) = @_;
    croak('Parameter tag must be provided for get_tag.')
      if not $tag;
    my $query = Mojo::URL->new( $self->url )->path("/api/plain/tags/$tag");
    return $self->query_endpoint( $query, $cb );
}

sub get_mentions {
    my ( $self, $url, $cb ) = @_;
    croak('Parameter url must be provided for get_mentions.')
      if not $url;
    my $query = Mojo::URL->new( $self->url )->path('/api/plain/mentions')
      ->query( url => $url );
    return $self->query_endpoint( $query, $cb );
}

sub query_endpoint {
    my ( $self, $endpoint, $cb ) = @_;
    croak('Missing parameter callback.') if not $cb;
    $self->ua->get(
        $endpoint => sub {
            my ( $ua, $tx ) = @_;
            my @result;
            if ( my $res = $tx->success ) {
                for my $line ( split /\n/, b( $res->body )->decode ) {
                    push @result, [ split /\t/, $line ];
                }
            }
            $cb->(@result);
        }
    );
    return;
}

1;
