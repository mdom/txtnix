package App::txtnix::Plugin::ShellExec;
use Mojo::Base 'App::txtnix::Plugin';
use String::ShellQuote qw(shell_quote);

has handlers => sub {
    {
        pre_tweet  => \&pre_tweet,
        post_tweet => \&post_tweet,
    };
};

sub pre_tweet {
    my $app = shift;

    my $twtfile  = shell_quote( $app->twtfile );
    my $pre_hook = $app->pre_tweet_hook;
    if ( $app->hooks && $pre_hook ) {
        $pre_hook =~ s/\Q{twtfile}/$twtfile/ge;
        system($pre_hook) == 0 or die "Can't call pre_tweet_hook $pre_hook.\n";
    }
    return;
}

sub post_tweet {
    my $app = shift;

    my $twtfile   = shell_quote( $app->twtfile );
    my $post_hook = $app->post_tweet_hook;
    if ( $app->hooks && $post_hook ) {
        $post_hook =~ s/\Q{twtfile}/$twtfile/ge;
        system($post_hook) == 0
          or die "Can't call post_tweet_hook $post_hook.\n";
    }
    return;
}

1;
