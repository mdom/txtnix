package App::txtnix::Cmd::publish;
use Mojo::Base 'App::txtnix';

sub run {
    my ($self) = @_;

    my $file = $self->twtfile;
    $file->touch if !$file->exists;

    $self->emit('post_tweet');
    return 0;
}

1;
