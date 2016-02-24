package App::txtnix::Cmd::config::edit;
use Moo;
extends 'App::txtnix';

sub run {
    my ( $self, $opts ) = @_;
    my $editor = $ENV{VISUAL} || $ENV{EDITOR} || 'vi';
    system( $editor, $self->config ) == 0
      or die "Can't edit configuration file: $!\n";
    return 0;
}

1;
