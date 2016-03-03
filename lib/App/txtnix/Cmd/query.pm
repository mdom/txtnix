package App::txtnix::Cmd::query;
use Mojo::Base 'App::txtnix';
use App::txtnix::Tweet;
use App::txtnix::Source;

sub query_result_to_tweets {
    my ( $self, @results ) = @_;
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
    return @tweets;
}

1;
