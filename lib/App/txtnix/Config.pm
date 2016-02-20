package App::txtnix::Config;
use strict;
use warnings;
use Moo;
use HTTP::Date;
use Path::Tiny;
use Pod::Usage qw(pod2usage);
use Getopt::Long qw(GetOptionsFromArray);

has twtfile => (
    is      => 'rw',
    default => sub { path('~/twtxt') },
    coerce  => sub { ref $_[0] ? $_[0] : path( $_[0] ) }
);

has use_pager         => ( is => 'rw', default => sub { 1 } );
has sorting           => ( is => 'rw', default => sub { 'descending' } );
has timeout           => ( is => 'rw', default => sub { 5 } );
has use_cache         => ( is => 'rw', default => sub { 1 } );
has limit_timeline    => ( is => 'rw', default => sub { 20 } );
has time_format       => ( is => 'rw', default => sub { '%F %H:%M' } );
has disclose_identity => ( is => 'rw', default => sub { 0 } );
has rewrite_urls      => ( is => 'rw', default => sub { 1 } );
has embed_names       => ( is => 'rw', default => sub { 1 } );
has check_following   => ( is => 'rw', default => sub { 1 } );
has users             => ( is => 'rw', default => sub { {} } );
has nick              => ( is => 'rw' );
has twturl            => ( is => 'rw' );
has pre_tweet_hook    => ( is => 'rw' );
has post_tweet_hook   => ( is => 'rw' );
has config_file       => ( is => 'rw' );
has since => ( is => 'rw', default => sub { 0 }, coerce => \&to_epoch );
has until => ( is => 'rw', default => sub { time }, coerce => \&to_epoch );

sub BUILDARGS {
    my ( $class, @args ) = @_;
    my $args = ref $args[0] ? $args[0] : {@args};
    $args->{config_file} =
      path( $args->{config_file} || '~/.config/twtxt/config' );

    GetOptionsFromArray(
        \@ARGV,
        'help|h'        => sub { pod2usage(1) },
        'cache!'        => sub { $args->{use_cache} = $_[1]; },
        'pager!'        => sub { $args->{use_pager} = $_[1]; },
        'new'           => sub { $args->{limit_to_new} = $_[1]; },
        'rewrite-urls!' => sub { $args->{rewrite_urls} = $_[1]; },
        'ascending'     => sub { $args->{sorting} = "$_[0]"; },
        'descending'    => sub { $args->{sorting} = "$_[0]"; },
        'sorting=s'     => sub { $args->{sorting} = $_[1]; },
        'timeout=i'     => sub { $args->{timeout} = $_[1]; },
        'twtfile|f=s'   => sub { $args->{twtfile} = $_[1]; },
        'twturl=s'      => sub { $args->{twturl} = $_[1]; },
        'nick=s'        => sub { $args->{nick} = $_[1]; },
        'since=s'       => sub { $args->{since} = $_[1]; },
        'until=s'       => sub { $args->{until} = $_[1]; },
        'limit|l=i'     => sub { $args->{limit_timeline} = $_[1]; },
        'time-format=s' => sub { $args->{time_format} = $_[1]; },
        'config|c=s' => sub {
            $args->{config_file} = path( $_[1] );
            die "Configuration file $_[1] does not exists\n"
              unless $args->{config_file}->exists;
        }
    ) or pod2usage(2);

    if ( $args->{config_file}->exists ) {
        my $config =
          Config::Tiny->read( $args->{config_file}->stringify, 'utf8' );
        die "Could not read configuration file: " . $config->errstr . "\n"
          if $config->errstr;
        if ( $config->{twtxt} ) {
            $args = { %{ $config->{twtxt} }, %$args };
        }
        if ( $config->{following} ) {
            $args->{users} = $config->{following};
        }
    }

    return $args;
}

sub to_epoch {
    return $_[0] =~ /[^\d]/ ? str2time( $_[0] ) : $_[0];
}

sub sync {
    my ($self) = @_;
    if ( !$self->config_file->exists ) {
        $self->config_file->parent->mkpath;
        $self->config_file->touch;
    }
    my $config = Config::Tiny->read( $self->config_file->stringify, 'utf8' );
    die "Could not read configuration file: " . $config->errstr . "\n"
      if $config->errstr;
    $config->{following} = $self->users;
    $config->write( $self->config_file, 'utf8' );
    return;
}

1;
