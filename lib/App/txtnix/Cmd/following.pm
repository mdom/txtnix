package App::txtnix::Cmd::following;
use Mojo::Base 'App::txtnix';

has 'nick';
has 'url';

sub run {
    my ( $self, $whom, $url ) = @_;
    my %following = %{ $self->following };
    for my $user ( keys %following ) {
        print "$user \@ " . $following{$user} . "\n";
    }
    return 0;
}

1;
