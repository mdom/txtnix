package App::txtnix::Tweet;
use Mojo::Base -base;
use Mojo::ByteStream 'b';
use Mojo::Date;
use POSIX ();

has [qw(source text)];
has timestamp => sub { time };

sub strftime {
    my ( $self, $format ) = @_;
    return POSIX::strftime( $format, localtime $self->timestamp );
}

sub to_string {
    my $self = shift;
    return Mojo::Date->new( $self->timestamp )->to_datetime . "\t"
      . $self->text;
}

sub md5_hash {
    my $self = shift;
    return b( $self->timestamp . $self->text )->encode->md5_sum;
}

1;
