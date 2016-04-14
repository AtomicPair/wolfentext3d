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

VERSION = "0.7.0"

# Defines a single map cell in the current world map.
#
# @author Adam Parrott <parrott.adam@gmail.com>
#
class Cell
  HEIGHT = 64
  HALF   = 32
  MARGIN = 24
  WIDTH  = 64

  MOVING_EAST  = 1
  MOVING_NORTH = 2
  MOVING_SOUTH = 4
  MOVING_WEST  = 8

  EMPTY_CELL     = "."
  END_CELL       = "E"
  DOOR_CELL      = "D"
  DOOR_CELLS     = %w( - | )
  MAGIC_CELL     = "S"
  MOVE_WALL_HORZ = "m"
  MOVE_WALL_VERT = "M"
  MOVE_WALLS     = %w( M m )
  PLAYER_CELLS   = %w( < ^ > v )
  PLAYER_UP      = "^"
  PLAYER_DOWN    = "v"
  PLAYER_LEFT    = "<"
  PLAYER_RIGHT   = ">"
  SECRET_CELL    = "P"
  WALL_CELLS     = %w( 1 2 3 4 5 6 7 8 )

  attr_accessor :bottom
  attr_accessor :direction
  attr_accessor :left
  attr_accessor :map
  attr_accessor :offset
  attr_accessor :right
  attr_accessor :state
  attr_accessor :top
  attr_accessor :value
  attr_accessor :x_cell
  attr_accessor :y_cell

  def initialize( args = {} )
    @bottom    = args[ :bottom ] || 0
    @direction = args[ :direction ]
    @left      = args[ :left ]   || 0
    @map       = args[ :map ]
    @offset    = args[ :offset ] || 0
    @right     = args[ :right ]  || 0
    @state     = args[ :state ]
    @top       = args[ :top ]    || 0
    @value     = args[ :value ]  || EMPTY_CELL
    @x_cell    = args[ :x_cell ]
    @y_cell    = args[ :y_cell ]
  end

  # Identifies the type of cell class being used.
  #
  # @return [Symbol] The name of the current class
  #
  def type
    self.class.to_s.downcase.to_sym
  end
end

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
  # @param value [String]  Text value to colorize
  # @param color [Integer] Terminal color code to use for colorizing
  # @param mode  [Integer] Desired color mode to use (Color::MODE_X)
  # @return      [String]  The colorized string
  #
  def self.colorize( value, color, mode = 0 )
    case mode
    when MODE_NONE
      value
    when MODE_PARTIAL
      color += 10 unless is_dark? color
      "\e[1;#{ color }m#{ value }\e[0m"
    when MODE_FILL
      "\e[7;#{ color };#{ color + 10 }m \e[0m"
    end
  end

  private

  # Tests whether a given color index is light or dark.
  #
  # @param color [Integer] Color value to be tested
  #
  def self.is_dark?( color )
    if [ LIGHT_BLUE,
         LIGHT_CYAN,
         LIGHT_GRAY,
         LIGHT_GREEN,
         LIGHT_MAGENTA,
         LIGHT_RED,
         LIGHT_YELLOW ].include? color
      false
    else
      true
    end
  end
end

# Defines the behavior and actions for the doors in our map.
#
# @author Adam Parrott <parrott.adam@gmail.com>
# @tip "I can only show you the door, Neo. You're the one who has to walk through it."
#
class Door < Cell
  STATE_CLOSED  = 1
  STATE_OPENING = 2
  STATE_OPEN    = 3
  STATE_CLOSING = 4

  attr_accessor :open_since

  def initialize( args = {} )
    super args

    @open_since = args[ :open_since ]
    @state      = args[ :state ] || STATE_CLOSED
    @value      = Cell::DOOR_CELL
  end

  # Checks and updates the doors state and position since the last update.
  #
  # @param delta_time [Float] The current delta time factor to apply to our movement calculations
  #
  def update( delta_time )
    case @state
    when STATE_CLOSED
      return
    when STATE_OPENING
      if @offset >= Cell::WIDTH
        @state = STATE_OPEN
        @open_since = Time.now
      else
        @offset += ( 32 * delta_time )
      end
    when STATE_OPEN
      if ( Time.now - @open_since ) > 5.0
        @state = STATE_CLOSING
        @open_since = 0.0
      end
    when STATE_CLOSING
      if @offset <= 0
        @state = STATE_CLOSED
      else
        @offset -= ( 32 * delta_time )
      end
    end
  end
end

# Contains static game helper functions.
#
# @author Adam Parrott <parrott.adam@gmail.com>
#
module GameHelpers
  # Ensures that a given value is within a specified range.
  # If the value is less than the minimum value, the minimum
  # value will be returned.  If the value is greater than the
  # maximum value, the maximum value will be returned.
  #
  # @param test_value [Object] Value to be tested
  # @param min_value  [Object] Minimum value in testing range
  # @param max_value  [Object] Maximum value in testing range
  # @return [Object] The test object clipped within the range limits
  #
  def clip_value( test_value, min_value, max_value )
    [ [ test_value, min_value ].max, max_value ].min
  end

  # Custom puts output method to handle unique console configuration.
  #
  # @param string [String] The text value to be output to the console
  #
  def puts( string = "" )
    STDOUT.write "#{ string }\r\n"
  end

  # Helper function to convert degrees to radians.
  #
  # @param value [Float] Value in degrees to be converted to radians
  # @return [Float] The input value converted to radians
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
module Input
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
  def self.clear_input
    STDIN.ioflush
    self.get_key
  end

  # Returns the first key found in the current input buffer.
  #
  def self.get_key
    if WINDOWS_INPUT
      if WINDOWS_KB_HIT.Call.zero?
        @input = nil
      else
        @input = WINDOWS_GET_CHAR.Call.chr( Encoding::UTF_8 )

        if @input == "\u00E0"
          @input << WINDOWS_GET_CHAR.Call.chr( Encoding::UTF_8 )
        end
      end
    else
      @input = STDIN.read_nonblock( 1 ).chr rescue nil

      if @input == "\e"
        @input << STDIN.read_nonblock( 3 ) rescue nil
        @input << STDIN.read_nonblock( 2 ) rescue nil
      end
    end

    return @input
  end

  # Waits for and returns the first character entered by a user.
  #
  def self.wait_key
    if WINDOWS_INPUT
      @input = WINDOWS_GET_CHAR.Call.chr( Encoding::UTF_8 )

      if @input == "\u00E0"
        @input << WINDOWS_GET_CHAR.Call.chr( Encoding::UTF_8 )
      end
    else
      @input = STDIN.getc.chr
    end

    return @input
  end
end

