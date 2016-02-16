package App::twtxtpl::Cache;
use strict;
use warnings;
use Moo;
use Mojo::ByteStream 'b';
use Path::Tiny;
use Mojo::JSON qw(encode_json decode_json);

has cache_dir => ( is => 'lazy' );

sub _build_cache_dir {
    my $dir = path('~/.cache/twtxtpl/');
    $dir->mkpath if not $dir->exists;
    return $dir;
}

sub get {
    my ( $self, $key ) = @_;
    my $id         = b($key)->b64_encode('');
    my $cache_file = $self->cache_dir->child($id);
    return undef if !$cache_file->exists;
    return decode_json( $cache_file->slurp_utf8 );
}

sub set {
    my ( $self, $key, $last_modified, $body ) = @_;
    my $id         = b($key)->b64_encode('');
    my $cache_file = $self->cache_dir->child($id);
    return $cache_file->spew_utf8(
        encode_json( { last_modified => $last_modified, body => $body } ) );
}

1;