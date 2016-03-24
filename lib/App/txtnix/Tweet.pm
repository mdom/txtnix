package App::txtnix::Tweet;
use Mojo::Base -base;
use Mojo::ByteStream 'b';
use Mojo::Date;
use Time::Duration qw(concise ago);
use App::txtnix::Date qw(to_date);
use POSIX ();

has [qw(source text)];
has timestamp => sub { Mojo::Date->new() };

has is_metadata => sub { !!@{ shift->command } };
has command     => sub { [] };

sub strftime {
    my ( $self, $format ) = @_;
    if ( $format eq 'relative' ) {
        return concise(
            ago( ( int( ( time - $self->timestamp->epoch ) / 60 ) ) * 60 ) );
    }
    return POSIX::strftime( $format, localtime $self->timestamp->epoch );
}

sub to_string {
    my $self = shift;
    return $self->timestamp->to_datetime . "\t" . $self->text;
}

sub md5_hash {
    my $self = shift;
    return b( $self->timestamp . $self->text )->encode->md5_sum;
}

sub from_string {
    my ( $class, $line, $source ) = @_;
    return unless $line;
    my ( $time, $sep, $text ) = $line =~ /(.+?)(\s+|#)(.+)/;
    return unless $time && $sep && $text;
    $text =~ s/\P{XPosixPrint}//g;

    $time = to_date($time);
    return if !defined $time->epoch;

    my $command = $sep eq '#' ? [ split( ' ', $text ) ] : [];

    if ( $time and $text ) {
        return $class->new(
            source    => $source,
            timestamp => $time,
            text      => $text,
            command   => $command,

        );
    }
    return;
}

1;
