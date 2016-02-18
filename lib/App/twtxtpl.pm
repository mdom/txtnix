package App::twtxtpl;

use strict;
use warnings;
use Getopt::Long qw(GetOptionsFromArray);
use Config::Tiny;
use Path::Tiny;
use Mojo::UserAgent;
use Mojo::ByteStream 'b';
use Moo;
use App::twtxtpl::Tweet;
use App::twtxtpl::Cache;
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

has config_file => ( is => 'ro' );
has ua          => ( is => 'lazy' );
has name        => ( is => 'ro', default => sub { basename $0 } );
has cache => ( is => 'ro', default => sub { App::twtxtpl::Cache->new() } );

has use_pager         => ( is => 'rw', default => sub { 1 } );
has twtfile           => ( is => 'rw', default => sub { path('~/twtxt') } );
has sorting           => ( is => 'rw', default => sub { 'descending' } );
has timeout           => ( is => 'rw', default => sub { 5 } );
has use_cache         => ( is => 'rw', default => sub { 1 } );
has limit_timeline    => ( is => 'rw', default => sub { 20 } );
has time_format       => ( is => 'rw', default => sub { '%F %H:%M' } );
has disclose_identity => ( is => 'rw', default => sub { 0 } );
has embed_names       => ( is => 'rw', default => sub { 1 } );
has check_following   => ( is => 'rw', default => sub { 1 } );
has users             => ( is => 'rw', default => sub { {} } );
has nick              => ( is => 'rw' );
has twturl            => ( is => 'rw' );
has pre_tweet_hook    => ( is => 'rw' );
has post_tweet_hook   => ( is => 'rw' );

sub _build_ua {
    my $self = shift;
    my $ua   = Mojo::UserAgent->new()->request_timeout( $self->timeout )
      ->max_redirects(5);
    my $ua_string = "twtxtpl/$VERSION";
    if ( $self->disclose_identity && $self->nick && $self->twturl ) {
        $ua_string .= ' (+' . $self->twturl . '; @' . $self->nick . ')';
    }
    $ua->transactor->name($ua_string);
    return $ua;
}

sub BUILDARGS {
    my ( $class, @args ) = @_;
    my $args = ref $args[0] ? $args[0] : {@args};
    my $config_file = path( $args->{config_file} || '~/.config/twtxt/config' );

    my $cli = {};
    GetOptionsFromArray(
        \@ARGV,
        'cache!'        => sub { $cli->{use_cache}      = $_[1]; },
        'pager!'        => sub { $cli->{use_pager}      = $_[1]; },
        'ascending'     => sub { $cli->{sorting}        = "$_[0]"; },
        'descending'    => sub { $cli->{sorting}        = "$_[0]"; },
        'sorting=s'     => sub { $cli->{sorting}        = $_[1]; },
        'timeout=i'     => sub { $cli->{timeout}        = $_[1]; },
        'twtfile|f=s'   => sub { $cli->{twtfile}        = $_[1]; },
        'twturl=s'      => sub { $cli->{twturl}         = $_[1]; },
        'nick=s'        => sub { $cli->{nick}           = $_[1]; },
        'limit|l=i'     => sub { $cli->{limit_timeline} = $_[1]; },
        'time-format=s' => sub { $cli->{time_format}    = $_[1]; },
        'config|c=s'    => sub {
            $config_file = path( $_[1] );
            die "Configuration file $_[1] does not exists\n"
              unless $config_file->exists;
        }
    ) or pod2usage(2);

    $args->{config_file} = $config_file;

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

sub sync_followers {
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
    my $following = $self->users;
    if ($who) {
        if ( exists $self->users->{$who} ) {
            $following = { $who => $self->users->{$who} };
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
                        $self->cache->set( $self->users->{$user},
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

    $self->cache->clean if $self->use_cache;

    @tweets = sort {
            $self->sorting eq 'descending'
          ? $b->timestamp <=> $a->timestamp
          : $a->timestamp <=> $b->timestamp
    } @tweets;
    my $limit = $self->limit_timeline - 1;
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
    if ( $self->use_pager ) {
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
    my %urls = map { $self->users->{$_} => $_ } keys %{ $self->users };
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
    if ( $self->users->{$user} ) {
        if ( $self->embed_names ) {
            return "\@<$user " . $self->users->{$user} . ">";
        }
        else {
            return '@<' . $self->users->{$user} . '>';
        }
    }
    return "\@$user";
}

sub tweet : Command {
    my ( $self, $text ) = @_;
    $text = b($text)->decode;
    $text =~ s/\@(\w+)/$self->expand_mention($1)/ge;
    my $tweet = App::twtxtpl::Tweet->new( text => $text );
    my $file = path( $self->twtfile );
    $file->touch unless $file->exists;

    my $pre_hook  = $self->pre_tweet_hook;
    my $post_hook = $self->post_tweet_hook;
    my $twtfile   = shell_quote( $self->twtfile );
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
    $self->users->{$whom} = $url;
    $self->sync_followers;
    return;
}

sub unfollow : Command {
    my ( $self, $whom ) = @_;
    delete $self->users->{$whom};
    $self->sync_followers;
    print "You've unfollowed $whom.\n";
    return;
}

sub following : Command {
    my ( $self, $whom, $url ) = @_;
    for my $user ( keys %{ $self->users } ) {
        print "$user \@ " . $self->users->{$user} . "\n";
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
