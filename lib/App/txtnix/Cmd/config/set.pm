package App::txtnix::Cmd::config::set;
use Moo;
extends 'App::txtnix';

has key   => ( is => 'rw' );
has value => ( is => 'rw' );

sub run {
    my ($self) = @_;
    my $config = $self->read_file;
    $config->{twtxt}->{ $self->key } = $self->value;
    $self->write_file($config);
    return 0;
}

1;
