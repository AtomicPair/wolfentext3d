[![Run on Repl.it](https://repl.it/badge/github/AtomicPair/wolfentext3d)](https://repl.it/github/AtomicPair/wolfentext3d)

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

"Kinda like the original, but now for your terminal window!"

Wolfentext3D is a simple take on a classic game with the following goals:

* Lean and mean: all code should be contained in a single source file.
* Cross-platform: it should work reasonably well across Linux, Mac, and yes, even Windows.
* Instructive: the code should be clean, readable, and easy to follow.
* Stand-alone: No external dependencies, other than the Ruby core and standard libraries.
* No bitmap graphics: everything uses ASCII art and terminal colors!

Wolfentext is proudly (if not somewhat arbitrarily) written in pure Ruby.

Documentation may be derived from the code using the popular YARD documentation format.

Features
========

![Preview](preview.gif)

Here are the features currently supported in Wolfentext:

* Solid, orthogonal walls
* Recessed horizontal sliding doors
* Solid floor and ceiling background
* Textured floors and ceilings
* Collision detection with wall sliding
* Multi-directional pushwalls and moving walls
* Title, help, debug, and ending screens
* Over 16 colors of pixelated eye candy!

...and here are some **missing** features that are still in the works:

* [Stationary and usable objects](https://github.com/AtomicPair/wolfentext3d/issues/5)
* [Enemies and other entities](https://github.com/AtomicPair/wolfentext3d/issues/4)
* [Sounds and/or music](https://github.com/AtomicPair/wolfentext3d/issues/6)
* [Resizeable viewport](https://github.com/AtomicPair/wolfentext3d/issues/7)
* [Terminal type detection](https://github.com/AtomicPair/wolfentext3d/issues/8)

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

To start enjoying Wolfentext's pixelated goodness, command thine terminal thusly:

```
$ cd wolfentext
$ ruby wolfentext.rb
```

Compatibility
=============

Wolfentext has been tested against the following terminals and platforms:

| Terminal       | Platform     | B/W performance | Color performance |
|----------------|--------------|----------------:|------------------:|
| Command Prompt | Windows 7    |       30-45 fps |        0-15 fps   |
| ConEmu         | Windows 7    |  Not yet tested |  Not yet tested   |
| Cygwin         | Windows 7    |  Not yet tested |  Not yet tested   |
| GNOME Terminal | Ubuntu 14.04 |       45-60 fps |        0-15 fps   |
| Guake          | Ubuntu 14.04 |       45-60 fps |       45-60 fps   |
| iTerm          | Mac OS X     |  Not yet tested |  Not yet tested   |
| Konsole        | Ubuntu 14.04 |       45-60 fps |       45-60 fps   |
| PowerShell     | Windows 7    |       30-45 fps |        0-15 fps   |
| Tilda          | Ubuntu 14.04 |       45-60 fps |        0-15 fps   |
| tmux           | Ubuntu 14.04 |       45-60 fps |       45-60 fps   |
| XTerm          | Ubuntu 14.04 |       45-60 fps |        0-15 fps   |
| Z shell (zsh)  | Mac OS X     |       45-60 fps |       45-60 fps   |

Although most modern terminal emulators seem capable of delivering playable frame rates, it goes without saying that users with integrated or low-end graphics cards may experienced decreased (and in some cases, unplayable) performance.  I have noticed this myself when testing various terminal emulators on my main system: a 2010 HP Pavilion dv7 laptop with hybrid ATI graphics.  *Some terminals performed over 100-200% faster when using the discrete ATI graphics card instead of the integrated Intel 915 chipset.*

**If you are experiencing degraded or unplayable performance with Wolfentext in your favorite terminal program,** try adjusting the graphics properties of your host system (including switching to a discrete graphics mode, if your system supports it).  Using the table above as a guide, you can also try running Wolfentext in another terminal emulator which may yield better performance.

Finally, help us keep this table updated with the latest information!  If you experience results different from these, please let us know by [filing an issue](http://github.com/AtomicPair/wolfentext3d/issues/) in the tracker.

Issues
======

Despite it's shimmering textiness, Wolfentext ain't perfect.  Here are some known issues with the game of which you should be aware:

* *Graphics*: In order to maintain code readability and cross-platform compatibility, Wolfentext uses a simple, single-buffered, terminal-based graphics system. In non-color mode, this should work quite well across all platforms, often achieving frame rates up to 60 fps.  However, some users may notice **significant** performance issues when using *any* color mode in their preferred terminal (see Compatibility section above).  Other third-party terminals may yield better performance but have not yet been tested.

* *Input*: The input logic only handles one keypress at a time.  Support for multiple keypresses is planned in a future release, assuming we can find a sensible cross-platform method that works.

* *Terminal*: At present, the code assumes you are running this script in a compatible terminal.  Logic should be added that detects not only the current terminal upon program start, but also what features are presently available to that terminal and whether they are compatible with the current version of Wolfentext.

* *Optimizations*: Although the script utilizes several optimizations in key areas, the code could still benefit from (1) further graphical optimizations for common, low-performing terminal configurations; (2) reducing and/or eliminating the amount of floating-point math used across game calculations and lookup tables (with additional benchmarking to prove which optimizations are the most beneficial); and (3) optimizing any other remaining areas of the core ray casting engine, which presently consumes most of the processing time for each game loop iteration.  Other areas of opportunity may also exist which have not yet been identified.

Any suggestions for solving these issues are always welcome!  See the Contributing section below.

Contributing
============

Pull requests that fix bugs or propose new functionality are always welcome, provided contributors keep the following conditions in mind:

* Code contributions should be properly formatted and fully documented before final submissions are merged into master.  If I make formatting changes to your code or request that you make similar changes yourself, please don't take it personally: the goal is to maintain a simple but consistent style across the entire project that is both readable and maintainable by others in the future.  :-)

* Before submitting new feature requests, it is recommended that you check the list of [open roadmap tickets](https://github.com/AtomicPair/wolfentext3d/labels/roadmap) to see if anyone else is already working on that feature.  This will help reduce the chance of duplicating efforts while allowing everyone to collaborate on the same feature more effectively.

* All contributors whose pull requests are accepted will be given full credit for their ideas and/or submissions in the project README.

* Since this project is officially ["unlicensed"](http://unlicense.org/) as public domain software, all contributors will need to agree to the following snippet and include it as a separate comment in their pull request before their contributions can be merged into the repository:

```
I dedicate any and all copyright interest in this software to the
public domain. I make this dedication for the benefit of the public at
large and to the detriment of my heirs and successors. I intend this
dedication to be an overt act of relinquishment in perpetuity of all
present and future rights to this software under copyright law.
```

If you have any questions about this process, please let me know!

Support
=======

If you have any problems or suggestions, please let me know by [filing an issue](http://github.com/AtomicPair/wolfentext3d/issues/) in the tracker.

History
=======

Wolfentext was originally born from the need to share a code sample with a potential recruiter.  The sample had to be contained within a single file, and since I didn't have any public samples available at the time that I felt comfortable sharing, I spent the next few days creating the first iteration of Wolfentext from scratch.  Since then, the script has taken on a life of it's own: adding new features, fixing bugs, and morphing into an homage to the classic 2.5D shooters from the days of my youth.

For the curious, here's a short summary table highlighting various milestones from past releases:

| Release | Notable features                                |
|---------|-------------------------------------------------|
| 0.9.1   | Updated licensing and contributor information   |
| 0.9.0   | Ceiling and floor textures                      |
|         | In-game system messages                         |
| 0.8.0   | Wall textures                                   |
| 0.7.0   | Multi-direction pushwalls                       |
|         | Multi-direction moving walls                    |
|         | Directionally colored walls (light/dark)        |
| 0.6.0   | Sliding doors                                   |
| 0.5.1   | Player strafing support                         |
| 0.3.0   | REAL non-blocking game loop and input system    |
| 0.2.0   | Improved graphic system with almost no flicker  |
| 0.1.0   | Initial alpha release                           |

License
=======

This is free and unencumbered software released into the public domain.

Anyone is free to copy, modify, publish, use, compile, sell, or distribute this software, either in source code form or as a compiled binary, for any purpose, commercial or non-commercial, and by any means.

In jurisdictions that recognize copyright laws, the author or authors of this software dedicate any and all copyright interest in the software to the public domain. We make this dedication for the benefit of the public at large and to the detriment of our heirs and successors. We intend this dedication to be an overt act of relinquishment in perpetuity of all present and future rights to this software under copyright law.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

For more information, please refer to [http://unlicense.org/](http://unlicense.org/).

Written by Adam Parrott between 2016 and 2018.  All wrongs reversed.
