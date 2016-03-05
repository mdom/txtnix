package App::txtnix::Cache;
use Mojo::Base -base;
use Mojo::ByteStream 'b';
use Path::Tiny;
use Mojo::JSON qw(encode_json decode_json);

has cache_dir => sub { path('~/.cache/txtnix/') };

sub new {
    my $class = shift;
    my $self = bless @_ ? @_ > 1 ? {@_} : { %{ $_[0] } } : {},
      ref $class || $class;
    $self->cache_dir->mkpath if not $self->cache_dir->exists;
    return $self;
}

sub get {
    my ( $self, $key ) = @_;
    my $id         = b($key)->b64_encode('');
    my $cache_file = $self->cache_dir->child($id);
    return undef if !$cache_file->exists;
    return decode_json( $cache_file->slurp_utf8 );
}

sub set {
    my ( $self, $key, $hash ) = @_;
    my $id         = b($key)->b64_encode('');
    my $cache_file = $self->cache_dir->child($id);
    return $cache_file->spew_utf8( encode_json($hash) );
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
