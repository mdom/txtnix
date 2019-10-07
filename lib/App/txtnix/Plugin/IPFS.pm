package App::txtnix::Plugin::IPFS;
use Mojo::Base 'App::txtnix::Plugin';
use Mojo::JSON 'decode_json';

sub tx_error {
    my $tx  = shift;
    my $err = $tx->error;
    warn $err->{code}
      ? "$err->{code} response: $err->{message}\n"
      : "Connection error: $err->{message}\n";
    return;
}

has api_url => sub { "http://127.0.0.1:5001/api/v0/" };
has publish => sub { 0 };

sub post_tweet {
    my $self = shift;
    my $app  = $self->app;

    my $ua   = $app->ua;
    my $file = $app->twtfile;

    if ( !$file || !$file->exists ) {
        warn "Can't find twtfile to upload\n";
        return;
    }

    my $base = Mojo::URL->new( $self->api_url );
    my $add  = $base->clone->path('add');

    my $tx = $ua->post(
        $add => form => {
            twtxt =>
              { file => $file->stringify, 'Content-Type' => 'text/plain' }
        }
    );
    my $res = $tx->result;
    if ( $res->is_success ) {
        my @json =
          grep { $_->{Hash} } map { decode_json($_) } split( "\n", $res->body );
        my $hash = $json[0]->{Hash};
        if ( $self->publish ) {
            my $publish =
              $base->clone->path('name/publish')->query( arg => $hash );
            my $tx = $ua->post($publish);
            if ( $tx->result->is_success ) {
                print "IPFS published";
            }
            else {
                tx_error($tx);
                return;
            }
        }
        print "Uploaded twtxt file to ipfs at $hash.\n";
    }
    else {
        tx_error($tx);
        return;
    }

    return;
}

1;
