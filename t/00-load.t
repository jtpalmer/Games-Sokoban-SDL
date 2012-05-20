#!perl
use strict;
use warnings;
use Test::More;

BEGIN {
    my @modules = qw(
        Games::Sokoban::SDL
    );

    for my $module (@modules) {
        use_ok($module) or BAIL_OUT("Failed to load $module");
    }
}

diag(
    sprintf(
        'Testing Games::Sokoban::SDL %f, Perl %f, %s',
        $Games::Sokoban::SDL::VERSION, $], $^X
    )
);

done_testing();

