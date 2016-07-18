package App::txtnix::Cmd::view;
use Mojo::Base 'App::txtnix';
use Path::Tiny;

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

    @tweets = $self->filter_tweets(@tweets);
    $self->display_tweets(@tweets);
    return 0;
}

1;
