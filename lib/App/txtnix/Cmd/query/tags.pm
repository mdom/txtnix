package App::txtnix::Cmd::query::tags;
use Mojo::Base 'App::txtnix';
use App::txtnix::Registry;
use App::txtnix::Tweet;
use App::txtnix::Source;
use Mojo::IOLoop;

has [qw( search_term )];

sub run {
    my $self = shift;
    die "Missing parameter registry." if !$self->registry;
    my $registry =
      App::txtnix::Registry->new( url => $self->registry, ua => $self->ua );

    my @results = $registry->get_tags( $self->search_term );

    my @tweets;
    for my $result (@results) {
        my ( $mention, $time, $text ) = @$result;
        my ( $nick, $url ) = $self->parse_mention($mention);
        my $source = App::txtnix::Source->new( nick => $nick, url => $url );
        push @tweets,
          App::txtnix::Tweet->new(
            source    => $source,
            text      => $text,
            timestamp => $self->to_date($time)
          );
    }

    $self->display_tweets( 1, @tweets );

    return 0;
}

1;
