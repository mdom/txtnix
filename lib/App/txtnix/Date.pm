package App::txtnix::Date;
use strict;
use warnings;
use Mojo::Date;
use base 'Exporter';

our @EXPORT_OK = 'to_date';

sub to_date {
    my ($date) = @_;
    $date =~ s/T(\d\d:\d\d)([Z+-])/T$1:00$2/;
    $date =~ s/([+-]\d\d)(\d\d)/$1:$2/;
    return Mojo::Date->new($date);
}

1;
