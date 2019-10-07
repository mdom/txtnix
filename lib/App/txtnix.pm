package App::txtnix;

use Mojo::Base -base;
use 5.14.0;
use Config::Tiny;
use Path::Tiny;
use Mojo::Date;
use Mojo::UserAgent;
use Mojo::URL;
use Mojo::Loader qw(data_section find_modules load_class);
use Mojo::Template;
use App::txtnix::Tweet;
use App::txtnix::URLQueue;
use App::txtnix::Source;
use App::txtnix::Cache;
use App::txtnix::Registry;
use App::txtnix::Date qw(to_date);
use IO::Pager;
use Mojo::ByteStream 'b';

our $VERSION = '0.07';

has ua      => sub { shift->_build_ua };
has cache   => sub { App::txtnix::Cache->new( cache_dir => shift->cache_dir ) };
has twtfile => sub { path('~/twtxt') };
has cache_dir         => sub { path('~/.cache/txtnix') };
has use_pager         => sub { 0 };
has sorting           => sub { "descending" };
has timeout           => sub { 5 };
has limit             => sub { 20 };
has time_format       => sub { '%Y-%m-%d %H:%M' };
has disclose_identity => sub { 0 };
has write_metadata    => sub { 0 };
has hide_metadata     => sub { 1 };
has rewrite_urls      => sub { 1 };
has embed_names       => sub { 1 };
has following         => sub { {} };
has template          => sub { 'pretty' };
has nick              => sub { $ENV{USER} };
has since             => sub { Mojo::Date->new->epoch(0) };
has until             => sub { Mojo::Date->new() };
has ca_file           => sub { '/etc/ssl/certs/ca-certificates.crt' };
has show_new          => sub { 0 };
has last_timeline     => sub { 0 };
has use_colors        => sub { 0 };
has wrap_text         => sub { 1 };
has character_limit   => sub { 1024 };
has expand_me         => sub { 0 };
has hooks             => sub { 1 };
has registry          => sub { "" };
has sign              => sub { 0 };

has unfollow_codes => sub { { "410" => 1 } };

has [
    qw( colors twturl pre_tweet_hook post_tweet_hook config_file config_dir
      force key_file cert_file plugins cache pager http_proxy https_proxy)
];

sub new {
    my ( $class, @args ) = @_;
    my $args = ref $args[0] ? $args[0] : {@args};

    my %translate = (
        pager => 'use_pager',
        new   => 'show_new',
    );

    for ( keys %translate ) {
        $args->{ $translate{$_} } = delete $args->{$_} if exists $args->{$_};
    }

    $args->{config_file} =
      $args->{config}
      ? path( delete $args->{config} )
      : $class->_build_config_file;

    for (qw(since until)) {
        if ( exists $args->{$_} ) {
            $args->{$_} = to_date( $args->{$_} );
            die "Can't parse parameter $_ as rfc3339.\n"
              if !defined $args->{$_}->epoch;
        }
    }

    $args->{colors} ||= {};

    if ( !$args->{template} ) {
        for (qw(pretty simple )) {
            $args->{template} = $_ if exists $args->{$_} && $args->{$_};
        }
    }

    for (qw(ascending descending )) {
        $args->{sorting} = $_ if exists $args->{$_} && $args->{$_};
    }

    my $config;
    if ( $args->{config_file}->exists ) {
        $config = $class->read_config( $args->{config_file} );
        if ( $config->{twtxt} ) {
            $args = { %{ $config->{twtxt} }, %$args };
        }
        if ( $config->{following} ) {
            $args->{following} = $config->{following};
        }

        if ( $config->{colors} ) {
            $args->{colors} = { %{ $config->{colors} }, %{ $args->{colors} } };
        }
    }

    $args->{colors} = {
        nick    => 'bright_yellow',
        time    => 'bright_blue',
        mention => 'cyan',
        hashtag => 'cyan',
        %{ $args->{colors} },
    };

    if ( $args->{unfollow_codes} ) {
        $args->{unfollow_codes} =
          { map { $_ => 1 } split( ',', $args->{unfollow_codes} ) };
    }

    for my $path (qw(twtfile cache_dir)) {
        $args->{$path} = path( $args->{$path} ) if exists $args->{$path};
    }

    $args->{config_dir} = $args->{config_file}->parent;

    my $self = bless {%$args}, ref $class || $class;

    $self->cache = App::txtnix::Cache->new( cache_dir => $self->cache_dir )
      if $self->cache && !ref $self->cache;

    my @plugins;
    my @modules = find_modules('App::txtnix::Plugin');
    for my $module (@modules) {
        if ( my $e = load_class $module) {
            die ref $e ? "Exception: $e" : 'Not found!';
        }
        my ($name) = $module =~ /^.*::(.*)$/;
        my $plugin_config = $config->{$name} || {};
        push @plugins,
          $module->new(
            app    => $self,
            name   => $name,
            config => $plugin_config,
            %$plugin_config
          );
    }
    $self->plugins(
        [
            sort { $a->priority <=> $b->priority || $a->name cmp $b->name }
              @plugins
        ]
    );

    if ( $self->pager ) {
        $ENV{PAGER} = $self->pager;
        $self->use_pager(1);
    }

    return $self;
}

