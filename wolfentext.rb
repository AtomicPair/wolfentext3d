#!/usr/bin/env ruby

#################################################################################
#                                                                               #
# Wolfentext3D                                                                  #
#                                                                               #
# Copyright (c) 2016 Adam Parrott <parrott.adam@gmail.com>                      #
#                                                                               #
# Permission is hereby granted, free of charge, to any person obtaining a copy  #
# of this software and associated documentation files (the "Software"), to deal #
# in the Software without restriction, including without limitation the rights  #
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell     #
# copies of the Software, and to permit persons to whom the Software is         #
# furnished to do so, subject to the following conditions:                      #
#                                                                               #
# The above copyright notice and this permission notice shall be included in    #
# all copies or substantial portions of the Software.                           #
#                                                                               #
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR    #
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,      #
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE   #
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER        #
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, #
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN     #
# THE SOFTWARE.                                                                 #
#                                                                               #
# For more information about this script, please visit the official repo:       #
#                                                                               #
# http://www.github.com/AtomicPair/wolfentext3d/                                #
#                                                                               #
#################################################################################

VERSION = "0.5.1"

# Handles color information and application for the game.
#
# @author Adam Parrott <parrott.adam@gmail.com>
#
module Color
  BLACK         = 30
  BLUE          = 34
  CYAN          = 36
  GRAY          = 90
  GREEN         = 32
  LIGHT_BLUE    = 94
  LIGHT_CYAN    = 96
  LIGHT_GRAY    = 37
  LIGHT_GREEN   = 92
  LIGHT_MAGENTA = 95
  LIGHT_RED     = 91
  LIGHT_YELLOW  = 93
  MAGENTA       = 35
  RED           = 31
  WHITE         = 97
  YELLOW        = 33

  MODE_NONE    = 1
  MODE_PARTIAL = 2
  MODE_FILL    = 3

  # Colorizes a given piece of text for display in the terminal.
  #
  # @param  [String]  value Text value to colorize
  # @param  [Integer] color Terminal color code to use for colorizing
  # @option [Integer] mode  Desired color mode to use (Color::MODE_X)
  #
  def self.colorize( value, color, mode = 0 )
    case mode
    when MODE_NONE
      value
    when MODE_PARTIAL
      "\e[1;#{ color }m#{ value }\e[0m";
    when MODE_FILL
      "\e[7;#{ color };#{ color + 10 }m \e[0m";
    end
  end
end

# Contains static game helper functions.
#
# @author Adam Parrott <parrott.adam@gmail.com>
#
module GameHelpers
  # Custom puts output method to handle unique console configuration.
  #
  # @param [String] The text value to be output to the console
  #
  def puts( string = "" )
    STDOUT.write "#{ string }\r\n"
  end

  # Helper function to convert degrees to radians.
  #
  # @param [Float] value Value in degrees to be converted to radians
  #
  def radians( value )
    value * 0.0174533
  end
end

# Handles all keyboard input for the game.
#
# @author Muriel Salvan <http://blog.x-aeon.com/2014/03/26/how-to-read-one-non-blocking-key-press-in-ruby/>
# @author James Edward Gray II <http://graysoftinc.com/terminal-tricks/random-access-terminal>
# @author Adam Parrott <parrott.adam@gmail.com>
#
module GameInput
  require 'io/console'
  require 'io/wait'

  # Since the require statement driving this condition could still fail
  # on some Windows systems, this is not an ideal solution.  TODO: we should
  # ask the OS to identify itself, then resolve from there. [ABP 201603013]
  #
  WINDOWS_INPUT = begin
    require 'Win32API'
    WINDOWS_GET_CHAR = Win32API.new( 'crtdll', '_getch', [], 'L' )
    WINDOWS_KB_HIT = Win32API.new( 'crtdll', '_kbhit', [], 'I' )
    true
  rescue LoadError
    false
  end

  # Clears the current input buffer of any data.
  #
  def clear_input
    STDIN.ioflush
    self.get_key
  end

  # Waits for and returns the first character entered by a user.
  #
  def wait_key
    if WINDOWS_INPUT
      input = WINDOWS_GET_CHAR.Call.chr( Encoding::UTF_8 )

      if input == "\u00E0"
        input << WINDOWS_GET_CHAR.Call.chr( Encoding::UTF_8 )
      end
    else
      input = STDIN.getc.chr
    end

    return input
  end

  # Returns the first key found in the current input buffer.
  #
  def get_key
    if WINDOWS_INPUT
      if WINDOWS_KB_HIT.Call.zero?
        input = nil
      else
        input = WINDOWS_GET_CHAR.Call.chr( Encoding::UTF_8 )

        if input == "\u00E0"
          input << WINDOWS_GET_CHAR.Call.chr( Encoding::UTF_8 )
        end
      end
    else
      input = STDIN.read_nonblock( 1 ).chr rescue nil

      if input == "\e"
        input << STDIN.read_nonblock( 3 ) rescue nil
        input << STDIN.read_nonblock( 2 ) rescue nil
      end
    end

    return input
  end
