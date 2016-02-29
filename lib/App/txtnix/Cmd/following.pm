package App::txtnix::Cmd::following;
use Mojo::Base 'App::txtnix';


sub run {
    my ($self)    = @_;
    my %following = %{ $self->following };
    for my $user ( keys %following ) {
        print "$user \@ " . $following{$user} . "\n";
    }
    return 0;
}

1;
