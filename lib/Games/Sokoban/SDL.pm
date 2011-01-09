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
use File::ShareDir;
use Path::Class;

my $size = 32;

my $grid;
my @boxes;

my ($player_x,  $player_y,      $player_vx,
    $player_vy, $player_moving, $player_box
);

my $share_dir = Path::Class::Dir->new('share') or die $!;

#= Path::Class::Dir->new( File::ShareDir::dist_dir('Games-Sokoban-SDL') );

my $background = SDLx::Surface->new( w => 640, h => 480 );

my $wall = SDLx::Surface->load( $share_dir->file('wall.bmp') );
my $box  = SDLx::Surface->load( $share_dir->file('box.bmp') );
my $goal = SDLx::Surface->load( $share_dir->file('goal.bmp') );

my $player = SDLx::Sprite::Animated->new(
    image           => $share_dir->file('player.bmp'),
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

sub init_level {
    my $level
        = Games::Sokoban->new_from_file( $share_dir->file('level1.sok') );

    $background->draw_rect( [ 0, 0, 640, 480 ], 0x000000ff );
    my ( $x, $y ) = ( 0, 0 );
    foreach my $row ( $level->as_lines ) {
        $x = 0;
        foreach my $element ( split //, $row ) {
            given ($element) {
                $grid->[$x][$y] = $_;
                when ('#') {
                    $wall->blit(
                        $background,
                        [ 0,          0,          $size, $size ],
                        [ $x * $size, $y * $size, $size, $size ]
                    );
                }
                when ('.') {
                    $goal->blit(
                        $background,
                        [ 0,          0,          $size, $size ],
                        [ $x * $size, $y * $size, $size, $size ]
                    );
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

    $player_moving = 1;
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
        if ( !$player_moving && !$player_vx && !$player_vy ) {
            move_player('west')  if $e->key_sym == SDLK_LEFT;
            move_player('east')  if $e->key_sym == SDLK_RIGHT;
            move_player('north') if $e->key_sym == SDLK_UP;
            move_player('south') if $e->key_sym == SDLK_DOWN;
        }
    }
    elsif ( $e->type == SDL_KEYUP ) {
        if ($player_moving) {
            $player_moving = 0
                if $e->key_sym == SDLK_LEFT && $player_vx == -1;
            $player_moving = 0
                if $e->key_sym == SDLK_RIGHT && $player_vx == 1;
            $player_moving = 0 if $e->key_sym == SDLK_UP && $player_vy == -1;
            $player_moving = 0 if $e->key_sym == SDLK_DOWN && $player_vy == 1;
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
        $player_box = undef;
        if ( !$player_moving ) {
            $player_vx = 0;
            $player->stop();
        }
        else {
            move_player('west') if $player_vx == -1;
            move_player('east') if $player_vx == 1;
        }
    }

    if ( $player_vy && $player_y * $size == $y ) {
        $player_box = undef;
        if ( !$player_moving ) {
            $player_vy = 0;
            $player->stop();
        }
        else {
            move_player('north') if $player_vy == -1;
            move_player('south') if $player_vy == 1;
        }
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

my $app = SDLx::App->new(
    w            => 640,
    h            => 480,
    exit_on_quit => 1,
);

$app->add_show_handler( \&handle_show );
$app->add_event_handler( \&handle_event );
$app->add_move_handler( \&handle_move );

$player->alpha_key( [ 0, 0, 0 ] );
init_level();
$app->run();

1;
