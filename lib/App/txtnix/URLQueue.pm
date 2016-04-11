# stolen from https://gist.github.com/jberger/5153008
# all errors probably by me
package App::txtnix::URLQueue;
use Mojo::Base 'Mojo::EventEmitter';
use Mojo::UserAgent;

has queue => sub { [] };
has ua => sub { Mojo::UserAgent->new( max_redirects => 5 ) };
has worker => 16;
has [qw(delay cache)];

sub start {
    my ( $self, $cb ) = @_;

    return unless @{ $self->queue };
    $self->{running} = 0;

    $self->_refresh;

    return;
}

sub _refresh {
    my $self = shift;

    my $worker = $self->worker;
    while ( $self->{running} < $worker
        and my $url = shift @{ $self->queue } )
    {
        $self->{running}++;
        my $end = $self->delay->begin;

        my ( $cached, $params ) = ( undef, {} );
        if ( $self->cache ) {
            $cached = $self->cache->get($url);
            if ($cached) {
                $params = { "If-Modified-Since" => $cached->{last_modified} };
            }
        }

        $self->ua->get(
            $url => $params => sub {
                my ( $ua, $tx ) = @_;

                $self->emit( process => $tx, $url );

                # refresh worker pool
                $self->{running}--;
                $self->_refresh;
                $end->();
            }
        );
    }
}

1;
