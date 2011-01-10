package Games::Sokoban::SDL;

# ABSTRACT: Sokoban game

use Modern::Perl;
use SDL;
use SDL::Event;
use SDL::Events ':all';
use SDL::Rect;
use SDLx::App;
use SDLx::Sprite;
use SDLx::Sprite::Animated;
use Games::Sokoban;
use Path::Class;

# Tile width and height
my $size = 32;

# Game state
my $grid;
my @boxes;

# Player state
my ( $player, $player_x, $player_y, $player_vx, $player_vy, $player_moving,
    $player_direction, $player_box );

# Surfaces
my ( $background, $wall, $box, $goal );

# Share directory
my $share;

sub init_level {
    my $level = Games::Sokoban->new_from_file( $share->file('level1.sok') );

    @boxes = ();
    $background->draw_rect( undef, 0x000000ff );

    my ( $x, $y ) = ( 0, 0 );
    foreach my $row ( $level->as_lines ) {
        $x = 0;
        foreach my $element ( split //, $row ) {
            given ($element) {
                $grid->[$x][$y] = $_;
                when ('#') {
                    $wall->blit( $background, undef,
                        [ $x * $size, $y * $size, $size, $size ] );
                }
                when ('.') {
                    $goal->blit( $background, undef,
                        [ $x * $size, $y * $size, $size, $size ] );
                }
                when ('$') {
                    push @boxes,
                        SDLx::Sprite->new(
                        surface => $box,
                        x       => $x * $size,
                        y       => $y * $size,
                        );
                }
                when ('@') {
                    $player_x      = $x;
                    $player_y      = $y;
                    $player_vx     = 0;
                    $player_vy     = 0;
                    $player_moving = 0;
                    $player->x( $x * $size );
                    $player->y( $y * $size );
                }
            }
            $x++;
        }
        $y++;
    }
}

sub move_player {
    my ($direction) = @_;

    my ( $old_x, $old_y ) = ( $player_x, $player_y );

    $player_moving    = 1;
    $player_direction = $direction;
    $player->sequence($direction);
    $player->start();

    given ($direction) {
        when ('west') {
            $player_x--;
            $player_vx = -1;
        }
        when ('east') {
            $player_x++;
            $player_vx = 1;
        }
        when ('north') {
            $player_y--;
            $player_vy = -1;
        }
        when ('south') {
            $player_y++;
            $player_vy = 1;
        }
    }

    my $collision;
    given ( $grid->[$player_x][$player_y] ) {
        when ('#') {
            $collision = 1;
        }
        when ('$') {
            my $box_x    = $player_x + $player_vx;
            my $box_y    = $player_y + $player_vy;
            my $box_cell = $grid->[$box_x][$box_y];
            if ( $box_cell eq '#' || $box_cell eq '$' ) {
                $collision = 1;
            }
            else {
                ($player_box) = grep {
                           $_->x() eq $player_x * $size
                        && $_->y() eq $player_y * $size
                } @boxes;
                $grid->[$player_x][$player_y] = ' ';
                $grid->[$box_x][$box_y]       = '$';
            }
        }
    }

    if ($collision) {
        $player_x      = $old_x;
        $player_y      = $old_y;
        $player_vx     = 0;
        $player_vy     = 0;
        $player_moving = 0;
        $player->stop();
    }
}

sub handle_event {
    my ( $e, $app ) = @_;

    if ( $e->type == SDL_KEYDOWN ) {
        init_level() if SDL::Events::get_key_name( $e->key_sym ) eq 'r';

        if ( !$player_moving && !$player_vx && !$player_vy ) {
            move_player('west')  if $e->key_sym == SDLK_LEFT;
            move_player('east')  if $e->key_sym == SDLK_RIGHT;
            move_player('north') if $e->key_sym == SDLK_UP;
            move_player('south') if $e->key_sym == SDLK_DOWN;
        }
        else {
            $player_direction = 'west'  if $e->key_sym == SDLK_LEFT;
            $player_direction = 'east'  if $e->key_sym == SDLK_RIGHT;
            $player_direction = 'north' if $e->key_sym == SDLK_UP;
            $player_direction = 'south' if $e->key_sym == SDLK_DOWN;
        }
    }
    elsif ( $e->type == SDL_KEYUP ) {
        if ($player_direction) {
            $player_direction = undef
                if $e->key_sym == SDLK_LEFT && $player_direction eq 'west';
            $player_direction = undef
                if $e->key_sym == SDLK_RIGHT && $player_direction eq 'east';
            $player_direction = undef
                if $e->key_sym == SDLK_UP && $player_direction eq 'north';
            $player_direction = undef
                if $e->key_sym == SDLK_DOWN && $player_direction eq 'south';
        }
    }

    return 1;
}

sub handle_move {
    my ( $step, $app, $t ) = @_;

    my $x = $player->x + $player_vx;
    my $y = $player->y + $player_vy;

    if ($player_box) {
        $player_box->x( $player_box->x + $player_vx );
        $player_box->y( $player_box->y + $player_vy );
    }

    if ( $player_vx && $player_x * $size == $x ) {
        $player_box    = undef;
        $player_moving = undef;
        $player_vx     = 0;
        $player->stop();
        move_player($player_direction) if $player_direction;
    }

    if ( $player_vy && $player_y * $size == $y ) {
        $player_box    = undef;
        $player_moving = undef;
        $player_vy     = 0;
        $player->stop();
        move_player($player_direction) if $player_direction;
    }

    $player->x($x);
    $player->y($y);
}

sub handle_show {
    my ( $delta, $app ) = @_;

    $background->blit($app);
    foreach my $box (@boxes) { $box->draw($app); }
    $player->draw($app);
    $app->update();
}

sub run {
    my $app = SDLx::App->new(
        w            => 640,
        h            => 480,
        exit_on_quit => 1,
    );

    $app->add_show_handler( \&handle_show );
    $app->add_event_handler( \&handle_event );
    $app->add_move_handler( \&handle_move );

    $share = Path::Class::Dir->new('share') or die $!;

    $background = SDLx::Surface->new( w => $app->w, h => $app->h );
    $wall       = SDLx::Surface->load( $share->file('wall.bmp') );
    $box        = SDLx::Surface->load( $share->file('box.bmp') );
    $goal       = SDLx::Surface->load( $share->file('goal.bmp') );

    $player = SDLx::Sprite::Animated->new(
        image           => $share->file('player.bmp'),
        rect            => SDL::Rect->new( 0, 0, $size, $size ),
        ticks_per_frame => 10,
        sequences       => {
            'north' => [ [ 0, 1 ], [ 0, 2 ], [ 0, 0 ] ],
            'south' => [ [ 2, 1 ], [ 2, 2 ], [ 2, 0 ] ],
            'west'  => [ [ 3, 0 ], [ 3, 1 ], [ 3, 2 ] ],
            'east'  => [ [ 1, 0 ], [ 1, 1 ], [ 1, 2 ] ],
        },
    );
    $player->sequence('south');
    $player->alpha_key( [ 255, 0, 0 ] );

    init_level();

    $app->run();
}

run() unless caller();

1;
