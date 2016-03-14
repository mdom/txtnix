package App::txtnix::Cmd::tweet;
use Mojo::Base 'App::txtnix';
use Mojo::ByteStream 'b';
use App::txtnix::Tweet;
use Path::Tiny;
use String::ShellQuote qw(shell_quote);
use Mojo::Date;
use IO::Interactive qw(is_interactive);

has 'text';
has 'created_at';

sub run {
    my ($self) = @_;

    my $time =
        $self->created_at
      ? $self->to_date( $self->created_at )
      : Mojo::Date->new();

    die "Can't parse --created-at " . $self->created_at . " as rfc3339.\n"
      if !defined $time->epoch;

    $self->emit('pre_tweet');

    my @lines;
    if ( $self->text ) {
        push @lines, $self->text;
    }
    elsif ( is_interactive() ) {
        my $file = Path::Tiny->tempfile;
        my $editor = $ENV{VISUAL} || $ENV{EDITOR} || 'vi';
        system( $editor, $file ) == 0
          or die "Can't execute $editor: $!\n";
        push @lines, $file->lines_utf8( { chomp => 1 } );
    }
    else {
        @lines = <STDIN>;
        chomp(@lines);
    }

    return 0 if !@lines;

    my @tweets;

    for my $line (@lines) {
        $line =~ s/\@(\w+)/$self->expand_mention($1)/ge;
        push @tweets,
          App::txtnix::Tweet->new( text => $line, timestamp => $time );
        $time = Mojo::Date->new( $time->epoch + 0.1 );
    }

    for my $tweet (@tweets) {
        $self->twtfile->append_utf8( $tweet->to_string . "\n" );
    }

    $self->emit( 'post_tweet', @tweets );

    return 0;
}

1;
