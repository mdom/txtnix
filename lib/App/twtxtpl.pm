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
    my $config = Config::Tiny->read( $self->config_file->stringify );
    my %defaults = (
	    check_following => 1,
	    use_pager => 1,
	    use_cache => 1,
	    disclose_identity => 0,
	    limit_timeline => 20,
	    timeout => 5,
	    sorting => 'descending',
    );
    $config->{twtxt} = { %defaults, %{ $config->{twtxt}||{} } };
    return $config;
}

sub run {
    my ( $self, $subcommand ) = splice( @_, 0, 2 );
    if ( $self->can($subcommand) ) {
        $self->$subcommand(@_);
    }
    $self->config->write( $self->config_file, 'utf8' );
    return 0;

}

sub timeline {
    my $self = shift;
    my $ua   = Mojo::UserAgent->new();
    my @tweets;
    Mojo::IOLoop->delay(
        sub {
            my $delay = shift;
	    while ( my ($user, $url) = each %{ $self->config->{following} } ) {
		$delay->pass($user);
                $ua->get( $url => $delay->begin );
            }
        },
        sub {
            my ( $delay, @results ) = @_;
            while ( my ($user, $tx ) = splice(@results,0,2) ) {
                push @tweets,
                  map {
                    App::twtxtpl::Tweet->new(
		        user      => $user,
                        timestamp => $_->[0],
                        text      => $_->[1]
                      )
                  }
                  map { [ split /\t/, $_, 2 ] }
                  split( /\n/, $tx->res->body );
            }
        }
    )->wait;
    @tweets = sort { $a->timestamp cmp $b->timestamp } @tweets;
    for my $tweet (@tweets) {
	    printf "%s %s: %s\n", $tweet->timestamp, $tweet->user, $tweet->text;
    }
}

sub follow {
    my ( $self, $whom, $url ) = @_;
    $self->config->{following}->{$whom} = $url;
    return;
}

sub unfollow {
    my ( $self, $whom, $url ) = @_;
    delete $self->config->{following}->{$whom};
    print "You've unfollowed $whom.\n";
    return;
}

sub following {
    my ( $self, $whom, $url ) = @_;
    for my $user ( keys %{ $self->config->{following} } ) {
        print "$user \@ " . $self->config->{following}->{$user} . "\n";
    }
    return;
}

1;
