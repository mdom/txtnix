package App::txtnix::Cmd::query::users;
use Mojo::Base 'App::txtnix::Cmd::query';
use App::txtnix::Registry;

has [qw( search_term )];

sub run {
    my $self = shift;
    die "Missing parameter registry." if !$self->registry;
    my $registry =
      App::txtnix::Registry->new( url => $self->registry, ua => $self->ua );

    my @results = $registry->get_users( $self->search_term );

    if ( $self->limit && @results > $self->limit ) {
        @results = @results[ 0 .. $self->limit - 1 ];
    }

    for my $result (@results) {
        my ( $url, undef, $nick ) = @$result;
        print "$nick @ $url\n";
    }

    return 0;
}

1;
