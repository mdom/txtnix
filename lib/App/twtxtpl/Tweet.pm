package App::twtxtpl::Tweet;
use strict;
use warnings;
use Mojo::Date;
use HTTP::Date 'str2time';
use POSIX ();
use Moo;

has user => ( is => 'ro' );
has timestamp => (
    is      => 'ro',
    coerce  => \&to_timestamp,
    default => sub { Mojo::Date->new() }
);
has text => ( is => 'ro' );

sub to_timestamp {
    return
      ref $_[0] eq 'Mojo::Date' ? $_[0] : Mojo::Date->new( str2time( $_[0] ) );
}

sub strftime {
    my ( $self, $format ) = @_;
    return POSIX::strftime( $format, gmtime $self->timestamp->epoch );
}

sub to_string {
    my $self = shift;
    return $self->strftime('%FT%T%z') . "\t" . $self->text;
}

1;