# Defines the behavior and actions for our magical pushwalls.
#
# @author Adam Parrott <parrott.adam@gmail.com>
#
class Pushwall < Cell
  STATE_STOPPED  = 0
  STATE_MOVING   = 1
  STATE_FINISHED = 2
  TYPE_PUSH      = 1
  TYPE_MOVE      = 2

  attr_reader   :cells_moved
  attr_accessor :to_x_cell
  attr_accessor :to_y_cell
  attr_accessor :type

  def initialize( args = {} )
    super args

    @state = args[ :state ] || STATE_STOPPED
    @type  = args[ :type ]  || TYPE_PUSH

    @cells_moved = 0
    @bottom      = ( @y_cell + 1 ) * Cell::HEIGHT
    @left        = @x_cell * Cell::WIDTH
    @right       = ( @x_cell + 1 ) * Cell::WIDTH
    @top         = @y_cell * Cell::HEIGHT
    @to_x_cell   = @x_cell
    @to_y_cell   = @y_cell
    @value       = Cell::SECRET_CELL
  end

  # Activates the pushwall in the desired direction.
  #
  # @param [Integer] direction The direction this pushwall should be moving (Cell::MOVING_X)
  #
  def activate( direction )
    if @type == TYPE_PUSH && @state != STATE_STOPPED
      return false
    elsif @type == TYPE_MOVE && @state != STATE_STOPPED
      return false
    else
      return reset( direction )
    end
  end

  # Updates the pushwall's current state and position, if active.
  #
  # @param delta_time [Float] The current delta time factor to apply to our movement calculations.
  #
  def update( delta_time )
    return if @state == STATE_FINISHED

    case @type
    when TYPE_MOVE
      @push_amount = 64 * delta_time
    when TYPE_PUSH
      @push_amount = 32 * delta_time
    end

    case @direction
    when MOVING_EAST
      @cell_size   = Cell::WIDTH
      @push_amount = -@push_amount
      @push_left   = @push_amount
      @push_right  = @push_amount
      @push_top    = 0
      @push_bottom = 0
      @next_x_cell = @to_x_cell - 1
      @next_y_cell = @to_y_cell
      @next_left   = ( @next_x_cell + 1 ) * Cell::WIDTH
      @next_right  = ( @to_x_cell + 1 ) * Cell::WIDTH
      @next_top    = @to_y_cell * Cell::HEIGHT
      @next_bottom = @next_y_cell * Cell::HEIGHT
      @next_offset = @cell_size
      @offset_good = ( @offset >= -@cell_size )

    when MOVING_WEST
      @cell_size   = Cell::WIDTH
      @push_left   = @push_amount
      @push_right  = @push_amount
      @push_top    = 0
      @push_bottom = 0
      @next_x_cell = @to_x_cell + 1
      @next_y_cell = @to_y_cell
      @next_left   = @to_x_cell * Cell::WIDTH
      @next_right  = @next_x_cell * Cell::WIDTH
      @next_top    = @to_y_cell * Cell::HEIGHT
      @next_bottom = @next_y_cell * Cell::HEIGHT
      @next_offset = -@cell_size
      @offset_good = ( @offset <= @cell_size )

    when MOVING_NORTH
      @cell_size   = Cell::HEIGHT
      @push_amount = -@push_amount
      @push_left   = 0
      @push_right  = 0
      @push_top    = @push_amount
      @push_bottom = @push_amount
      @next_x_cell = @to_x_cell
      @next_y_cell = @to_y_cell - 1
      @next_left   = @to_x_cell * Cell::WIDTH
      @next_right  = @next_x_cell * Cell::WIDTH
      @next_top    = ( @next_y_cell + 1 ) * Cell::HEIGHT
      @next_bottom = ( @to_y_cell + 1 ) * Cell::HEIGHT
      @next_offset = @cell_size
      @offset_good = ( @offset >= -@cell_size )

    when MOVING_SOUTH
      @cell_size   = Cell::HEIGHT
      @push_left   = 0
      @push_right  = 0
      @push_top    = @push_amount
      @push_bottom = @push_amount
      @next_x_cell = @to_x_cell
      @next_y_cell = @to_y_cell + 1
      @next_left   = @to_x_cell * Cell::WIDTH
      @next_right  = @next_x_cell * Cell::WIDTH
      @next_top    = @to_y_cell * Cell::HEIGHT
      @next_bottom = @next_y_cell * Cell::HEIGHT
      @next_offset = -@cell_size
      @offset_good = ( @offset <= @cell_size )
    end

    @offset += @push_amount
    @left   += @push_left
    @right  += @push_right
    @top    += @push_top
    @bottom += @push_bottom

    @map[ @to_y_cell ][ @to_x_cell ].offset += @push_amount
    @map[ @to_y_cell ][ @to_x_cell ].left    = @left
    @map[ @to_y_cell ][ @to_x_cell ].right   = @right
    @map[ @to_y_cell ][ @to_x_cell ].top     = @top
    @map[ @to_y_cell ][ @to_x_cell ].bottom  = @bottom

    unless @offset_good
      @cells_moved += 1

      @map[ @y_cell ][ @x_cell ] = @map[ @to_y_cell ][ @to_x_cell ]
      @map[ @y_cell ][ @x_cell ].offset = 0
      @map[ @y_cell ][ @x_cell ].state  = STATE_STOPPED
      @map[ @y_cell ][ @x_cell ].value  = Cell::EMPTY_CELL

      @map[ @to_y_cell ][ @to_x_cell ] = self
      @map[ @to_y_cell ][ @to_x_cell ].offset    = @push_amount
      @map[ @to_y_cell ][ @to_x_cell ].state     = STATE_MOVING
      @map[ @to_y_cell ][ @to_x_cell ].direction = @direction
      @map[ @to_y_cell ][ @to_x_cell ].value     = Cell::SECRET_CELL

      if @map[ @next_y_cell ][ @next_x_cell ].value == Cell::EMPTY_CELL
        @x_cell    = @to_x_cell
        @y_cell    = @to_y_cell
        @to_x_cell = @next_x_cell
        @to_y_cell = @next_y_cell

        @left      = @next_left + @push_amount
        @right     = @next_right + @push_amount
        @top       = @next_top + @push_amount
        @bottom    = @next_bottom + @push_amount

        @map[ @to_y_cell ][ @to_x_cell ].offset    = @next_offset + @push_amount
        @map[ @to_y_cell ][ @to_x_cell ].direction = @direction
        @map[ @to_y_cell ][ @to_x_cell ].state     = STATE_MOVING
        @map[ @to_y_cell ][ @to_x_cell ].value     = Cell::SECRET_CELL
        @map[ @to_y_cell ][ @to_x_cell ].left      = @left
        @map[ @to_y_cell ][ @to_x_cell ].right     = @right
        @map[ @to_y_cell ][ @to_x_cell ].top       = @top
        @map[ @to_y_cell ][ @to_x_cell ].bottom    = @bottom

      else
        @offset = 0
        @value  = Cell::SECRET_CELL
        @x_cell = @to_x_cell
        @y_cell = @to_y_cell

        @left   = @x_cell * Cell::WIDTH
        @right  = ( @x_cell + 1 ) * Cell::WIDTH
        @top    = @y_cell * Cell::HEIGHT
        @bottom = ( @y_cell + 1 ) * Cell::HEIGHT

        case @type
        when TYPE_PUSH
          @direction = nil
          @state     = STATE_FINISHED
        when TYPE_MOVE
          case @direction
          when MOVING_WEST
            reset MOVING_EAST
          when MOVING_EAST
            reset MOVING_WEST
          when MOVING_NORTH
            reset MOVING_SOUTH
          when MOVING_SOUTH
            reset MOVING_NORTH
          end
        end
      end
    end
  end

  private

  def reset( direction )
    case direction
    when MOVING_EAST
      return false if @map[ @y_cell ][ @x_cell - 1 ].value != Cell::EMPTY_CELL

      @direction = MOVING_EAST
      @offset    = 0
      @state     = STATE_MOVING
      @to_offset = Cell::WIDTH
      @to_x_cell = @x_cell - 1
      @to_y_cell = @y_cell
      @value     = Cell::SECRET_CELL

    when MOVING_WEST
      return false if @map[ @y_cell ][ @x_cell + 1 ].value != Cell::EMPTY_CELL

      @direction = MOVING_WEST
      @offset    = 0
      @state     = STATE_MOVING
      @to_offset = -Cell::WIDTH
      @to_x_cell = @x_cell + 1
      @to_y_cell = @y_cell
      @value     = Cell::SECRET_CELL

    when MOVING_NORTH
      return false if @map[ @y_cell - 1 ][ @x_cell ].value != Cell::EMPTY_CELL

      @direction = MOVING_NORTH
      @offset    = 0
      @state     = STATE_MOVING
      @to_offset = Cell::HEIGHT
      @to_x_cell = @x_cell
      @to_y_cell = @y_cell - 1
      @value     = Cell::SECRET_CELL

    when MOVING_SOUTH
      return false if @map[ @y_cell + 1 ][ @x_cell ].value != Cell::EMPTY_CELL

      @direction = MOVING_SOUTH
      @offset    = 0
      @state     = STATE_MOVING
      @to_offset = -Cell::HEIGHT
      @to_x_cell = @x_cell
      @to_y_cell = @y_cell + 1
      @value     = Cell::SECRET_CELL
    end

    @map[ @to_y_cell ][ @to_x_cell ].direction = @direction
    @map[ @to_y_cell ][ @to_x_cell ].offset    = @to_offset
    @map[ @to_y_cell ][ @to_x_cell ].state     = STATE_MOVING
    @map[ @to_y_cell ][ @to_x_cell ].value     = Cell::SECRET_CELL

    return true
  end
