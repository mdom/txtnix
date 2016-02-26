package App::txtnix::Cmd::config::remove;
use Mojo::Base 'App::txtnix';

has 'key';

sub run {
    my ($self) = @_;
    my $config = $self->read_file;
    delete $config->{twtxt}->{ $self->key };
    $self->write_file($config);
    return 0;
}

1;