end

# Main game class
#
# @author Adam Parrott <parrott.adam@gmail.com>
#
class Game
  include GameHelpers
  include GameInput
  include Math

  MAP_EMPTY_CELL = "."
  WIPE_BLINDS = 1
  WIPE_PIXELIZE_IN = 2
  WIPE_PIXELIZE_OUT = 3

  def initialize
    setup_variables
    setup_tables
    setup_map
    setup_input
  end

  # This is where the magic happens.  :-)
  #
  def play
    show_title_screen
    reset_frame_rate
    update_buffer

    while true
      check_input
      update_frame_rate
      draw_debug_info if @display_debug_info
      sleep 0.01

      @frames_rendered += 1
    end
  end

  private

  # Checks whether the player has collided with a wall.
  #
  def check_collisions
    @x_cell = @player_x / @cell_width
    @y_cell = @player_y / @cell_height
    @x_sub_cell = @player_x % @cell_width
    @y_sub_cell = @player_y % @cell_height

    if @move_x > 0
      # Player is moving right
      unless @map[ @y_cell ][ @x_cell + 1 ] == MAP_EMPTY_CELL
        if @map[ @y_cell ][ @x_cell + 1 ] == "E"
          show_end_screen
        elsif @x_sub_cell > ( @cell_width - @cell_margin )
          @move_x -= @x_sub_cell - ( @cell_width - @cell_margin )
        end
      end
    else
      # Player is moving left
      unless @map [ @y_cell ][ @x_cell - 1 ] == MAP_EMPTY_CELL
        if @map[ @y_cell ][ @x_cell - 1 ] == "E"
          show_end_screen
        elsif @x_sub_cell < @cell_margin
          @move_x += @cell_margin - @x_sub_cell
        end
      end
    end

    if @move_y > 0
      # Player is moving up
      unless @map[ @y_cell + 1 ][ @x_cell ] == MAP_EMPTY_CELL
        if @map[ @y_cell + 1 ][ @x_cell ] == "E"
          show_end_screen
        elsif @y_sub_cell > ( @cell_height - @cell_margin )
          @move_y -= @y_sub_cell - ( @cell_height - @cell_margin )
        end
      end
    else
      # Player is moving down
      unless @map[ @y_cell - 1 ][ @x_cell ] == MAP_EMPTY_CELL
        if @map[ @y_cell - 1 ][ @x_cell ] == "E"
          show_end_screen
        elsif @y_sub_cell < @cell_margin
          @move_y += @cell_margin - @y_sub_cell
        end
      end
    end

    @player_x += @move_x
    @player_y += @move_y
  end

  # Waits for and processes keyboard input from user.
  #
  # @see https://gist.github.com/acook/4190379
  #
  def check_input
    key = get_key

    return if key.nil?

    case key
      # Escape
      when "\e"

      # Up arrow
      when "\e[A", "\u00E0H", "w"
        @move_x = ( @cos_table[ @player_angle ] * 4 ).round
        @move_y = ( @sin_table[ @player_angle ] * 4 ).round
        check_collisions
        update_buffer

      # Down arrow
      when "\e[B", "\u00E0P", "s"
        @move_x = -( @cos_table[ @player_angle ] * 4 ).round
        @move_y = -( @sin_table[ @player_angle ] * 4 ).round
        check_collisions
        update_buffer

      # Right arrow
      when "\e[C", "\u00E0M", "d"
        @player_angle = ( @player_angle + @angles[ 2 ] ) % @angles[ 360 ]
        update_buffer

      # Left arrow
      when "\e[D", "\u00E0K", "a"
        @player_angle = ( @player_angle - @angles[ 2 ] + @angles[ 360 ] ) % @angles[ 360 ]
        update_buffer

      # Ctrl-C
      when "\u0003"
        exit 0

      when "1", "2", "3"
        @color_mode = key.to_i
        update_buffer

      when "c"
        @draw_ceiling = !@draw_ceiling
        update_buffer

      when "?"
        show_debug_screen

      when "f"
        @draw_floor = !@draw_floor
        update_buffer

      when "h"
        show_help_screen

      when "i"
        @display_debug_info = !@display_debug_info
        clear_screen true
        update_buffer

      when "m"
        draw_screen_wipe WIPE_PIXELIZE_IN
        @player_x = @magic_x unless @magic_x.nil?
        @player_y = @magic_y unless @magic_y.nil?
        update_buffer
        draw_screen_wipe WIPE_PIXELIZE_OUT
        update_buffer

      when "q"
        show_exit_screen
    end
  end

  # Clears the current screen buffer.
  #
  def clear_buffer
    @buffer.map! do |row|
      row.map! do |char|
        ""
      end
    end
  end

  # Clears the current screen.
  #
  def clear_screen( full = false )
    puts "\e[2J" if full
    puts "\e[0;0H"
  end

  # Draws the current buffer to the screen.
  #
  def draw_buffer
    puts @buffer.map { |b| b.join }.join( "\r\n" )
  end

  # Draws extra information onto HUD.
  #
  def draw_debug_info
    STDOUT.write "\e[1;#{ @screen_width - 10 }H"
    STDOUT.write " #{ '%.2f' % @frame_rate } fps "
  end

  # Applies the selected screen wipe/transition to the active buffer.
  #
  # @param [Integer] type Desired wipe mode to use (WIPE_X)
  #
  def draw_screen_wipe( type )
    case type
    when WIPE_BLINDS
      for j in 5.downto( 1 )
        for y in ( 0...@buffer.size ).step( j )
          for x in 0...@buffer[ y ].size
            @buffer[ y ][ x ] = ""
          end
        end

        clear_screen true
        draw_buffer
        sleep 0.25
      end

    when WIPE_PIXELIZE_IN
      ( 0..( @screen_height - 1 ) * @screen_width ).to_a.shuffle.each_with_index do |i, j|
        @buffer[ i / @screen_width ][ i % @screen_width ] = Color.colorize( " ", Color::WHITE, @color_mode )

        if j % ( 4 ** @color_mode ) == 0
          clear_screen
          draw_buffer
        end
      end

    when WIPE_PIXELIZE_OUT
      @backup_buffer = Marshal.load( Marshal.dump( @buffer ) )

      @buffer.map! do |row|
        row.map! do |item|
          Color.colorize( " ", Color::WHITE, @color_mode )
        end
      end

      ( 0..( @screen_height - 1 ) * @screen_width ).to_a.shuffle.each_with_index do |i, j|
        @buffer[ i / @screen_width ][ i % @screen_width ] = @backup_buffer[ i / @screen_width ][ i % @screen_width ]

        if j % ( 4 ** @color_mode ) == 0
          clear_screen
          draw_buffer
        end
      end
    end
  end

  # Displays the current status line on the screen.
  #
  def draw_status_line
    @status_x = @player_x.to_s.rjust( 3 )
    @status_y = @player_y.to_s.rjust( 3 )
    @status_angle = ( ( @player_angle / @fixed_step ).round ).to_s.rjust( 3 )

    @status_left = "(Press H for help)".ljust( 18 )
    @status_middle = @hud_messages[ @play_count % 3 ].center( 44 )
    @status_right = "#{ @status_x } x #{ @status_y } / #{ @status_angle }°".ljust( 18 )

    puts @status_left + @status_middle + @status_right
  end

  # Our ray casting engine, AKA The Big Kahuna(TM).
  #
  # Many thanks to Andre LaMothe for serving as the inspiration behind
  # the original engine that drives this ray caster today.
  #
  # @author Adam Parrott <parrott.adam@gmail.com>
  # @author Andre LaMothe <andre@gameinstitute.com>
  #
  # @param [Integer] x_start Starting X world coordinate to use for casting
  # @param [Integer] y_start Starting Y world coordinate to use for casting
  # @param [Float]   angle   Starting viewing angle to use for casting
  #
  def ray_cast( x_start, y_start, angle )
    @view_angle = ( angle - @angles[ 30 ] + @angles[ 360 ] ) % @angles[ 360 ]

    for ray in 1..@screen_width
      if @view_angle >= @angles[ 0 ] && @view_angle < @angles[ 180 ]
        # Upper half plane
        #
        @y_bound = @cell_height + @cell_height * ( y_start / @cell_height )
        @y_delta = @cell_height
        @xi = @inv_tan_table[ @view_angle ] * ( @y_bound - y_start ) + x_start
        @next_y_cell = 0
      else
        # Lower half plane
        #
        @y_bound = @cell_height * ( y_start / @cell_height )
        @y_delta = -@cell_height
        @xi = @inv_tan_table[ @view_angle ] * ( @y_bound - y_start ) + x_start
        @next_y_cell = -1
      end

      if @view_angle < @angles[ 90 ] || @view_angle >= @angles[ 270 ]
        # Right half plane
        #
        @x_bound = @cell_width + @cell_width * ( x_start / @cell_width )
        @x_delta = @cell_width
        @yi = @tan_table[ @view_angle ] * ( @x_bound - x_start ) + y_start
        @next_x_cell = 0
      else
        # Left half plane
        #
        @x_bound = @cell_width * ( x_start / @cell_width )
        @x_delta = -@cell_width
        @yi = @tan_table[ @view_angle ] * ( @x_bound - x_start ) + y_start
        @next_x_cell = -1
      end

      @x_ray = false
      @x_cell = 0
      @x_dist = 0
      @x_x_save = 0
      @x_y_save = 0

      @y_ray = false
      @y_cell = 0
      @y_dist = 0
      @y_x_save = 0
      @y_y_save = 0

      @casting = 2

      while @casting > 0
        unless @x_ray
          if @y_step[ @view_angle ].abs == 0 || !@x_bound.between?( 0, @map_x_size )
            @x_ray = true
            @casting -= 1
            @x_dist = 1e+8
          end

          @x_cell = ( ( @x_bound + @next_x_cell ) / @cell_width ).to_i
          @y_cell = ( @yi.to_i / @cell_height ).to_i
          @hit_type = @map[ @y_cell ][ @x_cell ] rescue MAP_EMPTY_CELL

          if @hit_type != MAP_EMPTY_CELL
            @x_dist = ( @yi - y_start ) * @inv_sin_table[ @view_angle ]
            @x_map = @map[ @y_cell ][ @x_cell ]
            @yi_save = @yi
            @xb_save = @x_bound
            @x_x_save = @x_cell
            @x_y_save = @y_cell

            @x_ray = true
            @casting -= 1
          else
            @yi += @y_step[ @view_angle ]
          end
        end

        unless @y_ray
          if @x_step[ @view_angle ].abs == 0 || !@y_bound.between?( 0, @map_y_size )
            @y_ray = true
            @casting -= 1
            @y_dist = 1e+8
          end

          @x_cell = ( @xi.to_i / @cell_width ).to_i
          @y_cell = ( ( @y_bound + @next_y_cell ) / @cell_height ).to_i
          @hit_type = @map[ @y_cell ][ @x_cell ] rescue MAP_EMPTY_CELL

          if @hit_type != MAP_EMPTY_CELL
            @y_dist = ( @xi - x_start ) * @inv_cos_table[ @view_angle ]
            @y_map = @map[ @y_cell ][ @x_cell ]
            @xi_save = @xi
            @yb_save = @y_bound
            @y_x_save = @x_cell
            @y_y_save = @y_cell

            @y_ray = true
            @casting -= 1
          else
            @xi += @x_step[ @view_angle ]
          end
        end

        @x_bound += @x_delta
        @y_bound += @y_delta
      end

      if @x_dist < @y_dist
        @map_type = @x_map
        @map_x = @x_x_save
        @map_y = @x_y_save
        @scale = @fish_eye_table[ ray ] * ( 2048 / ( 1e-10 + @x_dist ) )
      else
        @map_type = @y_map
        @map_x = @y_x_save
        @map_y = @y_y_save
        @scale = @fish_eye_table[ ray ] * ( 2048 / ( 1e-10 + @y_dist ) )
      end

      @wall_scale = ( @scale / 2 ).to_i
      @wall_top = ( @screen_height / 2 ) - @wall_scale
      @wall_bottom = ( @screen_height / 2 ) + @wall_scale
      @wall_color = @wall_colors[ @map_type ]
      @wall_texture = ( 32 + @map_type.to_i ).chr
      @wall_sliver = Color.colorize( @wall_texture, @wall_color, @color_mode )

      @ceiling_sliver = if @draw_ceiling
                          Color.colorize( @ceiling_texture, Color::LIGHT_GRAY, @color_mode )
                        else
                          " "
                        end
      @floor_sliver = if @draw_floor
                          Color.colorize( @floor_texture, Color::GRAY, @color_mode )
                        else
                          " "
                        end

      @sliver  = "#{ @ceiling_sliver }," * [ @wall_top - 1, 0 ].max
      @sliver += "#{ @wall_sliver },"    * ( @wall_bottom - @wall_top + 1 )
      @sliver += "#{ @floor_sliver },"   * [ @screen_height - @wall_bottom, 0 ].max

      @final_sliver = @sliver.split( "," )

      for y in 0...@screen_height
        @buffer[ y ][ ray ] = @final_sliver[ y ]
      end

      @view_angle = ( @view_angle + 1 ) % @angles[ 360 ]
    end
  end

  # Resets the frame rate metrics.
  #
  def reset_frame_rate
    @frames_rendered = 0
    @frame_start_time = Time.now
    @frame_rate = 0.0
  end

  # Resets the console input stream back to default.
  #
  def reset_input
    STDIN.cooked!
    STDOUT.write "\e[?25h"
  end

  # Resets player's position.
  #
  def reset_player
    @player_angle = @starting_angle
    @player_x = @starting_x
    @player_y = @starting_y
  end

  # Configures the console input stream for game usage.
  #
  def setup_input
    STDIN.raw!
    STDIN.echo = false
    STDOUT.write "\e[?25l"

    at_exit do
      reset_input
    end
  end

  # Configures the world map.
  #
  def setup_map
    # Are you cheating by looking at this map?  Maybe we should apply some
    # run-length encoding to this data so it's no so easy for the casual
    # observer to admire it's contents. :-) [ABP 20160308]
    #
    @map = \
    [
      %w( 5 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 5 ),
      %w( 2 P . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 2 ),
      %w( 2 . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 2 ),
      %w( 2 . . 2 1 1 1 1 1 1 1 1 2 . 2 1 1 1 1 1 1 1 2 . 2 1 1 1 2 . . 2 ),
      %w( 2 . . 1 . . . . . . . . . . . . . . . . . . . . . . . . 1 . . 2 ),
      %w( 2 . . 1 . . . . . . . . . . . . . . . . . . . . . . . . 1 . . 2 ),
      %w( 2 . . 1 . . 3 4 4 4 4 4 4 4 4 3 . 3 4 4 4 4 4 4 4 3 . . 1 . . 2 ),
      %w( 2 . . 1 . . 4 . . . . . . . . . . . . . . . . . . 4 . . 1 . . 2 ),
      %w( 2 . . 1 . . 4 . . . . . . . . . . . . . . . . . . 4 . . 1 . . 2 ),
      %w( 2 . . 1 . . 4 . . 4 3 3 3 3 3 3 3 3 3 3 3 3 4 . . 4 . . 1 . . 2 ),
      %w( 2 . . 1 . . 4 . . 3 . . . . . . . . . . . . 3 . . 4 . . 1 . . 2 ),
      %w( 2 . . 1 . . 4 . . 3 . . . . . . . . . . . . 3 . . 4 . . 1 . . 2 ),
      %w( 2 . . 1 . . 4 . . 3 . . 6 5 5 5 5 5 5 6 . . 3 . . 4 . . 1 . . 2 ),
      %w( 2 . . 1 . . 4 . . 3 . . . . . . . . . 5 . . 3 . . 4 . . 1 . . 2 ),
      %w( 2 . . 1 . . 4 . . 3 . . 6 5 5 5 5 5 5 5 . . 3 . . 4 . . 2 . . 2 ),
      %w( 2 . . 1 . . 4 . . 3 . . 5 . . . . . . 5 . . 3 . . 4 . . . . . 2 ),
      %w( 2 . . 2 . . 4 . . 3 . . 5 . . . . . . 5 . . 3 . . 4 . . . . . 2 ),
      %w( 2 . . . . . 4 . . 3 . . 5 . . . . . . 5 . . 3 . . 4 . . 2 . . 2 ),
      %w( 2 . . 2 . . 4 . . 3 . . 5 5 5 5 5 5 5 6 . . 3 . . 4 . . 1 . . 2 ),
      %w( 2 . . 1 . . 4 . . 3 . . 5 E . . . . . . . M 3 . . 4 . . 1 . . 2 ),
      %w( 2 . . 1 . . 4 . . 3 . . 6 5 5 5 5 5 5 6 . . 3 . . 4 . . 1 . . 2 ),
      %w( 2 . . 1 . . 4 . . 4 . . . . . . . . . . . . 3 . . 4 . . 1 . . 2 ),
      %w( 2 . . 1 . . 4 . . . . . . . . . . . . . . . 3 . . 4 . . 1 . . 2 ),
      %w( 2 . . 1 . . 4 . . 4 3 3 3 3 3 3 3 3 3 3 3 3 4 . . 4 . . 1 . . 2 ),
      %w( 2 . . 1 . . 4 . . . . . . . . . . . . . . . . . . 4 . . 1 . . 2 ),
      %w( 2 . . 1 . . 4 . . . . . . . . . . . . . . . . . . 4 . . 1 . . 2 ),
      %w( 2 . . 1 . . 3 . 3 4 4 4 4 4 4 4 4 4 4 4 4 4 4 3 . 3 . . 1 . . 2 ),
      %w( 2 . . 1 . . . . . . . . . . . . . . . . . . . . . . . . 1 . . 2 ),
      %w( 2 . . 1 . . . . . . . . . . . . . . . . . . . . . . . . 1 . . 2 ),
      %w( 2 . . 2 1 1 1 1 1 1 1 1 1 1 2 . 2 1 1 1 1 1 1 1 1 1 2 . 2 . . 2 ),
      %w( 2 . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 2 ),
      %w( 2 . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 2 ),
      %w( 5 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 5 )
    ]

    for y in 0...@map_rows
      if x = @map[ y ].find_index( 'M' )
        @map[ y ][ x ] = MAP_EMPTY_CELL
        @magic_x = x * @cell_width + ( @cell_width / 2 )
        @magic_y = y * @cell_height + ( @cell_height / 2 )
        @player_x = @starting_x
        @player_y = @starting_y
      elsif x = @map[ y ].find_index( 'P' )
        @map[ y ][ x ] = MAP_EMPTY_CELL
        @starting_x = x * @cell_width + ( @cell_width / 2 )
        @starting_y = y * @cell_height + ( @cell_height / 2 )
        @player_x = @starting_x
        @player_y = @starting_y
      end
    end
  end

  # Configures all precalculated lookup tables.
  #
  def setup_tables
    @angles = []
    @cos_table = []
    @sin_table = []
    @tan_table = []
    @fish_eye_table = []
    @inv_cos_table = []
    @inv_sin_table = []
    @inv_tan_table = []
    @x_step = []
    @y_step = []
    @wall_colors = {}

    for i in 0..360
      @angles[ i ] = ( i * @fixed_step ).round
    end

    # Configure our trigonometric lookup tables, because math is good.
    #
    for angle in @angles[ 0 ]..@angles[ 360 ]
      rad_angle = ( 3.272e-4 ) + angle * 2 * 3.141592654 / @angles[ 360 ]

      @cos_table[ angle ] = cos( rad_angle )
      @sin_table[ angle ] = sin( rad_angle )
      @tan_table[ angle ] = tan( rad_angle )

      @inv_cos_table[ angle ] = 1.0 / cos( rad_angle )
      @inv_sin_table[ angle ] = 1.0 / sin( rad_angle )
      @inv_tan_table[ angle ] = 1.0 / tan( rad_angle )

      if angle >= @angles[ 0 ] && angle < @angles[ 180 ]
        @y_step[ angle ] =  ( @tan_table[ angle ] * @cell_height ).abs
      else
        @y_step[ angle ] = -( @tan_table[ angle ] * @cell_height ).abs
      end

      if angle >= @angles[ 90 ] && angle < @angles[ 270 ]
        @x_step[ angle ] = -( @inv_tan_table[ angle ] * @cell_width ).abs
      else
        @x_step[ angle ] =  ( @inv_tan_table[ angle ] * @cell_width ).abs
      end
    end

    for angle in -@angles[ 30 ]..@angles[ 30 ]
      rad_angle = ( 3.272e-4 ) + angle * 2 * 3.141592654 / @angles[ 360 ]
      @fish_eye_table[ angle + @angles[ 30 ] ] = 1.0 / cos( rad_angle )
    end

    # Configure some basic lookup tables for our wall colors.
    #
    @wall_colors[ '1' ] = Color::BLUE
    @wall_colors[ '2' ] = Color::LIGHT_BLUE
    @wall_colors[ '3' ] = Color::GREEN
    @wall_colors[ '4' ] = Color::LIGHT_GREEN
    @wall_colors[ '5' ] = Color::YELLOW
    @wall_colors[ '6' ] = Color::LIGHT_YELLOW
    @wall_colors[ 'E' ] = Color::BLACK
  end

  # Configures all application variables.
  #
  def setup_variables
    @screen_width = 80
    @screen_height = 36

    @cell_height = 64
    @cell_width = 64
    @cell_margin = 32

    @map_cols = 32
    @map_rows = 32
    @map_x_size = @map_cols * @cell_width
    @map_y_size = @map_rows * @cell_height

    @player_angle = 0
    @player_fov = 60
    @starting_angle = 0

    @fixed_factor = 512
    @fixed_count = ( 360 * @screen_width ) / @player_fov
    @fixed_step = @fixed_count / 360.0

    @frames_rendered = 0
    @frame_rate = 0.0
    @frame_start_time = 0.0
    @play_count = 0

    @color_mode = Color::MODE_NONE
    @draw_ceiling = true
    @draw_floor = true

    @ceiling_texture = "%"
    @floor_texture = "-"
    @wall_texture = "#"

    @display_debug_info = false
    @hud_messages =
    [
      "FIND THE EXIT!",
      "HAHA! LET'S DO IT AGAIN!",
      "ARE WE HAVING FUN YET?"
    ]

    @buffer = Array.new( @screen_height ) { Array.new( @screen_width ) }
  end

  # Displays the game's debug screen, waiting for the user to
  # press a key before returning control back to the caller.
  #
  def show_debug_screen
    clear_screen true

    puts
    puts "Super Awesome Debug Console(TM)".center( @screen_width )
    puts
    puts "[ Flags ]".center( @screen_width )
    puts
    puts ( "Color mode".ljust( 25 )          + @color_mode.to_s.rjust( 25 ) ).center( @screen_width )
    puts ( "Ceiling enabled?".ljust( 25 )    + @draw_ceiling.to_s.rjust( 25 ) ).center( @screen_width )
    puts ( "Display extra info?".ljust( 25 ) + @display_debug_info.to_s.rjust( 25 ) ).center( @screen_width )
    puts ( "Floor enabled?".ljust( 25 )      + @draw_floor.to_s.rjust( 25 ) ).center( @screen_width )
    puts
    puts "[ Metrics ]".center( @screen_width )
    puts
    puts ( "cell_height".ljust( 25 )         + @cell_height.to_s.rjust( 25 ) ).center( @screen_width )
    puts ( "cell_width".ljust( 25 )          + @cell_width.to_s.rjust( 25 ) ).center( @screen_width )
    puts ( "frames_rendered".ljust( 25 )     + @frames_rendered.to_s.rjust( 25 ) ).center( @screen_width )
    puts ( "frame_rate".ljust( 25 )          + @frame_rate.to_s.rjust( 25 ) ).center( @screen_width )
    puts ( "frame_total_time".ljust( 25 )    + ( Time.now - @frame_start_time ).to_s.rjust( 25 ) ).center( @screen_width )
    puts ( "play_count".ljust( 25 )          + @play_count.to_s.rjust( 25 ) ).center( @screen_width )
    puts ( "player_angle".ljust( 25 )        + ( @player_angle / @fixed_step ).to_s.rjust( 25 ) ).center( @screen_width )
    puts ( "player_angle_raw".ljust( 25 )    + @player_angle.to_s.rjust( 25 ) ).center( @screen_width )
    puts ( "player_fov".ljust( 25 )          + @player_fov.to_s.rjust( 25 ) ).center( @screen_width )
    puts ( "player_x".ljust( 25 )            + @player_x.to_s.rjust( 25 ) ).center( @screen_width )
    puts ( "player_y".ljust( 25 )            + @player_y.to_s.rjust( 25 ) ).center( @screen_width )
    puts ( "map_columns".ljust( 25 )         + @map_cols.to_s.rjust( 25 ) ).center( @screen_width )
    puts ( "map_rows".ljust( 25 )            + @map_rows.to_s.rjust( 25 ) ).center( @screen_width )
    puts ( "map_x_size".ljust( 25 )          + @map_x_size.to_s.rjust( 25 ) ).center( @screen_width )
    puts ( "map_y_size".ljust( 25 )          + @map_y_size.to_s.rjust( 25 ) ).center( @screen_width )
    puts ( "screen_width".ljust( 25 )        + @screen_width.to_s.rjust( 25 ) ).center( @screen_width )
    puts ( "screen_height".ljust( 25 )       + @screen_height.to_s.rjust( 25 ) ).center( @screen_width )
    puts
    puts "Press any key to continue...".center( @screen_width )
    puts

    wait_key
    clear_screen true
    update_buffer
  end

  # Shows the ending screen.
  #
  def show_end_screen
    draw_screen_wipe WIPE_BLINDS
    clear_screen true

    puts $/ * ( ( @screen_height / 2 ) - 7 )
    puts "You have reached...".center( 72 )
    puts "                ,,                                                  ,,  "
    puts " MMP''MM''YMM `7MM                    `7MM'''YMM                  `7MM  "
    puts " P'   MM   `7   MM                      MM    `7                    MM  "
    puts "      MM        MMpMMMb.  .gP'Ya        MM   d    `7MMpMMMb.   ,M''bMM  "
    puts "      MM        MM    MM ,M'   Yb       MMmmMM      MM    MM ,AP    MM  "
    puts "      MM        MM    MM 8M''''''       MM   Y  ,   MM    MM 8MI    MM  "
    puts "      MM        MM    MM YM.    ,       MM     ,M   MM    MM `Mb    MM  "
    puts "    .JMML.    .JMML  JMML.`Mbmmd'     .JMMmmmmMMM .JMML  JMML.`Wbmd'MML."
    puts
    puts "...or have you?".center( 72 )
    puts
    puts "Press any key to find out!".center( 72 )
    puts $/ * ( ( @screen_height / 2 ) - 7 )

    clear_input
    wait_key

    @play_count += 1

    reset_player
    clear_screen true
    update_buffer
  end

  # Displays the exit screen and quits the game.
  #
  def show_exit_screen
    clear_screen true

    puts
    puts "Thanks for playing...".center( @screen_width )
    puts
    show_logo
    puts
    puts
    puts "Problems or suggestions? Visit the repo!".center( @screen_width )
    puts "http://www.github.com/AtomicPair/wolfentext3d".center( @screen_width )
    puts

    exit 0
  end

  # Displays the game's help screen, waiting for the user to
  # press a key before returning control back to the caller.
  #
  def show_help_screen
    clear_screen true

    puts
    puts "Wolfentext3D Help".center( @screen_width )
    puts
    puts "[ Notes ]".center( @screen_width )
    puts
    puts "Windows users: testing has shown that running this".center( @screen_width )
    puts "script in any color mode under most terminals will".center( @screen_width )
    puts "result in very poor performance.  For now, it is  ".center( @screen_width )
    puts "recommended that you run in 'no color' mode to    ".center( @screen_width )
    puts "enjoy the highest framerate and best experience.  ".center( @screen_width )
    puts
    puts "Enjoy the game!                                   ".center( @screen_width )
    puts
    puts "[ Keys ]".center( @screen_width )
    puts
    puts ( "Move forward".ljust( 25 )   + "W, Up Arrow".rjust( 25 ) ).center( @screen_width )
    puts ( "Move backward".ljust( 25 )  + "S, Down Arrow".rjust( 25 ) ).center( @screen_width )
    puts ( "Turn left".ljust( 25 )      + "A, Left Arrow".rjust( 25 ) ).center( @screen_width )
    puts ( "Turn right".ljust( 25 )     + "D, Right Arrow".rjust( 25 ) ).center( @screen_width )
    puts
    puts ( "Toggle ceiling".ljust( 25 )    + "C".rjust( 25 ) ).center( @screen_width )
    puts ( "Toggle debug info".ljust( 25 ) + "I".rjust( 25 ) ).center( @screen_width )
    puts ( "Toggle floor".ljust( 25 )      + "F".rjust( 25 ) ).center( @screen_width )
    puts
    puts Color.colorize( ( "No color".ljust( 25 )      + "1".rjust( 25 ) ).center( @screen_width ), Color::BLUE, 2 )
    puts Color.colorize( ( "Partial color".ljust( 25 ) + "2".rjust( 25 ) ).center( @screen_width ), Color::GREEN, 2 )
    puts Color.colorize( ( "Full color".ljust( 25 )    + "3".rjust( 25 ) ).center( @screen_width ), Color::YELLOW, 2 )
    puts
    puts ( "Debug screen".ljust( 25 )   + "?".rjust( 25 ) ).center( @screen_width )
    puts ( "Help screen".ljust( 25 )    + "H".rjust( 25 ) ).center( @screen_width )
    puts ( "Quit game".ljust( 25 )      + "Q".rjust( 25 ) ).center( @screen_width )
    puts
    puts "Press any key to continue...".center( @screen_width )
    puts

    wait_key
    clear_screen true
    update_buffer
  end

  # Displays the game's title screen.
  #
  def show_title_screen
    clear_screen true

    puts
    show_logo
    puts
    puts
    puts "Press any key to start...".center( 88 )

    wait_key
    clear_screen true
  end

  # Displays the Wolfentext logo.
  #
  # Logo courtesy of PatorJK's ASCII Art Generator.
  # @see http://patorjk.com/software/taag/
  #
  def show_logo
    puts "    .~`'888x.!**h.-``888h.               x .d88'     oec :                              "
    puts "   dX   `8888   :X   48888>         u.    5888R     @88888                u.    u.      "
    puts "  '888x  8888  X88.  '8888>   ...ue888b   '888R     8'*88%       .u     x@88k u@88c.    "
    puts "  '88888 8888X:8888:   )?''`  888R Y888r   888R     8b.       ud8888.  ^'8888''8888'^   "
    puts "   `8888>8888 '88888>.88h.    888R I888>   888R    u888888> :888'8888.   8888  888R     "
    puts "     `8' 888f  `8888>X88888.  888R I888>   888R     8888R   d888 '88%'   8888  888R     "
    puts "    -~` '8%'     88' `88888X  888R I888>   888R     8888P   8888.+'      8888  888R     "
    puts "    .H888n.      XHn.  `*88! u8888cJ888    888R     *888>   8888L        8888  888R     "
    puts "   :88888888x..x88888X.  `!   '*888*P'    .888B .   4888    '8888c. .+  '*88*' 8888'    "
    puts "   f  ^%888888% `*88888nx'      'Y'       ^*888%    '888     '88888%      ''   'Y'      "
    puts "        `'**'`    `'**''                    '%       88R       'YP'                     "
    puts "                                                     88>                                "
    puts "                                                     48                                 "
    puts "                                                     '8                                 "
    puts "    .....                                       s                          ....         "
    puts " .H8888888h.  ~-.                              :8      .x~~'*Weu.      .xH888888Hx.     "
    puts " 888888888888x  `>               uL   ..      .88     d8Nu.  9888c   .H8888888888888:   "
    puts "X~     `?888888hx~      .u     .@88b  @88R   :888ooo  88888  98888   888*'''?''*88888X  "
    puts "'      x8.^'*88*'    ud8888.  ''Y888k/'*P  -*8888888  '***'  9888%  'f     d8x.   ^%88k "
    puts " `-:- X8888x       :888'8888.    Y888L       8888          ..@8*'   '>    <88888X   '?8 "
    puts "      488888>      d888 '88%'     8888       8888       ````'8Weu    `:..:`888888>    8>"
    puts "    .. `'88*       8888.+'        `888N      8888      ..    ?8888L         `'*88     X "
    puts "  x88888nX'      . 8888L       .u./'888&    .8888Lu= :@88N   '8888N    .xHHhx..'      ! "
    puts " !'*8888888n..  :  '8888c. .+ d888' Y888*'  ^%888*   *8888~  '8888F   X88888888hx. ..!  "
    puts "'    '*88888888*    '88888%   ` 'Y   Y'       'Y'    '*8'`   9888%   !   '*888888888'   "
    puts "        ^'***'`       'YP'                             `~===*%'`            ^'***'`     "
  end

  # Calls the main ray casting engine, updates the screen buffer,
  # and displays the updated buffer on the screen.
  #
  def update_buffer
    clear_buffer
    ray_cast @player_x, @player_y, @player_angle
    clear_screen
    draw_buffer
    draw_status_line
  end

  # Updates the current frame rate metric.
  #
  def update_frame_rate
    if ( Time.now - @frame_start_time ) >= 1.0
      @frame_rate = ( @frames_rendered / ( Time.now - @frame_start_time ) ).round( 2 )
      @frames_rendered = 0
      @frame_start_time = Time.now
    end
  end
end

Game.new.play
