use strict;
use warnings;
use Test::More;
use App::txtnix;
use FindBin qw($Bin);
use Path::Tiny;

my $empty_config = Path::Tiny->tempfile;

my $app;

$app = App::txtnix->new(
    nick              => 'mdom',
    twturl            => 'http://www.domgoergen.com/twtxt.txt',
    disclose_identity => 0,
    config            => "$empty_config"
);

is( $app->ua->transactor->name, "txtnix/$App::txtnix::VERSION" );

$app = App::txtnix->new(
    nick              => 'mdom',
    twturl            => 'http://www.domgoergen.com/twtxt.txt',
    disclose_identity => 1,
    config            => "$empty_config"
);

is( $app->ua->transactor->name,
"txtnix/$App::txtnix::VERSION (+http://www.domgoergen.com/twtxt.txt; \@mdom)"
);

$app = App::txtnix->new(
    twturl            => 'http://www.domgoergen.com/twtxt.txt',
    disclose_identity => 1,
    config            => "$empty_config"
);
is( $app->ua->transactor->name, "txtnix/$App::txtnix::VERSION" );

$app = App::txtnix->new(
    nick              => 'mdom',
    disclose_identity => 1,
    config            => "$empty_config"
);
is( $app->ua->transactor->name, "txtnix/$App::txtnix::VERSION" );

done_testing;
