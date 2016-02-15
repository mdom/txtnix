package App::twtxtpl::Tweet;
use strict;
use warnings;
use Mojo::Date;
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
    return ref $_[0] eq 'Mojo::Date' ? $_[0] : Mojo::Date->new( $_[0] );
}

sub strftime {
    my ( $self, $format ) = @_;
    $DB::single = 1;
    return POSIX::strftime( $format, gmtime shift->timestamp->epoch );
}

sub to_string {
    my $self = shift;
    return $self->strftime('%FT%T%z') . "\t" . $self->text;
}

1;
