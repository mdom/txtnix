use strict;
use warnings;
use Test::More;
use App::txtnix;
use FindBin qw($Bin);

my $twtxt = App::txtnix->new( config_file => "$Bin/config" );

is( $twtxt->collapse_mentions('@<foo https://example.com/foo/twtxt.txt>'),
    '@foo' );
is( $twtxt->collapse_mentions('@<bar https://example.com/bar/twtxt.txt>'),
    '@<bar https://example.com/bar/twtxt.txt>' );
is( $twtxt->expand_mentions('@foo'),
    '@<foo https://example.com/foo/twtxt.txt>' );
is( $twtxt->expand_mentions('@bar'), '@bar' );

$twtxt->config->embed_names(0);
is( $twtxt->expand_mentions('@foo'), '@<https://example.com/foo/twtxt.txt>' );

## with nick and twturl
is( $twtxt->collapse_mentions('@<mdom http://www.domgoergen.com/twtxt.txt>'),
    '@mdom' );

## with twtwurl but no nick
$twtxt->config->nick(undef);
is( $twtxt->collapse_mentions('@<mdom http://www.domgoergen.com/twtxt.txt>'),
    '@<mdom http://www.domgoergen.com/twtxt.txt>' );

## without twturl and nick
$twtxt->config->twturl(undef);
is( $twtxt->collapse_mentions('@<mdom http://www.domgoergen.com/twtxt.txt>'),
    '@<mdom http://www.domgoergen.com/twtxt.txt>' );

## which nick but no twturl
$twtxt->config->nick('mdom');
is( $twtxt->collapse_mentions('@<mdom http://www.domgoergen.com/twtxt.txt>'),
    '@<mdom http://www.domgoergen.com/twtxt.txt>' );

done_testing;
