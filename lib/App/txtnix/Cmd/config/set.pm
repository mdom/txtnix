package App::txtnix::Cmd::config::set;
use Mojo::Base 'App::txtnix';

has 'key';
has 'value';

sub run {
    my ($self) = @_;
    my $config = $self->read_file;
    $config->{twtxt}->{ $self->key } = $self->value;
    $self->write_file($config);
    return 0;
}

1;
