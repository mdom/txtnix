package App::txtnix::Cmd::info;
use Mojo::Base 'App::txtnix';
use Path::Tiny;
use Mojo::JSON 'encode_json';
use Data::Dumper;

$Data::Dumper::Terse = 1;

has 'source';

sub run {
    my ($self) = @_;
    my $url =
        $self->following->{ $self->source }
      ? $self->following->{ $self->source }
      : $self->source;

    my @tweets;

    my $file = path($url);
    if ( $file->is_file ) {
        my $source = App::txtnix::Source->new( file => $file );
        @tweets = $self->parse_twtfile( $source, $file->slurp_utf8 );
    }
    else {
        @tweets = $self->get_tweets($url);
    }

    my $metadata = get_metadata(@tweets);

    if ( !$metadata ) {
        print "No metadata for " . $self->source . " found.\n";

    }
    else {
        print Dumper($metadata);
    }

    return 0;
}

sub get_metadata {
    my @tweets = @_;
    my $metadata;
    for my $tweet (@tweets) {
        if ( $tweet->is_metadata ) {
            my ( $command, @args ) = @{ $tweet->command };
            if ( $command eq 'follow' ) {
                my ( $nick, $url ) = @args;
                $metadata->{following}->{$nick} = $url;
            }
            elsif ( $command eq 'unfollow' ) {
                my ($nick) = @args;
                delete $metadata->{following}->{$nick};

            }
            else {
                $metadata->{$command} = [@args];
            }
        }
    }
    return $metadata;
}

1;
