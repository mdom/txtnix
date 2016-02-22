package App::txtnix;

use strict;
use warnings;
use Config::Tiny;
use Path::Tiny;
use Mojo::UserAgent;
use Mojo::ByteStream 'b';
use Moo;
use App::txtnix::Tweet;
use App::txtnix::Cache;
use App::txtnix::Config;
use IO::Pager;
use String::ShellQuote qw(shell_quote);
use Pod::Usage qw(pod2usage);

our $VERSION = '0.01';

has config => ( is => 'ro' );
has ua     => ( is => 'lazy' );
has name   => ( is => 'ro', default => sub { path($0)->basename } );
has cache  => ( is => 'ro', default => sub { App::txtnix::Cache->new() } );

sub _build_ua {
    my $self = shift;
    my $ua   = Mojo::UserAgent->new()->request_timeout( $self->config->timeout )
      ->max_redirects(5);
    my $ua_string = "txtnix/$VERSION";
    if (   $self->config->disclose_identity
        && $self->config->nick
        && $self->config->twturl )
    {
        $ua_string .=
          ' (+' . $self->config->twturl . '; @' . $self->config->nick . ')';
    }
    $ua->transactor->name($ua_string);
    $ua->proxy->detect;
    return $ua;
}

sub BUILDARGS {
    my ( $class, @args ) = @_;
    return { config => App::txtnix::Config->new(@args) };
}

sub run {
    my ( $self, $command ) = splice( @_, 0, 2 );

    $command = "cmd_$command";

    if ( my $method = $self->can($command) ) {
        $self->$method(@_);
    }
    else {
        pod2usage( -exitval => 1, -message => "Unknown command" );
    }
    return 0;

}

sub get_tweets {
    my ( $self, $who ) = @_;
    my @tweets;
    my $following = $self->config->following;
    if ($who) {
        if ( exists $self->config->following->{$who} ) {
            $following = { $who => $self->config->following->{$who} };
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
                        $self->cache->set( $self->config->following->{$user},
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

    $self->config->sync;

    $self->cache->clean if $self->config->use_cache;

    return $self->filter_tweets(@tweets);
}

sub filter_tweets {
    my ( $self, @tweets ) = @_;

    @tweets = grep {
             $_->timestamp >= $self->config->since
          && $_->timestamp <= $self->config->until
    } @tweets;

    @tweets = sort {
            $self->config->sorting eq 'descending'
          ? $b->timestamp <=> $a->timestamp
          : $a->timestamp <=> $b->timestamp
    } @tweets;

    my $limit = $self->config->limit_timeline;
    return @tweets > $limit ? @tweets[ 0 .. $limit - 1 ] : @tweets;
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
            $self->config->following->{$user} = $res->headers->location;
        }
    }
    return;
}

sub parse_twtfile {
    my ( $self, $user, $string ) = @_;
    return map {
        App::txtnix::Tweet->new(
            user      => $user,
            timestamp => $_->[0],
            text      => $_->[1]
          )
      }
      map { [ split /\t/, $_, 2 ] }
      split( /\n/, $string );
}

sub display_tweets {
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
          $tweet->user, $text;
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
    if ( $self->config->nick and $self->config->twturl ) {
        return {
            $self->config->nick => $self->config->twturl,
            %{ $self->config->following }
        };
    }
    return $self->config->following;
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
        if ( $self->config->embed_names ) {
            return "\@<$user " . $known_users->{$user} . ">";
        }
        else {
            return '@<' . $known_users->{$user} . '>';
        }
    }
    return "\@$user";
}

sub cmd_tweet {
    my ( $self, $text ) = @_;
    $text = b($text)->decode;
    $text =~ s/\@(\w+)/$self->expand_mention($1)/ge;
    my $tweet = App::txtnix::Tweet->new( text => $text );
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

sub cmd_timeline {
    my $self   = shift;
    my @tweets = $self->get_tweets();
    $self->display_tweets(@tweets);
}

sub cmd_view {
    my ( $self, $who ) = @_;
    if ( !$who ) {
        die $self->name . ": Missing name for view.\n";
    }
    my @tweets = $self->get_tweets($who);
    $self->display_tweets(@tweets);
}

sub cmd_follow {
    my ( $self, $whom, $url ) = @_;
    if (    $self->config->following->{$whom}
        and $self->config->following->{$whom} eq $url )
    {
        print "You're already following $whom.\n";
        return;
    }
    elsif ( $self->config->following->{$whom} && not $self->config->force ) {
        print "You're already following $whom under a differant url.\n";
    }
    else {
        print "You're now following $whom.\n";
        $self->config->following->{$whom} = $url;
        $self->config->sync;
    }
    return;
}

sub cmd_unfollow {
    my ( $self, $whom ) = @_;
    if ( not $self->config->following->{$whom} ) {
        print "You're not following $whom\n";
    }
    else {
        delete $self->config->following->{$whom};
        $self->config->sync;
        print "You've unfollowed $whom.\n";
    }
    return;
}

sub cmd_following {
    my ( $self, $whom, $url ) = @_;
    my %following = %{ $self->config->following };
    for my $user ( keys %following ) {
        print "$user \@ " . $following{$user} . "\n";
    }
    return;
}

sub cmd_config {
    my ( $self, $command, @args ) = @_;

    pod2usage(2) if !$command;

    $command = "cmd_config_$command";
    if ( $self->can($command) ) {
        $self->$command(@args);
    }
    else {
        pod2usage(2);
    }
    return;
}

sub cmd_config_edit {
    my $self = shift;
    my $editor = $ENV{VISUAL} || $ENV{EDITOR} || 'vi';
    system( $editor, $self->config->config_file ) == 0
      or die "Can't edit configuration file: $!\n";
    return;
}

sub cmd_config_get {
    my ( $self, $key ) = @_;

    pod2usage(2) if !$key;

    my $config = $self->config->read_file;
    if ( exists $config->{twtxt}->{$key} ) {
        print $config->{twtxt}->{$key} . "\n";
    }
    else {
        warn "Configuration key $key unset.\n";
    }
    return;
}

sub cmd_config_set {
    my ( $self, $key, $value ) = @_;

    pod2usage(2) if !$key || !defined $value;

    my $config = $self->config->read_file;
    $config->{twtxt}->{$key} = $value;
    $self->config->write_file($config);
    return;
}

sub cmd_config_remove {
    my ( $self, $key ) = @_;

    pod2usage(2) if !$key;

    my $config = $self->config->read_file;
    delete $config->{twtxt}->{$key};
    $self->config->write_file($config);
    return;
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
