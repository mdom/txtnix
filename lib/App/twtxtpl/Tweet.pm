package App::twtxtpl::Tweet;
use strict;
use warnings;
use Mojo::Date;
use POSIX ();
use Moo;

has user      => ( is => 'ro' );
has timestamp => ( is => 'ro', coerce => \&to_time_piece );
has text      => ( is => 'ro' );

sub to_time_piece{
	return Mojo::Date->new(shift);
}

sub strftime {
	my ($self,$format ) = @_;
	$DB::single=1;
	return POSIX::strftime($format, gmtime shift->timestamp->epoch);
}

1;
