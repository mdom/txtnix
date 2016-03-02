package App::txtnix::Cmd::view;
use Mojo::Base 'App::txtnix';

has 'source';

sub run {
    my ($self) = @_;
    my $url =
        $self->following->{ $self->source }
      ? $self->following->{ $self->source }
      : $self->source;
    my @tweets = $self->get_tweets($url);
    @tweets = $self->filter_tweets(@tweets);
    $self->display_tweets( 0, @tweets );
    return 0;
}

1;
