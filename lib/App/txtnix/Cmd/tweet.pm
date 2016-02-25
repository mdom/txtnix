package App::txtnix::Cmd::tweet;
use Moo;
use Mojo::ByteStream 'b';
use App::txtnix::Tweet;
use Path::Tiny;
use String::ShellQuote qw(shell_quote);

extends 'App::txtnix';

has text       => ( is => 'rw' );
has created_at => ( is => 'rw' );

sub run {
    my ($self) = @_;
    my $text = $self->text;
    $text = b($text)->decode;
    $text =~ s/\@(\w+)/$self->expand_mention($1)/ge;

    if ( $self->created_at ) {
        $self->to_epoch( $self->created_at );
    }
    else {
        $self->created_at(time);
    }

    my $tweet =
      App::txtnix::Tweet->new( text => $text, timestamp => $self->created_at );
    my $file = path( $self->twtfile );
    $file->touch unless $file->exists;

    my $pre_hook  = $self->pre_tweet_hook;
    my $post_hook = $self->post_tweet_hook;
    my $twtfile   = shell_quote( $self->twtfile );
    if ($pre_hook) {
        $pre_hook =~ s/\Q{twtfile}/$twtfile/ge;
        system($pre_hook) == 0 or die "Can't call pre_tweet_hook $pre_hook.\n";
    }
    $file->append_utf8( $tweet->to_string . "\n" );
    if ($post_hook) {
        $post_hook =~ s/\Q{twtfile}/$twtfile/ge;
        system($post_hook) == 0
          or die "Can't call post_tweet_hook $post_hook.\n";
    }
    return 0;
}

1;
