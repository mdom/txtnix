package App::txtnix::Registry;
use Mojo::Base -base;
use Mojo::UserAgent;
use Carp;

has 'url';
has ua => sub {
    return Mojo::UserAgent->new();
};

sub get_users {
    my ( $self, $user ) = @_;
    my $query = Mojo::URl->new( $self->url )->path('/api/plain/users')
      ->query( q => $user || '' );
    return $self->query_endpoint($query);
}

sub get_tweets {
    my ( $self, $text ) = @_;
    my $query = Mojo::URl->new( $self->url )->path('/api/plain/tweets')
      ->query( q => $text || '' );
    return $self->query_endpoint($query);
}

sub get_tag {
    my ( $self, $tag ) = @_;
    croak('Parameter tag must be provided for get_tag.')
      if not $tag;
    my $query = Mojo::URl->new( $self->url )->path("/api/plain/tags/$tag");
    return $self->query_endpoint($query);
}

sub get_mentions {
    my ( $self, $url ) = @_;
    croak('Parameter url must be provided for get_mentions.')
      if not $url;
    my $query = Mojo::URl->new( $self->url )->path('/api/plain/mentions')
      ->query( url => $url );
    return $self->query_endpoint($query);
}

sub query_endpoint {
    my ( $self, $endpoint ) = @_;
    my $tx = $self->ua->get($endpoint);
    my @result;
    if ( my $res = $tx->success ) {
        for my $line ( split /\n/, $res->body ) {
            push @result, [ split /\t/, $line ];
        }
    }
    return @result;
}

1;
