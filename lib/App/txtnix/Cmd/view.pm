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
    $self->display_tweets(@tweets);
    return 0;
}

1;
