```
   .~`'888x.!**h.-``888h.               x .d88'     oec :
  dX   `8888   :X   48888>         u.    5888R     @88888                u.    u.
 '888x  8888  X88.  '8888>   ...ue888b   '888R     8'*88%       .u     x@88k u@88c.
 '88888 8888X:8888:   )?''`  888R Y888r   888R     8b.       ud8888.  ^'8888''8888'^
  `8888>8888 '88888>.88h.    888R I888>   888R    u888888> :888'8888.   8888  888R
    `8' 888f  `8888>X88888.  888R I888>   888R     8888R   d888 '88%'   8888  888R
   -~` '8%'     88' `88888X  888R I888>   888R     8888P   8888.+'      8888  888R
   .H888n.      XHn.  `*88! u8888cJ888    888R     *888>   8888L        8888  888R
  :88888888x..x88888X.  `!   '*888*P'    .888B .   4888    '8888c. .+  '*88*' 8888'
  f  ^%888888% `*88888nx'      'Y'       ^*888%    '888     '88888%      ''   'Y'
       `'**'`    `'**''                    '%       88R       'YP'
                                                    88>
                                                    48
                                                    '8
   .....                                       s                          ....
.H8888888h.  ~-.                              :8      .x~~'*Weu.      .xH888888Hx.
888888888888x  `>               uL   ..      .88     d8Nu.  9888c   .H8888888888888:
~     `?888888hx~      .u     .@88b  @88R   :888ooo  88888  98888   888*'''?''*88888X
      x8.^'*88*'    ud8888.  ''Y888k/'*P  -*8888888  '***'  9888%  'f     d8x.   ^%88k
`-:- X8888x       :888'8888.    Y888L       8888          ..@8*'   '>    <88888X   '?8
     488888>      d888 '88%'     8888       8888       ````'8Weu    `:..:`888888>    8>
   .. `'88*       8888.+'        `888N      8888      ..    ?8888L         `'*88     X
 x88888nX'      . 8888L       .u./'888&    .8888Lu= :@88N   '8888N    .xHHhx..'      !
!'*8888888n..  :  '8888c. .+ d888' Y888*'  ^%888*   *8888~  '8888F   X88888888hx. ..!
    '*88888888*    '88888%   ` 'Y   Y'       'Y'    '*8'`   9888%   !   '*888888888'
       ^'***'`       'YP'                             `~===*%'`            ^'***'`
```

"Kinda like the original. Now for your terminal window!"

Wolfentext3D is a simple take on a classic game with the following goals:

* Lean and mean: all code should be contained in a single source file.
* Cross-platform: it should work reasonably well across Linux, Mac, and yes, even Windows.
* No external dependencies, other than the Ruby core and standard libraries.
* No bitmap graphics: everything uses ASCII art and terminal colors!

Wolfentext is proudly (if not somewhat arbitrarily) written in pure Ruby.  Where possible, documentation is provided by code comments using the popular YARD documentation format.

Features
========

Here are the features currently supported in Wolfentext:

* Solid orthogonal walls
* Floor colors and "textures"
* Ceiling colors and "textures"
* Collision detection with wall sliding
* Title, help, debug, and ending screens
* 16 colors of super-pixelated eye candy!

...and here are some **missing** features that are in the works:

* Wall textures
* Sliding doors
* Secret walls
* Stationary and usable objects
* Enemies and other entities
* Sounds or music
* Resizeable viewport
* OS and terminal type detection
* 256 colors (on supported terminals)

Requirements
============

The only requirement for Wolfentext is a local installation of **Ruby 2.0.0+**.

Wolfentext should also work on all recent versions of OS X, Linux, and Windows.  *(That said, Windows users may notice some issues when running Wolfentext in color mode.  See the notes below for more information.)*

Installation
============

To install Wolfentext, simply download the `wolfentext.rb` file or clone the repo to your local machine:

```
$ git clone http://github.com/AtomicPair/wolfentext3d.git
```

Usage
=====

```
$ cd wolfentext
$ ruby wolfentext.rb
```

Notes
=====

Despite it's shimmering textiness, Wolfentext ain't perfect.  Here are some known issues with the game of which you should be aware:

* *Graphics*: In order to maintain code readability and cross-platform compatibility, Wolfentext uses a simple, single-buffered, terminal-based graphics system. In non-color mode, this should work quite well across all platforms, achieving framerates up to 60 fps.  However, Windows users may notice **significant** performance issues when using *any* color mode in the native Comand Prompt or Powershell terminals.  Other third-party terminals may yield better performance but have not yet been tested.
* *Input*: The input logic only handles one keypress at a time.  Support for multiple keypresses is planned in a future release, assuming we can find a sensible cross-platform method that works.
* *Terminal*: At present, the code assumes you are running this script in a compatible terminal.  Logic should be added that detects not only the current terminal upon program start, but also what features are presently available to that terminal and whether they are compatible with the current version of Wolfentext.
* *Optimizations*: Although the script utilizes several optimizations in key areas, the code could still benefit from (1) further graphical optimizations for Windows users, (2) further refinement to the ray casting lookup tables, and (3) better memory profiling to identify and reduce overall resource allocations.

Any thoughts or suggestions for solving these problems -- including pull requests -- are always welcome!

Support
=======

If you have any problems or suggestions, please file an issue in the official [GitHub repository](http://github.com/AtomicPair/wolfentext3d/).
