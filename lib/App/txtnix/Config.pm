package App::txtnix::Config;
use strict;
use warnings;
use Moo;
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
has file              => ( is => 'rw' );

sub BUILDARGS {
    my ( $class, @args ) = @_;
    my $args = ref $args[0] ? $args[0] : {@args};
    my $config_file = path( $args->{config_file} || '~/.config/twtxt/config' );

    my $cli = {};
    GetOptionsFromArray(
        \@ARGV,
        'help|h'        => sub { pod2usage(1) },
        'cache!'        => sub { $cli->{use_cache} = $_[1]; },
        'pager!'        => sub { $cli->{use_pager} = $_[1]; },
        'new'           => sub { $cli->{limit_to_new} = $_[1]; },
        'rewrite-urls!' => sub { $cli->{rewrite_urls} = $_[1]; },
        'ascending'     => sub { $cli->{sorting} = "$_[0]"; },
        'descending'    => sub { $cli->{sorting} = "$_[0]"; },
        'sorting=s'     => sub { $cli->{sorting} = $_[1]; },
        'timeout=i'     => sub { $cli->{timeout} = $_[1]; },
        'twtfile|f=s'   => sub { $cli->{twtfile} = $_[1]; },
        'twturl=s'      => sub { $cli->{twturl} = $_[1]; },
        'nick=s'        => sub { $cli->{nick} = $_[1]; },
        'limit|l=i'     => sub { $cli->{limit_timeline} = $_[1]; },
        'time-format=s' => sub { $cli->{time_format} = $_[1]; },
        'config|c=s' => sub {
            $config_file = path( $_[1] );
            die "Configuration file $_[1] does not exists\n"
              unless $config_file->exists;
        }
    ) or pod2usage(2);

    $args->{file} = $config_file;

    if ( $config_file->exists ) {
        my $config = Config::Tiny->read( "$config_file", 'utf8' );
        die "Could not read configuration file: " . $config->errstr . "\n"
          if $config->errstr;
        if ( $config->{twtxt} ) {
            $args = { %{ $config->{twtxt} }, %$args };
        }
        if ( $config->{following} ) {
            $args->{users} = $config->{following};
        }
    }

    return { %$args, %$cli };
}

sub sync {
    my ($self) = @_;
    if ( !$self->file->exists ) {
        $self->file->parent->mkpath;
        $self->file->touch;
    }
    my $config = Config::Tiny->read( $self->file->stringify, 'utf8' );
    die "Could not read configuration file: " . $config->errstr . "\n"
      if $config->errstr;
    $config->{following} = $self->users;
    $config->write( $self->file, 'utf8' );
    return;
}

1;
