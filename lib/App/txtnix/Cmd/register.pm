package App::txtnix::Cmd::register;
use Mojo::Base 'App::txtnix';

sub run {
    my ($self) = @_;
    die "The options twturl, nick and registry needs to be set to register.\n"
      if !$self->registry || !$self->nick || !$self->twturl;

    my $registry =
      App::txtnix::Registry->new( url => $self->registry, ua => $self->ua );

    if ( $registry->register_user( $self->twturl, $self->nick ) ) {
        print "You've registered at " . $self->registry . ".\n";
        return 0;
    }
    return 1;
}

1;
