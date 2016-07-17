package App::txtnix::Cmd::following;
use Mojo::Base 'App::txtnix';

has 'nickname';

sub run {
    my ($self)    = @_;
    my %following = %{ $self->following };
    my $nick      = $self->nickname;
    if ($nick) {
        if ( $following{$nick} ) {
            print $self->nickname . ' @ '
              . $following{ $self->nickname } . "\n";
        }
    }
    else {
        for my $user ( sort keys %following ) {
            print "$user \@ " . $following{$user} . "\n";
        }
    }
    return 0;
}

1;
