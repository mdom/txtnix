package App::txtnix::Cmd::timeline;
use Mojo::Base 'App::txtnix';

sub run {
    my $self   = shift;
    my @tweets = $self->get_tweets();
    $self->display_tweets( 1, @tweets );
    return 0;
}

1;
