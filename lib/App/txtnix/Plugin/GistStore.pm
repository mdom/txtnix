package App::txtnix::Plugin::GistStore;
use strict;
use warnings;
use Mojo::Base 'App::txtnix::Plugin';
use Path::Tiny;
use Mojo::JSON qw(true false);

has handlers => sub {
    { post_tweet => \&store };
};

sub store {
    my $app = shift;
    my $ua  = $app->ua;

    my $config = $app->read_config;

    my $plugin_config = $config->{'GistStore'};

    return if !$plugin_config;

    my $token    = $plugin_config->{access_token};
    my $username = $plugin_config->{user};
    my $id       = $plugin_config->{id};

    my $url =
      Mojo::URL->new("https://api.github.com/gists")
      ->userinfo("$username:$token");

    if ($id) {
        $url->path( $url->path . '/' . $id );
    }

    my $file = $app->twtfile;

    my $tx = $ua->post(
        $url => json => {
            description => "twtxt.txt for $username",
            public      => true,
            files       => {
                "twtxt.txt" => {
                    content => $file->slurp_utf8,
                }
            }
        }
    );

    if ( my $res = $tx->success ) {
        print "Uploaded gist.\n";
        if ( !$id ) {
            $config->{'Store::Gist'}->{id} = $res->json->{id};
            $config->write( $app->config, 'utf8' );
        }
    }
    else {
        my $err   = $tx->error;
        my $error = $err->{message};
        $error = $err->code . " $error" if $err->{code};
        warn "Error while uploading gist: $error\n";
    }

    return;
}

1;
