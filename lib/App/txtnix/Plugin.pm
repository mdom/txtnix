package App::txtnix::Plugin;
use strict;
use warnings;
use Mojo::Base -base;

has 'app';
has config => sub { shift->_build_config };
has name => sub { my ($name) = ref( $_[0] ) =~ /^.*::(.*)$/; return $name };

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

=head1 NAME

App::txtnix::Plugin - txtnix plugin base class

=head1 SYNOPSIS

  package App::txtnix::Plugin::Foo;
  use Mojo::Base 'App::txtnix::Plugin';

  sub post_tweet {
    my ( $self, $event, @tweets) = @_;
    warn $self->app->twtfile . "\n";
  }

  1;

=head1 EVENTS

Plugins can provide functions that are called when events happen in I<txtnix>.
There are currently six events:

=over 4

=item pre_tweet

Is called with one argument, the name of the event.

=item post_tweet

Is called with two arguments, the name of the event and an array of
App::txtnix::Tweet object.

=item pre_follow

Is called with one argument, the name of the event.

=item post_follow

Is called with one argument, the name of the event.

=item pre_unfollow

Is called with one argument, the name of the event.

=item post_unfollow

Is called with one argument, the name of the event.

=back

Your plugin has to be a subclass of I<App::txtnix::Plugin> and define at least
a subroutine named after one of the events. See the above list for a list of
arguments that are provided.

=head1 ATTRIBUTES

App::txtnix::Plugin implements the following attributes.

=over 4

=item app

The I<App::txtnix> object that called the plugin.

=item config

A hash reference with the plugin configuration from the configuration
file.

=item name

The basename of the plugin. This defaults to the package name without
the leading I<App::txtnix::Plugin>.

=back

=head1 METHODS

App::txtnix::Plugin implements the following methods:

=over 4

=item is_enabled

Returns true if the plugin has been enabled in the configuration file.

=back
