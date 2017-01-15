package App::txtnix::Cmd::watch;
use Mojo::Base 'App::txtnix';
use Mojo::JSON 'decode_json';
use App::txtnix::Tweet;
use App::txtnix::Source;
use Mojo::ByteStream 'b';

has url    => sub { "ws://roster.twtxt.org/stream" };
has alarm  => sub { "mention" };
has filter => sub { 1 };

sub run {
    my $self = shift;
    $self->use_pager(0);
    $self->time_format('%F %H:%M');
    $self->ua->inactivity_timeout(0);
    my $exit = 0;
    $self->ua->websocket(
        $self->url => sub {
            my ( $ua, $tx ) = @_;
            if ( !$tx->is_websocket ) {
                say 'WebSocket handshake failed!';
                $exit = 1;
                return;
            }
            $tx->on(
                finish => sub {
                    my ( $tx, $code, $reason ) = @_;
                    say "WebSocket closed with status $code.";
                }
            );
            $tx->on(
                message => sub {
                    my ( $tx, $msg ) = @_;
                    my $data = decode_json( b($msg)->encode );
                    return if !$data;

                    return
                      if $self->filter
                      && ( $data->{is_bot} || $data->{is_metadata} );

                    my $tweet = App::txtnix::Tweet->new(
                        timestamp => Mojo::Date->new( $data->{time} ),
                        source    => App::txtnix::Source->new(
                            url  => $data->{url},
                            nick => $data->{nick}
                        ),
                        text => $data->{tweet},
                    );
                    $self->display_tweets($tweet);

                    if ( $self->alarm eq 'mention' ) {
                        my $am_i_mentioned = grep { $_ eq $self->twturl }
                          $tweet->text =~ m{\@<(?:\w+ )?([^>]+)>}g;
                        print "\a" if $am_i_mentioned;
                    }
                    elsif ( $self->alarm eq 'tweet' ) {
                        print "\a";
                    }
                    return;
                }
            );
        }
    );
    Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
    return $exit;
}

1;
