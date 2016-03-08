Wolfentext3D
============

"Inspired by the classic, but now for your terminal window!"

Wolfentext3D is a simple take on a classic game with the following goals:

* Lean and mean: all code should be contained in a single source file.
* No external dependencies, other than the Ruby core and standard libraries.
* No bitmap graphics: everything uses ASCII art and terminal colors!

Wolfentext3D is proudly (if not somewhat arbitrarily) written in pure Ruby.  Where possible, code documentation is provided in YARD format.

Features
========

Here are the items and features currently supported in Wolfentext:

* Solid orthogonal walls
* Floor colors and "textures"
* Ceiling colors and "textures"
* Collision detection with wall sliding
* Title, help, and debug screens

...and here are some items presently **missing** that may be added later:

* Wall textures
* Sliding doors
* Secret walls
* Stationary and usable objects
* Enemies and other entities
* Sounds or music

Requirements
============

The only requirement for Wolfentext is a local installation of Ruby 2.0.0+.

Wolfentext should also work on all recent versions of OS X, Linux, and Windows.  *(That said, Windows users may notice some issues when running Wolfentext on their machines.  See the notes below for more information.)*

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

* *Input*: The input logic only handles one keypress at a time.  Support for multiple keypresses is planned in a future release.
* *Gameplay*: Right now, Wolfentext only runs when a key is pressed.  This will change in the future once support for enemies and other dynamic objects are added.
* *Timing*: Currently, there are no delta time calculations applied to the screen updates, player movements, or world events.  This could cause events to occur slower or faster than expected, depending on the speed of your machine and terminal.
* *Graphics*: In order to maintain code readability and cross-platform compatibility, Wolfentext uses a fairly crude, single-buffered graphical updating system. Migrating to Ruby's built-in support for the well-known curses library would greatly improve this situation on *nix systems, but doing so might pose an external dependency problem for Windows users.
* *Optimizations*: Although the script utilizes several optimizations in key areas, the code could still benefit from (1) further optimizations in the area of the graphics subsystem (mentioned above), (2) further refinement to the ray casting lookup tables, and (3) better memory profiling to identify and reduce overall resource allocations.

Any thoughts or suggestions (up to and including pull requests) for solving some of these problems are always welcome!

Support
=======

If you have any problems or suggestions, please file an issue in the official [GitHub repository](http://github.com/AtomicPair/wolfentext3d/).
