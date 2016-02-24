package App::txtnix::Cmd::view;
use Moo;
extends 'App::txtnix';

has source => ( is => 'rw' );

sub run {
    my ($self) = @_;
    my @tweets = $self->get_tweets( $self->source );
    $self->display_tweets(@tweets);
    return 0;
}

1;
