package App::twtxtpl::Tweet;
use strict;
use warnings;
use Moo;

has user      => ( is => 'ro' );
has timestamp => ( is => 'ro' );
has text      => ( is => 'ro' );

1;
