package App::txtwat;

use strict;
use warnings;
use Config::Tiny;
use Path::Tiny;
use Mojo::UserAgent;
use Mojo::ByteStream 'b';
use Moo;
use App::txtwat::Tweet;
use App::txtwat::Cache;
use App::txtwat::Config;
use IO::Pager;
use String::ShellQuote qw(shell_quote);
use File::Basename qw(basename);
use Pod::Usage qw(pod2usage);
use Scalar::Util qw( refaddr );

my %commands;

sub MODIFY_CODE_ATTRIBUTES {
    my ( $package, $addr, @attrs ) = @_;
    my %attrs = map { $_ => 1 } @attrs;
    $commands{ refaddr $_[1] } = 1 if $attrs{Command};
    return;
}

our $VERSION = '0.01';

has config => ( is => 'ro' );
has ua     => ( is => 'lazy' );
has name   => ( is => 'ro', default => sub { basename $0 } );
has cache  => ( is => 'ro', default => sub { App::txtwat::Cache->new() } );

sub _build_ua {
    my $self = shift;
    my $ua   = Mojo::UserAgent->new()->request_timeout( $self->config->timeout )
      ->max_redirects(5);
    my $ua_string = "txtwat/$VERSION";
    if (   $self->config->disclose_identity
        && $self->config->nick
        && $self->config->twturl )
    {
        $ua_string .=
          ' (+' . $self->config->twturl . '; @' . $self->config->nick . ')';
    }
    $ua->transactor->name($ua_string);
    return $ua;
}

sub BUILDARGS {
    my ( $class, @args ) = @_;
    my $args = ref $args[0] ? $args[0] : {@args};
    return { config => App::txtwat::Config->new($args) };
}

sub run {
    my ( $self, $subcommand ) = splice( @_, 0, 2 );

    my $method = $self->can($subcommand);
    if ( $method && $commands{ refaddr $method} ) {
        $self->$method(@_);
    }
    else {
        pod2usage( -exitval => 1, -message => "Unknown command" );
    }
    return 0;

}

sub _get_tweets {
    my ( $self, $who ) = @_;
    my @tweets;
    my $following = $self->config->users;
    if ($who) {
        if ( exists $self->config->users->{$who} ) {
            $following = { $who => $self->config->users->{$who} };
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
                if ( $self->config->use_cache ) {
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

                    if (   $self->config->use_cache
                        && $res->code == 200
                        && $res->headers->last_modified )
                    {
                        $self->cache->set( $self->config->users->{$user},
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

    if ( $self->config->twtfile->exists ) {
        push @tweets,
          $self->parse_twtfile(
            $self->config->nick || $ENV{USER},
            $self->config->twtfile->slurp_utf8
          );
    }

    $self->cache->clean if $self->config->use_cache;

    @tweets = sort {
            $self->config->sorting eq 'descending'
          ? $b->timestamp <=> $a->timestamp
          : $a->timestamp <=> $b->timestamp
    } @tweets;
    my $limit = $self->config->limit_timeline - 1;
    return @tweets[ 0 .. $limit ];
}

sub check_for_moved_url {
    my ( $self, $tx, $user ) = @_;
    my $redirect = $tx->redirects->[0];
    if ( $redirect && $self->config->rewrite_urls ) {
        my $res = $redirect->res;
        if ( $res->code == 301 && $res->headers->location ) {
            warn 'Rewrite url from '
              . $redirect->req->url . ' to '
              . $res->headers->location
              . " after 301.\n";
            $self->config->users->{$user} = $res->headers->location;
            $self->config->sync;
        }
    }
    return;
}

sub parse_twtfile {
    my ( $self, $user, $string ) = @_;
    return map {
        App::txtwat::Tweet->new(
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
    if ( $self->config->use_pager ) {
        IO::Pager->new($fh);
    }
    else {
        $fh = \*STDOUT;
    }
    for my $tweet (@tweets) {
        my $text = $tweet->text;
        $text = $self->collapse_mentions($text);
        printf {$fh} "%s %s: %s\n",
          $tweet->strftime( $self->config->time_format ),
          $tweet->user, $tweet->text;
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
    my %urls =
      map { $self->config->users->{$_} => $_ } keys %{ $self->config->users };
    if ( $urls{$url} ) {
        return "\@$urls{$url}";
    }
    else {
        return "\@<$user $url>";
    }
}

sub expand_mentions {
    my ( $self, $text ) = @_;
    $text =~ s/\@(\w+)/$self->expand_mention($1)/ge;
    return $text;
}

sub expand_mention {
    my ( $self, $user ) = @_;
    if ( $self->config->users->{$user} ) {
        if ( $self->config->embed_names ) {
            return "\@<$user " . $self->config->users->{$user} . ">";
        }
        else {
            return '@<' . $self->config->users->{$user} . '>';
        }
    }
    return "\@$user";
}

sub tweet : Command {
    my ( $self, $text ) = @_;
    $text = b($text)->decode;
    $text =~ s/\@(\w+)/$self->expand_mention($1)/ge;
    my $tweet = App::txtwat::Tweet->new( text => $text );
    my $file = path( $self->config->twtfile );
    $file->touch unless $file->exists;

    my $pre_hook  = $self->config->pre_tweet_hook;
    my $post_hook = $self->config->post_tweet_hook;
    my $twtfile   = shell_quote( $self->config->twtfile );
    if ($pre_hook) {
        $pre_hook =~ s/\Q{twtfile}/$twtfile/ge;
        system($pre_hook) == 0 or die "Can't call pre_tweet_hook $pre_hook.\n";
    }
    $file->append_utf8( $tweet->to_string . "\n" );
    if ($post_hook) {
        $post_hook =~ s/\Q{twtfile}/$twtfile/ge;
        system($post_hook) == 0
          or die "Can't call post_tweet_hook $post_hook.\n";
    }
    return;
}

sub timeline : Command {
    my $self   = shift;
    my @tweets = $self->_get_tweets();
    $self->_display_tweets(@tweets);
}

sub view : Command {
    my ( $self, $who ) = @_;
    if ( !$who ) {
        die $self->name . ": Missing name for view.\n";
    }
    my @tweets = $self->_get_tweets($who);
    $self->_display_tweets(@tweets);
}

sub follow : Command {
    my ( $self, $whom, $url ) = @_;
    $self->config->users->{$whom} = $url;
    $self->config->sync;
    return;
}

sub unfollow : Command {
    my ( $self, $whom ) = @_;
    if ( not $self->config->users->{$whom} ) {
        print "You're not following $whom\n";
    }
    else {
        delete $self->config->users->{$whom};
        $self->config->sync;
        print "You've unfollowed $whom.\n";
    }
    return;
}

sub following : Command {
    my ( $self, $whom, $url ) = @_;
    my %following = %{ $self->config->users };
    for my $user ( keys %following ) {
        print "$user \@ " . $following{$user} . "\n";
    }
    return;
}

1;

__END__

=pod

=head1 NAME

txtwat - Client for txtwt, the minimalist microblogging service for hackers

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
