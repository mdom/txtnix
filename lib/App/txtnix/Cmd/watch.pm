package App::txtnix::Cmd::watch;
use Mojo::Base 'App::txtnix';
use Mojo::JSON 'decode_json';
use App::txtnix::Tweet;
use App::txtnix::Source;
use Mojo::ByteStream 'b';

has 'url';

sub run {
    my $self = shift;
    $self->use_pager(0);
    $self->ua->inactivity_timeout(0);
    $self->ua->websocket(
        $self->url => sub {
            my ( $ua, $tx ) = @_;
            say 'WebSocket handshake failed!' and return
              unless $tx->is_websocket;
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
                    my $tweet = App::txtnix::Tweet->new(
                        timestamp => Mojo::Date->new( $data->{time} ),
                        source    => App::txtnix::Source->new(
                            url  => $data->{url},
                            nick => $data->{nick}
                        ),
                        text => $data->{tweet},
                    );
                    $self->display_tweets( 1, $tweet );

                }
            );
        }
    );
    Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
}

1;
