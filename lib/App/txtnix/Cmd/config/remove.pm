package App::txtnix::Cmd::config::remove;
use Mojo::Base 'App::txtnix';

has 'key';

sub run {
    my ($self) = @_;
    my $config = $self->read_config;
    delete $config->{twtxt}->{ $self->key };
    $self->write_config($config);
    return 0;
}

1;
