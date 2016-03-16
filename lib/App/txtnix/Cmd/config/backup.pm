package App::txtnix::Cmd::config::backup;
use Mojo::Base 'App::txtnix';

sub run {
    my ( $self, $opts ) = @_;
    $self->config_file->copy(
        $self->config_file->parent->child(
            'config-' . Mojo::Date->new->to_datetime
        )
    );
    return 0;
}

1;
