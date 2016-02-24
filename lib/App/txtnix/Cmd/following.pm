package App::txtnix::Cmd::following;
use Moo;
extends 'App::txtnix';

has 'nick' => ( is => 'rw' );
has 'url'  => ( is => 'rw' );

sub run {
    my ( $self, $whom, $url ) = @_;
    my %following = %{ $self->following };
    for my $user ( keys %following ) {
        print "$user \@ " . $following{$user} . "\n";
    }
    return 0;
}

1;
