#!/usr/bin/perl
use strict;
use warnings;

use SDL;
use SDL::Event;
use SDL::Rect;
use SDLx::App;
use SDLx::Sprite;
use SDLx::Sprite::Animated;
use SDLx::Surface;
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
        sprite => SDLx::Sprite::Animated->new(
            surface => $SURFACES{player},
            rect    => SDL::Rect->new( $x * $SIZE, $y * $SIZE, $SIZE, $SIZE ),
            ticks_per_frame => 10,
            sequences       => {
                'north' => [ [ 0, 1 ], [ 0, 2 ], [ 0, 0 ] ],
                'south' => [ [ 2, 1 ], [ 2, 2 ], [ 2, 0 ] ],
                'west'  => [ [ 3, 0 ], [ 3, 1 ], [ 3, 2 ] ],
                'east'  => [ [ 1, 0 ], [ 1, 1 ], [ 1, 2 ] ],
            },
            sequence => 'south',
            )->alpha_key( [ 255, 0, 0 ] ),
    );
    $PLAYER{sprite};
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
        sprite => SDLx::Sprite::Animated->new(
            surface => $SURFACES{goal},
            rect    => SDL::Rect->new( $x * $SIZE, $y * $SIZE, $SIZE, $SIZE ),
            ticks_per_frame => 10,
            type            => 'reverse',
            )->start(),
        };
}

sub move_player {
    my ($direction) = @_;

    $PLAYER{want_direction} = $direction;

    return if $PLAYER{moving};

    $PLAYER{sprite}->sequence($direction);

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
            $box->{x}    = $box_x;
            $box->{y}    = $box_y;
            $PLAYER{box} = $box;
        }
    }

    $PLAYER{x}         = $x;
    $PLAYER{y}         = $y;
    $PLAYER{dx}        = $dx;
    $PLAYER{dy}        = $dy;
    $PLAYER{moving}    = 1;
    $PLAYER{direction} = $direction;
    $PLAYER{sprite}->start();

    return 1;
}

sub stop_player {
    $PLAYER{want_direction} = undef;
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
    elsif ( $event->type == SDL_KEYUP ) {
        stop_player() if $event->key_sym == SDLK_LEFT;
        stop_player() if $event->key_sym == SDLK_RIGHT;
        stop_player() if $event->key_sym == SDLK_UP;
        stop_player() if $event->key_sym == SDLK_DOWN;
    }
}

sub handle_move {
    return unless $PLAYER{moving};

    $PLAYER{sprite}->x( $PLAYER{sprite}->x + $PLAYER{dx} );
    $PLAYER{sprite}->y( $PLAYER{sprite}->y + $PLAYER{dy} );

    if ( my $box = $PLAYER{box} ) {
        $box->{sprite}->x( $box->{sprite}->x + $PLAYER{dx} );
        $box->{sprite}->y( $box->{sprite}->y + $PLAYER{dy} );
    }

    if ( $PLAYER{dx} && $PLAYER{sprite}->x == $PLAYER{x} * $SIZE ) {
        $PLAYER{box}    = undef;
        $PLAYER{moving} = undef;
        $PLAYER{dx}     = 0;
        $PLAYER{sprite}->stop();
        move_player( $PLAYER{want_direction} ) if $PLAYER{want_direction};
    }

    if ( $PLAYER{dy} && $PLAYER{sprite}->y == $PLAYER{y} * $SIZE ) {
        $PLAYER{box}    = undef;
        $PLAYER{moving} = undef;
        $PLAYER{dy}     = 0;
        $PLAYER{sprite}->stop();
        move_player( $PLAYER{want_direction} ) if $PLAYER{want_direction};
    }
}

sub handle_show {
    $APP->draw_rect( undef, 0x000000FF );
    foreach my $wall (@WALLS) { $wall->{sprite}->draw($APP); }
    foreach my $goal (@GOALS) { $goal->{sprite}->draw($APP); }
    foreach my $box  (@BOXES) { $box->{sprite}->draw($APP); }
    $PLAYER{sprite}->draw($APP);
    $APP->update();
}

$APP->add_event_handler( \&handle_event );
$APP->add_move_handler( \&handle_move );
$APP->add_show_handler( \&handle_show );
init_level( Games::Sokoban->new_from_file( $SHARE->file('level1.sok') ) );
$APP->run();