sub emit {
    my ( $self, $event ) = ( shift, shift );
    foreach my $plugin ( @{ $self->plugins } ) {
        next if !$plugin->is_enabled;
        my $method = $plugin->can($event);
        next if !$method;
        $plugin->$method( $event, @_ );
    }
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
    $ua->ca( $self->ca_file );
    $ua->cert( $self->cert_file ) if $self->cert_file;
    $ua->key( $self->key_file )   if $self->key_file;
    if ( $self->http_proxy ) {
        $ua->proxy->http( $self->http_proxy );
    }
    if ( $self->https_proxy ) {
        $ua->proxy->https( $self->https_proxy );
    }
    return $ua;
}

sub _build_config_file {
    my $dir =
      $ENV{TXTNIX_CONFIG_DIR} ? path( $ENV{TXTNIX_CONFIG_DIR} )
      : path(
          $ENV{XDG_CONFIG_HOME} ? $ENV{XDG_CONFIG_HOME}
        : $^O eq "MSWin32"      ? $ENV{APPDATA}
        : $^O eq 'darwin'       ? '~/Library/Application Support'
        :                         '~/.config/'
      )->child('txtnix');
    $dir->mkpath if !$dir->exists;
    return $dir->child('config');
}

sub write_config {
    my ( $self, $config ) = @_;
    $config->write( $self->config_file, 'utf8' );
    return;
}

sub read_config {
    my ( $self, $file ) = @_;
    $file = path( $file || $self->config_file );
    if ( !$file->exists ) {
        $file->parent->mkpath;
        $file->touch;
    }
    my $config =
      Config::Tiny->read( $file || $self->config_file->stringify, 'utf8' );
    die "Could not read configuration file: $Config::Tiny::errstr\n"
      if !defined $config;
    return $config;
}

sub sync {
    my ($self) = @_;
    my $config = $self->read_config;
    $config->{following} = $self->following;
    $self->write_config($config);
    return;
}

sub config_set {
    my ( $self, $key, $value ) = @_;
    my $config = $self->read_config;
    $config->{twtxt}->{$key} = $value;
    $self->write_config($config);
    return;
}

sub add_metadata {
    my $self = shift;
    return $self->twtfile->append_utf8(
        Mojo::Date->new()->to_datetime . "#" . join( ' ', @_ ) . "\n" );
}

