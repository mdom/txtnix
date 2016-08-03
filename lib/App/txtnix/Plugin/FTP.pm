package App::txtnix::Plugin::FTP;
use Mojo::Base 'App::txtnix::Plugin';
use Net::FTP;

has ssl => sub { 1 };
has [qw(host user password remote_file)];

sub post_tweet {
    my $self = shift;

    my $file = $self->app->twtfile;

    if ( !$file || !$file->exists ) {
        warn "Can't find twtfile to upload\n";
        return;
    }

    if ( !$self->host ) {
        warn "Missing host for ftp upload\n";
        return;
    }

    my $ftp = Net::FTP->new( $self->host, SSL => $self->ssl );

    if ( !$ftp ) {
        warn "Cannot connect to ftp://", $self->host, ": $@\n";
        return;
    }

    if ( !$ftp->login( $self->user, $self->password ) ) {
        warn "Cannot login to ftp server ", $ftp->message, "\n";
        return;
    }

    $ftp->binary;

    if ( !$ftp->put( $file->stringify, $self->remote_file ) ) {
        warn "Cannot upload $file: ", $ftp->message, "\n";
        return;
    }

    $ftp->quit;

    print "Uploaded twtxt file to ftp.\n";

    return;
}

1;
