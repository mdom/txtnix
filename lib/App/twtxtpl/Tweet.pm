package App::twtxtpl::Tweet;
use strict;
use warnings;
use HTTP::Date 'str2time';
use POSIX ();
use Moo;

has user => ( is => 'ro' );
has timestamp => (
    is      => 'ro',
    coerce  => \&to_epoch,
    default => sub { time }
);
has text => ( is => 'ro' );

sub to_epoch {
    return $_[0] =~ /[^\d]/ ? str2time( $_[0] ) : $_[0];
}

sub strftime {
    my ( $self, $format ) = @_;
    return POSIX::strftime( $format, gmtime $self->timestamp );
}

sub to_string {
    my $self = shift;
    return $self->strftime('%FT%T%z') . "\t" . $self->text;
}

1;
