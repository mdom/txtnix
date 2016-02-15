package App::twtxtpl;

use strict;
use warnings;
use Getopt::Long qw(GetOptionsFromArray);
use Config::Tiny;
use Path::Tiny;
use Mojo::UserAgent;
use Moo;
use App::twtxtpl::Tweet;

has config => ( is => 'lazy' );
has config_file =>
  ( is => 'ro', default => sub { path('~/.config/twtxt/config') } );

sub _build_config {
    my ($self) = @_;
    unless ( $self->config_file->exists ) {
        $self->config_file->parent->mkpath;
        $self->config_file->touch;
    }
    return Config::Tiny->read( $self->config_file->stringify );
}

sub run {
    my ( $self, $subcommand ) = splice( @_, 0, 2 );
    no strict 'refs';
    if ( defined &{$subcommand} ) {
        $self->$subcommand(@_);
    }
    $self->config->write( $self->config_file, 'utf8' );
    return 0;

}

sub follow {
    my ( $self, $whom, $url ) = @_;
    $self->config->{following}->{$whom} = $url;
    return;
}

1;
