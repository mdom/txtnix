package App::txtnix::Source;
use Mojo::Base -base;

has [qw(nick url file)];

sub to_string {
    my $self = shift;
    return $self->nick || $self->url || $self->file;
}

1;
