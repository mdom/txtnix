package App::txtnix::Plugin::LinkBack;
use strict;
use warnings;
use Mojo::Base 'App::txtnix::Plugin';
use Mojo::IOLoop::Delay;

has handlers => sub {
    { post_tweet => \&linkback };
};

sub linkback {
    my $config = $app->read_config;

    my $plugin_config = $config->{'LinkBack'};

    return if !$plugin_config;
    my ( $self, $event, @tweets ) = @_;
    my $app = $self->app;

    if ( !$app->twturl ) {
        warn "Cannot send ping back without twturl.\n";
        return;
    }

    my @mentions;
    for my $tweet (@tweets) {
        push @mentions, $tweet->text =~ m/@<(?:\w+ )?(.*?)>/g;
    }

    return if !@mentions;

    my %linkback;
    for my $tweet ( $app->get_tweets(@mentions) ) {
        if ( $tweet->text =~ m{^\s*//\s+linkback\s+(.*?)\s*$} ) {
            $linkback{ $tweet->source->url } = $1;
        }
    }
    my @linkbacks = values %linkback;

    my $delay = Mojo::IOLoop::Delay->new;
    for my $url (@linkbacks) {
        my $end = $delay->begin;
        $app->ua->post(
            $url => form => { url => $app->twturl } => sub {
                my ( $ua, $tx ) = @_;
                if ( $tx->success ) {
                    warn "Send ping back to $url.\n";
                }
                else {
                    my $prefix = "Couldn't ping back to $url";
                    if ( my $err = $tx->error ) {
                        warn $err->{code}
                          ? "$prefix: $err->{code} response: $err->{message}\n"
                          : "$prefix: Connection error: $err->{message}\n";
                    }
                }
                $end->();
            }
        );
    }
    $delay->wait;

    return;
}

1;
