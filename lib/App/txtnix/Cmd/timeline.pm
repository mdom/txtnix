package App::txtnix::Cmd::timeline;
use Moo;
extends 'App::txtnix';

sub run {
    my $self   = shift;
    my @tweets = $self->get_tweets();
    $self->display_tweets(@tweets);
    return 0;
}

1;