end

# Main game class
#
# @author Adam Parrott <parrott.adam@gmail.com>
#
class Game
  include GameHelpers
  include Math

  WIPE_BLINDS       = 1
  WIPE_PIXELIZE_IN  = 2
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
    activate_movewalls
    reset_timers
    update_buffer

    while true
      check_input
      check_collisions
      update_buffer
      update_doors
      update_movewalls
      update_pushwalls
      update_frame_rate
      update_delta_time
      draw_debug_info if @show_debug_info

      # TODO: Dynamically update this based on frame rate.
      # If the current frame rate exceeds the target refresh
      # rate, then sleep execution and/or drop frames to
      # maintain the desired maximum refresh rate.
      #
      sleep 0.010
    end
  end

  private

  ## Attributes ##

  # Defines our time-independent step value for movement calculations.
  #
  def movement_step
    ( 160 * @delta_time )
  end

  # Defines our time-independent step value for turning calculations.
  #
  def turn_step
    ( @angles[ 90 ] * @delta_time )
  end

  ## Methods ##

  # Activate all of the moveable walls in the current map.
  #
  def activate_movewalls
    return if @movewalls.size == 0

    @movewalls.each do |movewall|
      movewall.activate movewall.direction
    end
  end

  # Checks for horizontal intersections in the world map along a given angle.
  #
  # @param x_start [Integer] Starting X world coordinate to use for casting
  # @param y_start [Integer] Starting Y world coordinate to use for casting
  # @param angle   [Float]   Starting viewing angle to use for casting
  #
  def cast_x_ray( x_start, y_start, angle )
    @x_ray_dist = 0
    @x_push_dist = 1e+8
    @x_x_cell = 0
    @x_y_cell = 0

    # Abort the cast if the next Y step sends us out of bounds.
    #
    if @y_step[ angle ].abs == 0
      return 1e+8
    end

    if angle < @angles[ 90 ] || angle >= @angles[ 270 ]
      #
      # Setup our cast for the right half of the map.
      #  _ _ _  ____
      # |_|_|_|/    |
      # |_|_|_/     |
      # |_|_|/      |
      # |_|_|\      |
      # |_|_|_\     |
      # |_|_|_|\____|
      #
      @x_bound = Cell::WIDTH + Cell::WIDTH * ( x_start / Cell::WIDTH )
      @x_delta = Cell::WIDTH
      @y_intercept = @tan_table[ angle ] * ( @x_bound - x_start ) + y_start
      @next_x_cell = 0
    else
      #
      # Setup our cast for the left half of the map.
      #  ____  _ _ _
      # |    \|_|_|_|
      # |     \_|_|_|
      # |      \|_|_|
      # |      /|_|_|
      # |     /_|_|_|
      # |____/|_|_|_|
      #
      @x_bound = Cell::WIDTH * ( x_start / Cell::WIDTH )
      @x_delta = -Cell::WIDTH
      @y_intercept = @tan_table[ angle ] * ( @x_bound - x_start ) + y_start
      @next_x_cell = -1
    end

    # Check to see if we have any visible pushwalls in our ray's path.
    #
    ( @movewalls + @pushwalls ).each do |pushwall|
      case pushwall.direction
      when Cell::MOVING_EAST, Cell::MOVING_WEST
        # The wall is moving in one the directions we can work with.
      else
        next
      end

      if angle >= @angles[ 90 ] && angle < @angles[ 270 ]
        @push_x_bound = pushwall.right
        next if @push_x_bound > x_start
      else
        @push_x_bound = pushwall.left
        next if @push_x_bound < x_start
      end

      @push_y_intercept = @tan_table[ angle ] * ( @push_x_bound - x_start ) + y_start
      @push_x_cell = ( @push_x_bound / Cell::WIDTH ).to_i
      @push_y_cell = ( @push_y_intercept / Cell::HEIGHT ).to_i
      @push_map_cell = @map[ @push_y_cell ][ @push_x_cell ] rescue nil

      next if @push_map_cell.nil?

      if @push_map_cell.value == Cell::SECRET_CELL \
         && ( pushwall.x_cell == @push_x_cell || pushwall.to_x_cell == @push_x_cell ) \
         && ( pushwall.y_cell == @push_y_cell || pushwall.to_y_cell == @push_y_cell )

        @push_dist = ( @push_y_intercept - y_start ) * @inv_sin_table[ angle ]

        if @push_dist < @x_push_dist
          @x_push_dist = @push_dist
          @x_push_x_cell = @push_x_cell
          @x_push_y_cell = @push_y_cell
          @x_push_map_cell = @push_map_cell
        end
      end
    end

    while true
      # Calculate the next X and Y cells hit by our casted ray,
      # and see if they fall within our map's boundaries.
      #
      @x_x_cell = ( ( @x_bound + @next_x_cell ) / Cell::WIDTH ).to_i
      @x_y_cell = ( @y_intercept / Cell::HEIGHT ).to_i

      if @x_x_cell.between?( 0, @map_columns - 1 ) && @x_y_cell.between?( 0, @map_rows - 1 )
        @x_map_cell = @map[ @x_y_cell ][ @x_x_cell ]
      else
        @x_intercept = 1e+8
        break
      end

      # Check the map cell at the intersected coordinates.
      #
      case @x_map_cell.value
      when Cell::END_CELL
        break
      when Cell::DOOR_CELL
        if @x_map_cell.offset < ( @y_intercept % Cell::HEIGHT )
          @y_intercept += ( @y_step[ angle ] / 2 )
          break
        end
      when Cell::SECRET_CELL
        case @x_map_cell.state
        when Pushwall::STATE_MOVING
          case @x_map_cell.direction
          when Cell::MOVING_NORTH, Cell::MOVING_SOUTH
            if @x_map_cell.offset >= 0 && ( @y_intercept % Cell::HEIGHT ) > @x_map_cell.offset
              break
            elsif @x_map_cell.offset < 0 && ( @y_intercept % Cell::HEIGHT ) < ( Cell::WIDTH + @x_map_cell.offset )
              break
            end
          when Cell::MOVING_EAST, Cell::MOVING_WEST
            if @x_map_cell.offset.between? -1, 1
              break
            end
          end
        when Pushwall::STATE_STOPPED, Pushwall::STATE_FINISHED
          break
        end
      when Cell::WALL_CELLS.first..Cell::WALL_CELLS.last
        break
      end

      @y_intercept += @y_step[ angle ]
      @x_bound += @x_delta
    end

    if @y_intercept == 1e+8
      @x_ray_dist = 1e+8
    else
      @x_ray_dist = ( @y_intercept - y_start ) * @inv_sin_table[ angle ]
    end

    if @x_push_dist < @x_ray_dist
      @x_map_cell = @x_push_map_cell
      @x_x_cell = @x_push_x_cell
      @x_y_cell = @x_push_y_cell
      return @x_push_dist
    else
      return @x_ray_dist
    end
  end

  # Checks for vertical intersections in the world map along a given angle.
  #
  # @param x_start [Integer] Starting X world coordinate to use for casting
  # @param y_start [Integer] Starting Y world coordinate to use for casting
  # @param angle   [Float]   Starting viewing angle to use for casting
  #
  def cast_y_ray( x_start, y_start, angle )
    @y_ray_dist = 0
    @y_push_dist = 1e+8
    @y_x_cell = 0
    @y_y_cell = 0

    # Abort the cast if the next X step sends us out of bounds.
    #
    if @x_step[ angle ].abs == 0
      return 1e+8
    end

    if angle >= @angles[ 0 ] && angle < @angles[ 180 ]
      #
      # Setup our cast for the lower half of the map.
      #  _ _ _ _ _ _
      # |_|_|_|_|_|_|
      # |_|_|_|_|_|_|
      # |_|_|/ \|_|_|
      # |_|_/   \_|_|
      # |_|/     \|_|
      # |_/_______\_|
      #
      @y_bound = Cell::HEIGHT + Cell::HEIGHT * ( y_start / Cell::HEIGHT )
      @y_delta = Cell::HEIGHT
      @x_intercept = @inv_tan_table[ angle ] * ( @y_bound - y_start ) + x_start
      @next_y_cell = 0
    else
      #
      # Setup our cast for the upper half of the map.
      #  _ _______ _
      # |_\       /_|
      # |_|\     /|_|
      # |_|_\   /_|_|
      # |_|_|\ /|_|_|
      # |_|_|_|_|_|_|
      # |_|_|_|_|_|_|
      #
      @y_bound = Cell::HEIGHT * ( y_start / Cell::HEIGHT )
      @y_delta = -Cell::HEIGHT
      @x_intercept = @inv_tan_table[ angle ] * ( @y_bound - y_start ) + x_start
      @next_y_cell = -1
    end

    # Check to see if we have any visible pushwalls in our ray's path.
    #
    ( @movewalls + @pushwalls ).each do |pushwall|
      case pushwall.direction
      when Cell::MOVING_NORTH, Cell::MOVING_SOUTH
        # The wall is moving in one the directions we can work with.
      else
        next
      end

      if angle >= @angles[ 0 ] && angle < @angles[ 180 ]
        @push_y_bound = pushwall.top
        next if @push_y_bound < y_start
      else
        @push_y_bound = pushwall.bottom
        next if @push_y_bound > y_start
      end

      @push_x_intercept = @inv_tan_table[ angle ] * ( @push_y_bound - y_start ) + x_start
      @push_x_cell = ( @push_x_intercept / Cell::WIDTH ).to_i
      @push_y_cell = ( @push_y_bound / Cell::HEIGHT ).to_i
      @push_map_cell = @map[ @push_y_cell ][ @push_x_cell ] rescue nil

      next if @push_map_cell.nil?

      if @push_map_cell.value == Cell::SECRET_CELL \
         && ( pushwall.x_cell == @push_x_cell || pushwall.to_x_cell == @push_x_cell ) \
         && ( pushwall.y_cell == @push_y_cell || pushwall.to_y_cell == @push_y_cell )

        @push_dist = ( @push_x_intercept - x_start ) * @inv_cos_table[ angle ]

        if @push_dist < @y_push_dist
          @y_push_dist = @push_dist
          @y_push_x_cell = @push_x_cell
          @y_push_y_cell = @push_y_cell
          @y_push_map_cell = @push_map_cell
        end
      end
    end

    while true
      # Calculate the next X and Y cells hit by our casted ray,
      # and see if they fall within our map's boundaries.
      #
      @y_x_cell = ( @x_intercept / Cell::WIDTH ).to_i
      @y_y_cell = ( ( @y_bound + @next_y_cell ) / Cell::HEIGHT ).to_i

      if @y_x_cell.between?( 0, @map_columns - 1 ) && @y_y_cell.between?( 0, @map_rows - 1 )
        @y_map_cell = @map[ @y_y_cell ][ @y_x_cell ]
      else
        @x_intercept = 1e+8
        break
      end

      # Check the map cell at the intersected coordinates.
      #
      case @y_map_cell.value
      when Cell::END_CELL
        break
      when Cell::DOOR_CELL
        if @y_map_cell.offset < ( @x_intercept % Cell::WIDTH )
          @x_intercept += ( @x_step[ angle ] / 2 )
          break
        end
      when Cell::SECRET_CELL
        case @y_map_cell.state
        when Pushwall::STATE_MOVING
          case @y_map_cell.direction
          when Cell::MOVING_EAST, Cell::MOVING_WEST
            if @y_map_cell.offset >= 0 && ( @x_intercept % Cell::WIDTH ) > @y_map_cell.offset
              break
            elsif @y_map_cell.offset < 0 && ( @x_intercept % Cell::WIDTH ) < ( Cell::WIDTH + @y_map_cell.offset )
              break
            end
          when Cell::MOVING_NORTH, Cell::MOVING_SOUTH
            if @y_map_cell.offset.between? -1, 1
              break
            end
          end
        when Pushwall::STATE_STOPPED, Pushwall::STATE_FINISHED
          break
        end
      when Cell::WALL_CELLS.first..Cell::WALL_CELLS.last
        break
      end

      @x_intercept += @x_step[ angle ]
      @y_bound += @y_delta
    end

    if @x_intercept == 1e+8
      @y_ray_dist = 1e+8
    else
      @y_ray_dist = ( @x_intercept - x_start ) * @inv_cos_table[ angle ]
    end

    if @y_push_dist < @y_ray_dist
      @y_map_cell = @y_push_map_cell
      @y_x_cell = @y_push_x_cell
      @y_y_cell = @y_push_y_cell
      return @y_push_dist
    else
      return @y_ray_dist
    end
  end

  # Checks for collisions between the player and other world objects.
  #
  def check_collisions
    @x_cell = @player_x / Cell::WIDTH
    @y_cell = @player_y / Cell::HEIGHT
    @x_sub_cell = @player_x % Cell::WIDTH
    @y_sub_cell = @player_y % Cell::HEIGHT

    if @player_move_x == 0 && @player_move_y == 0
      @map_cell = @map[ @y_cell ][ @x_cell + 1 ]

      if @map_cell.value == Cell::SECRET_CELL \
        && @map_cell.direction == Cell::MOVING_EAST \
        && @player_x >= ( @map_cell.left.to_i - ( Cell::WIDTH - Cell::MARGIN ) )

        @player_move_x = @map_cell.left.to_i - ( Cell::WIDTH - Cell::MARGIN ) - @player_x
      end

      @map_cell = @map[ @y_cell ][ @x_cell - 1 ]

      if @map_cell.value == Cell::SECRET_CELL \
        && @map_cell.direction == Cell::MOVING_WEST \
        && @player_x <= @map_cell.right.to_i + Cell::MARGIN

        @player_move_x = @map_cell.right.to_i + Cell::MARGIN - @player_x
      end

      @map_cell = @map[ @y_cell + 1 ][ @x_cell ]

      if @map_cell.value == Cell::SECRET_CELL \
        && @map_cell.direction == Cell::MOVING_NORTH \
        && @player_y >= ( @map_cell.top.to_i - ( Cell::HEIGHT - Cell::MARGIN ) )

        @player_move_y = @map_cell.top.to_i - ( Cell::HEIGHT - Cell::MARGIN ) - @player_y
      end

      @map_cell = @map[ @y_cell - 1 ][ @x_cell ]

      if @map_cell.value == Cell::SECRET_CELL \
        && @map_cell.direction == Cell::MOVING_SOUTH \
        && @player_y <= ( @map_cell.bottom.to_i + Cell::MARGIN )

        @player_move_y = @map_cell.bottom.to_i + Cell::MARGIN - @player_y
      end
    end

    # Check for collisions while player is moving west
    #
    if @player_move_x > 0
      @map_cell = @map[ @y_cell ][ @x_cell + 1 ]

      if @map_cell.value == Cell::EMPTY_CELL
        # Let the player keep on walkin'...
      elsif @map_cell.value == Cell::END_CELL
        show_end_screen
      elsif @map_cell.value == Cell::DOOR_CELL \
         && @map_cell.state == Door::STATE_OPEN
        # Let the player pass through the open door...
      elsif @map_cell.value == Cell::SECRET_CELL \
         && @map_cell.state == Pushwall::STATE_MOVING

        if @player_x >= ( @map_cell.left.to_i - ( Cell::WIDTH - Cell::MARGIN ) )
          @player_move_x = @map_cell.left.to_i - ( Cell::WIDTH - Cell::MARGIN ) - @player_x
        end
      elsif @x_sub_cell >= ( Cell::WIDTH - Cell::MARGIN )
        @player_move_x = -( @x_sub_cell - ( Cell::WIDTH - Cell::MARGIN ) )
      end

    # Check for collisions while player is moving east
    #
    elsif @player_move_x < 0
      @map_cell = @map[ @y_cell ][ @x_cell - 1 ]

      if @map_cell.value == Cell::EMPTY_CELL
        # Let the player keep on walkin'...
      elsif @map_cell.value == Cell::END_CELL
        show_end_screen
      elsif @map_cell.value == Cell::DOOR_CELL \
         && @map_cell.state == Door::STATE_OPEN
        # Let the player pass through the open door...
      elsif @map_cell.value == Cell::SECRET_CELL \
         && @map_cell.state == Pushwall::STATE_MOVING

        if @player_x <= ( @map_cell.right.to_i + Cell::MARGIN )
          @player_move_x = @map_cell.right.to_i + Cell::MARGIN - @player_x
        end
      elsif @x_sub_cell <= Cell::MARGIN
        @player_move_x = Cell::MARGIN - @x_sub_cell
      end
    end

    # Check for collisions while player is moving south
    #
    if @player_move_y > 0
      @map_cell = @map[ @y_cell + 1 ][ @x_cell ]

      if @map_cell.value == Cell::EMPTY_CELL
        # Let the player keep on walkin'...
      elsif @map_cell.value == Cell::END_CELL
        show_end_screen
      elsif @map_cell.value == Cell::DOOR_CELL \
         && @map_cell.state == Door::STATE_OPEN
        # Let the player pass through the open door...
      elsif @map_cell.value == Cell::SECRET_CELL \
         && @map_cell.state == Pushwall::STATE_MOVING

        if @player_y >= ( @map_cell.top.to_i - ( Cell::HEIGHT - Cell::MARGIN ) )
          @player_move_y = @map_cell.top.to_i - ( Cell::HEIGHT - Cell::MARGIN ) - @player_y
        end
      elsif @y_sub_cell >= ( Cell::HEIGHT - Cell::MARGIN )
        @player_move_y = -( @y_sub_cell - ( Cell::HEIGHT - Cell::MARGIN ) )
      end

    # Check for collisions while player is moving north
    #
    elsif @player_move_y < 0
      @map_cell = @map[ @y_cell - 1 ][ @x_cell ]

      if @map_cell.value == Cell::EMPTY_CELL
        # Let the player keep on walkin'...
      elsif @map_cell.value == Cell::END_CELL
        show_end_screen
      elsif @map_cell.value == Cell::DOOR_CELL \
         && @map_cell.state == Door::STATE_OPEN
        # Let the player pass through the open door...
      elsif @map_cell.value == Cell::SECRET_CELL \
         && @map_cell.state == Pushwall::STATE_MOVING

        if @player_y <= ( @map_cell.bottom.to_i + Cell::MARGIN )
          @player_move_y = @map_cell.bottom.to_i + Cell::MARGIN - @player_y
        end
      elsif @y_sub_cell <= Cell::MARGIN
        @player_move_y = Cell::MARGIN - @y_sub_cell
      end
    end

    @player_x = clip_value( @player_x + @player_move_x, Cell::WIDTH,  @map_x_size - Cell::WIDTH )
    @player_y = clip_value( @player_y + @player_move_y, Cell::HEIGHT, @map_y_size - Cell::HEIGHT )

    @player_move_x = 0
    @player_move_y = 0
  end

  # Waits for and processes keyboard input from user.
  #
  # @see https://gist.github.com/acook/4190379
  #
  def check_input
    key = Input.get_key

    return if key.nil?

    case key
      # Escape
      when "\e"

      # Backspace
      when "\177"
        @player_angle = ( @player_angle - @angles [ 90 ] ) % @angles[ 360 ]

      # Delete
      when "\004"

      # Up arrow
      when "\e[A", "\u00E0H", "w"
        @player_move_x = ( @cos_table[ @player_angle ] * movement_step ).round
        @player_move_y = ( @sin_table[ @player_angle ] * movement_step ).round

      # Down arrow
      when "\e[B", "\u00E0P", "s"
        @player_move_x = -( @cos_table[ @player_angle ] * movement_step ).round
        @player_move_y = -( @sin_table[ @player_angle ] * movement_step ).round

      # Right arrow
      when "\e[C", "\u00E0M", "l"
        @player_angle = ( @player_angle + turn_step ) % @angles[ 360 ]

      # Left arrow
      when "\e[D", "\u00E0K", "k"
        @player_angle = ( @player_angle - turn_step + @angles[ 360 ] ) % @angles[ 360 ]

      # Ctrl-C
      when "\u0003"
        exit 0

      when " "
        @move_x = ( @cos_table[ @player_angle ] * Cell::WIDTH ).round
        @move_y = ( @sin_table[ @player_angle ] * Cell::HEIGHT ).round
        @x_cell = ( @player_x + @move_x ) / Cell::WIDTH
        @y_cell = ( @player_y + @move_y ) / Cell::HEIGHT

        case @map[ @y_cell ][ @x_cell ].class.to_s
        when "Door"
          case @map[ @y_cell ][ @x_cell ].state
          when Door::STATE_CLOSED
            @map[ @y_cell ][ @x_cell ].state = Door::STATE_OPENING
            @doors << @map[ @y_cell ][ @x_cell ]
          when Door::STATE_OPEN
            @map[ @y_cell ][ @x_cell ].state = Door::STATE_CLOSING
          end
        when "Pushwall"
          case @map[ @y_cell ][ @x_cell ].type
          when Pushwall::TYPE_PUSH
            if @move_x.abs > @move_y.abs
              if @player_angle >= @angles[ 90 ] && @player_angle < @angles[ 270 ]
                @push_direction = Cell::MOVING_EAST
              else
                @push_direction = Cell::MOVING_WEST
              end
            else
              if @player_angle >= @angles[ 0 ] && @player_angle < @angles[ 180 ]
                @push_direction = Cell::MOVING_SOUTH
              elsif @player_angle >= @angles[ 180 ] && @player_angle < @angles[ 360 ]
                @push_direction = Cell::MOVING_NORTH
              end
            end

            if @map[ @y_cell ][ @x_cell ].activate( @push_direction )
              @pushwalls << @map[ @y_cell ][ @x_cell ]
            end
          end
        end

      when "1", "2", "3"
        @color_mode = key.to_i

      when "a"
        # Player is attempting to strafe left
        @player_move_x = ( @cos_table[ ( @player_angle - @angles[ 90 ] ) % @angles[ 360 ] ] * movement_step ).round
        @player_move_y = ( @sin_table[ ( @player_angle - @angles[ 90 ] ) % @angles[ 360 ] ] * movement_step ).round

      when "d"
        # Player is attempting to strafe right
        @player_move_x = ( @cos_table[ ( @player_angle + @angles[ 90 ] ) % @angles[ 360 ] ] * movement_step ).round
        @player_move_y = ( @sin_table[ ( @player_angle + @angles[ 90 ] ) % @angles[ 360 ] ] * movement_step ).round

      when "c"
        @draw_ceiling = !@draw_ceiling

        if @draw_ceiling
          @ceiling_color = @default_ceiling_color
          @ceiling_texture = @default_ceiling_texture
        else
          @ceiling_color = Color::BLACK
          @ceiling_texture = " "
        end

      when "?"
        show_debug_screen

      when "f"
        @draw_floor = !@draw_floor

        if @draw_floor
          @floor_color = @default_floor_color
          @floor_texture = @default_floor_texture
        else
          @floor_color = Color::BLACK
          @floor_texture = " "
        end

      when "h"
        show_help_screen

      when "i"
        @show_debug_info = !@show_debug_info
        clear_screen true

      when "m"
        draw_screen_wipe WIPE_PIXELIZE_IN
        @player_x = @magic_x unless @magic_x.nil?
        @player_y = @magic_y unless @magic_y.nil?
        update_buffer
        draw_screen_wipe WIPE_PIXELIZE_OUT
        update_buffer

      when "p"
        Input.get_key
        reset_frame_rate

      when "q"
        show_exit_screen

      when "r"
        load __FILE__

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
    @debug_string = "#{ @player_x / Cell::WIDTH } x #{ @player_y / Cell::HEIGHT } | #{ '%.2f' % @frame_rate } fps "
    STDOUT.write "\e[1;#{ @screen_width - @debug_string.size }H #{ @debug_string }"
  end

  # Applies the selected screen wipe/transition to the active buffer.
  #
  # @param type [Integer] Desired wipe mode to use (WIPE_X)
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
    @status_right = "#{ @status_x } x #{ @status_y } / #{ @status_angle }".ljust( 18 )

    puts @status_left + @status_middle + @status_right
  end

  # Positions the cursor to the specified row and column.
  #
  def position_cursor( row, column )
    STDOUT.write "\e[#{ row };#{ column }H"
  end

  # Our ray casting engine, AKA The Big Kahuna(TM).
  #
  # Many thanks to Andre LaMothe for serving as the inspiration behind
  # the original engine that drives this ray caster today.
  #
  # @author Adam Parrott <parrott.adam@gmail.com>
  # @author Andre LaMothe <andre@gameinstitute.com>
  #
  # @param x_start [Integer] Starting X world coordinate to use for casting
  # @param y_start [Integer] Starting Y world coordinate to use for casting
  # @param angle   [Float]   Starting viewing angle to use for casting
  #
  def ray_cast( x_start, y_start, angle )
    @cast_angle = ( angle - @angles[ @half_fov ] + @angles[ 360 ] ) % @angles[ 360 ]

    for ray in 1..@screen_width
      @x_dist = cast_x_ray( x_start, y_start, @cast_angle )
      @y_dist = cast_y_ray( x_start, y_start, @cast_angle )

      if @x_dist < @y_dist
        @cast[ ray ] =
        {
          dist: @x_dist,
          map_x: @x_x_cell,
          map_y: @x_y_cell,
          map_type: @x_map_cell.value,
          scale: ( @fish_eye_table[ ray ] * ( 2048 / ( 1e-10 + @x_dist ) ) ).round,
          dark_wall: true
        }
      else
        @cast[ ray ] =
        {
          dist: @y_dist,
          map_x: @y_x_cell,
          map_y: @y_y_cell,
          map_type: @y_map_cell.value,
          scale: ( @fish_eye_table[ ray ] * ( 2048 / ( 1e-10 + @y_dist ) ) ).round,
          dark_wall: false
        }
      end

      @cast_angle = ( @cast_angle + 1 ) % @angles[ 360 ]
    end
  end

  # Fills the buffer with the results of our ray casting data.
  #
  def populate_buffer
    @cast.each_with_index do |ray, index|
      next if ray.nil?

      @wall_scale = ( clip_value( ray[ :scale ], 0, @screen_height ) / 2 ).to_i
      @wall_top = ( @screen_height / 2 ) - @wall_scale
      @wall_bottom = ( @screen_height / 2 ) + @wall_scale

      @wall_color = @wall_colors[ ray[ :map_type ] ][ ray[ :dark_wall ] ? 0 : 1 ]
      @wall_sliver = Color.colorize( ray[ :map_type ], @wall_color, @color_mode )
      @ceiling_sliver = Color.colorize( @ceiling_texture, @ceiling_color, @color_mode )
      @floor_sliver = Color.colorize( @floor_texture, @floor_color, @color_mode )

      @slice  = "#{ @ceiling_sliver }," * [ @wall_top - 1, 0 ].max
      @slice += "#{ @wall_sliver },"    * ( @wall_bottom - @wall_top + 1 )
      @slice += "#{ @floor_sliver },"   * [ @screen_height - @wall_bottom, 0 ].max

      @sliver = @slice.split( "," )

      for y in 0...@screen_height
        @buffer[ y ][ index ] = @sliver[ y ]
      end
    end
  end

  # Resets the delta time adjustment value used for our movement calculations.
  #
  def reset_delta_time
    @delta_start_time = Time.now
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

  # Resets world map.
  #
  def reset_map
    setup_map
  end

  # Resets player's position.
  #
  def reset_player
    @player_angle = @player_starting_angle
    @player_x = @player_starting_x
    @player_y = @player_starting_y
  end

  # Resets internal game timers.
  #
  def reset_timers
    reset_delta_time
    reset_frame_rate
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
    @movewalls = []
    @pushwalls = []

    @map = \
    [
      %w( 5 5 5 5 5 5 5 5 5 5 5 5 5 5 5 5 5 5 5 4 4 4 4 4 4 4 4 4 2 2 2 2 ),
      %w( 5 . . . . . . . . . . . . . . . . . 4 4 . . . . . . . . | . . 2 ),
      %w( 5 . . . . . . . 6 6 6 . . . . . . . 4 4 . . . . . . . 4 2 2 . 2 ),
      %w( 5 . . . . . . . 6 M 6 . . . . . . . 4 4 . m . . . . . 4 2 2 . 2 ),
      %w( 5 . . . . . . 6 6 . 6 6 . . . . . . 4 4 . . m . . . . 4 2 2 . 2 ),
      %w( 5 . . . 6 . . . . . . . . . 6 . . . 4 4 . . . m . . . 4 2 . . 2 ),
      %w( 5 . 6 6 6 . . . . . . . . . 6 6 6 . 4 4 . . . . . . . 4 2 . 2 2 ),
      %w( 5 . 6 m . . . . 3 . 3 m . . . . 6 . 4 4 . 3 . . . 3 . 4 2 . 2 2 ),
      %w( 5 . 6 6 6 . . . . . . . . . 6 6 6 . 4 4 . . . . . . . 4 2 . 2 2 ),
      %w( 5 . . . 6 . . . . . . . . . 6 . . . 4 4 . . . m . . . 4 2 . . 2 ),
      %w( 5 . . . . . . 6 6 . 6 6 . . . . . . 4 4 . . . . m . . 4 2 2 . 2 ),
      %w( 5 . . . . . . . 6 E 6 . . . . . . . 4 4 . . . . . m . 4 2 2 . 2 ),
      %w( 5 . . . . . . . 6 6 6 . . . . . . . 4 4 . . . . . . . 4 2 2 . 2 ),
      %w( 5 . . . . . . . . . . . . . . . . . 4 4 . . . . . . . 4 2 . . 2 ),
      %w( 5 5 5 5 5 5 5 - 5 5 5 5 5 5 5 5 5 5 5 4 4 4 4 - 4 4 4 4 2 . 2 2 ),
      %w( 5 5 . . 5 . . . . . 5 4 4 4 4 4 4 4 4 4 . . . . . . . 4 2 . 2 2 ),
      %w( 5 5 . . | . . . . . 5 . . . . . . . . . . . . . . . . 4 2 . 2 2 ),
      %w( 5 . . . 5 . . . . . | . . . . . . . . . . . . . . . . 4 2 . . 2 ),
      %w( 5 . . . 5 5 5 5 5 5 5 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4 2 . . 2 ),
      %w( 2 P 2 2 2 2 2 2 2 2 2 1 1 1 1 1 1 1 1 1 1 1 1 1 2 2 2 2 2 2 P 2 ),
      %w( 2 . . . 2 2 2 . . . 2 1 M 1 . . . . . . 1 M 1 1 . . . . 2 . . 2 ),
      %w( 2 . . . 2 2 2 . . . 2 . . . . . . . . . . . . 1 . . . . 2 . . 2 ),
      %w( 2 . . . 2 2 2 . . . 2 . . . . . . . . . . . . 1 . . . . | . . 2 ),
      %w( 2 2 - 2 2 2 2 2 - 2 2 . . . . . . . . . . . . 1 . . . . 2 . . 2 ),
      %w( 2 . . . . . . . . . 2 . . . . 3 . . 3 . . . . 1 . . . . 2 2 2 2 ),
      %w( 2 . . . . . . . . . | . . . . . . . . . . . . | . . . . 2 2 2 2 ),
      %w( 2 . . . . . . . . . 2 . . . . 3 . . 3 . . . . 1 . . . . 2 2 2 2 ),
      %w( 2 2 - 2 2 2 2 2 - 2 2 . . . . . . . . . . . . 1 . . . . 2 . . 2 ),
      %w( 2 . . . 2 2 2 . . . 2 . . . . . . . . . . . . 1 . . . . | . . 2 ),
      %w( 2 . . . 2 2 2 . . . 2 . M . . . . . . . . M . 1 . . . . 2 . . 2 ),
      %w( 2 . ^ . 2 2 2 . . . 2 1 . 1 . . . . . . 1 . 1 1 . . . . 2 . . 2 ),
      %w( 2 2 2 2 2 2 2 2 2 2 2 1 1 1 1 1 1 1 1 1 1 1 1 1 2 2 2 2 2 2 2 2 )
    ]

    for y in 0...@map_rows
      for x in 0...@map_columns
        if Cell::DOOR_CELLS.include? @map[ y ][ x ]
          @map[ y ][ x ] = Door.new(
            map: @map,
            x_cell: x,
            y_cell: y
          )

        elsif @map[ y ][ x ] == Cell::MAGIC_CELL
          @map[ y ][ x ] = Cell.new(
            map: @map,
            x_cell: x,
            y_cell: y
          )

          @magic_x = x * Cell::WIDTH + ( Cell::WIDTH / 2 )
          @magic_y = y * Cell::HEIGHT + ( Cell::HEIGHT / 2 )

        elsif Cell::PLAYER_CELLS.include? @map[ y ][ x ]
          case @map[ y ][ x ]
          when Cell::PLAYER_UP
            @player_starting_angle = @angles[ 270 ]
          when Cell::PLAYER_DOWN
            @player_starting_angle = @angles[ 90 ]
          when Cell::PLAYER_LEFT
            @player_starting_angle = @angles[ 180 ]
          when Cell::PLAYER_RIGHT
            @player_starting_angle = @angles[ 0 ]
          end

          @map[ y ][ x ] = Cell.new(
            map: @map,
            x_cell: x,
            y_cell: y
          )

          @player_starting_x = x * Cell::WIDTH + ( Cell::WIDTH / 2 )
          @player_starting_y = y * Cell::HEIGHT + ( Cell::HEIGHT / 2 )

        elsif Cell::MOVE_WALLS.include? @map[ y ][ x ]
          case @map[ y ][ x ]
          when Cell::MOVE_WALL_HORZ
            @push_direction = Cell::MOVING_WEST
          when Cell::MOVE_WALL_VERT
            @push_direction = Cell::MOVING_SOUTH
          end

          @map[ y ][ x ] = Pushwall.new(
            map: @map,
            x_cell: x,
            y_cell: y,
            direction: @push_direction,
            type: Pushwall::TYPE_MOVE
          )

          @movewalls << @map[ y ][ x ]

        elsif @map[ y ][ x ] == Cell::SECRET_CELL
          @map[ y ][ x ] = Pushwall.new(
            map: @map,
            x_cell: x,
            y_cell: y,
            type: Pushwall::TYPE_PUSH
          )

        else
          @map[ y ][ x ] = Cell.new(
            map: @map,
            value: @map[ y ][ x ],
            x_cell: x,
            y_cell: y
          )
        end
      end
    end

    @player_angle = @player_starting_angle
    @player_x = @player_starting_x
    @player_y = @player_starting_y
  end

  # Configures all precalculated lookup tables.
  #
  def setup_tables
    @angles         = []
    @cast           = []
    @cos_table      = []
    @sin_table      = []
    @tan_table      = []
    @doors          = []
    @fish_eye_table = []
    @inv_cos_table  = []
    @inv_sin_table  = []
    @inv_tan_table  = []
    @movewalls      = []
    @pushwalls      = []
    @x_step         = []
    @y_step         = []
    @wall_colors    = {}

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
        @y_step[ angle ] =  ( @tan_table[ angle ] * Cell::HEIGHT ).abs
      else
        @y_step[ angle ] = -( @tan_table[ angle ] * Cell::HEIGHT ).abs
      end

      if angle >= @angles[ 90 ] && angle < @angles[ 270 ]
        @x_step[ angle ] = -( @inv_tan_table[ angle ] * Cell::WIDTH ).abs
      else
        @x_step[ angle ] =  ( @inv_tan_table[ angle ] * Cell::WIDTH ).abs
      end
    end

    for angle in -@angles[ @half_fov ]..@angles[ @half_fov ]
      rad_angle = ( 3.272e-4 ) + angle * 2 * 3.141592654 / @angles[ 360 ]
      @fish_eye_table[ angle + @angles[ @half_fov ] ] = 1.0 / cos( rad_angle )
    end

    # Configure some basic lookup tables for our wall colors.
    #
    @wall_colors[ '1' ] = [ Color::BLUE, Color::LIGHT_BLUE ]
    @wall_colors[ '2' ] = [ Color::GREEN, Color::LIGHT_GREEN ]
    @wall_colors[ '3' ] = [ Color::YELLOW, Color::LIGHT_YELLOW ]
    @wall_colors[ '4' ] = [ Color::CYAN, Color::LIGHT_CYAN ]
    @wall_colors[ '5' ] = [ Color::BLUE, Color::LIGHT_BLUE ]
    @wall_colors[ '6' ] = [ Color::GREEN, Color::LIGHT_GREEN ]
    @wall_colors[ '7' ] = [ Color::YELLOW, Color::LIGHT_YELLOW ]
    @wall_colors[ '8' ] = [ Color::CYAN, Color::LIGHT_CYAN ]
    @wall_colors[ 'D' ] = [ Color::MAGENTA, Color::LIGHT_MAGENTA ]
    @wall_colors[ 'E' ] = [ Color::WHITE, Color::WHITE ]
    @wall_colors[ 'P' ] = [ Color::RED, Color::LIGHT_RED ]

    # Configure our snarky HUD messages to the player.
    #
    @hud_messages =
    [
      "FIND THE EXIT!",
      "HAHA! LET'S DO IT AGAIN!",
      "ARE WE HAVING FUN YET?"
    ]
  end

  # Configures all application variables.
  #
  # NOTE: The order of some of these blocks are dependent upon one another,
  # so take care when moving or refactoring lines in this method.
  #
  def setup_variables
    # Define the variables for our world map.
    #
    @map_columns = 32
    @map_rows = 32
    @map_x_size = @map_columns * Cell::WIDTH
    @map_y_size = @map_rows * Cell::HEIGHT

    # Define the ever-important player variables.
    #
    @player_angle = 0
    @player_fov = 60
    @player_move_x = 0
    @player_move_y = 0
    @player_starting_angle = 90
    @player_starting_x = 0
    @player_starting_y = 0
    @player_x = 0
    @player_y = 0

    # Define our screen dimensions and field-of-view metrics.
    #
    @half_fov = @player_fov / 2
    @screen_width = 80
    @screen_height = 36

    @buffer = Array.new( @screen_height ) { Array.new( @screen_width ) }

    @fixed_factor = 512
    @fixed_count = ( 360 * @screen_width ) / @player_fov
    @fixed_step = @fixed_count / 360.0

    @frame_rate = 0.0
    @frames_rendered = 0
    @frame_start_time = 0.0

    # Define default colors and textures.
    #
    @default_ceiling_color = Color::LIGHT_GRAY
    @default_ceiling_texture = "@"
    @default_floor_color = Color::GRAY
    @default_floor_texture = "-"
    @default_wall_texture = "#"

    @ceiling_color = @default_ceiling_color
    @ceiling_texture = @default_ceiling_texture
    @floor_color = @default_floor_color
    @floor_texture = " "
    @wall_texture = @default_wall_texture

    @draw_ceiling = true
    @draw_floor = false
    @draw_walls = true

    # Define miscellaneous game variables.
    #
    @color_mode = Color::MODE_NONE
    @delta_start_time = 0.0
    @delta_time = 0.0
    @show_debug_info = false
    @play_count = 0
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
    puts ( "Draw ceiling?".ljust( 25 )       + @draw_ceiling.to_s.rjust( 25 ) ).center( @screen_width )
    puts ( "Draw floor?".ljust( 25 )         + @draw_floor.to_s.rjust( 25 ) ).center( @screen_width )
    puts ( "Display extra info?".ljust( 25 ) + @show_debug_info.to_s.rjust( 25 ) ).center( @screen_width )
    puts
    puts "[ Metrics ]".center( @screen_width )
    puts
    puts ( "active_doors".ljust( 25 )        + @doors.size.to_s.rjust( 25 ) ).center( @screen_width )
    puts ( "active_movewalls".ljust( 25 )    + @movewalls.size.to_s.rjust( 25 ) ).center( @screen_width )
    puts ( "active_pushwalls".ljust( 25 )    + @pushwalls.size.to_s.rjust( 25 ) ).center( @screen_width )
    puts ( "cell_height".ljust( 25 )         + Cell::HEIGHT.to_s.rjust( 25 ) ).center( @screen_width )
    puts ( "cell_width".ljust( 25 )          + Cell::WIDTH.to_s.rjust( 25 ) ).center( @screen_width )
    puts ( "frames_rendered".ljust( 25 )     + @frames_rendered.to_s.rjust( 25 ) ).center( @screen_width )
    puts ( "frame_rate".ljust( 25 )          + @frame_rate.to_s.rjust( 25 ) ).center( @screen_width )
    puts ( "frame_total_time".ljust( 25 )    + ( Time.now - @frame_start_time ).round( 4 ).to_s.rjust( 25 ) ).center( @screen_width )
    puts ( "play_count".ljust( 25 )          + @play_count.to_s.rjust( 25 ) ).center( @screen_width )
    puts ( "player_angle".ljust( 25 )        + ( @player_angle / @fixed_step ).round( 2 ).to_s.rjust( 25 ) ).center( @screen_width )
    puts ( "player_angle_raw".ljust( 25 )    + @player_angle.round( 2 ).to_s.rjust( 25 ) ).center( @screen_width )
    puts ( "player_fov".ljust( 25 )          + @player_fov.to_s.rjust( 25 ) ).center( @screen_width )
    puts ( "player_x".ljust( 25 )            + @player_x.to_s.rjust( 25 ) ).center( @screen_width )
    puts ( "player_y".ljust( 25 )            + @player_y.to_s.rjust( 25 ) ).center( @screen_width )
    puts ( "map_columns".ljust( 25 )         + @map_columns.to_s.rjust( 25 ) ).center( @screen_width )
    puts ( "map_rows".ljust( 25 )            + @map_rows.to_s.rjust( 25 ) ).center( @screen_width )
    puts ( "map_x_size".ljust( 25 )          + @map_x_size.to_s.rjust( 25 ) ).center( @screen_width )
    puts ( "map_y_size".ljust( 25 )          + @map_y_size.to_s.rjust( 25 ) ).center( @screen_width )
    puts ( "screen_width".ljust( 25 )        + @screen_width.to_s.rjust( 25 ) ).center( @screen_width )
    puts ( "screen_height".ljust( 25 )       + @screen_height.to_s.rjust( 25 ) ).center( @screen_width )
    puts
    puts "Press any key to continue...".center( @screen_width )
    puts

    Input.wait_key
    clear_screen true
    update_buffer
  end

  # Shows the ending screen.
  #
  def show_end_screen
    draw_screen_wipe WIPE_BLINDS
    clear_screen true

    position_cursor ( @screen_height / 2 ) - 7, 0

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

    Input.clear_input
    Input.wait_key

    @play_count += 1

    reset_player
    reset_map
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
    puts "Testing has shown that running this game in color ".center( @screen_width )
    puts "mode under some terminals will result in very poor".center( @screen_width )
    puts "poor performance.  Thus, if you experience low    ".center( @screen_width )
    puts "frame rates in your chosen terminal, try running  ".center( @screen_width )
    puts "in 'no color' mode OR use a different terminal    ".center( @screen_width )
    puts "altogether for the best possible experience. See  ".center( @screen_width )
    puts "the README for a table of compatible terminals.   ".center( @screen_width )
    puts
    puts "Enjoy the game!                                   ".center( @screen_width )
    puts
    puts "[ Keys ]".center( @screen_width )
    puts
    puts ( "Move forward".ljust( 25 )   + "Up Arrow, W".rjust( 25 ) ).center( @screen_width )
    puts ( "Move backward".ljust( 25 )  + "Down Arrow, S".rjust( 25 ) ).center( @screen_width )
    puts ( "Strafe left".ljust( 25 )    + "A".rjust( 25 ) ).center( @screen_width )
    puts ( "Strafe right".ljust( 25 )   + "D".rjust( 25 ) ).center( @screen_width )
    puts ( "Turn left".ljust( 25 )      + "Left Arrow, K".rjust( 25 ) ).center( @screen_width )
    puts ( "Turn right".ljust( 25 )     + "Right Arrow, L".rjust( 25 ) ).center( @screen_width )
    puts
    puts ( "Open doors/activate walls".ljust( 25 ) + "Space".rjust( 25 ) ).center( @screen_width )
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

    Input.wait_key
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

    Input.wait_key
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
    populate_buffer
    clear_screen
    draw_buffer
    draw_status_line
  end

  # Updates the current delta time factor, which we apply to all time-based
  # calculations (like object movement, animations, etc.) to acheive the same
  # rate of movement across different terminals and frame rates. 
  #
  def update_delta_time
    @delta_time = ( Time.now - @delta_start_time ).to_f
    @delta_start_time = Time.now
  end

  # Updates the state and position of all active doors.
  #
  def update_doors
    return if @doors.size == 0

    @doors.each do |door|
      door.update @delta_time

      if door.state == Door::STATE_CLOSED
        @doors.delete door
      end
    end
  end

  # Updates the state and position of any moving walls.
  #
  def update_movewalls
    return if @movewalls.size == 0

    @movewalls.each do |movewall|
      movewall.update @delta_time

      if movewall.state == Pushwall::STATE_FINISHED
        @movewalls.delete movewall
      end
    end
  end

  # Updates the state and position of any active pushwalls.
  #
  def update_pushwalls
    return if @pushwalls.size == 0

    @pushwalls.each do |pushwall|
      pushwall.update @delta_time

      if pushwall.state == Pushwall::STATE_FINISHED
        @pushwalls.delete pushwall
      end
    end
  end

  # Updates the current frame rate metric.
  #
  def update_frame_rate
    @frames_rendered += 1

    if ( Time.now - @frame_start_time ) >= 1.0
      @frame_rate = ( @frames_rendered / ( Time.now - @frame_start_time ) ).round( 2 )
      @frames_rendered = 0
      @frame_start_time = Time.now
    end
  end
end

Game.new.play
