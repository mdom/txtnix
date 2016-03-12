package App::txtnix::Cmd::unfollow;
use Mojo::Base 'App::txtnix';

has 'nickname';

sub run {
    my ($self) = @_;

    $self->emit('pre_unfollow');

    my $nick = $self->nickname;
    if ( not $self->following->{$nick} ) {
        print "You're not following $nick.\n";
        return 1;
    }
    $self->add_metadata( 'unfollow', $nick, $self->following->{$nick} )
      if $self->write_metadata;
    delete $self->following->{$nick};
    $self->sync;
    print "You've unfollowed $nick.\n";

    $self->emit('post_unfollow');

    return 0;
}

1;
