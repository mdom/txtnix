package App::txtnix;

use strict;
use warnings;
use 5.14.0;
use Config::Tiny;
use Path::Tiny;
use HTTP::Date;
use Mojo::UserAgent;
use Moo;
use App::txtnix::Tweet;
use App::txtnix::Cache;
use IO::Pager;
use Mojo::ByteStream 'b';

our $VERSION = '0.01';

has ua => ( is => 'lazy' );
has cache => ( is => 'ro', default => sub { App::txtnix::Cache->new() } );

has twtfile => (
    is      => 'rw',
    default => sub { path('~/twtxt') },
    coerce  => sub { ref $_[0] ? $_[0] : path( $_[0] ) }
);

has pager             => ( is => 'rw', default => sub { 1 } );
has sorting           => ( is => 'rw', default => sub { 'descending' } );
has timeout           => ( is => 'rw', default => sub { 5 } );
has use_cache         => ( is => 'rw', default => sub { 1 } );
has limit             => ( is => 'rw', default => sub { 20 } );
has time_format       => ( is => 'rw', default => sub { '%F %H:%M' } );
has disclose_identity => ( is => 'rw', default => sub { 0 } );
has rewrite_urls      => ( is => 'rw', default => sub { 1 } );
has embed_names       => ( is => 'rw', default => sub { 1 } );
has check_following   => ( is => 'rw', default => sub { 1 } );
has following         => ( is => 'rw', default => sub { {} } );
has nick              => ( is => 'rw' );
has twturl            => ( is => 'rw' );
has pre_tweet_hook    => ( is => 'rw' );
has post_tweet_hook   => ( is => 'rw' );
has config            => ( is => 'rw' );
has force             => ( is => 'rw' );
has since => ( is => 'rw', default => sub { 0 }, coerce => \&to_epoch );
has until => ( is => 'rw', default => sub { time }, coerce => \&to_epoch );

sub BUILDARGS {
    my ( $class, @args ) = @_;
    my $args = ref $args[0] ? $args[0] : {@args};
    $args->{use_cache} = delete $args->{cache};
    $args->{config} =
      path( $args->{config} || '~/.config/twtxt/config' );

    if ( $args->{config}->exists ) {
        my $config = $class->read_file( $args->{config} );
        if ( $config->{twtxt} ) {
            $args = { %{ $config->{twtxt} }, %$args };
        }
        if ( $config->{following} ) {
            $args->{following} = $config->{following};
        }
    }
    return $args;
}

sub _build_ua {
    my $self = shift;
    my $ua   = Mojo::UserAgent->new()->request_timeout( $self->timeout )
      ->max_redirects(5);
    my $ua_string = "txtnix/$VERSION";
    if (   $self->disclose_identity
        && $self->nick
        && $self->twturl )
    {
        $ua_string .= ' (+' . $self->twturl . '; @' . $self->nick . ')';
    }
    $ua->transactor->name($ua_string);
    $ua->proxy->detect;
    return $ua;
}

sub write_file {
    my ( $self, $config ) = @_;
    $config->write( $self->config, 'utf8' );
    return;
}

sub read_file {
    my ( $self, $file ) = @_;
    my $config =
      Config::Tiny->read( $file || $self->config->stringify, 'utf8' );
    die "Could not read configuration file: " . $config->errstr . "\n"
      if $config->errstr;
    return $config;
}

sub to_epoch {
    return $_[0] =~ /[^\d]/ ? str2time( $_[0] ) : $_[0];
}

sub sync {
    my ($self) = @_;
    if ( !$self->config->exists ) {
        $self->config->parent->mkpath;
        $self->config->touch;
    }
    my $config = $self->read_file;
    $config->{following} = $self->following;
    $self->write_file($config);
    return;
}

