package App::twtxtpl;

use strict;
use warnings;
use Getopt::Long qw(GetOptionsFromArray);
use Config::Tiny;
use Path::Tiny;
use Mojo::UserAgent;
use Moo;
use App::twtxtpl::Tweet;
use App::twtxtpl::Cache;
use IO::Pager;
use String::ShellQuote;
use File::Basename qw(basename);

our $VERSION = '0.01';

has name => ( is => 'ro', default => sub { basename $0 } );
has config => ( is => 'lazy' );
has config_file =>
  ( is => 'ro', default => sub { path('~/.config/twtxt/config') } );
has ua => ( is => 'lazy' );
has cache => ( is => 'ro', default => sub { App::twtxtpl::Cache->new() } );

sub _build_ua {
    my $self = shift;
    return Mojo::UserAgent->new()
      ->request_timeout( $self->config->{twtxt}->{timeout} )->max_redirects(5);
}

sub _build_config {
    my ($self) = @_;
    unless ( $self->config_file->exists ) {
        $self->config_file->parent->mkpath;
        $self->config_file->touch;
    }
    my $config   = Config::Tiny->read( $self->config_file->stringify );
    my %defaults = (
        check_following   => 1,
        use_pager         => 1,
        use_cache         => 1,
        disclose_identity => 0,
        limit_timeline    => 20,
        timeout           => 5,
        sorting           => 'descending',
        time_format       => '%F %H:%M',
        twtfile           => path('~/twtxt'),
    );
    $config->{twtxt} = { %defaults, %{ $config->{twtxt} || {} } };
    return $config;
}

sub run {
    my ( $self, $subcommand ) = splice( @_, 0, 2 );
    my %subcommands =
      map { $_ => 1 } qw(timeline follow unfollow following tweet view );
    if ( $subcommands{$subcommand} and $self->can($subcommand) ) {
        $self->$subcommand(@_);
    }
    else {
        die $self->name . ": Unknown subcommand $subcommand.\n";
    }
    return 0;

}

sub url_for_user {
    my ( $self, $user ) = @_;
    return $self->config->{following}->{$user};
}

sub _get_tweets {
    my ( $self, $who ) = @_;
    my @tweets;
    my $following = $self->config->{following};
    if ($who) {
        if ( exists $self->config->{following}->{$who} ) {
            $following = { $who => $self->config->{following}->{$who} };
        }
        else {
            return;
        }
    }
    Mojo::IOLoop->delay(
        sub {
            my $delay = shift;
            while ( my ( $user, $url ) = each %{$following} ) {
                my $cache = $self->cache->get($url);
                $delay->pass( $user, $cache );
                my $params =
                  $cache
                  ? { "If-Modified-Since" => $cache->{last_modified} }
                  : {};
                $self->ua->get( $url => $params => $delay->begin );
            }
        },
        sub {
            my ( $delay, @results ) = @_;
            while ( my ( $user, $cache, $tx ) = splice( @results, 0, 3 ) ) {

                if ( my $res = $tx->success ) {
                    my $body = $res->code == 304 ? $cache->{body} : $res->body;
                    if ( $res->code != 304 and $res->headers->last_modified ) {
                        $self->cache->set( $self->url_for_user($user),
                            $res->headers->last_modified, $body );
                    }
                    push @tweets, $self->parse_twtfile( $user, $body );
                }
                else {
                    my $err = $tx->error;
                    warn "Failing to get tweets for $user: "
                      . (
                        $err->{code}
                        ? "$err->{code} response: $err->{message}"
                        : "Connection error: $err->{message}"
                      ) . "\n";

                }
            }
        }
    )->wait;
    @tweets = sort {
            $self->config->{twtxt}->{sorting} eq 'descending'
          ? $b->timestamp <=> $a->timestamp
          : $a->timestamp <=> $b->timestamp
    } @tweets;
    my $limit = $self->config->{twtxt}->{limit_timeline} - 1;
    return @tweets[ 0 .. $limit ];
}

sub parse_twtfile {
    my ( $self, $user, $string ) = @_;
    return map {
        App::twtxtpl::Tweet->new(
            user      => $user,
            timestamp => $_->[0],
            text      => $_->[1]
          )
      }
      map { [ split /\t/, $_, 2 ] }
      split( /\n/, $string );
}

sub _display_tweets {
    my ( $self, @tweets ) = @_;
    my $fh;
    if ( $self->config->{twtxt}->{use_pager} ) {
        IO::Pager->new($fh);
    }
    else {
        $fh = \*STDOUT;
    }
    for my $tweet (@tweets) {
        printf {$fh} "%s %s: %s\n",
          $tweet->strftime( $self->config->{twtxt}->{time_format} ),
          $tweet->user, $tweet->text;
    }
    return;
}

sub tweet {
    my ( $self, $text ) = @_;
    my $tweet = App::twtxtpl::Tweet->new( text => $text );
    my $file = path( $self->config->{twtxt}->{twtfile} );
    $file->touch unless $file->exists;
    $file->append_utf8( $tweet->to_string . "\n" );
    return;
}

sub timeline {
    my $self   = shift;
    my @tweets = $self->_get_tweets();
    $self->_display_tweets(@tweets);
}

sub view {
    my ( $self, $who ) = @_;
    if ( !$who ) {
        die $self->name . ": Missing name for view.\n";
    }
    my @tweets = $self->_get_tweets($who);
    $self->_display_tweets(@tweets);
}

sub follow {
    my ( $self, $whom, $url ) = @_;
    $self->config->{following}->{$whom} = $url;
    $self->config->write( $self->config_file, 'utf8' );
    return;
}

sub unfollow {
    my ( $self, $whom, $url ) = @_;
    delete $self->config->{following}->{$whom};
    $self->config->write( $self->config_file, 'utf8' );
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

__END__

=pod

=head1 NAME

twtxtpl - Decentralised, minimalist microblogging service for hackers

=head1 COPYRIGHT AND LICENSE

Copyright 2015 Mario Domgoergen C<< <mario@domgoergen.com> >>

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program.  If not, see <http://www.gnu.org/licenses/>.
