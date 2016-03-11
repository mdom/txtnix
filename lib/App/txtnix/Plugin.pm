package App::txtnix::Plugin;
use strict;
use warnings;
use Mojo::Base -base;

has 'app';
has handlers => sub { {} };

sub register {
    my $self = shift;
    for my $key ( keys %{ $self->handlers } ) {
        $self->app->on( $key => $self->handlers->{$key} );
    }
    return;
}

1;
