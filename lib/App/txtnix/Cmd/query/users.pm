package App::txtnix::Cmd::query::users;
use Mojo::Base 'App::txtnix';
use App::txtnix::Registry;
use Mojo::IOLoop;

has [qw( search_term )];

sub run {
    my $self = shift;
    die "Missing parameter registry." if !$self->registry;
    my $registry =
      App::txtnix::Registry->new( url => $self->registry, ua => $self->ua );

    my $delay = Mojo::IOLoop->delay;
    my $end   = $delay->begin;
    $registry->get_users(
        $self->search_term,
        sub {
            my @results = @_;
            if ( $self->limit && @results > $self->limit ) {
                @results = @results[ 0 .. $self->limit - 1 ];
            }
            for my $result (@results) {
                my ( $url, undef, $nick ) = @$result;
                print "$nick \@ $url\n";
            }
            $end->();
        }
    );
    $delay->wait;
    return 0;
}

1;
