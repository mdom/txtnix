package App::txtnix::Cmd::timeline;
use Mojo::Base 'App::txtnix';

has 'me' => sub { 0 };

sub run {
    my $self   = shift;
    my @tweets = $self->get_tweets();
    my $url    = $self->twturl;

    if ( $self->me ) {
        @tweets =
          grep { $_->source->file || $_->text =~ /\@<(?:\w+ )?$url>/o } @tweets;
    }

    @tweets = $self->filter_tweets(@tweets);
    $self->display_tweets( 1, @tweets );
    return 0;
}

1;
