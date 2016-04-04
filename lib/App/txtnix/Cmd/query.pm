package App::txtnix::Cmd::query;
use Mojo::Base 'App::txtnix';
use App::txtnix::Tweet;
use App::txtnix::Source;
use App::txtnix::Date qw(to_date);

sub query_result_to_tweets {
    my ( $self, @results ) = @_;
    my @tweets;
    for my $result (@results) {
        my ( $nick, $url, $time, $text ) = @$result;
        my $source = App::txtnix::Source->new( nick => $nick, url => $url );
        push @tweets,
          App::txtnix::Tweet->new(
            source    => $source,
            text      => $text,
            timestamp => to_date($time),
          );
    }
    return @tweets;
}

1;