sub get_tweets {
    my ( $self, $who ) = @_;
    my @tweets;
    my $following = $self->following;
    if ($who) {
        if ( exists $self->following->{$who} ) {
            $following = { $who => $self->following->{$who} };
        }
        else {
            return;
        }
    }
    Mojo::IOLoop->delay(
        sub {
            my $delay = shift;
            while ( my ( $user, $url ) = each %{$following} ) {
                my ( $cache, $params );
                if ( $self->use_cache ) {
                    $cache = $self->cache->get($url);
                    if ($cache) {
                        $params =
                          { "If-Modified-Since" => $cache->{last_modified} };
                    }
                }
                $delay->pass( $user, $cache );
                $self->ua->get( $url => $params => $delay->begin );
            }
        },
        sub {
            my ( $delay, @results ) = @_;
            while ( my ( $user, $cache, $tx ) = splice( @results, 0, 3 ) ) {

                if ( my $res = $tx->success ) {

                    $self->check_for_moved_url( $tx, $user );

                    my $body = $res->body;
                    if ( $res->code == 304 && $cache ) {
                        $body = $cache->{body};
                    }

                    if ( !$body ) {
                        warn "No $body for $user. Ignoring\n";
                        next;
                    }

                    if (   $self->use_cache
                        && $res->code == 200
                        && $res->headers->last_modified )
                    {
                        $self->cache->set( $self->following->{$user},
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

    if ( not defined $who and $self->twtfile->exists ) {
        push @tweets,
          $self->parse_twtfile( $self->nick || $ENV{USER},
            $self->twtfile->slurp_utf8 );
    }

    $self->sync;

    $self->cache->clean if $self->use_cache;

    return $self->filter_tweets(@tweets);
}

sub filter_tweets {
    my ( $self, @tweets ) = @_;

    @tweets =
      grep { $_->timestamp >= $self->since && $_->timestamp <= $self->until }
      @tweets;

    @tweets = sort {
            $self->sorting eq 'descending'
          ? $b->timestamp <=> $a->timestamp
          : $a->timestamp <=> $b->timestamp
    } @tweets;

    my $limit = $self->limit;
    return @tweets > $limit ? @tweets[ 0 .. $limit - 1 ] : @tweets;
}

sub check_for_moved_url {
    my ( $self, $tx, $user ) = @_;
    my $redirect = $tx->redirects->[0];
    if ( $redirect && $self->rewrite_urls ) {
        my $res = $redirect->res;
        if ( $res->code == 301 && $res->headers->location ) {
            warn 'Rewrite url from '
              . $redirect->req->url . ' to '
              . $res->headers->location
              . " after 301.\n";
            $self->following->{$user} = $res->headers->location;
        }
    }
    return;
}

sub parse_twtfile {
    my ( $self, $user, $string ) = @_;
    my @tweets;
    for my $line ( split( /\n/, $string ) ) {
        my ( $time, $text ) = split( /\t/, $line, 2 );
        next if not defined $text;
        $text = b($text)->decode;
        $text =~ s/\P{XPosixPrint}//g;
        if ( $time and $text ) {
            push @tweets,
              App::txtnix::Tweet->new(
                user      => $user,
                timestamp => $time,
                text      => $text,
              );
        }
    }
    return @tweets;
}

sub display_tweets {
    my ( $self, @tweets ) = @_;
    my $fh;
    if ( $self->pager ) {
        IO::Pager->new($fh);
    }
    else {
        $fh = \*STDOUT;
    }
    for my $tweet (@tweets) {
        my $text = $tweet->text;
        $text = $self->collapse_mentions($text);
        printf {$fh} "%s %s: %s\n",
          $tweet->strftime( $self->time_format ),
          $tweet->user, b($text)->encode;
    }
    return;
}

sub collapse_mentions {
    my ( $self, $text ) = @_;
    $text =~ s/\@<(?:(\w+) )?([^>]+)>/$self->collapse_mention($1,$2)/ge;
    return $text;
}

sub collapse_mention {
    my ( $self, $user, $url ) = @_;
    my $known_users = $self->known_users;
    my %urls = map { $known_users->{$_} => $_ } keys %{$known_users};
    if ( $urls{$url} ) {
        return "\@$urls{$url}";
    }
    else {
        return "\@<$user $url>";
    }
}

sub known_users {
    my $self = shift;
    if ( $self->nick and $self->twturl ) {
        return {
            $self->nick => $self->twturl,
            %{ $self->following }
        };
    }
    return $self->following;
}

sub expand_mentions {
    my ( $self, $text ) = @_;
    $text =~ s/\@(\w+)/$self->expand_mention($1)/ge;
    return $text;
}

sub expand_mention {
    my ( $self, $user ) = @_;
    my $known_users = $self->known_users;
    if ( $known_users->{$user} ) {
        if ( $self->embed_names ) {
            return "\@<$user " . $known_users->{$user} . ">";
        }
        else {
            return '@<' . $known_users->{$user} . '>';
        }
    }
    return "\@$user";
}

1;

__END__

=pod

=head1 NAME

txtnix - Client for txtwt, the minimalist microblogging service for hackers

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
