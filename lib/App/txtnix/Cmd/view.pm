package App::txtnix::Cmd::view;
use Mojo::Base 'App::txtnix';

has 'source';

sub run {
    my ($self) = @_;
    my @tweets = $self->get_tweets( $self->source );
    $self->display_tweets(@tweets);
    return 0;
}

1;