sub get_tweets {
    my ( $self, @source ) = @_;

    my @urls = @source ? @source : values %{ $self->following };
    my %urls = map { $_ => 1 } @urls;

    my @tweets;

    my $delay = Mojo::IOLoop->delay;

    my $q = App::txtnix::URLQueue->new(
        queue => \@urls,
        ua    => $self->ua,
        cache => $self->cache,
        delay => $delay,
    );

    $q->on(
        process => sub {
            my ( $q, $tx, $url ) = @_;
            my $nick = $self->url_to_nick($url);
            my $res = $tx->result;
            if ( $res->is_success ) {
                my $body = b( $res->body )->decode;

                if ( $self->cache ) {
                    if ( $res->code == 304 ) {
                        $body = $self->cache->get($url)->{body};
                    }
                    elsif ($res->code == 200
                        && $res->headers->last_modified )
                    {
                        $self->cache->set(
                            $url,
                            {
                                last_modified => $res->headers->last_modified,
                                body          => $body
                            }
                        );
                    }
                }

                $self->check_for_moved_url( $tx, $nick ) if $nick;

                my $source = App::txtnix::Source->new(
                    url  => $url,
                    nick => $nick
                );
                push @tweets, $self->parse_twtfile( $source, $body );

            }
            else {
                my $err = $tx->error;
                my $source = $nick || $url;
                chomp( $err->{message} );
                warn "Failing to get tweets for $source: "
                  . (
                    $err->{code}
                    ? "$err->{code} response: $err->{message}"
                    : "Connection error: $err->{message}"
                  ) . "\n";
                if (   $nick
                    && $tx->res
                    && $tx->res->code
                    && $self->rewrite_urls )
                {
                    my $code = $tx->res->code;
                    if ( $self->unfollow_codes->{$code} ) {
                        warn "Unfollow user $nick after $code response.\n";
                        delete $self->following->{$nick};
                    }
                }
            }
        }
    );

    $q->start;

    if ( !@source && $self->registry && $self->twturl ) {
        my $end      = $delay->begin;
        my $registry = App::txtnix::Registry->new(
            url => $self->registry,
            ua  => $self->ua
        );
        my @mentions = $registry->get_mentions(
            $self->twturl => sub {
                my (@results) = @_;
                for my $result (@results) {
                    my ( $nick, $url ) =
                      $result->[0] =~ /\@<(?:(\w+) )?([^>]+)>/;
                    next if $url and $urls{$url};
                    my $source = App::txtnix::Source->new(
                        url  => $url,
                        nick => $nick
                    );
                    my $timestamp = to_date( $result->[1] );
                    next if !defined $timestamp->epoch;
                    push @tweets,
                      App::txtnix::Tweet->new(
                        timestamp => $timestamp,
                        text      => $result->[2],
                        source    => $source,
                      );
                }
                $end->();
            }
        );
    }

    $delay->wait;

    if ( !@source and $self->twtfile->exists ) {
        my $source = App::txtnix::Source->new(
            file => $self->twtfile,
            nick => $self->nick,
        );
        push @tweets,
          $self->parse_twtfile( $source, $self->twtfile->slurp_utf8 );
    }

    if ( !@source ) {
        $self->sync;

        $self->cache->clean( values %{ $self->following } )
          if $self->cache;
    }

    @tweets =
      sort { $b->timestamp->epoch <=> $a->timestamp->epoch } @tweets;

    return @tweets;
}

sub filter_tweets {
    my ( $self, @tweets ) = @_;

    if ( $self->show_new && $self->last_timeline ) {
        $self->since( Mojo::Date->new( $self->last_timeline ) );
    }

    @tweets =
      grep {
             !( $self->hide_metadata && $_->is_metadata )
          && $_->timestamp->epoch >= $self->since->epoch
          && $_->timestamp->epoch <= $self->until->epoch
      } @tweets;

    my %seen_tweets;

    for my $tweet (@tweets) {
        $seen_tweets{ $tweet->md5_hash } = $tweet;
    }

    @tweets = values %seen_tweets;

    @tweets =
      sort { $b->timestamp->epoch <=> $a->timestamp->epoch } @tweets;

    $self->emit( 'filter_tweets', \@tweets );

    my $limit = $self->limit;
    return sort {
            $self->sorting eq 'descending'
          ? $b->timestamp->epoch <=> $a->timestamp->epoch
          : $a->timestamp->epoch <=> $b->timestamp->epoch
    } @tweets > $limit ? @tweets[ 0 .. $limit - 1 ] : @tweets;
}

