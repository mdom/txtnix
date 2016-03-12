package App::txtnix::Plugin::ShellExec;
use Mojo::Base 'App::txtnix::Plugin';
use String::ShellQuote qw(shell_quote);

has handlers => sub {
    my $handlers = {};
    for my $prefix (qw(tweet follow unfollow)) {
        for my $suffix (qw(pre post)) {
            $handlers->{"${suffix}_${prefix}"} = \&exec_hook;
        }
    }
    return $handlers;
};

sub exec_hook {
    my ( $self, $event ) = @_;

    my $app = $self->app;

    my $cmd = $self->config->{"${event}_cmd"};

    if ( !$cmd && $event =~ /(pre|post)_tweet/ ) {
        return if !$app->hooks;
        my $attribute = "${event}_hook";
        $cmd = $app->$attribute;
    }
    else {
    }

    return if !$cmd;

    my $twtfile = shell_quote( $app->twtfile );
    $cmd =~ s/\Q{twtfile}/$twtfile/ge;
    system($cmd) == 0 or die "Can't call ${event}_hook $cmd.\n";

    return;
}

1;
