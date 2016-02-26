package App::txtnix::Cache;
use Mojo::Base -base;
use Mojo::ByteStream 'b';
use Path::Tiny;
use Mojo::JSON qw(encode_json decode_json);

has cache_dir => sub {
    my $dir = path('~/.cache/txtnix/');
    $dir->mkpath if not $dir->exists;
    return $dir;
};

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

sub clean {
    my ( $self, @valid_keys ) = @_;
    my %valid_id = map { b($_)->b64_encode('') => 1 } @valid_keys;
    for my $file ( $self->cache_dir->children ) {
        $file->remove if not $valid_id{ $file->basename };
    }
    return;
}

1;