sub check_for_moved_url {
    my ( $self, $tx, $user ) = @_;
    my $redirect = $tx->redirects->[0];
    if ( $redirect && $self->rewrite_urls ) {
        my $res = $redirect->res;
        if ( ( $res->code == 301 || $res->code == 308 )
            && $res->headers->location )
        {
            warn 'Rewrite url from '
              . $redirect->req->url . ' to '
              . $res->headers->location
              . " after "
              . $res->code . ".\n";
            $self->following->{$user} = $res->headers->location;
        }
    }
    return;
}

sub parse_twtfile {
    my ( $self, $source, $string ) = @_;
    my @tweets;
    for my $line ( split( /\n/, $string ) ) {
        my $tweet = App::txtnix::Tweet->from_string( $line, $source );
        if ($tweet) {
            if ( $self->character_limit && $self->character_limit > 0 ) {
                $tweet->text(
                    substr( $tweet->text, 0, $self->character_limit ) );
            }

            $tweet->formatted_time( $tweet->strftime( $self->time_format ) );

            push @tweets, $tweet;
        }
    }
    return @tweets;
}

sub display_tweets {
    my ( $self, @tweets ) = @_;
    return if !@tweets;
    my $fh;
    if ( $self->use_pager ) {
        IO::Pager->new($fh);
    }
    else {
        $fh = \*STDOUT;
    }
    my $format        = $self->template;
    my $template_name = "$format.mt";

    my $template_file =
      $self->config_dir->child('templates')->child($template_name);
    my $template;
    if ( $template_file->exists ) {
        $template = $template_file->slurp_utf8;
    }
    else {
        $template = data_section( __PACKAGE__, $template_name );
    }

    if ( !$template ) {
        die "Unknown template $format.\n";
    }

    my $mt =
      Mojo::Template->new( vars => 1, encoding => 'UTF-8' )->parse($template);

    if ( !$self->use_colors ) {
        $ENV{ANSI_COLORS_DISABLED} = 0;
    }

    for my $tweet (@tweets) {
        $tweet->text( $self->collapse_mentions( $tweet->text || '' ) );
        if ( $tweet->source->nick && $self->expand_me ) {
            $tweet->text =~ s{^/me(?=\s)}{'@'.$tweet->source->nick}e;
        }
    }

    print {$fh} b(
        $mt->process(
            {
                tweets => \@tweets,
                app    => $self,
            }
        )
    )->encode;

    return;
}

sub normalize_url {
    my ( $self, $url ) = @_;
    $url = Mojo::URL->new($url);
    $url->scheme('http');
    $url->port(undef)
      if $url->port && ( $url->port == 80 || $url->port == 443 );
    $url->path->leading_slash(0);
    $url->path->trailing_slash(0);
    $url->path->canonicalize;
    $url->userinfo(undef);
    return $url;
}

sub url_to_nick {
    my ( $self, $url ) = @_;
    my $known_users = $self->known_users;
    my %urls =
      map { $self->normalize_url( $known_users->{$_} ) => $_ }
      keys %{$known_users};
    return $urls{ $self->normalize_url($url) };
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

__DATA__

@@ pretty.mt
% use Term::ANSIColor;
% use Text::Wrap;
%
% for my $tweet ( @$tweets ) {
%   my $text = $tweet->text;
%   $text =~ s/(@\w+)/colored($1, $app->colors->{mention})/ge;
%   $text =~ s/(#\w+)/colored($1, $app->colors->{hashtag})/ge;
%   my $time = colored($tweet->formatted_time,$app->colors->{time});
%   my $nick = colored($tweet->nick, $app->colors->{nick});
%
* <%= $nick %> (<%= $time %>):
%   if ( $app->wrap_text ) {
%=   wrap('','',$text) . "\n"
%   } else {
%=   $text . "\n"
%   }
% }

@@ simple.mt
% for my $t ( @$tweets ) {
<%= $t->formatted_time %> <%= $t->nick %>: <%= $t->text %>
% }

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
