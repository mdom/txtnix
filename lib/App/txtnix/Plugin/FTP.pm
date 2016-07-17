package App::txtnix::Plugin::FTP;
use Mojo::Base 'App::txtnix::Plugin';
use Net::FTP;

has ssl => sub { 1 };

sub post_tweet {
    my $self = shift;
    my $app  = $self->app;
    my $ua   = $app->ua;

    my $host        = $self->config->{host};
    my $user        = $self->config->{user};
    my $password    = $self->config->{password};
    my $remote_file = $self->config->{remote_file};

    my $file = $app->twtfile;

    if ( !$file || !$file->exists ) {
        warn "Can't find twtfile to upload\n";
        return;
    }

    if ( !$host ) {
        warn "Missing host for ftp upload\n";
        return;
    }

    my $ftp = Net::FTP->new( $host, SSL => $self->ssl );

    if ( !$ftp ) {
        warn "Cannot connect to ftp://$host: $@\n";
        return;
    }

    if ( !$ftp->login( $user, $password ) ) {
        warn "Cannot login to ftp server ", $ftp->message . "\n";
        return;
    }

    $ftp->binary;

    if ( !$ftp->put( $file->stringify, $remote_file ) ) {
        warn "Cannot upload $file: " . $ftp->message . "\n";
        return;
    }

    $ftp->quit;

    print "Uploaded twtxt file to ftp.\n";

    return;
}

1;
