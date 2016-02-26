package App::txtnix::Cmd::config::get;
use Mojo::Base 'App::txtnix';

has 'key';

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
