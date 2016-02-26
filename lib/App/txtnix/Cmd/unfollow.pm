package App::txtnix::Cmd::unfollow;
use Mojo::Base 'App::txtnix';

has 'nickname';

sub run {
    my ($self) = @_;
    my $nick = $self->nickname;
    if ( not $self->following->{$nick} ) {
        print "You're not following $nick.\n";
        return 1;
    }
    delete $self->following->{$nick};
    $self->sync;
    print "You've unfollowed $nick.\n";
    return 0;
}

1;
