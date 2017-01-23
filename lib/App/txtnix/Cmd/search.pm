package App::txtnix::Cmd::search;
use Mojo::Base 'App::txtnix';

has 'search';

sub compile_search {
    my ($self) = @_;
    my $search = $self->search;
    my $code   = 'sub { my ($tweet) = @_;';
    while (1) {
        if ( $search =~ /\G ( && | \|\| | \( | \) | ! )/gcx ) {
            $code .= $1;
        }
        elsif ( $search =~ /\G \@(\w+) /gcx ) {
            $code .=
              "(\$tweet->text =~ /\Q\@$1\E/ || \$tweet->text =~ /\Q\@<$1\E/)";
        }
        elsif ( $search =~ /\G (\S+) /gcx ) {
            $code .= "\$tweet->text =~ /\Q$1\E/";
        }
        elsif ( $search =~ /\G \s+ /gcx ) {
            redo;
        }
        elsif ( $search =~ /\G (.)/gcx ) {
            die "Error at $search\n" . ( ' ' x ( 8 + pos($search) ) ) . "^\n";
        }
        else {
            last;
        }
    }
    $code .= '}';
    my $sub = eval $code;
    die "$@" if "$@";
    return $sub;
}

sub run {
    my $self   = shift;
    my @tweets = $self->get_tweets();
    my $code   = $self->compile_search;
    @tweets = grep { $code->($_) } @tweets;
    $self->display_tweets(@tweets);
    return 0;
}

1;
