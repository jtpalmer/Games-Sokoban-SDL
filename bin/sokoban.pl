#!/usr/bin/perl
use strict;
use warnings;

use SDL;
use SDL::Event;
use SDLx::App;
use SDLx::Surface;
use SDLx::Sprite;
use Path::Class::Dir;
use Games::Sokoban;

my $SIZE = 32;

my %PLAYER;
my @WALLS;
my @BOXES;
my @GOALS;

my $SHARE = Path::Class::Dir->new('share') or die $!;

my %SURFACES = (
    player => SDLx::Surface->load( $SHARE->file('player.bmp') ),
    wall   => SDLx::Surface->load( $SHARE->file('wall.bmp') ),
    box    => SDLx::Surface->load( $SHARE->file('box.bmp') ),
    goal   => SDLx::Surface->load( $SHARE->file('goal.bmp') ),
);

my $APP = SDLx::App->new(
    w            => 640,
    h            => 480,
    title        => 'Sokoban',
    exit_on_quit => 1,
);

sub init_level {
    my ($level) = @_;

    @WALLS = ();
    @BOXES = ();
    @GOALS = ();

    my ( $x, $y ) = ( 0, 0 );
    foreach my $row ( $level->as_lines ) {
        $x = 0;
        foreach my $cell ( split //, $row ) {
            if ( $cell eq '#' ) {
                init_wall( $x, $y );
            }
            elsif ( $cell eq '$' ) {
                init_box( $x, $y );
            }
            elsif ( $cell eq '.' ) {
                init_goal( $x, $y );
            }
            elsif ( $cell eq '@' ) {
                init_player( $x, $y );
            }
            elsif ( $cell eq '*' ) {
                init_box( $x, $y );
                init_goal( $x, $y );
            }
            elsif ( $cell eq '+' ) {
                init_player( $x, $y );
                init_goal( $x, $y );
            }
            $x++;
        }
        $y++;
    }
}

sub init_player {
    my ( $x, $y ) = @_;

    %PLAYER = (
        x      => $x,
        y      => $y,
        sprite => SDLx::Sprite->new(
            surface => $SURFACES{player},
            x       => $x * $SIZE,
            y       => $y * $SIZE,
        ),
    );
}

sub init_wall {
    my ( $x, $y ) = @_;

    push @WALLS,
        {
        x      => $x,
        y      => $y,
        sprite => SDLx::Sprite->new(
            surface => $SURFACES{wall},
            x       => $x * $SIZE,
            y       => $y * $SIZE,
        ),
        };
}

sub init_box {
    my ( $x, $y ) = @_;

    push @BOXES,
        {
        x      => $x,
        y      => $y,
        sprite => SDLx::Sprite->new(
            surface => $SURFACES{box},
            x       => $x * $SIZE,
            y       => $y * $SIZE,
        ),
        };
}

sub init_goal {
    my ( $x, $y ) = @_;

    push @GOALS,
        {
        x      => $x,
        y      => $y,
        sprite => SDLx::Sprite->new(
            surface => $SURFACES{goal},
            x       => $x * $SIZE,
            y       => $y * $SIZE,
        ),
        };
}

sub move_player {
    my ($direction) = @_;

    my ( $dx, $dy ) = ( 0, 0 );
    $dx = -1 if $direction eq 'west';
    $dx = 1  if $direction eq 'east';
    $dy = -1 if $direction eq 'north';
    $dy = 1  if $direction eq 'south';

    my $x = $PLAYER{x} + $dx;
    my $y = $PLAYER{y} + $dy;

    if ( wall_at( $x, $y ) ) {
        return;
    }

    if ( my $box = box_at( $x, $y ) ) {
        my $box_x = $x + $dx;
        my $box_y = $y + $dy;
        if ( wall_at( $box_x, $box_y ) || box_at( $box_x, $box_y ) ) {
            return;
        }
        else {
            $box->{x} = $box_x;
            $box->{y} = $box_y;
            $box->{sprite}->x( $box_x * $SIZE );
            $box->{sprite}->y( $box_y * $SIZE );
        }
    }

    $PLAYER{x} = $x;
    $PLAYER{y} = $y;
    $PLAYER{sprite}->x( $x * $SIZE );
    $PLAYER{sprite}->y( $y * $SIZE );
}

sub wall_at {
    my ( $x, $y ) = @_;

    foreach my $wall (@WALLS) {
        return $wall if $wall->{x} == $x && $wall->{y} == $y;
    }
    return;
}

sub box_at {
    my ( $x, $y ) = @_;

    foreach my $box (@BOXES) {
        return $box if $box->{x} == $x && $box->{y} == $y;
    }
    return;
}

sub handle_event {
    my ($event) = @_;

    if ( $event->type == SDL_KEYDOWN ) {
        move_player('west')  if $event->key_sym == SDLK_LEFT;
        move_player('east')  if $event->key_sym == SDLK_RIGHT;
        move_player('north') if $event->key_sym == SDLK_UP;
        move_player('south') if $event->key_sym == SDLK_DOWN;
    }
}

sub handle_show {
    foreach my $wall (@WALLS) { $wall->{sprite}->draw($APP); }
    foreach my $goal (@GOALS) { $goal->{sprite}->draw($APP); }
    foreach my $box  (@BOXES) { $box->{sprite}->draw($APP); }
    $PLAYER{sprite}->draw($APP);
    $APP->update();
}

$APP->add_event_handler( \&handle_event );
$APP->add_show_handler( \&handle_show );
init_level( Games::Sokoban->new_from_file( $SHARE->file('level1.sok') ) );
$APP->run();
