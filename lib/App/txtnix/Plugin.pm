package App::txtnix::Plugin;
use strict;
use warnings;
use Mojo::Base -base;

has 'app';
has handlers => sub { {} };
has config   => sub { shift->_build_config };
has name     => sub { my ($name) = ref( $_[0] ) =~ /^.*::(.*)$/; return $name };

sub _build_config {
    my $self = shift;
    my ($name) = ref($self) =~ /^.*::(.*)$/;
    return $self->app->read_config->{$name} || {};
}

sub is_enabled {
    my $self   = shift;
    my $config = $self->config;

    return 1 if $self->name eq 'ShellExec';
    return defined $self->config && $self->config->{enabled};
}

1;
