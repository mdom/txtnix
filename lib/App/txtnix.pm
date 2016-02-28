package App::txtnix;

use Mojo::Base -base;
use 5.14.0;
use Config::Tiny;
use Path::Tiny;
use HTTP::Date;
use Mojo::UserAgent;
use App::txtnix::Tweet;
use App::txtnix::Source;
use App::txtnix::Cache;
use App::txtnix::Registry;
use IO::Pager;
use Mojo::ByteStream 'b';

our $VERSION = '0.02';

has 'ua' => sub { shift->_build_ua };
has cache => sub { App::txtnix::Cache->new( cache_dir => shift->cache_dir ) };

has twtfile           => sub { path('~/twtxt') };
has cache_dir         => sub { path('~/.cache/txtnix') };
has use_pager         => sub { 0 };
has sorting           => sub { "descending" };
has timeout           => sub { 5 };
has use_cache         => sub { 1 };
has limit             => sub { 20 };
has time_format       => sub { '%F %H:%M' };
has disclose_identity => sub { 0 };
has rewrite_urls      => sub { 1 };
has embed_names       => sub { 1 };
has check_following   => sub { 1 };
has following         => sub { {} };
has nick              => sub { $ENV{USER} };
has since             => sub { 0 };
has until             => sub { time };

has [qw( twturl pre_tweet_hook post_tweet_hook config force registry )];

sub new {
    my ( $class, @args ) = @_;
    my $args = ref $args[0] ? $args[0] : {@args};

    for (qw(cache pager)) {
        $args->{"use_$_"} = delete $args->{$_} if exists $args->{$_};
    }

    $args->{config} =
      path( $args->{config} || '~/.config/twtxt/config' );

    for (qw(since until)) {
        $args->{$_} = $class->to_epoch( $args->{$_} ) if exists $args->{$_};
    }

    for (qw(ascending descending )) {
        $args->{sorting} = $_ if exists $args->{$_} && $args->{$_};
    }

    if ( $args->{config}->exists ) {
        my $config = $class->read_file( $args->{config} );
        if ( $config->{twtxt} ) {
            $args = { %{ $config->{twtxt} }, %$args };
        }
        if ( $config->{following} ) {
            $args->{following} = $config->{following};
        }
    }
    for my $path (qw(twtfile cache_dir)) {
        $args->{$path} = path( $args->{$path} ) if exists $args->{$path};
    }

    return bless {%$args}, ref $class || $class;
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
    return str2time( $_[1] );
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
    my $delay = Mojo::IOLoop->delay;

    while ( my ( $user, $url ) = each %{$following} ) {
        my ( $cache, $params ) = ( undef, {} );
        if ( $self->use_cache ) {
            $cache = $self->cache->get($url);
            if ($cache) {
                $params = { "If-Modified-Since" => $cache->{last_modified} };
            }
        }
        my $end = $delay->begin;
        $self->ua->get(
            $url => $params => sub {
                my ( $ua, $tx ) = @_;

                if ( my $res = $tx->success ) {

                    $self->check_for_moved_url( $tx, $user );

                    my $body = b( $res->body )->decode;
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
                        $self->cache->set( $url, $res->headers->last_modified,
                            $body );
                    }
                    my $source =
                      App::txtnix::Source->new( url => $url, nick => $user );
                    push @tweets, $self->parse_twtfile( $source, $body );

                }
                else {
                    my $err = $tx->error;
                    warn "Failing to get tweets for $user: "
                      . (
                        $err->{code}
                        ? "$err->{code} response: $err->{message}"
                        : "Connection error: $err->{message}"
                      ) . "\n";
                    if (   $tx->res
                        && $tx->res->code
                        && $tx->res->code == 410
                        && $self->rewrite_urls )
                    {
                        warn "Unfollow user $user after 410 response.\n";
                        delete $self->following->{$user};
                    }
                }
                $end->();
            }
        );
    }

    if ( $self->registry && $self->twturl ) {
        my $end = $delay->begin;
        my $registry =
          App::txtnix::Registry->new( url => $self->registry, ua => $self->ua );
        my @mentions = $registry->get_mentions(
            $self->twturl => sub {
                my (@results) = @_;
                for my $result (@results) {
                    my ( $nick, $url ) =
                      $result->[0] =~ /\@<(?:(\w+) )?([^>]+)>/;
                    my $source =
                      App::txtnix::Source->new( url => $url, nick => $nick );
                    push @tweets,
                      App::txtnix::Tweet->new(
                        timestamp => $self->to_epoch( $result->[1] ),
                        text      => $result->[2],
                        source    => $source,
                      );
                }
                $end->();
            }
        );
    }

    $delay->wait;

    if ( not defined $who and $self->twtfile->exists ) {
        my $source = App::txtnix::Source->new(
            file => $self->twtfile->exists,
            nick => $self->nick
        );
        push @tweets,
          $self->parse_twtfile( $source, $self->twtfile->slurp_utf8 );
    }

    $self->sync;

    $self->cache->clean( values %{ $self->following } )
      if $self->use_cache;

    return $self->filter_tweets(@tweets);
}

sub filter_tweets {
    my ( $self, @tweets ) = @_;

    @tweets =
      grep { $_->timestamp >= $self->since && $_->timestamp <= $self->until }
      @tweets;

    my %seen_tweets;

    for my $tweet (@tweets) {
        $seen_tweets{ $tweet->md5_hash } = $tweet;
    }

    @tweets = values %seen_tweets;

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
    my ( $self, $source, $string ) = @_;
    my @tweets;
    for my $line ( split( /\n/, $string ) ) {
        my ( $time, $text ) = split( /\t/, $line, 2 );
        next if not defined $text;
        $text =~ s/\P{XPosixPrint}//g;
        $time = $self->to_epoch($time);
        if ( $time and $text ) {
            push @tweets,
              App::txtnix::Tweet->new(
                source    => $source,
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
    if ( $self->use_pager ) {
        IO::Pager->new($fh);
    }
    else {
        $fh = \*STDOUT;
    }
    for my $tweet (@tweets) {
        my $time = $tweet->strftime( $self->time_format );
        my $text = $self->collapse_mentions( $tweet->text || '' );

        my $nick;
        if ( $tweet->source->file ) {
            $nick = $tweet->source->nick;
        }
        elsif ( $tweet->source->url ) {
            if ( !( $nick = $self->url_to_nick( $tweet->source->url ) ) ) {
                if ( $tweet->source->nick ) {
                    $nick = '@<'
                      . $tweet->source->nick . ' '
                      . $tweet->source->url . '>';
                }
                else {
                    $nick = '@<' . $tweet->source->url . '>';
                }
            }
        }
        my $line = "$time $nick: $text\n";

        print {$fh} b($line)->encode,;
    }
    return;
}

sub url_to_nick {
    my ( $self, $url ) = @_;
    my $known_users = $self->known_users;
    my %urls = map { $known_users->{$_} => $_ } keys %{$known_users};
    return $urls{$url};
}

sub collapse_mentions {
    my ( $self, $text ) = @_;
    $text =~ s/\@<(?:(\w+) )?([^>]+)>/$self->collapse_mention($1,$2)/ge;
    return $text;
}

sub collapse_mention {
    my ( $self, $user, $url ) = @_;
    my $nick = $self->url_to_nick($url);
    return $nick ? "\@$nick" : $user ? "\@<$user $url>" : "\@<$url>";
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
