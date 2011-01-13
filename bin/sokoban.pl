#!/usr/bin/perl
use strict;
use warnings;

use SDL;
use SDLx::App;

my $APP = SDLx::App->new(
    w            => 640,
    h            => 480,
    title        => 'Sokoban',
    exit_on_quit => 1,
);

$APP->run();
