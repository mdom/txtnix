package App::txtnix::Cmd::mail;
use Mojo::Base 'App::txtnix';
use Mojo::ByteStream 'b';
use App::txtnix::Tweet;
use App::txtnix::Cmd::tweet;
use Mojo::Loader 'load_class';

sub run {
    my ($self) = @_;

    my $e = load_class('Email::MIME');

    die "Can't load Email::MIME to parse incoming mail.\n" if ref $e;

    my $stdin = do { local ($/); <> };
    return 0 if !defined $stdin;

    my $parsed = Email::MIME->new($stdin);
    return 0 if !defined $parsed;

    my $body;
    for my $part ( $parsed->parts ) {
        if ( $part->content_type =~ '^text/plain' ) {
            $body = $part->body_str;
            last;
        }
    }

    if ($body) {
        open( my $body_fh, '<', \$body );
        my $text = <$body_fh>;
        $text =~ s/\r\n$//;
        App::txtnix::Cmd::tweet->new( text => $text )->run;
    }

    return 0;
}

1;
