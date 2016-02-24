package App::txtnix::Cmd::config::get;
use Moo;
extends 'App::txtnix';

has key => ( is => 'rw' );

sub run {
    my ($self) = @_;
    my $key    = $self->key;
    my $config = $self->read_file;
    if ( exists $config->{twtxt}->{$key} ) {
        print $config->{twtxt}->{$key} . "\n";
    }
    else {
        print "The configuration key $key is unset.\n";
    }
    return 0;
}

1;
