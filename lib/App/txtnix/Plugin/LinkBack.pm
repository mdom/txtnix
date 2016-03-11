package App::txtnix::Plugin::LinkBack;
use strict;
use warnings;
use Mojo::Base 'App::txtnix::Plugin';
use Mojo::IOLoop::Delay;

has handlers => sub {
    { post_tweet => \&linkback };
};

sub linkback {
    my $app    = shift;
    my @tweets = @_;

    my $config = $app->read_config;

    my $plugin_config = $config->{'LinkBack'};

    return if !$plugin_config;
    return if !$app->twturl;

    my @mentions;
    for my $tweet (@tweets) {
        push @mentions, $tweet->text =~ m/@<(?:\w+ )?(.*?)>/g;
    }

    my %linkback;
    for my $tweet ( $app->get_tweets(@mentions) ) {
        if ( $tweet->text =~ m{//\s+linkback\s+(.*?)\s*$} ) {
            $linkback{ $tweet->source->url } = $1;
        }
    }
    my @linkbacks = values %linkback;

    my $delay = Mojo::IOLoop::Delay->new;
    for my $url (@linkbacks) {
        my $end = $delay->begin;
        $app->ua->post(
            $url => { url => $app->twturl } => sub {
                my ( $ua, $tx ) = @_;
                warn "Couldn't ping back to $url\n" if !$tx->success;
                $end->();
            }
        );
    }
    $delay->wait;

    return;
}

1;
