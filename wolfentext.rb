#!/usr/bin/env ruby

#################################################################################
#                                                                               #
# Wolfentext3D                                                                  #
#                                                                               #
# Written by Adam Parrott <parrott.adam@gmail.com>. All wrongs reversed.        #
#                                                                               #
# This is free and unencumbered software released into the public domain.       #
#                                                                               #
# Anyone is free to copy, modify, publish, use, compile, sell, or distribute    #
# this software, either in source code form or as a compiled binary, for any    #
# purpose, commercial or non-commercial, and by any means.                      #
#                                                                               #
# In jurisdictions that recognize copyright laws, the author or authors of this #
# software dedicate any and all copyright interest in the software to the       #
# public domain. We make this dedication for the benefit of the public at large #
# and to the detriment of our heirs and successors. We intend this dedication   #
# to be an overt act of relinquishment in perpetuity of all present and future  #
# rights to this software under copyright law.                                  #
#                                                                               #
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR    #
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,      #
# FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO EVENT SHALL THE  #
# AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN    #
# ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION  #
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.               #
#                                                                               #
# For more information about this script, please visit the official repo at:    #
#                                                                               #
# http://www.github.com/AtomicPair/wolfentext3d/                                #
#                                                                               #
#################################################################################

VERSION = "0.9.1"

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

  DIRECTION_CELLS = %w( < ^ > v )
  DIRECTION_DOWN  = "v"
  DIRECTION_LEFT  = "<"
  DIRECTION_RIGHT = ">"
  DIRECTION_UP    = "^"
  DOOR_CELL       = "D"
  DOOR_CELLS      = %w( - | )
  EMPTY_CELL      = "."
  END_CELL        = "E"
  MAGIC_CELL      = "M"
  PLAYER_CELL     = "S"
  PUSH_WALL       = "P"
  WALL_CELL       = "W"

  attr_accessor :bottom
  attr_accessor :direction
  attr_accessor :left
  attr_accessor :map
  attr_accessor :offset
  attr_accessor :right
  attr_accessor :state
  attr_accessor :texture_id
  attr_accessor :top
  attr_accessor :value
  attr_accessor :x_cell
  attr_accessor :y_cell

  def initialize( args = {} )
    @bottom     = args[ :bottom ] || 0
    @direction  = args[ :direction ]
    @left       = args[ :left ]   || 0
    @map        = args[ :map ]
    @offset     = args[ :offset ] || 0
    @right      = args[ :right ]  || 0
    @state      = args[ :state ]
    @texture_id = args[ :texture_id ]
    @top        = args[ :top ]    || 0
    @value      = args[ :value ]  || EMPTY_CELL
    @x_cell     = args[ :x_cell ]
    @y_cell     = args[ :y_cell ]
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

  def self.texturize( value, color, mode = 0 )
    case mode
    when MODE_NONE
      value
    when MODE_PARTIAL
      "\e[38;5;#{ color }m#{ value }\e[0;0m"
    when MODE_FILL
      "\e[1;38;5;#{ color }m#\e[0;0m"
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
        @offset += ( 64 * delta_time )
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
        @offset -= ( 64 * delta_time )
      end
    end
  end
end

# Contains color and texture data.
#
# @author Adam Parrott <parrott.adam@gmail.com>
#
class GameData
  # Use this temporary method to convert the ANSI terminal color codes output
  # from the im2a export tool into a Wolfentext compressed color texture map,
  # used as the raw color data array for the Texture.encoding methods.
  #
  def self.temp_colors
    # [
    #   %w[ 245 6 6 6 6 6 ... ],
    #   %w[ 152 37 37 73 152 23 ... ],
    #   %w[ 152 30 30 73 73 30 ... ]
    # ]
  end

  # Steps for generating texture data from images:
  #
  # 1. Convert image data to raw ASCII character map.
  #   @see http://www.text-image.com/convert/ascii.html
  #   Image width:  64
  #   Text color:   BLACK
  #   Background:   WHITE
  #   Invert image: Yes
  #
  # 2. Extract color map data from image.
  #   @see https://github.com/tzvetkoff/im2a
  #   im2a --height=32 --width=64 <file.png> > out.txt
  #
  # 3. Clean up output from (2) to match format given in self.temp_colors method
  #    header and add parsed array data to GameData.temp_colors method.
  #
  # 4. Run Texture.encode_colors against the new GameData.temp_colors method.
  #
  # 5. Use the raw ASCII character data from step (1) and encoded color data from
  #    step (4) to make a new texture entry for this method's returned Hash object.
  #
  def self.textures
    {
      '1' => [
        [ "...........o+++++oooooo///o``/+ooooo+++-//.`....................", "11zw4qi78w4z4hjro1j60g7mzxkas6vrqqamnrwrwc44dvl93g7vzb6xd2mnyuymzrwfcu2vuha2s51fkni3jsumwf979yz67j72" ],
        [ "++++++++.--NNyyyoyhhymmmsh+`.yNdsyyy+o+:/-.`.oyys+oyyss+::++////", "12mvri6350xa3e6lli236c9cblveyi09lp4iyqjyrrdk2ud8za96f46dsodo742gi2eybv3jdtcvi7cn5wll0g0gdjv7e85w9asy" ],
        [ "mdyhosoo`--Nmso//shyhyyoso-`./dysyyy+/://-.`.sdo/+ydmyyy-/ys//hd", "13osd4hl03jr47gvzr8xubzib94gy5a6oeb7ck4yahao3r2hvbpsnshwv9nxaom1yhnmwpd8ubrqihwh1bchjqa01oxaci11pj3u" ],
        [ "dh++yso/`.-NNs++shydsoyhos-`.-+ssyyyyos+...`.++/+oyhyo/+-++/:+s+", "12kif8wywxkoa6h63vcqsu49ebici3c02ymzc7mwi0ewe2kunt43kjfzwj4tuvatriugzzk8wakgvb2n0nb90tearh4uj2vgwjy1" ],
        [ "yyyo++--``-NNhssshyosysyys-``--::.......```..oshoyysoys:+yyysyy+", "12sp3lkmedyzgumy9dhme9tlztv4dby4xbb88czmmezhjcbe3twpdwbmojvuilcyradmjiw1s44jedquue299n60hciw54rqqfp2" ],
        [ "//::-.````-mNysshhs+hsyoyo:``.-...-////oo-...+doo:+yy:+/+:+::/::", "12bdy9m0jpop02b8ild7ku3m1j1l8xv8m24h5ivfszzju2qila8hpg3p35nqsd7b7b8kew9gsb4b3po6u50do4ld58y6qmuumga9" ],
        [ "`````````.-omNsyssoysyss++-.``.sddhddmhmds:`.-/:--.....`````````", "11inenr1pky6i648cy58jqo2z1fnu0l6j8yiq8zgbjzyfs9mzo7wtq6fneraz0fs8s00fr0rs9rzfos2h74djms1nx26d7gv942z" ],
        [ "-.........--omyyhhooyoyy/-/.``-hd+oyydyso-:.......`.............", "11zw4qi78w4z4hjrgliref8t1dsqa8x2azlu3y7d52ayct66sujcuhk61fqisvjeqv3wty1qbo5wduv9nu1399a6uzhqr6jsiar2" ],
        [ "dhyddhsoo``--hm/+s/y+oys++/-``-dyooyys/y+-...hys/.-/yhhhdyhhhhhd", "13ugjpzlznwj3v0xt6m5e3zbt8euxgk5k4o7jhhld2pd1ubsn74t2n481fpq6veljtvstgiybprol9f2gic69f8fcxms1usb7u9l" ],
        [ "hssyso/-+.`--:yo/s++o/o///-.``.ys+ss:--....`-s+/:`-yhhysysohhs++", "12jp4ljbnrv0jck5hxqlocf9s2upjg0z58tlw60yj1ucsjw019tb62rx6hxytuy7yd0izgch9dqn0v8lf2rz3ihrwzo5ocmetc3y" ],
        [ "syyy+::+-.`----..``````````````//.``````````+yoy-`-yhsyyyoyyhs/o", "g811unfumqd4tzkca8megxt1nli2ig5avp0yd4my6h88cgfskss5bfbno7ph1lckkgm0nutmpw3m34j0f9obymnnuer7ljwvr6t"  ],
        [ "shoo+os/-.`.+o+/::+++-`.:/++++sdddyyyyyo/`.+NNmd/`-oyhhyyhhhyysh", "13fkovwyfs6blsj1qcw3ecoaemoj0y2eiwx21ef2lasmce004sl7axfx5t2f1t5477j558qw3y0792lg8vkyjovr2bbyb3t77xf9" ],
        [ "yooysso:..`.hss++++++`--smyoshhhhyoyo+s/:`.smyydy`-yooshhy+ooooo", "g84y7v463mrsvfp7kbla49esj7z6ft04ct6hdr5b99fr9mpjugbzqcj0yvtvos3lx09mtt1ylj681iiqponb4ns1shg314vq0om"  ],
        [ ":::--..````.y+/oy+o//`--yMdhhy+yhshhsh+/.`.sooym:`-.``.........-", "125m8bx3il9qkhf3elwmmctzs72v1sfw1zrkcmdiujcvg44fmjw6w9jeittdc6oh148dhpxsxqiozf1jz299e8ufn8c8av3xdsu3" ],
        [ ".---://///-.Moyh+s/+/``-yMyhy/ohshhsy+o:.`.hMdNh-`-....`````````", "11oebco3k0em4g6whfdzsx0lhgw647a3r2al1br1eticdlnaxb2dgtgtatkqjxwagc79oswabt4vxv7oyydy09ubrd41dw6rkve4" ],
        [ "/hhys+hhhh:`Mhdy+yoo/.`-sdhy+/ohhhshy++-.`-sNmhs-`-/s+sysss+:+.-", "12bccati52majqzq2f4lmih5luvnt0dtld94p1cjwucj08mx2nxsxnvym0358rndphcynif95cfiisxafn72rq0ntpulbbanyn01" ],
        [ "/ys+/ysys+/`Mdyyhosy/.``-hdoyysyyosoy+/-``-sNdy:-`-dsss+++://+.-", "125lfq0uu1m7mvus72te8sb18yhyk7o4d3q0agt9ol5m8b4tn12tt23m01vqbp5gyjfuyb55n7r6jwfmplz5dxiucdivuzwsf46p" ],
        [ "/syyysys/+-`Ndyhhhyo/.``-oNms//oyhyhs//.``/sNy/:.`-mhys/ooyoh:.-", "11zurhpalag7tu2d6sruvoxwx975tl8q78xgralejjfwif2bfkm7h9ezlnorscewhp3jn40d9q12vqklasqyyx00fxo0z83q3f8x" ],
        [ "/Nhhsy///+-`mNohyosy/..`.-hNo+ooso/////.`.-/+::...-so/+//+//+-..", "11u58dwrv9npbx7fuoo29op6pn917a8xzrat3qcm8wo9wqj4pkcfbyvys62zo6zizm0lbavzm7a9bxudp8rqel0rx0v9puo4tgq9" ],
        [ "/Ndyyssoso-`sNhshy+s+-.``--//--...``...``.----...--...`````````.", "11u4ey4594ofsv7m1azrkrajynzl912lcukc1pmav5a7rux5gpedd0fusevh9fa7d45rg93rglr68cv69bkxyfnwx0fhm84i4d81" ],
        [ "/dyshys+//-`-Mhysosyo--``.:///////://+oosssyyyyysss+yyysyys+yo.-", "12baswqllgglyysn8ddambs8pbp4m3tn5salw9p1g0y648f6v1ta1el6dqfkx8cda1c2lobukirkimvkequ55lga9mprajj27ugh" ],
        [ "/y+ohys++:``-Myy//ys/--``./hhhhhhhhohmhdddyhdhhssssdhyymdsys+:`-", "11ztyg073lxpo2fewdvveoeujvv37sz44jkef034yzbl6mfqudpa59j8mhhkkjt3udvgtl3p65pe1uudocvjefcgrhh8vzg4kv75" ],
        [ ":s+syyyy+-`.-Nyyhysy/-.``.`yyssosoo//oddhsohdyhhhysssyhhooy++-`.", "11u4feihyqmvrbiqhcad1w8joxjravi87h77kps0kdcu502rzd8pwryeozx1p9qepjc7baptjxxg60f9w1v0nwi37s7oblf5c8vk" ],
        [ "-ooo+/:--``.-hhysys+/-.``.`mNmo////+osydhdshhhyyyooyhhsdhyo++-`.", "11u3mf4smsoxazvt6duek3eqtl9lg3ymuci14tasbdk4o392k4rvrgl74g3ydbpgckdas0vjky068epacag0mwtoittl0tj5k1ri" ],
        [ "--.......`.-.:------...````yNmoyyhyy/hhsdyyhdyohhdydyshhyyhs+-`.", "11u2tfqrynyf0jl18wq210oc70ippc28aueoxeiaz9e55ub7y2k988d9j927cwouyxoiwyosg2s7z6fz327plyhxuym438i7gi5r" ],
        [ "-/++++:/-..-..`````````````++:----:-:os+oydso+yosssshoohyoos/-`.", "11u2tfr3k0hr824gr5vb43tllyuqejvydfzgd5ymd2vhhbk59mhs3grrjij7kq6ecclca4qrvszq3dddj6hp5cvmaa0sczzacpgu" ],
        [ "-hhdhyyyyydysso++/////::::::--......`........................``.", "11zuifi1ju3dru7ux4y9z196j6e6e57zj93ry5jkuqznpfb3hczogrcvj122sh7bjs6a7takzey0r0l26ryb5nf2hicmhw7ls4xa" ],
        [ "-hmdydmddhmddhhysssssoo+symmddydo.--.........```````````````..--", "125m8by8s6ohej0cqe0e3jl80b0atp4no95t3iil6xbbcaj3d69ainlqmvccg1acpkas765rbxzeefo2nqhwy2p0x0hnjkri648e" ],
        [ "-hmmdhyhs/mdmmmddmhhyhyhyyhhdos+:`.--ssss/sso--+ohyo+oo+s+o+/---", "12bd50x0uxa6b6s2ir7c9movg20c1xqjhbh1ymv4vwx2vcxjrdzyk7a3thgrhjqw82cvaluwol2nbkp876nwvgaenhykpoq9urqm" ],
        [ "-y+:---:.:::-:::---::/+/:------...``-s+//oshh/-soyoyyhhyyo+ym+`-", "12b94gkqdr5gfvj3oyefrwtwtjk9a8k5lg2nog1001cjqwgnko8j8pg9kbt1aa1ifgv0j707xajhsgrdlfgwp6cznyrqrabv9wj2" ],
        [ "-.``````````````````````````````````.....-----.::+ooo+/o///++-`-", "12b94838g914ph1z59har63qtv331efo9asyb9uj24raq8zf4e3iwerkdv28s3k43kw91w62bbpssgel9rp8lt94iy4x01g9gstr" ],
        [ ".................................................``````````````.", "11zuijk6y8y9ha8bsnns37r6gxjmawis71oxnpijnmdoxx3gv5hykv6ge3rg3ex43es19lcmn5r77d3t8o0e793wchkrzs76wjxq" ],
      ],
      '2' => [
        [ "...........oooooooooooooooo``/++oooooo+++/.`....................", "11zw4qi78w4z4hjro1j60g7mzxkas6vrqqamra6wzeifvze39bprt9djoxmtlhpfi5x8kmozoqal58ks6a0myjm47xe7xncx2j8u" ],
        [ "++++++++.--NNmmmmNmmNmmmNh+`.yNdshsysysyy-.`.oddddddyss/////////", "12mvri6emnlp4k8pi5q6j3i1a0fqw72fzp98egcn54l7o0vq8ybo9v9n3av4liy9mpj0tx1kcnrkasbtsoluuxvh8bt3hliv4pv6" ],
        [ "mmmmdhoo`--Mmhhhhyhhhhyhh+-`./dsyyyyhyyo/-.`.sNmdhdhmmmddmhmhmhd", "13ose7fqntyf8lto5oi22ulesdnm4f51qg0znp1fsnxeaq839cu65zmrchvtqwiizuy8bn3souy5ismkv3j6ev3kfuvi8etz277e" ],
        [ "dhyhyy+/`.-MNyyyhhyysyyhy+-`.-/syhyyysh+...`.sNdyyysyyoyyshhysyh", "13fmaqm7mm2numa24saomt7ba07bgzejkzciemmndh9p6umifjnstai0i27yu0pate9jqa5j363vs9sr21f80k1x40ir80w30tmh" ],
        [ "yyyyo/--``-dNhhhsyyysysyy//``.-.:.......```../NNsyssysysyyyyhyys", "1345asifp0mt6kn71ddniq9l26kvqqsm4gghrs0hvl16c4a10u84jok78r9ziajhgkkh5813sadfprgulintqc4i6pc47lae3sae" ],
        [ "//::-.````-oNyyysooyhsyoy+:``.-...-:://++/-.--mhos+s+++//:::::::", "12bdy4caxrvc4tel6mqhtgkf7dvmaxq620g8kf7njwt46y9ehjnomfhu1ox7mw4moe179lil9fiejq2m3n7k2faecvluxuced3ox" ],
        [ "`````````.--mNsyssyysyssyo-.``.sdmNmdmhmy+.`../:--.....`````````", "11inenr1pky6i648cz72nlh5jldzydodhkedqbtj90wbdpfr966yvhkkju1012o1tso66kiezy3qz2rh4lkklp4764zp8rgldqej" ],
        [ "-.........--omyyhyysyoyyy-/.``-hMdysysysy-.`......`.............", "11zw4qi78w4z4hjrgliref8t1dsqa8x0xjd3u9by91jc9kwzdcnhssikesvabww408n5e32113huk5drx3u2i361054fuz7ihh4e" ],
        [ "ddddddhho``--hmyyssyosysoo/-``-hNyyyyyyys-.`.smNm.-/yddddddddddd", "13wv11ite6j54pp00s42j8t505kj3eaclz6ssjly6ubl20r01mq89hh5ov9vr8ad5h7gc44t72xqi67apia7taekn8wrbk1wv75l" ],
        [ "hyyyyyy++.`--:yhossoo/o///-.``.hhss+:::....`-Nmys`-yNmdhdhdhhhhh", "13ld7jlzh3vyg0rmesukm6om9505fkyaj2sftjpennnko7nwtdp1slb04rttoy1ckf9pn2rrh2r5ugppoltkrjauxq0qzs0m2ad4" ],
        [ "hyyyyyy+-.`----.......`````````//.``````````+Nhhs`-yNyyyyyyysoyy", "139uxyxkvx4fwn04z4saj167gwoswlocisxmi1e4doabx8celn5m63bmvws4l1rwvoqtrgjlqiurctjjvmzx50o564r57uyvfjeg" ],
        [ "syoosyy/-.`.+ssoo++/:-`.:/++oosdddmmddhs:`.+NNhy+`-omhyyyyyyoosy", "139tu8nupw8zp2rp3594toqij39dv53erlxd2grvjffcbfd5a39ynljw3kslk5yqh4r4spvasqi7uvipil4ove4qk29weo8g6prp" ],
        [ "yyyyyso:..`.Ndyyhhhyh`--sNNdmhdhhdhdhhh/-`.sMdyy/`-:hos+++++soys", "1345ncv89jfv6q6qzf61u4phhf0dtlolj9obypwxek8ugfqwlssvkjh5uxh3soa742ebvvpbc2xcqotkj1tz49fbhamvcyl6hq0m" ],
        [ ":::--..````.Nyhyydsy/`--yMyhyyyyyosyhsy--`.sMyhy-`-```.........-", "125m8bx3il9qkhf3elwmmd1jtvyvtd390yev9dtpyi9a5k28r84652iwzdjpsb530eo245uzyj0lsgdeoymu1ppv0l4959heiv5n" ],
        [ ".---://///-.Nhsyyyyo/``-yMhsysooooyosyy--`.sMhhy-`-...----...```", "11oebcp8zfjocvcaaro53gmend5gttgkjv4akp6ymy2m1qvv4yartv5btx6dk475g9plbdvoo72iolyahikb4vu3qxitts6hr8x8" ],
        [ "/hmNNmmmdh:`Mhhyoshy/.`-oNmhsyoyooyoyyo-.`.sNyyy-`-mddddyssss+.-", "12bccdtstayipx4b1djgxw9mqw5g1hzcktnfrculibnhz1ovu44ydc996yfmbile1ogn4ww861yftao00o90crrse492j8nbgy5t" ],
        [ "/Ndhyyyhyy+`Myyyhyyy/-``-dMhhhsyoyooyy+-``.sNyhs-`-Nyyyyyyyys+.-", "125lfszh8t92fn09pnb33i4ttacrs2q8o08uk0zzj80zid06awai1s13jz40hbyycok1z6e8jja7g7tgsmpchk9ne90zc6fuo2r5" ],
        [ "/Ndhyshhyy-`Ndyhsyhh/-``-oNmhsyysyyyyy/.``-sNyyo-`-mhyhyysyyh:.-", "11zurhqehkqw4nm1ta6hwswr1le3lj4smvt9vvjjovfnc9e6put7fnndoyvcnszpogx8o2wohl7to93oshr4ueetkebsfs9qsmb5" ],
        [ "/Ndyhyyhyy-`mNohysyy/-``.-hNhsy+s++//-..`.-/+:.....so/oo+o++o-..", "11u58a634s41nys58mp3b6rzop5gmmwd06pty9lr07rmt5ex9mkxps52hz2pl8gpv1rbbpw7daouo072kvbmm6fvurrp12thmynl" ],
        [ "/Ndsyhyyyy-`sNhshysy/-```--//-..`````````.---------...`````````.", "11u4ey4594ofsv7m1azrkrecbv3drmn8t2ybj2lr63xbmr3vjwxu9cdeypcsxijoqyscezuzvx0z49yyiuiti254zb5y0hi6ex9t" ],
        [ "/Ndyyyyhys-`-Myysoyy/-```.:/::::://///////++oyyyyyyyyyyyyyyyyo.-", "12baswqxeqra6s1z9rzt6w7q7w6rl0o6hcqq7587eecu0cl6yuyrx7izplrafkbzz21co6wa7ftjdoj0xgcjf6l5n3tz91kebbox" ],
        [ "/Ndhhyhyy-``-Myyyysy/-````ommNNNNNNNNNNNNNNMMMMNNNNNNmNNmNmms:`-", "11ztyiafxd9qe2i6gzn88kyt64iwav9cj7b3yyyuxpa3whfapgd0m9ttk3vneokgxrapl0xhx8jf16riuwnmi7ccp096psr09ecx" ],
        [ ":mhyyyooo-`.-Nyyyyys/-.```+mNdhhhhhydhhdhhhdhhyoyyyhysyyyhyy+-`.", "11u4feiieg54d1zzwpjryur7pkoxitov3zact4skf3jy24cqr31baveh3wc23hmomxgwlriiz1pem44e4uf5rgez6ra00zr9dvxs" ],
        [ "-yyyo+---``.-hhysyso/-.```.mNmyhsysyoyyysyyhyssyysoyysoyohsh+-`.", "11u3mf4t2xq8mo1cs6e1qzn4lgthpj44kutohyy2abumh5hkxxsqgxs62ssjzc3a3rrk4ytghdcjirarlbjnxcq8v53ohp4zho1a" ],
        [ "--..`....`.-.:------...````yNmhsyyyyoyssoyyyyyyyoyssoysoyyoo+-`.", "11u2tfqkfah3va6p2ibh5o03obp4tccgwnky9xe18mt2637pb9h15v41ub96s5bcd4sasssmamdk0cg5zu7i407tjz9otkmmdckv" ],
        [ "-/+++++/-..-..`````````````++::-----oosysooooooooyoyooyoooos/-`.", "11u2tfr3k0n525x7ncmkrktaki0mr2cci7psc2rcxifjx25yjicw6xihr74rr4nwusb1wkqudb0fzl1yxyz9v1j4jds4gr3psycu" ],
        [ "-hNmmdNNNmmhsso+++++///:::::--......`........................``.", "11zuifi1ju3dru7ux4y9z196j6e6e57zjg0v1gk0xtr0xcialev4dywejdm9dqigz9ap31sx4gwm3jwhak887barpjog1fnbjuni" ],
        [ "-hNhyhyyyhhhmdmdmdmmdmdmmmmmmmmdo.--.........```````````````..--", "125m8by8s6ohej0cqe0e3jl80b0atp4no95t3iil6xbbcaj3d69aiyt3s1l6wlhc6edgn98gq9mltfolyymq7vz9mkvqxsug3s32" ],
        [ "-hmhyhsyyhshhysyyosyssyshshshhh+:`.--mmmmhsso---ossssssssoo+/---", "12bd50x0uxaafx3sgh95lph9x3px0s7j3j28e7ig60bhcy5vwi3835kdmne8w6skyoyu5p3m5vys5f19fsztwl6oz3i9qxbdtre6" ],
        [ "-y+----------------------------...``-mdddhshh/-ymyhyyhyyhyyym+`-", "12b94gkqdtfcz8uqaxqhylqjp0iy17y900v0x20rzddm3psjl8tlmmfxz3n4hz0vnafrpoobxhgm41ygtwbxlcz6fb59n4ngsc1a" ],
        [ "-.``````````````````````````````````.--.------.so++oo++o+oo++-`-", "12b94838dll8nv4g9qq1joujhu7ulxlkv44lsjb6tkxgbppnqympkjk6ro9yobhpacej1wyvjnm398pfd6utfmh2i9hxbvwarbvz" ],
        [ ".................................................``````````````.", "11zuijk6y8y9ha8bsnns37r6gxjmawis71oxnpijnmdoxx3gv5hykv6ge3rg3ex43es19lcmn5r77d3t8o0e793wchkrzs76wjxq" ]
      ],
      '3' => [
        [ "................................................................", "11zw4qi78w4z4hjro2l051yff0hf7vo21ve6xpzuutm8atgmec1i0t1ei58qbgq1fl4xtxlvydxjw531pqsu1eab4unrglwupn1q" ],
        [ "-NNNNNNNNNNNNNNNNNNNNs/`-+mNNNNNNNNNmy/.--smNNNNmddyysssssssooo+", "12nd17q37b36r8heu6942e9l08gznms9eqocvoneod7lu8sk06jdfsw5fgdq624a95oj0gkcgrl6x8nncjkqkea18t0b9c9bsiy8" ],
        [ "-NNdyhyyhhhhhhyhyyyyy--`-dNhyhyyhyyhy+-.--NNhyyyshhmdddmmddmmddm", "19ny2v3xvqll2u0ow19c02b4yy6ryay6hzhl70nb37yk164ktgplanf5mwfskjfs2kq94any27e28fz8tl33z613o4484wiz08g"  ],
        [ "-dmyhyyyysyyysoyyysys+-`-dmyyhyysysyy/-.--NNhsssyyysyyysyyysyyyy", "139w7dblzxqybc7fqntrwwlypit77jnu6rsq1ivbbqli2phsp8f1rejgig7ze50dltb3332lxcivnsrbogp94t3n5cxbxjmor6k0" ],
        [ "-smsyyysyyyyhyyysyysyo-`-dmyhyssooysy/-.--NNyosyhssyooyhyhyhyhoy", "136ngz6sd74xl849i4gc3cpkieljpbs6qzzpmz0oab2zt0qpegds1qbtevg9vg61vv4fhu34wl0xrvcm0kmzft00q6n6skav6r5c" ],
        [ "`/myyyhyyyhysyoyhyyyss-`-dmsyyoyyyyoy/-.--NNshyysyyysyysooo+++++", "12mwklnepb2zp906ehg3b001zjy6bip1e22ale8ml0ofmaytc9b7ysgf5i5uodflujkhc37lwgsx83wkvpz0c97c20umjdx5xuju" ],
        [ "`-y/oo+++oyyyyhyysyhyo-`-dmysyyyyoyyy--`--Nms++/:::-----.......`", "11oebcoo9qdw4eeu0avssfce0djzblbmimjotfy2jlcstahgr1inel52o5chywtt3nr2iduoz0btr9fgkt5qtp7613e0rdd5nqwc" ],
        [ "-`````................``-dmysysyyysyo--`--o:..````````````````..", "11u4ey4594ofskpnwv3ldkkbnb99vm1jgpq8szuws1gqnju5493ywf3oqot2ffkuhm9pwy02dwyx27adzd1qnpg1pysobv9dvbhq" ],
        [ "dhyso+/:.......```````..-dmyyohyyosy/--`------/+ssssss+---/+yhmm", "142lxi7j72oi9r4e578tucamtaj0fs5kscwtww8dgurnbxp901y54pq2aupb1za5k4olqybauvjlgv5usaxkz7ry8z16qgkf86ih" ],
        [ "mmNNNNNNNNNNNNNNNNNds-`.-dmhyyyysosy:-.`--+dmmdmddyyys-.-yNNNmhh", "13j2anp0zy49u5btw2kf5pung2adasb2802wy730yxxm62as1ozli98gnor9ny8kjcu7n14ut79mlelkog1i1gicv2cniepo0rgn" ],
        [ "yyyyyyhhhhhdhhhyhhyy--``-dmyhhoyyysy--.`--NNsyhyyyshss-.-mNmyyyy", "13flhvb8o0cdet0a3x7ap9d17grh7pqmbs0gpk7ho3j3zjtccwub0etk9zmm6z4zaxx9slm89gak2m4ow5kb1h9nbre7ncyx6xh3" ],
        [ "syhshhhyhhyyyshsyysy--``-dmhyyysooys--``--hNysysyyyyyy-`-NNyyyyy", "139w7db1j0etn7763xmtfqayh87urh8t6rk1l79mmrajl0exnp5l4pwwx3oz2diur62s03xl8gqnf3c54nzqb282hcmh3rweplo5" ],
        [ "yysyyyyysyhyhsssyysh--``.dmsyooysysy--``--:Nsyyyyyssyy-`-NNyyyyy", "139ve9v6q73fewjjlm0iah9w28qoupu0vj1xdcajucculwhsozwfx4o9no1cacalqkzqj45nzero1hrqm5njgttchghbm7idaad3" ],
        [ "----//+++++++++++++/--``.dmyyyyoysys--``---d+o+//......`-my/----", "12bdy4cb3muxam8unrdhupp09jsj9f8yvmriebnoel0fn0hh28opvpxtzsmpvpzv99i3ftnfz2rpnoi8x69xt2kuh4goei191fcg" ],
        [ "````````````````````````.dmyyyyysyyy--``---`````````````````````", "11cwhytzv4o94ewz6hysmt7jdpbi1e63z0v67mg87pjgh6m5n9qnodm6rlzmanhtvsjn1uby0333ubc3t9gv77tqnx564av25v56" ],
        [ "----.................```-dmoyyysyso:-.``---/ossssssssssssssso`.-", "12bcbll1bw6xmzkasccx6kkd5gbr7cv6u6gz64t79rjynrstey8krph9zcwbwkcelnkb1ezfegjpqn4pivaqgksd63kq6gbae700" ],
        [ "--smmNNNNNNNNNNNNNNms`.--dmyoyy+:-.````---+mNNmddddmdddmdmhs/``-", "12bapmgg4l877vfnkket5barzal887hdqvpzbnm3whytd4m4d7dm94pltiau7httzbqlji6wldns9on7493rt9pwgf7cy6xkljw0" ],
        [ "--mNhhyhyhshhsyyysy/-`.--dmysyy-.``./sss--dNNysyysysyyyyyss-.``-", "12b93jk0fro02dzu9p598qtdajfnui6ztuzvjt6tzfinzw7phuyiq4yq9aceee2zzq80aty0r5ecaeitfqympo3km6jc4l1gdxio" ],
        [ "--NNyyyyyyyyyyssyhs-.`.--dmyyo+-``+Ndmds--NNshsyshyysyshyyy-.``-", "12b93jk0fs2szwrw7c4oh4nybgczu7qkwoe305fcm9dtfonwmbsp8eyk9arp2vmxrjnzlauip0khlfj2whpxqw6slnf2pjs8vn5c" ],
        [ "--msooysysysyshyysy-.`.--dmyy/-.`:Nhhyy.--NNyyyyyyyhyhyyyyh-.``-", "12b93jk0fsw4jppudbbbx1p45mzwaekxd616xp1092kq5ywnto99gwwrcgeqx8evbzj8yrlvffd6wzqksxn8u6oyc3dosfdpmeb4" ],
        [ "----..:oo++++o++++--.`.--ddo:-.``Nhhhy/`--NNyhyshyyyyyhyyhs-.``-", "12b93jk0fro4747s901bpzghg4623mnjes5tvd4iegv1wqjzbfm0ozqydoejeun50ekhnmic2aojuc12d2molyr1jz8icgiun84w" ],
        [ "-----`````````````````.--do..```-hhhyy-`--NNsyyysyssssyyyss-.``-", "12b93jk0fro023jdak5jl9ozxp1ovbgu799pe111ilfuxaexmme9xizqssfov3h7118djt7gh6kxpg1vuu2dj48cqkfklztbb8xc" ],
        [ "--------..............-..`````.--..``..`--mho/...............``-", "12b93jk09vvy8qggtophe1f8ywm9pq5mae00e66qbxhk9n50exzxukpnaxovlcl2upwxcaxw49qu8ee5k9swyd6lx8u78n8wft2o" ],
        [ "-dNNNNmdyysss+/-----+sssssssssss+//-....-..```````````````````.-", "12bbipsu8jy9hfm8bx24yjowqi452wo1qjaa7a1dlwp0nkz200cwfryn1gsoxr0nje2pmbmnzbj2glbro7wpz41o0trtgwx3260g" ],
        [ "-mNNdhhhhmmdhmhs-.--NNhdhddhhhdhmdNNNdyo:.-...................-.", "11u6u4fusclemm8ut0psu74al3gbdzxsoj35l2c7mc5mcnxizbrvy7ulrflgty0r0k6yyolehkfqv88zmj2dcl8v284aiazgiupc" ],
        [ "-mNyyyyyyhysyss/-`--Nmyhyyyyyysyoysyhsyshs-`.-/ymmmmmmmmmmmmmd/`", "11d2zfdw0ne6zd4nx7hhb4q1jtag989q2xf7lkrd91bb0b11n33bpgtbbjlh5es70hes4u8oys8ah3g3p87kyaqx3h0kieyes6wg" ],
        [ "-mNhyhyyyysyyy+-.`-:Nmsshssssysshhyyyhyyy--`.-hNNyyyssshyysyys-`", "11d1d45obmjsdlrb9p3l0bup1vcbx4uuvegdhe1tp4d4epe7xfkk96bgi63oq4h680rspzzhzpms2nozwufmjtu8xz58bw3zmynk" ],
        [ "-mNyyyysyyyyyy/-``-oNmysoyysyooyyyhyhyhs/-.`.-hNshshyyysyyyyyy-`", "11d1dcb4gzrktc7n5ostyjg3qq9la3gc0mos3x9ehbjlor27alir6sjmnvmnj5qyorjjerqyxv55ot4wqll2tydstaibec6ahrlc" ],
        [ "-mNsyyysssssys:-`.-mNdshyysyysyyyyyyyyyy--.`--hy+++ooo+s+o+oo:-`", "11d0ry98eobnko7koh2kjb0rbywdat70ayfd655ybf5h2ux7uk79ujcvueeyvylsigfm45dw7lcmv9z5l31bf9j0yhkhei74r9bk" ],
        [ "-mNyssysyyyhss-.`.-ms/-------------------.``-.:...............``", "11cy49vazluwphbbnl1m6pkj3c6suz9wi05bw550gyzaqvj16syjymasmg9icmef07wvhk83bs0av8ekcospt53sxoszyek3mewg" ],
        [ "-+s::::------..``--````````````````````````.--.````````````````.", "11u4ey4594ofsv7m1azrkr2z89s09qrt5s6snm4fv5w678jgd27l49ofewcviri0r78no4620bt4om529p0fh620mqvw3wx9bsvk" ],
        [ ".```````````````````````````````````````````````````````````````", "11zw4qi78w4z4hjro2l051yff0hf7vo21vd7rs2jcvq2qsfcqau360r1sgbr56f6non6cszv4bkvm8t4inykmt3mf65x0oroxre6" ]
      ],
      '4' => [
        [ ".```````````````````````````..`````````````..````````````.`````.", "117qndh9gqjxcehftq4w9xipftlmmvhacvl9h5zsktmso1l5m8s1vwkkksztriuz85igodk6vvmg8plf6hjmcga6xg6ogkau7soc" ],
        [ ".``````````````````````````` .````````````` .```.`..`.``` ````` ", "dqr4df7x290j7trdu7pxgijw9zkt39h6hr1kf7gt2ks64xoz7qg534hyvfukjidptfk41ofssggr2a6eplm97gkagfhfzrl62"    ],
        [ ".``````````````````````````` .````````````` .`.``-.`````` ````` ", "dqn11gltrq3nib2zbhp0iw2k0fropnrd92kntwv2zlgxiw5e7cxj2404uoevl2mj26ss6yleqdwr5m7zdlmabqr41o6ppxnmy"    ],
        [ ".``````````````````````````` .````````````` .``.````````` ````` ", "dqn12ihgro4oqiwulngvkmlv1vt6uqntlh59w30tlpsd1uedfkum195dhflxlpov2ur5wo6vo6y38cwg4uguhhtjb2i2lmf3e"    ],
        [ ".``````````````````````````` .````````````` .``.````````` ````` ", "dqn12ih22v1o5dzqtp9gai8c5kfsr5wcgd494sgdav5jkuk2gk6g2jesdy8w3ypgdkhnmuur8qewns81c9ckbkq64xnzzp7u2"    ],
        [ ".``````````````````````````` .````````````` .``..```````` ````` ", "dqqwck1n5peabbp96ai9vjgz4ok9x4rtun2wsyt2ustdyvdlnx2z9t250cmwnwgyzq81mr0ehjstypahazvsc97dkwalyvrhm"    ],
        [ ".``````````````````````````` .````````````` .```.```````` ````` ", "dqmtmcv1or4apg5j9npo0ygju2vantnb359rfud3b8p8jisf4wyxg2pup29nx81fzusbtkuco6jx0vf53p6eag513knixy7e2"    ],
        [ ".` `                         .` `           .`.``````````       ", "57idlixyowbzbdwwgiof2vjbl4soxiby0qj6tuisz9vrzhrb8g0y9sgeam7qq9u0xawn2p7b9wjisw5b0nx283woqzt4e41iwa"   ],
        [ "````````````````..``````..``````...````.````.```````````` `.....", "31799ip6bqey9j9cnoqykb33ogr8r21z5s9jlgjyedp0pqrxuti8l17yc8v8pv2avw1l60gbne8gdnsuviwiz6o107hociikbv7"  ],
        [ "``````````````` .````````````````..````````` ```````````` `.....", "31799j9ta5fogk3xe3mbigcozs0sk19xi0sep5g7zpcl6lo20o6a2z4zkx9ycthpcn5rhmrekigusufubqn5r87blmaveop4phv"  ],
        [ "``````````````` ````````````````` .````````` ```````````` `..```", "31795fz2dfc8v6wigpyz9xrdcinqxkqd256hkkb08qxu2zc7ug949p29qg8y9mlzte44o4an6k9egtxv1nhwz61mnrm1jnhijv6"  ],
        [ "``````````````` ````````````````` .`         ```````````` `.````", "316g629qvtxd4p1h3d69t0cu9r6gqvxyv5lsh0aqm0x94li1q2zvqdfuu9guq1rbm2g2py70k66i5ywqevbyp3d5g2aopspcff7"  ],
        [ "``````````````` ````````````````` ``.`````` .```````````` `.....", "31795fz2d0nfs6bdkpym7obias8cd471zqdvetrja59cwu69kkdzdzc39gslmqo1luceaemxedmqlgquh8nftajm46h97hhyuc3"  ],
        [ "``````````````` `````-``````````` ````````` .```.```````` `...``", "31795fz2d0nfs6bdkpyckc1xdrqe50tujjhsxplpri2ynsb31x6wql6cr4mkadgre13jmkz67818ofgwcwdznpcz0wngul0598z"  ],
        [ "```````````````  ```````````````` ````````` .```````````` `....`", "31795fz27b04ly3h3x00bylb6a9c8cb9qovz4lbsjl7qwf59zaobpdx050ex929g7rstf88feh955xnatb5bxtn4yag56pyz3te"  ],
        [ "``````````````` ````````````````` ````````` .```````````` `...``", "2vgckm81lfrkgfiodw6seddveni8jwselv1ph5dvjurn11nsn7wmx60pc2jags1mbvdhuaj5nsmmw35zf9r0y3kz0ccthx7bgnm"  ],
        [ "``````````````` ..`               ````````` .```````````` `..```", "mzoh1pt3afqb7fi8s0ga1l25mx5qh8q7no9sh074qvbmwr3dx84gx9tupnj87hq50wbtsj6ns19j4eb8x5yr7uu9aquv6vwpw2"   ],
        [ "``````````````` ..```````````````.````````` .``.````````` `.````", "nay8dka2x6kpd4snl7ur463673llxwm44xgi0xa20nn22n48mbhme1koa15lyqkwm8mxag8f3pljdpy5hjwfwem9hejc8h8078"   ],
        [ "``````````````` ..`````````````` .````````` .```````````` ``````", "mzmrw9glgugjszb0roii1z2o42pp33bih2g5r551mu0zx88sykpq3nusj161jfnzp4o54591szpviu9pqnft1f4oo2ozuzzyf8"   ],
        [ "``````````````` ..`````````````` .````````` .```````````` ``````", "mzocyezf0769uyy2d0cpilhzx0jwhclbd33lsatap1q14l4irfz0gk4lc8opzu43sarqs8occ8fwmx5ji34c9aft482jw64ah0"   ],
        [ "``````    ```   `````            .````````` .```````````` .    `", "1175l9wy0oucdrkjcedacxr42kl34fs5v2zn0s6z68kj4g6jymo0r5kdkmwth1ve5wuxll1u06y143l7fhp1f99nq76hib13qyuh" ],
        [ "..```...```.```.``````````.`````..````````` .`            .````.", "118141c3upgkmk236795ec0axh2fsriuermlxyb8gjushn5d44vhr03mqk5mohbu7z02eebx6lilvlgrxbxny4l0u7uhhqnff9wq" ],
        [ "..`.````````````````````` .````` .````````` ....................", "118141c3s8xyouuopcxqg00nee9k08hv6xgsm09o2uz5jwp5qswzwm590vt3qgczxl4nvy7cumxgz8clk0huz5uzeftsl0m9b46i" ],
        [ "...`````````````````````` .````` .``````````...``.````````````` ", "39z6swnx3idect794xcgnk583npkgati060bs5d8cb1cc5p4mw7wmzr50tfcnvujk0n2s8mebxj6rxiq4xaaq28336kbv3oq2"    ],
        [ "....````````````.```````` .````` .`````````` ..```````````````` ", "dp61lz5zahfnhs5cugpipl7ywly2ytn67g2i4yn4yn2pd7pevy4vargq1zjop5vl13unvll9be3pz7l7tv8p9cn3z0h8s2z8q"    ],
        [ "...````..```````````````` ..`````.````       ..``..```````````` ", "dqn1m3ek6byixzv4hm6lt5ds89ft52my2dqacklr5yo639yvx60fkgdkumkt96h92tid5e3qf3xkw710oin5zfddwrakpqp62"    ],
        [ "...`.`.:.```````````````` .``````````````````..```````````````` ", "dqn11grjn6yap6zr4cbcyd457pwtbtc1eb3rp3y5w2yboky8itkz7yirqlmdg3ybsax5r9l3jr6w30thb3atycq4k5pp73rvu"    ],
        [ "..``````````````````````` .````````````````` ..```````````````` ", "dqn12ih2b4ryg0c046jd6wl8yr4n3qjit8qw5pecogz7owcfotwgrow50fhz6n4unuvse465ed9p03u00he9zn4atfvyq2y22"    ],
        [ "...`.```````````````````` .````````````````` ..```````````````` ", "dqn12ih31z878x0sh9j55pku2npmeowx1gorj8oldnpe646d7tj2g4r6c9m605iry9bfyvz1bw6tq1mv0ei7xa6ffnhvt00dm"    ],
        [ "..``````````````````````` .````````````````` .````````````````` ", "dqn12ih31z878wn8fo8h46r4mdbrckjk48k1e4hjmz5joueuys2krvi3p0pvqls649ymsien4pbkjmwndcjn3kour0tc63ppm"    ],
        [ "..``````````````````````` .``````````````````.``````````````````", "112b0fw234o50ftyy09pnt6451bwdlcnzo5qhx47uc3msoci4hf3iwjk9t5z17517z4xa2rsqnrxadynhety7c1csrqj4g6inj6y" ],
        [ "::-----------------------::-----------------::-----------------:", "11zvbn173kjmavw1qd4e44usxwbfuzzp446bj8tqe0u1b3izrj4uxatpxq98qzhdcsrg20lufodh5lxbjyclh07yfaw7h5y2hbla" ]
      ],
      '5' => [
        [ "ssssssssso/-:::///+++syy/:::::+++o+ssssso+osssssssso++ssssssssss", "lveets0udnqkkzxsxk2cb1lmrvxs4bnrxosrht14ltqdrq54ndcqjg49fu5w7rtgocuynh50zx0g7y2j2nlwiheo5qdc27b9uh5" ],
        [ "sssssso/---::::///+++oy+//::/+oo+/::++oo+yssssssso/:osssossssoos", "lveets0udnqkkzqe5ajx7py2yxruhjqz5mezz0k6qvy2y7mpo6mvrzenn1i0lm4n0yx0bwxa1mw7z45tqe7ahjhd28k0lxxhbih" ],
        [ "ssso+:::::::////++++o+/+++/:o++/:::::::oysssssso/--ossooossososs", "lveets0udnqkkzqd3r2fjoh3e970x0m2k768ij1kkzpbfc14a05qp30engg9ii5zrp35f9h3i3vnz8aniti0xyb2sc8n25uubux" ],
        [ "o+/-::://++++ooss++//+++o+s+/////::::+ssoososo/-:/::+oooooosooss", "lveets0ub7loc5exxyl4fwp7aimh7bd3es3fwa2bfmdw2o3fev1vd8gsmaqvl7jtcxfz890oon5k5geh42sk0oyvukatkwjlv2b" ],
        [ ":-::+oooososs++///++oossoo/////////:/+soooso/:/++/::::/oooooooo+", "kwwzctiqo06d5si1h5r1kzipv4x927lzngg9ofrcc9hxr1tfmdu0bos320o4bbwtiyem3gm9crra0675e2ltss77rinxw4q2wda" ],
        [ "/+oooosssoo//++++ooosso+/////////::/+//+oo//++oo/::::-///ooo++::", "f09h9oy5bszeszchdodjzgt45pl4ou6ayq87fdnp0zl8b1vgmgt2uimrmkjpi3cqduatwqvi6dz4pwg4kfxi182fc9m5tc99z6n" ],
        [ "oo/::::/o+++s///oosso+//////////::/s+//:/+++ooss+///:-/:-:///++o", "lv9k8da8vkf2aagg0cmbzesn5ybwvurhlz9mgt7wfcki49aphr4c1gietun9z7mv4lekonx1mx8qtb3l0w9beqqez6ruvdjhz7n" ],
        [ "sooo+/::++ooos+::ssss++////////:/+sss+/++//ossssso+/:-:+/+++++ss", "lw7dixjcz2ydfen018diazj7y3jucsa0itvriw5sazc4wpzac550i0rodi7jmxxc06xosd2lwr8sckn3u2a460dlymjdcuijnux" ],
        [ "sssssso/+++/+o+/sssssso+/////:-:+sssso+/+osssssssso///:/+++++sso", "lveiweoojndiv8aon3zsuxhoc7wx0zcp3j6241lk1lr2pmesda02tfkjqb8tiy7uwrgkvuachzh6k3g1qxrrsrh7mo07gtezond" ],
        [ "oosso//++++++:oososssssso+/:--/+osss+o+ossssossso/:://///++ossoo", "lv9ky2fq306q12pmlsixxmlhy85mgl8d3s3mpfsphei5rcxrqs52ypacrg4yqlly3hdir1chfs1egtd8sueg2i3kd8buyosusuh" ],
        [ "ooo//+o+/+++os+//+ossssss/-:://+os+:+sssoooossso//++++///+osoooo", "lv9kxhvtwhpzwucioiiomt6fks5kn9v0y3o0hpyouhk810sohqj8730xcwcvwghqz59c4po7n5bfyxt2ogb5uhwz8qm7qcmvssj" ],
        [ "+//oo+///:+os+/////+soo+://:::+//+/-:+o+o+o+oo//++osso+/+oso+o+o", "kwwyo9ps7lxw4o95l7h09efd1d5v4fpvtkntjywfhy02f5yxcibj7d11bwge4y16bb492jlr9nv2r1ccqevc7g8tyh3e9s0lldv" ],
        [ "/ss+///::/so+/////:/oso++++//::+oy+:--:+oooo//++//++os++oo+++++/", "f6td880ngmz5g7cvasfyqukt3wmhfompjp66edb1uiyumz5f6ko4gmq588hmko4qus7vk70gthrhdbnhiskpwmtbcd3r81fpkyn" ],
        [ "sssso:::oso+/////:/ssoooo++/:--ossss+:-/+/+/oo+/:/oo//oo+/+++/+s", "rld1m9kyage1bcrf3b3o98j5nizy6pauhuxvp5n4ccv7aj6zi7gbdamehj55xyjrem186xhkco5y9wda0y7d9qwj63memhfljn1" ],
        [ "soso/:/sys+/////:/soooooo+:-:+o//+sso:///+oso+////o+oo+/::://sso", "lw7i9jagk4e63be8l3m42hhcon59wppvq1tc5bbzc6rvoou9gpa1u55t0nye485wlunz2dwgztelj7r7qhvdfc40mzainjy9v2h" ],
        [ "ooo/:osso+/////:/sooooo+/:/+oo+////+//+ossyo+///++os++/:::-/oooo", "lvee584y3creritid1u6m3vggv6rbkt8lh8cmwtxw0gvxw5wd0opzn7bj95a9e87fazxghssmaa5c0twa02laz16un6om4h2nb7" ],
        [ "oo/+sssssoo+//:/ossoo+/:/++s+/////::/+osyys++//+ossss/-..-::/+oo", "lvee4ni2w7rt8jobi9ftdgs8y1w4g8cl3up7gaqc1wv0grlopdujgcxmnex0qs683ufoxwp2f5yrvelc7mepwpyx6xfj21728p5" ],
        [ "s/+ssssssssoo///+ooo/:/+ooso++///-:/+oyyssso//osssso-..-://:::oo", "lv9g1jvamkgpcoczy7pditorr5ltot238cvor9ykdg7vx4hibccf4aaawjhx5042ptrh3k19ezhm3vhf81uv5vy8i6coltoofbd" ],
        [ "/osssssssso+///++/::oossssoooo+:::/++ssssss//ossss+-.-://///:/+o", "kwwukybaxtcaa9kyapyt8mcjncl9x3r5v809xmsca2jbuc2thpgkrr9rgupg81sgkrm4cikx1t58rb61q0l1vjr85cw3h9s7ihr" ],
        [ "-/sssssso+///////+/:+sssssoooo+-://oosssss/+sssss/.::/+/////:/+:", "f135jgkhjpu6ujbislx6i9c5cstbmezmmzhx3mv2r341hsecm1gyxip7dhahysu99hepiu2u4807l4sydtvbcl17388l8ixmy4a" ],
        [ ":-:/soo+::://:+oo//:::osssso+/::::::/oooo/-:/oss/:/+osy++//:-:/-", "9a6kl26vy81nxichivimqpps2y29x67j0g6b5xi216iek9ncgotvxdzb8amiazgfqrscnempb57v2hyujujk6enelff52rexd26" ],
        [ ":::+++////::+ooo//:::::+ooo+///::/://++syo/:-:/++oosyyss++:-.---", "99co83kep776wi889dnvlqo4c36nssxphri1re4iic4kie6keeb13b4vk171r2yjxvo6yu493s34opl24zzsg1gcbdfjl9edobi" ],
        [ ":+++//+////+ooo//::::::/os//////:///+oyyssoo/:/ooosysssss+:---::", "f098yzznua1p7gxapyj3icwlcfy9dif8q5cux66jse6ey3zkdyhesi6an1pmgho0ne2hhwn9cw727v60yro1qnpwwm0xnmd4ztq" ],
        [ "+++/+///++ooso//:/:/::+yo////////://osssosssso+oosssssss+/---:+o", "kwwugavec1skm5qj12z2udajxailpl3f7fr7niu6qh4ihxyi3ayqd3y9a2ksgspwhnowyz5sdqbcjyz3o348gtxwuft05p3bnnn" ],
        [ "+++/+/+++osso////::-:oso++/////////oosssoooss++ssosssss+/-::+oo+", "kwwzcpwk8jdti1ih731o7nvbmsr4jklspvh1fz86jhvr7gdc4swr3rgdkp0bvhntsosfsdrcxc7wqmhmrqapdwz5vdoe2qkhrwj" ],
        [ "+++++++oosso///:--.:ssssoo++//////:+osssssoo+osooososs+/::/oso++", "kwwyoxsu81u6u2abr8f6jy9dys9y08h5gsfycvge9x39znty2uzlvzq9loa96m0lttaxs1m61mj64vk880hxsdsxj1nk8woaf7n" ],
        [ "o+++++ossoooo+/:..:sssssssoo++///::/+osss//osoooooooo+/::/sssos+", "kx1t93tk4d6ufyrrb7oanese3d4aq2vu61v6v6yklc1glpi41vi7354upw5gb3vylgri9udhox17uwaw7nkmblrjioohbi3a1z7" ],
        [ "so++ossoooooo/-..:ssssssssssoo++/:-:/+o+/+ooo+oooooo+/::+ssososo", "kx1t93qno0sgad5txpsdi861tgah0p76bfaay4qmkchb4t68qh5hnuz64gr0vr14jzr0m1p4j8umdvw7fpr4xcqk3nz017ma1s9" ],
        [ "o++ssooooooo+/../ssosssssssssso/-.-::://oo+oo+oo+oo+/:/+sooosooo", "lveets0ub7m0j3wtk30farcg4uj8301rryy1whr1hpqmvw28s6ces4glzvgks608pgxyyskdm46lawt4unlzw4rammxb9rzur2b" ],
        [ "++ooooo+++oo+-./oooooosssssso+--.....//++///+++++o+/:+soooooosos", "lveets0udne4npimrujrfb1lmne7ydnis68hwdfiol36wc867hddslunut5vo7ju1idmhema39ijxcinvibyb2u15splcfee6pv" ],
        [ "/://++o+++++/./oooooooosooo+:-........//////+++/o+//ooooooooooo/", "f6tdwodc77g54h4rmohpnfylveji99buv9ee1c5k7hk4ydewuhwwlueo4qzvmxd39dlzxn9svoxe05k2hpz5kspv4gezmxs94db" ],
        [ "::::://++++/:+++++oooooo+::::........---///+//+o///ooooooooooo/:", "f0aa963qxwz73vyy3g998tzrozkjp9tznkds70uelyaz8gi2xb3vl50cztznmrdzg99alagmgnuu9px00ye52ncx53x0l6h24wu" ]
      ],
      '6' => [
        [ "//dmmddddds/:/ddddddddddddddds+-/yhhhhyyyyysso/:-/dddddddddhs+-:", "11zu2jvr7if58ah07jl3bn83bak7lh0bzulh2u9u32udtixy45vi4bohp55w6s35toshc3pn9e9cuzzgq9400945kb6maiffk1rk" ],
        [ "//dddddddhs/:/dddhhhhhhhhhhhyo+:/oyyssoooo++++/::/hhhhhhhhhyo/-:", "11zu2jb10xhoyvw05jysvd277zkmui40n8yrkw6o5wtq1zp525xmdmx4mnxpj199sx11327nt8x1ypdl86xib0eu8wir0z9j1gj4" ],
        [ "//ddhhhhhyo/:/dddhhhhhyhhhhhys+:::///////::::::://syysssssss+/-:", "11zu2f4s737v5vu4c6ncgtix13xzo0k4c3dumcy7m45vnuzl07yhn517burtqxuca6xiw3afpveaorw7wglodsilucdqcc3jsjjk" ],
        [ "//hhyyyyys+/:/dddhhhhhhhyyyhyo+:/shdddddddddhyso+/osssssssso+/-:", "11zu2ek4wkd3hse38obs6edc71tmouldjyfzl5et1cfd8zcs0qsgv2wd2ndgji4nofve5dyetppdtypsrgbqfr2pdzmkyoita2nk" ],
        [ "//hhysssso+::/dddhhhhhhhhyyyyo+:/dddddddddmddhyo+:/oooooooo++:-:", "11ztybu0s2i4xy50z3hcv21teouhnkqfnm6xrhxzydet54m0fha6c3zn7x8f87p4q4sz0z139cpvm0wkscr1pfsk69kux5ft25f4" ],
        [ "//yyssssso/::/ddhhhhhhhhyyyyyo+:/ddddddddddddhyo+---:::///++/:-:", "11ztybtd8empxypzf64tc2p19pg66jrxo8bu161ws3yih9honwwlds0iqkcq35dgnux92w7nayev6v5ur02ysmw5rc4avjyeg1dc" ],
        [ "//ssoooo+/:-:/ydhhhhyhhyyyyyso+:/dmdddddddddhhyo+-:////::-::::-:", "11zuramrbq7lzdzc3fbzit45z6upnypz8ydt68jetwj9b8wcc3m5txnt9hu4n6udrf89yvyfksyr2t4cxkwt0vjgp3ig6dowctm8" ],
        [ "//ooo++//:--:/shhhhyyysssssoo+/::+yyyyyyyyssss+/:/syyssoo+/:--::", "11zw4mebqmx0f658eg6r38l44i1ouw8eoq9gmhix4lpzsm567n656b3oke40fnb1eihje2uhn656scygg6vgoknki398e5f5u0vk" ],
        [ "///::::::-:::////////////////:::::://////////:::/yyysooooo/:-:::", "11zw4qh826ut1i815dht2wxdiswe3qskt4oytwsg3ybftl3sat3e968b373htrqo3v3h63e2avxo8tgsozobywhfas6rjnggn3e8" ],
        [ "mmmmddddhyysssssssso/:/sssssssssoooo+++/::oo+:::osso+++///:-:oyd", "yha8xoz6kmjpu64njvxhmx1t6xdp4cvlqbj6q0sbi1ictqapeszcpbcvco04ujjw1456wabjkv919ahtobw7i413pngnpuf5hpb"  ],
        [ "mmmmdddddddddddddddyo::/++//////////////:::/:::::::--------:+ymd", "yhlrk3911z2k5x8309gjtfwwpm07uzdqrprx00ovzo5u79oq6hshtqigkkvyqz81ochlluguoae1rqwyvyizgp1pqj8fibbxrdr"  ],
        [ "dmmddddddddddddddddyo:://++//::://+++++++/////////////:::::/sdmd", "yhlshct0m7wktlxuwgeo2nbcjtz5geeaommyb61akper9gzo788fqxutqvksaebi3ync9yp2zslxeph87mb5vm0fxq0p4bapc61"  ],
        [ "ddddddddddddddddhhhyo:/ooooo+/-:/++++++++++++++++///////:-:ohddd", "yhg5mdlwxrr9zb31cqho9d3gj0n3ogps3mzh1qnwfcsp4qzxbtytmy7cc9pbezkrdq7lu6gisdkxxjz58lqyw090ijfct2jp0bc"  ],
        [ "dddhhhhhhhhhhhhhhhhyo:/oo++++/-:-::::::::::::::::::------::ydddd", "yhg5ib235b8kz7kpwb81o1cxx0qo5fz2iqeiokzjiim1500qyptmg9pb2grpbca93qxpchuwvbz5z61ag7q45sjyeaumqvc628o"  ],
        [ "sssssssssoooooooosso+:/oo++++/-:dmddddhhhy+-/++++++++//:-::sysss", "rmb3qtvazvgp381444vnxmrpbo5h465e7dyedyi072cdeaiccs6tgeiser3twirrzy7ure06li3sps86f1aknu1rlb5dp8u6ugd"  ],
        [ "::::::::::::::::::::::/oo++++/-/mdhhhyyyyyo-::::::::::::-:::----", "11u581l5hdjn45pkzah5kbdzqnfkkztwtx3upsxbv3urhm8yxueofzrinavif5953wqrc1e5sh7sizkxz41unw8nzhuxdqycyqr3" ],
        [ "/+yddddmmmmmmmmmmmddo:/oo++++/-/mdhhhhhhyyo-:ossssssooooooo+/:::", "11zw4qigb52phml2txub8b1xdd0ajkid03lm0usgkgyyk734snps10o2adkhzmh4h2ff9o6uywkthddmauuhjzc5xnl5dkdgzsog" ],
        [ "/hdmmmmmmmmmmmmmmmdds:/oo++++/-/mddhhhhhyyo-/ddddhhhhyyyyyys+:-:", "11zurbsde5ege163h87xd3kucu582nkkc9g3vlgsoke0njuusgzyxa7fjv1fwmabkhczmxyiabsuvg4gopswu3di8lu4j30pmqk0" ],
        [ "/ddmmmmmmddddddddddhs:/oo+++++-/mddhhhhhyyo-/hhhysssssssssss+/-:", "11zu2f4s737v5vu4c6nbpzn41tvbhheooxuxsr8o7rbbzllniqgst2vpdyjzymhct99peuhzj8ighhk1xv5a6oaxh2ax3sg58d0w" ],
        [ "/dmmdddddddddddddddyo:/oooooo+-/mdhhhhhhyyo-/hhysssssssysssso/-:", "11zu2j7l7o23fpq25uh1dojg8qio39a2lqyjk7tixa0l3u0uw62pzzwta8vl3hut2ayiuep2dyw3a63zwvws2h0suy0ar0p1oik0" ],
        [ "/dmmdddddddddddddddyo:/ssooss+-/mdhhhhhhhyo-/yhyyyyyyyyyyyyyo+-:", "11zu2jb10gabxuhu56sbt9fnmj842nxvtxd1528mp9mjv8cuhg1z48cf8599l8b1t9asl3ojosonsnpu49apkfe2m1yzfd4ozzzk" ],
        [ "/hddhhhhhhhhhhhddhhyo:/oooooo+-/mdhhhhhhhho-/yhyyyyyyyyyyyyys+-:", "11zu6m154vp5lfnq2khgkriobd81q2saal2plcl4kfrg4tzmw3b0tk960h2csi3cgjwz7xzdynn2qgqglw6k9vf8q5ae9fyf91ww" ],
        [ "//ssssssssssssssysso+:///::::::/mdhhddddhyo::+oooooooooooooo+/-:", "11zu2f4rp7a185e5o726lh7togx6tzd4b51vhjzlckj88moq4bptwairy529ssj3zahlb4js4mmmc5qkbsd3yuahqjmunt56gmi8" ],
        [ "//://///:::://////:::://hmddho//mdddddddhs+:::::::::::::::::::::", "125m8by8y0esswkhff90nimmniv95n4de97pjgmvfdg31mu74dyd19o3ibrkp2gxa03988xl6e2bkvcl1zla2y692ubh79jo8xrk" ],
        [ "ddddddddyo/odmdddddhs+:/dddhy+:/mmdddhhys+::/ohddddddddddddddddd", "yhg5ib2n73042m6crrdm6q2u3ytv69mqe8f7nbv2ul23bj2zduv3rpfh3g4hnu6ltjgj4ep3x9lufrqvo6xkmosxl57vj1l1hp4"  ],
        [ "syyhhhhyyo:sddhhhhhyo/:/hdyys+:/mmhhyso+/:/+syhhhhhyyyyyyyyyyyyy", "rmb3qtva8u8l9fff8dmoyiv14x74997k2hy0jjrqe82xb5o9x81bylaxgccm3wrbx08tja7z3cmuguncwkhsbsnrrzhjsfpgn1p"  ],
        [ "+oooooooo+:hdhyssso+/:::/osso/-:ssso++:::+oosssssooooooooooooooo", "kwwyo9prqgnkgx46qu0j497g2uukumyhmlo48xpts3y24yx12kcv99gedcy9igaq35j79b2xoh4vuvo2jf0ad3atix9yhn151fn"  ],
        [ "::::::::::/sso+++//::/++/-://:::::::::::::::::::::::::::::::::::", "11zw4mewf2516mdwrqj40gdzoxx26x470szjjpa7ospw2tym24hkf1vsr1n1mygafpqnn2zcqbvnfe2o4w7t4ph0uezf9ak4owku" ],
        [ "::osssssssssssoooo+:/ddhyo/::ohdmmddhhhyyyssssssssssssssssooo+/:", "11zxagtrdjiaa0exs23xc147moh1oaiu8kld8ghdc2ta0vbw03j6hp0bed0jt61okds6wjuydz4ozkrlg83rzmv03gc0maekk1da" ],
        [ ":/dddddddhhhhhhhyo+:/ddyss+-:ddddddhhhhhhhhhhhhhhhhhhhhhhhhhys/-", "11l8lm82qxzky1pzx2eap6dd4oapchrndfcwh0rgofae7tvm9swkc09a6ecx6wrqzxkctt14djdnqeph2ibcnkco648scmg3lo8e" ],
        [ ":/yhhyyyyssssssoo/::/dhsoo/-:yhyyyyssssssssssssssssssssssssoo+/-", "11l7js9jl5y4d6caegpe60garkhx30k5b6v4b86qgl9s9psl3p9z2558ncox8xbqzcybfgb4shvlpgbzvmn5s67y91hjgqyekovi" ],
        [ ":/++++///////////:-:/oo///:-:+ooo+++/////////////////////////:--", "11oek4az2qtbroezuekj31b8yivze8oazjx244mw3et4tijc7bds4wmkmotgedcgmvljk141p33hv2mqrcccde0khs0xf3ecrdgu" ],
      ],
      '9' => [
        [ "s/////++++++++++++++++++++++++++++++///////////////////////////:", "11uomcx8y6iccwomfzj27qll45xk601vwdehevuj9lf6ogac4hmr7tvp24uk1gjfhtprvwtow9ezevv34kjo66m1et8vv2171k39" ],
        [ "d++smh//oooooossssssssssssssssssosososooooooooooooooooooosmh//+-", "3oi6h3boqah8c38wylfoanugksb3vpbs7qd6qfhx5nrv9evwsysiujlfl30io1azrterlpwbnqihh2gy741noajg1l8lq5ydlso"  ],
        [ "d//os///++++o+oooooosossssssssssssssssssssssssosososoooooss///o-", "3oi6h34qaun22r4g16m6vhj3fcxh8liyt3rztletfzla4obl4un5ikg96x5a6wlepicqzafr3ebyybn45tq93nq3sfkpjm2k4ns"  ],
        [ "d/////++++++/+++/+oo/ooo/oso/sss/sss+sss+sss+sss+sss+sssssososo-", "3oibcgfjj3us7h7o7bigoddpbtalpq54jk5gc7lqbzg4t0r2lrvicdwmrfl6clxlexabmp5uowifwuvye4zk15c9l9hbgq7r4ig"  ],
        [ "d////////++:::::::::::::::::::::::::::::::::::::::::oNsssssssss-", "3pbaqqdu8kymik1x9r0qblupgzyrwymp4nu3k68kics3uq3w4le1587oasdpqfgwmue60b5hfhssx7qdcb7f2599oljtp8j7cm0"  ],
        [ "h//+ys/////:-+++++++++++++o+oooooooooosossssssssssssdNsssymh//s-", "3pb5usn6bprpviuztaivbai9wen3qppjnk74j6k0bdezloyeu3jx4b39yr7qab0dawm41vhoabe5nsdaqh1lvbeqv4mp5ly2a9g"  ],
        [ "y::/o//:///:-///++++++++++++++++oooooooooooooosossssdNsssss///s-", "3pb5usg7w9j32k2vtvmqm5m50bxu88a9eq5879edm9clu7wqm6v0nba6xh4u5rgw2ehxotsi2chfk1pgsgf7dvd5rnsgjmdsw38"  ],
        [ "y::::::////:-///////++++++++++++++++o+oooooooooooooodNsssssssss-", "3pbaqqdu8kymik1xa2o2so7b0wps18s3082i1yn4e4nnuagzt6s7o7s8z25fmfec2ro5wnm55shodb7m0g85r4176to6wup3mno"  ],
        [ "y::::::////:-///////////++++++++++++++++o+oooooooooodNoooososss-", "3pbaqqaxs42ir2ubrj1tlf4cfolkxrcmuzhldqm9sdt8nbe1awb5avsaky5kn0ryrd94w7xh1zhokn4gzy6w8rvi4kcoq65hfn8"  ],
        [ "s::/++/:://:-///////////////++++++++++++++++++oooooodNooosmh//o-", "3oi6h3boqah8c391kh8p2b9pc3cva7bp5ny8tlf6ebcwgfoq5sj0fwztgcr84tyefzpgkcwgto90v36bexs43ns99lkynpxwr49"  ],
        [ "s::///:-::::-//////////////////+++++++++++++++++++o+dNoooss///o-", "3oi6h34qaun22r4kn2egt6xwnkaddkqfhd1t6kj6xdggms1zqh2w9zw91i3i8sn8zj1wldeq4dc23wu3h0vracsqg8k65brbhvt"  ],
        [ "s::::::::::--://///////////////////+++++++++++++++++dNo+ooooooo-", "3oi79q8in850uu48varrfu59s1skvg9c3gvcztj22si3qsl3dawxntwcb8zps4nwri1hhezwcn0wl1nklwslj08kozdwcrwi1xl"  ],
        [ "s::::::::::--::://////////////////////++++++++++++++dN++++++ooo-", "3oi79q8in850uu48varrfu59s1skvg9ar81yhl36b49gkbprzxgi4k7736lekmmvyiylk59tr6w0cblmwgxnocu2q8fki4rhg7d"  ],
        [ "s::/+//::::--:::::////////////////////////++++++++++yN+++smh//+-", "3oi6h3boqah8c391kbxw881cxghtccz4nzwgefrm6fydzrbanek1txudkuffneeul0jmo8al0zw276euz2nt9xtjiz9nun7k4ll"  ],
        [ "s::///:-:::--::::::://///////////////////////+++++++ym+++ss///+-", "3oi6h34qaun22r4jdwgtehzlxcrqb2w8ubieq0l80ymuhqcwcbbpekfb93q68pfux25fvmb0lohk3sioyievrzc7wcpt5s4tidl"  ],
        [ "s::::::::::--:::::::::///////////////////////////+++ym+++++++++-", "3oi79q8in850ujtmlxi3h9d6b3q0k7fbcn3i0hs0nqf3ujnse3p6jls4ynektwmj5vn3zg6imocewrxyqdxc5zfnlwo6rvwrvwp"  ],
        [ "o::::::::::--:::::::::::////////////////////////////ym+++++++++-", "3oi79q7yc19apboqxpjkfmz903ydamc2keq5q8ak7yi10fp6823ijlhqf52kjize6p3wgph1n9lf2d7u9zeykufi48afy3xydk5"  ],
        [ "o::///:::::--::::::::::::://////////////////////////yd///smh//+-", "3oi6h3boqah6alnlqpcx4w51i8eook3a643ks8ha6ockotmltkhal09ybjqgzqdqtguts9bgtcrc4omf8ps9nrmaqc05s6xg1t1"  ],
        [ "o::///:-:::--:::::::::::::::////////////////////////sd///os///+-", "3ocjlf7hvoqtvshv7egg9qwasfkjizuow0oxz08j0rvatalzb67lr1zcucgf49nyo4n99i94bdgemexxjjmh218dpc3yyh5zmlh"  ],
        [ "o::::::::::--:::::::::::::::::://///////////////////sd/////////-", "3ocjlf7he2n9n82nv32xcyz1lzkukdl1rr9h45upgj94074ag1olvd8su9f9m7jx9xgp5f1pj81uveoomkgt9v9qhu2oncystgl"  ],
        [ "o::::::::::--::::::::::::::::::::///////////////////sy/////////-", "3ocjlf7he2n9n82mte9vdzmu27ochiihl3o8szua7ny51mx3acc2et4cy93b58aveni1sqlt5syk6d3yxo8d4dhcd8wiznx5elh"  ],
        [ "o/:/+//::::--:::::::::::::::::::::://///////////////sy///ohy///-", "3ocjlfbj1a30uf1v8t52h32z9lyqruuy46wi2r59l67sjb1oto50rco19vpqth2xhdjo13cel2lnyir0vm2a9qodhdcx7vmc4yt"  ],
        [ "o/////:-:::--::::::::::::::::::::::::///////////////oy///+so///-", "3ocjlfayn8dn42uhg57g2hg3ojb71exqy5co3wlgjmtpvr1cb8qrna4ejokqk3wo6ipkebvpvcb00pmbqhz42i2dg13iyjxvp5x"  ],
        [ "o//::::::::--:::::::::::::::::::::::::://///////////oy/////////-", "3ocjlf7he2n9n82lrk60kx2a3vjzec09bu68w06xqrkgd24vvv9edzoy2v2xautdyjtfr8jskbw7rucgi41yp57aebwb784mvqd"  ],
        [ "o///:::::::--::::::::::::::::::::::::::::///////////os/////////-", "3ocjlf7he2n9n82lk8cd746wn13dzj4e5wkpfxx75ymgyj4xf1x98wqun7ikmcp969opubli87lcjt3ofrixgpfsmmna4mii71h"  ],
        [ "o///+//::::--:::::::::::::::::::::::::::::://///////+s///+ys///-", "3ocjlfayq37ap6yefi3glpv7uco0klrj32cr1s5ce8pt87kfl34nmilli0m7w28s1di6exc2po1t05tgcv5ycinc2sas504r3fp"  ],
        [ "o/////:-:::--::::::::::::::::::::::::::::::::///////+o///+o//:/-", "3ocgv81jdr1lirsy6j70u0nq81oi08x4kfnhopshl1ek05z1c2lcm2tsovftl9tg19edhq3a3r4ks3olczuyr2gh7aswdn5d8o5"  ],
        [ "o//::::::::-://///////////////////////////////+++++++o/////////-", "3ocjl1ecm7tmbxs0nnpdiujzfok2w9nldh7cm9kft4f5hh5s4lh9b2u6nqq9txqza2urs2vy4q83eknj51do2fbzmyk3090x5id"  ],
        [ "o/////::::::-:::-:::-:::-:::-:::-:::-:::-:::-:::-///://////////-", "3ocjlf7he2n9n7xlmvwa5y9z09wuwl55woeyf7sffajwdrsdzcommwxbzc7kmp6mnwypwfo7v6p6l5xqcaisgdb9mrb33e60m5h"  ],
        [ "o///o+:::::::::::::::::::::::::::::::::::::::::::::///////s+/:/-", "3ocgvltb8j9rp2659tik4je8389y0e92xshie78ufntzjm7ciss6du9gc4mv0p74qui7j913nbcxwip1of4a1o4virjpqm289wl"  ],
        [ "o////::-::::::::::::::::::::::::::::::::::::::::::::://///+/::/-", "3ocgv81jdqmxz6jbp7zc4hl9zh79jdoh83s5cp7t1ms7yqvv47y5kc7iszywdqiropcdhoh9p403ywmzrg1b7bcii6jnuuxerz9"  ],
        [ "+///:::////////////////////////////////////////////////////////:", "121r7thns7lwbhoes37r58ej4m8e0qwqdwrv3g6cxer0cdyycuk1lpvtwp82nv8a1d6x6njt36qnl4s7fnci2aenoum9bpxslcg2" ]
      ],
      'F' => [
        [ ".s++oshddhhhhyyoo++++shhssoosyy/-ysyyyysooooosso++++ossyyyyysoo-", "9azovusin28ws51hosc1cunrwtc27nyu7sawjiwrbi9xmcazksijab4nvq69px7mcvw2m4onltl448k4qn5qxpwtuhq4nmynjsd" ],
        [ ".sossyhhysso+//:::::oyhyo++ooso:.s/+so+/:::/+++/:::/+oossso+++o/", "f6td880nj3gfvtx0pr8girjsiatv0rcg9rmub0wii8179rbdrkfwz6q1g8f4ac2vcz7v6d7wryaawg0lnx2j8f3jcgsaj6lw830" ],
        [ "-dhysso++///:::////syhyssssoo+/..s/++/:::/++++++/:/+ssssoooosyy+", "kxuwq3skx0ypu3p9ryuwjdnqa1i0s0v1xlb63yi66835pn462giphs4h79di1pnde9f0lbs9upxawu6l64e6negg0zdc1y963i2" ],
        [ "-dso++///:::://++oyyyyysss+/::-..s+++///osso++++//++ssssosyyyso-", "9azsykwn2ezws4p8ci5y4d0s9nx3db9kq8nm6y8nk4k4o3fk7l1vyfe9a4wocvzgw63d5v7y5kgrshzrnhs7bgalr962nsvbwai" ],
        [ "-y+/////::::/+ssyyhysoooo+:---:..s+ssooo+++////////+ooosyydyo+/-", "9a6ot4hk2uf52srx7egupmxh2zgz1uy1a3ffquhe2gbl8ry8gvjnd2rm8fwdupdf1nu00vcljadt4wtc1xp7b7exq3tf59gm69m" ],
        [ ".s/:::::://+ssyhdhyo++//:-----:..yooo+//::////////+ooosssyyo++/-", "9a6ot0yud2f991ljegh93kbe3atuwicak0o11ww8u10w54el66b318no8ftg05z6ug14u248ffa7ucs49lofhje6pgeu0sfgl4d" ],
        [ ".s:::://+osyyyhhyo+//::-..--:/+:.y+/////++oo+//:/+ssssss+sso+++-", "9azo6qabyf8aggrfcn153zcthrj1nxovwm7499x96tbq5shky2do8rphl63hs1j94pnip3huxjzbhy0z9rht7n2obpf0w4ujtgs" ],
        [ ".s:/+osyyhyyyhyo//::::-..-:/+ss/.s////+sso+////+ssssyssosys++++:", "f139mryytki7ke2i5x72pmtketgwbjfzxm4dg01iq1joh5zgg0inx3i0xeovxad9vuz29ouizwuev9opla19b21qcifalrv44bw" ],
        [ ".y+oosyysooshys//:::--.-::/oss+-.s//+ssso+//+oyyyssyso++ss+++++-", "9azo6q9u2jthxr3g7lwy9vuueucesi8b5pcn9v5unpq2meuv6zhfgkwpla2drcmvpoixpgjm87r4bqd64vlgfvawc9ob0bc3a3x" ],
        [ ".hsoosso//shys+/::--..-:+oso+/:..s+ssssooossyysso+////oo+++so//.", "11qygd3alpaszb1u1tp21iqzq5du5j94u7nagk6v92bhp7xd3yekrdfblddxmmhvt4wklojgp9ujedh04hf5n1o5aure24tr3izx" ],
        [ "-dyyyysssyhyo/::-----:/+so+/::/-.yssooosssssso//:::/++///+o+/::.", "11qxn927w1m7wffyhgolfuc4q59e2bculr38lmsi6ndd5k5gm8u1woomys3fnvvna2a5in47gmv5aznnwmq6porj0gub3m922dkq" ],
        [ "-hyhdhs++ss+/:::---::/+oo/:://o:-y++syyssosso/:/+oss/:://++:--:-", "9a5niydgfyoa7q38m92eoxwwhea86hywp64kcb4ztmb2548q4h2zq6vjbl1ox2qqjjwe1gc3kfbssx1dxu8hzf2zw2vm7z33n7e" ],
        [ "-dhs+::/oso/:::::::/+++/////+oo:.s+syysooossooooo+/::::/++/--/+/", "f6t94bwelt38e5ddtjff5x7hq06yex7iucx3l3i6spo2syql1kxw1pp41jeepaw2redcgoedr0e9matfb0yrlbttz6686sgzrqy" ],
        [ ":d+:-::+ss+/:::::/oso++++ooso+/-.ysyso+osyysso+/::::::/+o+//+ss:", "f213l7s4qtcwonpp1xqrzjsmqtajkhq78b0sn3vsmjb6oxxz8od1hjd19aqqtozvksyunwzyxcqdwsu8yt9ujg2tk0xoxa1avku" ],
        [ ".s:://+sso/:://ooso+/+oooosso//-.hyyyssooo+/:::::://///+syssss+.", "11rroldcjbbmz04sr3o2hjoy7dt1a27ka4oyx87w37h2rwbhh3q1dk1b70shiwx6snpvrvl699mt92a2zc3zuc1rqc0jj9go5nfx" ],
        [ "./::///o+:::/+ooo+/:-::::/+//::--yso+/:://::----:://///+ooooo+:.", "11qxrgfox8dqugnuu766tjcsl8l026h44qns4ef2yggbben3byb4eg3sl7arplj2w9vb7iqcrbbolvnt6u9dne1p1rta2diyzbos" ],
        [ ".+++//+oo+++++++//////////+++oo:.oo///++//////++//////++++oo+//.", "11l8crn8wnh45e4fnsy0p27ek1tqoyfhljj5eteg4ls3ccfr2bomk3lleeq6pksifhv1jxmt5zlgqzqjwqe4dmyxns56age5njl8" ],
        [ ".yoo++syyoo++++//::::/+ossyssys/-ds++oo/::/+oo+/:-:/+ssooosso//-", "9a6kqaxmdzzybq920wd19d564hwkqdnx128xxzlwl920wbbbs4ilz75vbxwfxcocljvxbogkpsgjgvoc1iitn426c49hbkdnj71" ],
        [ ".y++ossso++++//::///+oo+oyyysss/-dysso//:/ooo/:::/osysoo+ossso+-", "9azo7efthqjsbbga1pu7rabxxz5ybbut8one23zd46s8mhfd6q0ljxgso2tbz5d4rtsk70wtx16h0af8vnx2x7q45iobg3mpiwd" ],
        [ ".s:/o+//++++/+oosyso++osyyyssss/-ds+////++//::/+ossyssooossso++-", "9azo6tt174cnjsmghbexlr9z036qjiurripx9joxvm6gq2p16eyjcymx5i971ahaakw7c38a5lhkc1enlzjeer6mwp9dy0y13hp" ],
        [ ".s:+o+///+ossyssso+//osyysoooso:-do///+//::://+ssssssso++osso++:", "f139ms2condrf7vepefurp9am8bdslx6olb1h2gfl03iy1feew18n65anyc970wfhnjy31m4qjzujb8p0t2k9r3lpu7xciat3os" ],
        [ ".s+so+//osyhsssoo+///+syyssssso:-dsooo/://///+osyssoo+///oso+/+/", "f6t95hx0x3k1ku0bxotvr9s66ikr68523vno9b1lx6qbtvux2n101qx4i2uwy8xiuefm8utfnnoqdc832dphb233uc1fpyh9hik" ],
        [ ".ysso+osysso+++///+oo+oyyysssyy+:h+/:::/+++//+osso+//::/+so+/+s+", "kx1sjzavyo288bw3u77e4h18xkw2mcwv36cn6qs8vxvnw273k2qsfa3w796t8snhx1zz3a8gx92ac5aqv0bsd62fxsbsuanxm99" ],
        [ "-dsyyhyso++/////++ssosyyyyssyys:.s-..-/+++///+sss++///+oso++oss:", "f217o1eytk1xsp24auz2n63b4ip76zuue4b3mbr1iapzdjpegu9wiwc6f0p0q2mgbl67yojjjpz84bpq4u6auvwt2za3exijbju" ],
        [ "-dyyhhso+///+oosssoosssssooso/:..s---://////+syyso++++ossosso+/-", "9a6ot4hj6y92tab37ht4zm37av6ub19ayxur5qvu2lzszprre8rvauar7staprggbwzeu8ufqi30cl3wswkjmm385qptdig32gq" ],
        [ "-dsosssso+++++ossssyyyssyso+/++:.s:::::::/+sssyyso+++oyhdys+::/-", "9a6klmwohq4oq5ut7ta2vrq3byrlrx4fd2zfpoj5jds7czfitoooml94p9wextxxb8vbxa0io51a4z9p91w0b83p203ob2wujp6" ],
        [ "-hoosso+++++++syyyhhyo+////osso:.s::::::/+sssssoo++osssyyo+:://.", "11qygchzpfmo3lknqls6yc12xjloj4up1tndr781icypx6djr2zpmgvelvu1zflzp868rdq329ms3rpi5zl7gcghwdh7qsptlid6" ],
        [ ".y++ooo++oossyyyyyo+:///++osso+-.s:::/++osssssooooss+//++os+//:.", "11qxnd4y061n0kytu428bojr11w5m1oguxnafmbb4c4o9fuy50piki1hlmfbbead9t8tg1ubna278k3pxsz95umghfm9ds5reqr1" ],
        [ ".s++sysssyyyssyyo+///+oooosss+/..s:/+syyyyssssssss+/://+++oo+::.", "11qxn9mv65q44f24hutgwhqf3vcfsasvyz2z09z3wlvw72nlqnyvhkzya0c15axsj7tmnb8tpo0pjmhbgs90elcvtoe8pfwpbm5p" ],
        [ ".sosyssssss++osossoosso+++ooo//..s/+syhhyysssoso/:::/++++/+o+::-", "9a5rmuesfmvlg4eryryecp9joux0hv4dzbdhfvaf4jsr1c883urvftpzy8p3nwpfznxbnbkuxdiaenpehl29p7tx8rf5c6cculo" ],
        [ ".ysssssyso/:+ysssssoo+///++++/:.`s+syhyysossyy+::://+++///ossoo/", "f6y74loul4373tvhiare5tewph7zn8zzejs8yk3hjimhnt7f49umzexk9sch7kl1jn1wkqu99lbxn25yz3um4sf90f733rxugvh" ],
        [ "-soo+ooo+:-/oo+++//::::::+++/:/-.o+ooo+////oo/:--:://::://+ooo+:", "f139mryycb2tfyisjv56qgk9clmew7cdb2co1w5928m5lv956bti9xqt6ipsrp1n2znon39vyekmhlk87shawqngvtpg51t7pdm" ]
      ],
      'D' => [
        [ ".--------------------------------------------------------------.", "11pc9ei9rjbknpv5lnpg4wmzymdsysr8tu0i8a8betgn5p4bqp9ukaomrq223mmo2d1qfhhip0ms9i8xev5iaqgrfswlxzgn6xv1" ],
        [ ".ooo+:-++++++:-+o++++:-++++++:-+++oo+:-+ooo++:-++++++:-+++//+/:.", "11oylhof5275barq5b4lqrflc59nl8ymyi4u75mss0vnwtjjwxpab4yefhzqrflvlpys65n52gwzbhi5dgh8za5slrr8recwdn1p" ],
        [ ".oooo/-://///--://///--://///--:/++o/--:++///--://///--:::/++/:.", "11oylhof525rhjgbb695j2jse96aof36uaer55o9i9usmm9cdl9oafz00b4p1o39jxd7emem80bgpd6vl6edy4vp0qlvfggumval" ],
        [ ".o+hoh+/////////////////////////////////////////////////:.+/y/:.", "11oylid2dchrjo6b5of13hds08gey6ochnn8oi6c27ekisdtiv0hwhprh7qrits8dtvoxn53e4ln9jcipzvcqd4rg1isgccn5yp9" ],
        [ ".::/oNyooooooooooooooooooooosssssssssssssssoooooooo++++/:.:://:.", "11oylhod75gbkydeai0ndtj63xfc0nevloy2pqq9ha4ixhe8e6xx3hz8tf4qpobfcbk8qq15pvl9agfvtki50yfww4mn4mc6zdv1" ],
        [ ".ooooNhoooooooooooooooooossssssssssssssssoooooooo++++++/:.+oo/:.", "11oylhsg4yb891r695fyrcfwbzzt28ko0itn71ynidyuh28abtpob5e9f52rqrc9jf9s4it9x5of4i8jlsqvkv345q44ifrfl1il" ],
        [ ".ooooNhoooooooooooooossssssssssssssssssoooooooo++++++///:.+oo/:.", "11oylhsg5161wmva7dthbzwlvimjx1ko6ozkxkjy9lndpvrw965atf89jd3rsvi1el5zvr2pat7hnwqyh3radui3xoob9j8xyvot" ],
        [ ".o+hoNhoooooooooossssssssssssssssssssoooooooo+++++++////:.++h/:.", "11oylih2t0a74fu9b3x9zz5j9yc0dg5s2h0993hyk0ekmwtzw7ost45ydrdg8p28s9h7eec1ockfn42jl2p8sisni0lwib1kyr59" ],
        [ ".::/oNhooooooosssssssssssssssssssssoooooooooo+++++//////:.:://:.", "11oylhod75gbkydeai0n8kz568nttfezwv3gtgvxpaxm56q8sw089cpbmpi3oezfk5k1gx6ohv7o1ck9y8ivekvdlp2i9uswdtkd" ],
        [ ".ooooNhooosssssssssssssssssssssssoooooooooo+++++++//////:.ooo/:.", "11oylhsg5161wmva7dthbzwi5a4vdgnbums4ltbifi5pa7iywm1ifn64826qqgnb3i79rq7gdc473ymgi94h0gj1sdgh63so0lpp" ],
        [ ".ooooNhssssssssssssssssssssssssoooooooooo+++++++////////:.ooo/:.", "11oylhsg5161wmva7dthbzwi5a4vderaodol5fgo1ykzjs2vbpfhxf3i2f320yzyx6nsxouu4em159dojb7drr43odlp6kfsbhm5" ],
        [ ".o+hoNhssssssssssssssssssssssoooooooooooo++++++///////+/:.o+h/:.", "11oylih2t0a74fu9b3x9zz5j9y9ct4p43uc4c35rwzapo8sz9yrma5ccq1hdmv8d2mmogz28zx1xh5ghf330q3qmwmiksogcgnal" ],
        [ ".::/oNhssssssssssssssssssssoooooooooooo+++++++////////+/:.:://:.", "11oylhod75gbkydeai0n8kz568nttdiyp9kargndfqva1c8qiqs5s3pf7ow1dr4qy6gu2w6yb1ux1hs6l0b3yykqx43pjj0art9p" ],
        [ ".ooooNhsssssssshhdhdhdhhhoooooooooooo+++++++/////////++/:.ooo/:.", "11oylhsg5161wmva7dthbzwi5a4vderan18yjt2y5y3d6d1gmgucdsbex2ojb7vir8wtk4chsmlu80d8l9ogc2qpaqcmpwi2v20d" ],
        [ ".oossNhssyyhss+:/:s+o+dhmoooooooooo++++++++/////////+++/:.o+//:.", "11oylhofpg8fzhavk5gb5tixj6n6pqh5195txb3eoda8u9dvj1q5yh7hez03e5319x51gt486hhra47z8qc70bwz73m4b7lgd9m5" ],
        [ ".o+hsNho:.+dy+:`////++oodooooooooo++++++++//////////+++/:.+/o/:.", "11oylhsdn06gw4bw73o65t4lhy41dfrjtozqq2dle2nqufl4d0mdj76j0rt3ss3k7uitnhhh3y2l8zzmxbk0b1yu2hw6bf1m2sbx" ],
        [ ".::/sNo/y.+dy/:`::/ssy++hoooooooo+++++++///////////++++/:.:://:.", "11oylham00jdkfaad4rhi9ebn1u1uhpacazac1b68fs85p2pn0uedsl5n4pmvlk4o4shom9cu73gj61uhxh7e2wp6yv1yf96cpnx" ],
        [ ".ssydy+/h.+hy/:`.`/  h//hoooooo++++++++///////////+++++/:.:/+/:.", "11oylhof4se77qkkwznbl78nae684mdbb94wuc1s73kbb5yvnprg29td1t3y1qqqy8pw0kzdtusbwzo6lipy8mcepfun0huw9gx9" ],
        [ ".hdmmo+/y.+hy/:```-.-s//hoooo+++++++++////////////+++++/:.//o/:.", "11oylhsfkn4ciwj2tlauife3m3mfoolwfokcsxsop4upv895957o5ydp7lz3s5id42qubrlja8s94sk8keu6nqcj0sflisjclr71" ],
        [ ".dhNNo+/y.+sy/:``````.//yoo+++++++++/////////////++++++/:.//h/:.", "11oylih2sxfdguq5cvjra34wizcsaomkkwj02kqtmf11qzda0pq4qz4bmcu25tvenlshjtjn5wb11wpj3j5g92zjvpalwvo8h0j1" ],
        [ ".o+yNo+//:-+s/:`.`:-:-+/yoo+++++++//////////////+++++++/:.:://:.", "11oylhod75gbkydfqm3hiqa8y10rpc1m60ujl4hho4eko2whc029x2o1bjurrljco78r19drtetq4rfx27xyvt4p4bhlorm4b10t" ],
        [ ".mmmms+//+sso/:```...---++++++++++//////////////+++++++/:./+o/:.", "11oylhsfkn4ciwj49pdoskp7dvzdkn4jwfulmlnhh7vy9aanu3qhz7n330x39g60xcsvthum64bih4mcdvvbhw8mz7t91s9h073h" ],
        [ ".mmdhs+osssoo///////////++++++++//////////////+++++++++/:.+oo/:.", "11oylhsg4yb891r7pgumjmzujkfo2frg2s0p71zjym85u40gp84iupsmbdmmeptng8laqy2xcahi6t2j9vk16vs6d4zjil7i6zu5" ],
        [ ".ysdydossoooooooooooooo+++++++////////////////+++++++++/:.++h/:.", "11oylih2t0a74fuarfbxxi9if7gq0lrt2iwxbvvgvjv4u0jv0iwa4ob6g98m64p80iza0c6l2iccihrfls2el124d3aizkkor84t" ],
        [ ".::/yNyoooooooooooooo++++++++////////////////+++++++++o/:.:://:.", "11oylhod75gbkydfqtgc9pxqxwp4jvnpcwq4il49xiknjekx1dfw81449igllzrztdjb8f9le3692yzacej5l9hix444g3085ckt" ],
        [ ".ssysNhoooooooooooo+++++++++////////////////++++++++++o/:.ooo/:.", "11oylhsg5161wmvbnp96d4v3wy663ww1aoesaxjunpsqofdn53i2tpq3yw93v434qdgzikxgg83lypv7gg1dtwyuvn8v6df9vp4d" ],
        [ ".ssssNhoooooooooo+++++++++//////////////////+++++++++oo/:.ooo/:.", "11oylhsg5161wmvbnp96d4v3wy663ww1aoesaxjunpsqofdn53i2tpq3yw93v434qdfu0893nnqythue31i0jqnyzh3jyjhclast" ],
        [ ".o+hsNhoooooooooo+++++++//////////////////+++++++++++oo/:.++h/:.", "11oylih2t0a74fuarfcz6bxnexbm4ntfv3kj7ikvbwfotakxvzeh3vh5c9c3aq9oqz8hghzxuhtro6yenhtpnsuff2rqwmuzg7ot" ],
        [ ".::/oNhyysysysssssssssssooo+++++++++oooooooooooooooooooo:.:://:.", "11oylhod75gbkynqbtnokpglh9hm0m6hfcynei4zzjtje1lgs6q7xabttgz1pu6lz5atou7qwdiivxjokv0ojj6eeh2v743ebnql" ],
        [ ".oooohhhhhhhhhhhhhyyyyyyyyyssooooosyyyyyyyyyyhhhhhhyyyys++ooo/:.", "11oylhsg516gm8fv0ez4hwtvkiywjyqlqmu4mjp2cmb70x7w505akcd2oekc9dtyu1mv9ugx6zpog3z40n7hmt06nxasohrjt9t9" ],
        [ ".oooo/:yooooo/:y+++++/-++///::-::///+/-++++oo/:yooooo/:yooooo/:.", "11oylhsg516v2s24rf215sphn52xjj0albelx4il2meaniimitgoxof5nwbq6mfj7uw8jqgw923jjuxgnp4ppyjgtamjcn5hglil" ],
        [ "-////::://///::://///:::::::::::::://::://///::://///::://///::-", "120seosrx8421e6769sky3ueotnmlbd3rl6mqc7cfvk23unl7atm4uyvq466qco4m2d560ch6aaihz4utlv72287ek4yht132cj3" ]
      ],
      'E' => [
        [ "mmmmmddddhhhhhyyyyyysssssssooooooooooooosssssssyyyyyyhhhhhdddddm", "11zw4uli2qjnxvw6h849ekmn19qjxmvl517541kpq7dzu21kqm3spvs3d6youq1ca18a93d62s1oe1inkjel5knzlumv8t4sckbx" ],
        [ "mmmddddhhhhyyyyysssssoooooooooo+++++oooooooooosssssyyyyyhhhhdddd", "125n1fftt1aav7105t884e332hxj5ailv33ubobhgnqzizzd8iy8trsxjct01y7bz7kv6oqnkjoq93h5qldu743oye39any4ngfi" ],
        [ "mddddhhhhyyyyssssoooooo+++++++++++++++++++++oooooossssyyyyhhhhdd", "125nuivunhhr9iuzk51vz7xdgzxytpt7xm8bf4wr9uhg26i60zik27y285cxll7g7a4w0sljgua7sxxotjsdqbj53xuypcob5432" ],
        [ "dddhhhhyyyyssssoooo++++++/////////////////++++++oooossssyyyyhhhh", "12bddmnkx8d30voibtl2edkn5szw7in9yaqw1ng5x0iq8girnai2kyy4lxxfm0jljphw1s9ott2hjqjyvvy3t53kkzzmj6ulfzsf" ],
        [ "ddhhhyyyyssssooo+++++///////:::::::::::///////+++++oooosssyyyyhh", "127c8cjb322m7njg4qco9jtm0reian5axg2z57lct6t16lezbfxxhumhz8yj5cw48vnkmpgg7qiou6kntfiym51bqhx2ataimc4v" ],
        [ "dhhhyyyssssooo++++/////::::::::::::::::::::://///++++ooossssyyyh", "9j6oi82mgh5zy3j7vdzdbcgwz54n0fz6vr7cq8itvkor0yyh5adoqk2z9ion713o1u6kn2m1g4dtnpzwbzzphyir0r62x7foiy8"  ],
        [ "hhhyyysssooo++++////:::::----------------::::::////++++ooosssyyy", "12h5nwqd0fthtcse93s3zj9k3jn9mjfy5v7z57qgoguwp3zk5a3n9gsbxnkxykqnyd2apta1dlxr1meeexk1b2a1h8pozbyeh5gw" ],
        [ "hhyyysssooo+++////::::------..........-------::::////+++ooosssyy", "12mvri6z9owrtimlw3suv2657qi1mjuhb693fjbkczmf4qg507xs55vb9xjsc1m4ec96qriyo426mgxxtt7dacw40x2ay8xqd9vf" ],
        [ "hyyysssoo++++///::::-----.................-----::::///+++ooosssy", "12mvrm96fycvqgskrrm0jbtw1ibk9378gqr6ycwkqpxjjs5mlxgxxae53sy2s32fo4gi93b5vzw64yqxf5s2epjt8tqze0clvo6z" ],
        [ "yyysssooo++////:::----.......`````````.......----:::///+++ooosss", "12mwkhw6z4wovvtzxqp8h1ekxk8spc2pyyeuwn0wi27b23arybvp40ookmqh46tyauwv35iib0pw0ihgje9xax70alcokxtsf10x" ],
        [ "yysssooo+++///:::----....`````````````````....----:::///+++oooss", "12slxhjzc3ffvulvzxxh7qd70kivp1suq8b1l6ipilwg7abgukct8feuamiwimfh15lkehcay9f4rr0ga6e7bjbqeyd66vwcyd4h" ],
        [ "yysssoo+++///:::---.....```````````````````.....---:::///+++ooss", "12slxhjzdps1h7135fm8d7a6ppuuw5cjvq9fxv8jgt00usiamwtow8qgnur5n96bkyrh7cl5e5pn179ioe75si7hijal4zaiuy9e" ],
        [ "ysssooo++///:::----...```````         ```````...----:::///++ooos", "12ncqklwfqfsik8xhgdn9nn727t5hywbgcsrfjrmaampk061s824xpqcgu1x9bd8ippmflkwj6gnooro82bs0gwa2ih3bjb7zwmq" ],
        [ "ysssoo+++///:::---....`````             `````....---:::///+++oos", "12ncqklwfqfsik8xhhfc30il4irgnxtxsjxrppwoaoh6ryuu51pwcl5l662n1bnh6k36w1dp2qlrp64toxhwkmue6t6f43es5vjm" ],
        [ "ysssoo+++///:::---...`````              ``````...---:::///+++oos", "12ncqklwfqfsik8xhhfc30ilnmf6yj0nem8ko4vj9uthbbtpocvforz4ugdroas3ntljk9azfag721jiljiq7ats8lwz1j4ruuwi" ],
        [ "ysssoo+++///:::---...`````              ``````...---:::///+++oos", "12ncqklwfqfsik8xhhfc30ilnmf6yj0nem8ko4vj9uthbbtpocvforz4ugdroas3ntljk9azfdfyy2qktdjcnr0mpe2zxgivx90y" ],
        [ "ysssoo+++///:::---....`````             `````....---:::///+++oos", "12ncqklwfqfsik8xhhfc30il4irgnxtxsjxrppwoaoh6ryuu51pwcl5l662n1bnh6k36w1dp2qlrp64toxhwkmue6t6f43es5vjm" ],
        [ "ysssooo++///:::----...``````           ``````...----:::///++ooos", "12ncqklwfqfsik8xhhfc2pm6efcxegz6iwzf0rwh8kzclmfmermuidyyutisvzvge91x3q0c4m26p8tcvv83tvfotzk1p1bnifoy" ],
        [ "yysssoo+++///:::---....`````````   `````````....---:::///+++ooss", "12slxhjzdps1h7135fm8d7a6ppuuw5cjvq9fxv8jgsze4hkkqqyhzhzdru7ypfvcnc5jh7cl3zt8d7agr815qzqimslq2nndieia" ],
        [ "yysssooo+++///:::---.....`````````````````.....---:::///+++oooss", "12slxhjzdprzetxuf9lo6wftgnv3b0yjhk2e1bhq882ee31frccf843qj6d4yyvz2y2ryplih61wlvoz3djlo81o2xw549u31ss1" ],
        [ "yyysssooo+++///:::----......```````````......----:::////+++oosss", "12mwkhw6z4wovvtzxrqxa3dk9rskluf9k985e9band99vahue2z6rij77kt8e8t8zalp4letcmd70zxsonbynb88a3jsy7qabbw1" ],
        [ "hyyysssooo+++///:::-----...................-----:::///++++oosssy", "12mwklmvrfyam7aft50qewfdh4m4l21vayvoig7drs12zmw13g1kzumzy12mons12i7kmema2n1d0hmwrwfnjbwvf5hpdfqtkvld" ],
        [ "hhyyysssooo+++////::::------...........------::::////+++ooosssyy", "12mvrm9pdtc6nc229qyps1ekv9pqiqd0ctv3o888ph5ofq3v0dnz117218v4qtutm78tnijj0a1yzppk1p7saw5y0tg4nxo7ps1n" ],
        [ "hhhyyysssooo+++/////:::::-----------------::::://///+++ooosssyyy", "12h5nwqd0fthtgmmnr37ug966iapfvz04gyrxukuhcv4a7p80geo20csf9a4eb9xcysrokf0y8hs58phm827ewecy5vwzmwp2ne8" ],
        [ "dhhhyyysssoooo+++/////:::::::::-----::::::::://///+++oooosssyyyh", "12h4uxcnm257fvprhwskplp1xv5gnj2xxwgs8q812aytrquspygxi01wflwt20mocltzyq1hzdt0bknrqrfe93l1jh2sqdpqimls" ],
        [ "ddhhhyyyysssoooo++++///////:::::::::::::///////++++oooosssyyyyhh", "9f45iurskogihztj8ypyjxnd90bd4wroedrze8dx6qcq7zs6zke7fj4ahp64bncfl33xw5pvw7qw69m0pqfte8szq2ceh2vucbz"  ],
        [ "dddhhhhyyyssssooooo+++++///////////////////+++++ooooossssyyyhhhh", "12bddmnkx8d30vpz9ogyzrpm8wfo9rd7qfl93osuxt8wf9mou297ubgzi7r86eks8wscq7bashq9if951fzi8aj5fivbiu8ulvcf" ],
        [ "mddddhhhyyyyyssssooooo+++++++++++++++++++++++ooooossssyyyyyhhhdd", "125nug0415xaqtdi7mh3dqvw2aramahz1947gzief5o40ohnlk5w78hz5lcvqtrk7hkkq863lcolca6yog14igh5w0avaxu29otq" ],
        [ "mmddddhhhhhyyyysssssooooooooo+++++++++ooooooooosssssyyyyhhhhhddd", "125n1fftqzfkn12qknimye7beutnka2di4azen4g1m8debm0lju2xjoeo29la6c7395yjw5i67mcds6e4z4urlmps873fo5raj8u" ],
        [ "mmmmdddddhhhhyyyyyysssssssooooooooooooooosssssssyyyyyyhhhhdddddm", "11zw4uli2qjnxvw6h849ekmn19qjzjpyee5zffftwa062j5rwkqrjpbborx54yplbz450wbxfut3ldawu7hdl0nfwlfpn43xy2nh" ],
        [ "Nmmmmmdddddhhhhhyyyyyyyysssssssssssssssssssyyyyyyyyhhhhhdddddmmm", "11zw4qi7bt04tytrxjahtptwd35w636u8gqo1zb391jrso09d1q842juowa8zyu15m67v7ttn94zc74169w83nkot5n0cakloa25" ],
        [ "NNNmmmmmddddddhhhhhhhyyyyyyyyyyyyyyyyyyyyyyyyyhhhhhhhddddddmmmmm", "11u581lq45udtc17f3yno4wg62watdep8i6wus0fl7uv5t0grmv3q9b8pgo7r5dw12fqxgecx1wgkwv4g0dbw6qo6gg0wph4p818" ]
      ]
    }
  end

  def self.wall_colors
    {
      '0' => [ Color::BLUE,    Color::LIGHT_BLUE ],
      '0' => [ Color::CYAN,    Color::LIGHT_CYAN ],
      '0' => [ Color::GREEN,   Color::LIGHT_GREEN ],
      '0' => [ Color::RED,     Color::LIGHT_RED ],
      '0' => [ Color::YELLOW,  Color::LIGHT_YELLOW ],
      '1' => [ Color::GRAY,    Color::WHITE ],
      '2' => [ Color::GRAY,    Color::WHITE ],
      '3' => [ Color::GRAY,    Color::WHITE ],
      '4' => [ Color::BLUE,    Color::LIGHT_BLUE ],
      '5' => [ Color::YELLOW,  Color::LIGHT_YELLOW ],
      '6' => [ Color::YELLOW,  Color::LIGHT_YELLOW ],
      '9' => [ Color::GREEN,   Color::LIGHT_GREEN ],
      'D' => [ Color::CYAN,    Color::LIGHT_CYAN ],
      'E' => [ Color::MAGENTA, Color::LIGHT_MAGENTA ]
    }
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
# TODO: Move input loop checks to separate thread to help lag in
#       full textured mode and low-framerate terminals?
#
module Input
  require 'io/console'
  require 'io/wait'

  # Since the require statement driving this condition could still fail
  # on some Windows systems, this is not an ideal solution.  TODO: We should
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
    @value       = Cell::PUSH_WALL
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
      @map[ @y_cell ][ @x_cell ].texture_id = nil
      @map[ @y_cell ][ @x_cell ].value  = Cell::EMPTY_CELL

      @map[ @to_y_cell ][ @to_x_cell ] = self
      @map[ @to_y_cell ][ @to_x_cell ].direction  = @direction
      @map[ @to_y_cell ][ @to_x_cell ].offset     = @push_amount
      @map[ @to_y_cell ][ @to_x_cell ].state      = STATE_MOVING
      @map[ @to_y_cell ][ @to_x_cell ].texture_id = @texture_id
      @map[ @to_y_cell ][ @to_x_cell ].value      = Cell::PUSH_WALL

      if @map[ @next_y_cell ][ @next_x_cell ].value == Cell::EMPTY_CELL
        @x_cell    = @to_x_cell
        @y_cell    = @to_y_cell
        @to_x_cell = @next_x_cell
        @to_y_cell = @next_y_cell

        @left      = @next_left + @push_amount
        @right     = @next_right + @push_amount
        @top       = @next_top + @push_amount
        @bottom    = @next_bottom + @push_amount

        @map[ @to_y_cell ][ @to_x_cell ].bottom     = @bottom
        @map[ @to_y_cell ][ @to_x_cell ].direction  = @direction
        @map[ @to_y_cell ][ @to_x_cell ].left       = @left
        @map[ @to_y_cell ][ @to_x_cell ].offset     = @next_offset + @push_amount
        @map[ @to_y_cell ][ @to_x_cell ].right      = @right
        @map[ @to_y_cell ][ @to_x_cell ].state      = STATE_MOVING
        @map[ @to_y_cell ][ @to_x_cell ].texture_id = @texture_id
        @map[ @to_y_cell ][ @to_x_cell ].top        = @top
        @map[ @to_y_cell ][ @to_x_cell ].value      = Cell::PUSH_WALL

      else
        @offset = 0
        @value  = Cell::PUSH_WALL
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
      @value     = Cell::PUSH_WALL

    when MOVING_WEST
      return false if @map[ @y_cell ][ @x_cell + 1 ].value != Cell::EMPTY_CELL

      @direction = MOVING_WEST
      @offset    = 0
      @state     = STATE_MOVING
      @to_offset = -Cell::WIDTH
      @to_x_cell = @x_cell + 1
      @to_y_cell = @y_cell
      @value     = Cell::PUSH_WALL

    when MOVING_NORTH
      return false if @map[ @y_cell - 1 ][ @x_cell ].value != Cell::EMPTY_CELL

      @direction = MOVING_NORTH
      @offset    = 0
      @state     = STATE_MOVING
      @to_offset = Cell::HEIGHT
      @to_x_cell = @x_cell
      @to_y_cell = @y_cell - 1
      @value     = Cell::PUSH_WALL

    when MOVING_SOUTH
      return false if @map[ @y_cell + 1 ][ @x_cell ].value != Cell::EMPTY_CELL

      @direction = MOVING_SOUTH
      @offset    = 0
      @state     = STATE_MOVING
      @to_offset = -Cell::HEIGHT
      @to_x_cell = @x_cell
      @to_y_cell = @y_cell + 1
      @value     = Cell::PUSH_WALL
    end

    @map[ @to_y_cell ][ @to_x_cell ].direction  = @direction
    @map[ @to_y_cell ][ @to_x_cell ].offset     = @to_offset
    @map[ @to_y_cell ][ @to_x_cell ].state      = STATE_MOVING
    @map[ @to_y_cell ][ @to_x_cell ].texture_id = @texture_id
    @map[ @to_y_cell ][ @to_x_cell ].value      = Cell::PUSH_WALL

    return true
  end
end

# Contains the pixels for our screen buffer.
#
# @author Adam Parrott <parrott.adam@gmail.com>
#
class Buffer
  attr_reader :height
  attr_reader :pixels
  attr_reader :screen
  attr_reader :width

  def initialize( args = {} )
    @height = args[ :height ]
    @screen = args[ :screen ]
    @width  = args[ :width ]
    @pixels = Array.new( @height ) { Array.new( @width ) }
  end

  # Clears the buffer.
  #
  def clear
    @pixels.map! do |row|
      row.map! do |char|
        " "
      end
    end
  end

  # Draws the buffer to the screen.
  #
  def draw
    @screen.output_line @pixels.map { |b| b.join }.join( "\r\n" )
  end
end

# Defines the active game screen area.
#
# @author Adam Parrott <parrott.adam@gmail.com>
#
class Screen
  WIPE_BLINDS       = 1
  WIPE_PIXELIZE_IN  = 2
  WIPE_PIXELIZE_OUT = 3

  attr_reader   :buffer
  attr_accessor :color_mode
  attr_reader   :height
  attr_reader   :width

  def initialize( args = {} )
    @height = args[ :height ]
    @width  = args[ :width ]
    @buffer = Buffer.new( height: @height, screen: self, width: @width )
  end

  # Clears the current screen.
  #
  def clear( full = false )
    output_line "\e[2J" if full
    output_line "\e[0;0H"
  end

  # Custom output method to handle unique console configuration.
  #
  # @param string [String] The text value to be output to the console
  #
  def output_line( string = "" )
    STDOUT.write "#{ string }\r\n"
  end

  # Applies the selected screen wipe/transition to the active buffer.
  #
  # @param type [Integer] Desired wipe mode to use (WIPE_X)
  #
  def wipe( type )
    case type
    when WIPE_BLINDS
      for j in 5.downto( 1 )
        for y in ( 0...@buffer.pixels.size ).step( j )
          for x in 0...@buffer.pixels[ y ].size
            @buffer.pixels[ y ][ x ] = ""
          end
        end

        clear true
        @buffer.draw
        sleep 0.25
      end

    when WIPE_PIXELIZE_IN
      ( 0..( @height - 1 ) * @width ).to_a.shuffle.each_with_index do |i, j|
        @buffer.pixels[ i / @width ][ i % @width ] = Color.colorize( " ", Color::WHITE, @color_mode )

        if j % ( 4 ** @color_mode ) == 0
          clear
          @buffer.draw
        end
      end

    when WIPE_PIXELIZE_OUT
      @backup_buffer = Marshal.load( Marshal.dump( @buffer.pixels ) )

      @buffer.pixels.map! do |row|
        row.map! do |item|
          Color.colorize( " ", Color::WHITE, @color_mode )
        end
      end

      ( 0..( @height - 1 ) * @width ).to_a.shuffle.each_with_index do |i, j|
        @buffer.pixels[ i / @width ][ i % @width ] = @backup_buffer[ i / @width ][ i % @width ]

        if j % ( 4 ** @color_mode ) == 0
          clear
          @buffer.draw
        end
      end
    end
  end
end

# Defines a single wall texture.
#
# @author Adam Parrott <parrott.adam@gmail.com>
#
class Texture
  DEFAULT_HEIGHT  = 32
  DEFAULT_WIDTH   = 64
  MAX_COLOR_VALUE = 255
  MAX_PIXEL_VALUE = 255
  MIN_COLOR_VALUE = 0
  MIN_PIXEL_VALUE = 0
  SHIFT_FACTOR    = 8

  attr_reader :height
  attr_reader :width

  def initialize( args = {} )
    @data   = args[ :data ]
    @height = args[ :height ] || @data.size || DEFAULT_HEIGHT
    @width  = args[ :width ] || @data[ 0 ][ 0 ].size || DEFAULT_WIDTH
  end

  def colors
    @colors ||= decode_colors( @data.map { |item| item[ 1 ] } )
  end

  def self.encode_data( pixel_values, color_values )
    colors = self.encode_colors( color_values )

    pixel_values.map.with_index do |pixel, index|
      [ pixel, colors[ index ] ]
    end
  end

  def pixels
    @pxiels ||= @data.map { |item| item[ 0 ] }
  end

  private

  def decode_colors( colors )
    decoded_colors = []

    @height.times do |row|
      values = []
      datum = @data[ row ][ 1 ].to_i( 36 )

      @width.times do |column|
        values << ( datum >> ( column * SHIFT_FACTOR ) & MAX_COLOR_VALUE )
      end

      decoded_colors << values
    end

    decoded_colors
  end

  def decode_pixels( pixels )
    decoded_pixels = []

    @height.times do |row|
      values = []
      datum = @data[ row ][ 0 ].to_i( 36 )

      @width.times do |column|
        values << ( datum >> ( column * SHIFT_FACTOR ) & MAX_COLOR_VALUE )
      end

      decoded_pixels << values
    end

    decoded_pixels
  end

  def self.encode_colors( colors )
    encoded_colors = []

    colors.each do |row|
      encoded_value = 0

      row.each.with_index do |item, column|
        encoded_value += item.to_i * ( 2 ** ( column * SHIFT_FACTOR ) )
      end

      encoded_colors << encoded_value.to_s( 36 )
    end

    encoded_colors
  end

  def self.encode_pixels( pixels )
    encoded_pixels = []

    pixels.each do |row|
      encoded_value = 0

      row.each_char.with_index do |item, column|
        encoded_value += item.ord * ( 2 ** ( column * SHIFT_FACTOR ) )
      end

      encoded_pixels << encoded_value.to_s( 36 )
    end

    encoded_pixels
  end
end

# Main game class
#
# @author Adam Parrott <parrott.adam@gmail.com>
#
class Game
  include GameHelpers
  include Math

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
      display_messages

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
    @x_offset = 0
    @x_push_offset = 0
    @x_push_dist = 1e+8
    @x_ray_dist = 0
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

      if @push_map_cell.value == Cell::PUSH_WALL \
         && ( pushwall.x_cell == @push_x_cell || pushwall.to_x_cell == @push_x_cell ) \
         && ( pushwall.y_cell == @push_y_cell || pushwall.to_y_cell == @push_y_cell )

        @push_dist = ( @push_y_intercept - y_start ) * @inv_sin_table[ angle ]

        if @push_dist < @x_push_dist
          @x_push_dist = @push_dist
          @x_push_intercept = @push_y_intercept
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
        @y_intercept += ( @y_step[ angle ] / 2 )

        if @x_map_cell.offset < ( @y_intercept % Cell::HEIGHT )
          @x_offset = @x_map_cell.offset
          break
        end
      when Cell::PUSH_WALL
        case @x_map_cell.state
        when Pushwall::STATE_MOVING
          case @x_map_cell.direction
          when Cell::MOVING_NORTH, Cell::MOVING_SOUTH
            if @x_map_cell.offset >= 0 && ( @y_intercept % Cell::HEIGHT ) > @x_map_cell.offset
              @x_offset = @x_map_cell.offset
              break
            elsif @x_map_cell.offset < 0 && ( @y_intercept % Cell::HEIGHT ) < ( Cell::WIDTH + @x_map_cell.offset )
              @x_offset = @x_map_cell.offset
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
      when Cell::WALL_CELL
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
      @y_intercept = @x_push_intercept
      @x_map_cell = @x_push_map_cell
      @x_offset = @x_push_offset
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
    @y_push_dist = 1e+8
    @y_push_offset = 0
    @y_offset = 0
    @y_ray_dist = 0
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

      if @push_map_cell.value == Cell::PUSH_WALL \
         && ( pushwall.x_cell == @push_x_cell || pushwall.to_x_cell == @push_x_cell ) \
         && ( pushwall.y_cell == @push_y_cell || pushwall.to_y_cell == @push_y_cell )

        @push_dist = ( @push_x_intercept - x_start ) * @inv_cos_table[ angle ]

        if @push_dist < @y_push_dist
          @y_push_dist = @push_dist
          @y_push_intercept = @push_x_intercept
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
        @x_intercept += ( @x_step[ angle ] / 2 )

        if @y_map_cell.offset < ( @x_intercept % Cell::WIDTH )
          @y_offset = @y_map_cell.offset
          break
        end
      when Cell::PUSH_WALL
        case @y_map_cell.state
        when Pushwall::STATE_MOVING
          case @y_map_cell.direction
          when Cell::MOVING_EAST, Cell::MOVING_WEST
            if @y_map_cell.offset >= 0 && ( @x_intercept % Cell::WIDTH ) > @y_map_cell.offset
              @y_offset = @y_map_cell.offset
              break
            elsif @y_map_cell.offset < 0 && ( @x_intercept % Cell::WIDTH ) < ( Cell::WIDTH + @y_map_cell.offset )
              @y_offset = @y_map_cell.offset
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
      when Cell::WALL_CELL
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
      @x_intercept = @y_push_intercept
      @y_map_cell = @y_push_map_cell
      @y_offset = @y_push_offset
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

      if @map_cell.value == Cell::PUSH_WALL \
        && @map_cell.direction == Cell::MOVING_EAST \
        && @player_x >= ( @map_cell.left.to_i - ( Cell::WIDTH - Cell::MARGIN ) )

        @player_move_x = @map_cell.left.to_i - ( Cell::WIDTH - Cell::MARGIN ) - @player_x
      end

      @map_cell = @map[ @y_cell ][ @x_cell - 1 ]

      if @map_cell.value == Cell::PUSH_WALL \
        && @map_cell.direction == Cell::MOVING_WEST \
        && @player_x <= @map_cell.right.to_i + Cell::MARGIN

        @player_move_x = @map_cell.right.to_i + Cell::MARGIN - @player_x
      end

      @map_cell = @map[ @y_cell + 1 ][ @x_cell ]

      if @map_cell.value == Cell::PUSH_WALL \
        && @map_cell.direction == Cell::MOVING_NORTH \
        && @player_y >= ( @map_cell.top.to_i - ( Cell::HEIGHT - Cell::MARGIN ) )

        @player_move_y = @map_cell.top.to_i - ( Cell::HEIGHT - Cell::MARGIN ) - @player_y
      end

      @map_cell = @map[ @y_cell - 1 ][ @x_cell ]

      if @map_cell.value == Cell::PUSH_WALL \
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
      elsif @map_cell.value == Cell::PUSH_WALL \
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
      elsif @map_cell.value == Cell::PUSH_WALL \
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
      elsif @map_cell.value == Cell::PUSH_WALL \
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
      elsif @map_cell.value == Cell::PUSH_WALL \
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
        Input.clear_input

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

      when "1"
        update_message "Color mode disabled."
        @screen.color_mode = key.to_i

      when "2"
        update_message "Partial color mode enabled."
        @screen.color_mode = key.to_i

      when "3"
        update_message "Full color mode enabled."
        @screen.color_mode = key.to_i

      when "a"
        # Player is attempting to strafe left
        @player_move_x = ( @cos_table[ ( @player_angle - @angles[ 90 ] + @angles[ 360 ] ) % @angles[ 360 ] ] * movement_step ).round
        @player_move_y = ( @sin_table[ ( @player_angle - @angles[ 90 ] + @angles[ 360 ] ) % @angles[ 360 ] ] * movement_step ).round

      when "d"
        # Player is attempting to strafe right
        @player_move_x = ( @cos_table[ ( @player_angle + @angles[ 90 ] ) % @angles[ 360 ] ] * movement_step ).round
        @player_move_y = ( @sin_table[ ( @player_angle + @angles[ 90 ] ) % @angles[ 360 ] ] * movement_step ).round

      when "c"
        @draw_ceiling = !@draw_ceiling

        if @draw_ceiling
          @ceiling_color = @default_ceiling_color
          @ceiling_texture = @default_ceiling_texture
          update_message "Ceiling drawing enabled."
        else
          @ceiling_color = Color::BLACK
          @ceiling_texture = " "
          update_message "Ceiling drawing disabled."
        end

      when "?"
        show_debug_screen

      when "f"
        @draw_floor = !@draw_floor

        if @draw_floor
          @floor_color = @default_floor_color
          @floor_texture = @default_floor_texture
          update_message "Floor drawing enabled."
        else
          @floor_color = Color::BLACK
          @floor_texture = " "
          update_message "Floor drawing disabled."
        end

      when "h"
        show_help_screen

      when "i"
        @show_debug_info = !@show_debug_info
        clear_screen

      when "m"
        @screen.wipe Screen::WIPE_PIXELIZE_IN
        @player_x = @magic_x unless @magic_x.nil?
        @player_y = @magic_y unless @magic_y.nil?
        update_buffer
        @screen.wipe Screen::WIPE_PIXELIZE_OUT
        update_buffer

      when "p"
        Input.get_key
        reset_frame_rate

      when "q"
        show_exit_screen

      when "r"
        load __FILE__

      when "t"
        @draw_textures = !@draw_textures

        if @draw_textures
          update_message "Wall textures enabled."
        else
          update_message "Wall textures disabled."
        end

      end
  end

  # Clears the current screen buffer.
  #
  def clear_buffer
    @screen.buffer.clear
  end

  # Clears the current screen.
  #
  def clear_screen( full = true )
    @screen.clear full
  end

  def display_messages
    return if @message_timer.nil?

    if ( Time.now - @message_timer > 3 ) || @display_message.empty?
      @display_message = "".ljust( 40 )
      @message_timer = nil
    end

    position_cursor 1, 2
    @screen.output_line @display_message
  end

  # Draws the current buffer to the screen.
  #
  def draw_buffer
    @screen.buffer.draw
  end

  # Draws extra information onto HUD.
  #
  def draw_debug_info
    @debug_string = "#{ @player_x / Cell::WIDTH } x #{ @player_y / Cell::HEIGHT } | #{ '%.2f' % @frame_rate } fps "
    STDOUT.write "\e[1;#{ @screen_width - @debug_string.size }H #{ @debug_string }"
  end

  # Displays the current status line on the screen.
  #
  def draw_status_line
    @status_x = @player_x.to_s.rjust( 3 )
    @status_y = @player_y.to_s.rjust( 3 )
    @status_angle = ( ( @player_angle / @fixed_step ).round ).to_s.rjust( 3 )

    @status_left = "(Press H for help)".rjust( 19 )
    @status_middle = @hud_messages[ @play_count % 3 ].center( 44 )
    @status_right = "#{ @status_x } x #{ @status_y } / #{ @status_angle }".ljust( 17 )

    @screen.output_line @status_left + @status_middle + @status_right
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
          dark_wall: true,
          dist: @x_dist,
          intercept: @y_intercept,
          map_x: @x_x_cell,
          map_y: @x_y_cell,
          map_type: @x_map_cell.value,
          offset: @x_offset,
          scale: ( @fish_eye_table[ ray ] * ( 2048 / ( 1e-10 + @x_dist ) ) ).round,
          texture_id: @x_map_cell.texture_id
        }
      else
        @cast[ ray ] =
        {
          dark_wall: false,
          dist: @y_dist,
          intercept: @x_intercept,
          map_x: @y_x_cell,
          map_y: @y_y_cell,
          map_type: @y_map_cell.value,
          offset: @y_offset,
          scale: ( @fish_eye_table[ ray ] * ( 2048 / ( 1e-10 + @y_dist ) ) ).round,
          texture_id: @y_map_cell.texture_id
        }
      end

      @cast_angle = ( @cast_angle + 1 ) % @angles[ 360 ]
    end
  end

  # Fills the buffer with all objects and structures to be drawn to the screen.
  #
  def populate_buffer
    @cast.each_with_index do |ray, index|
      next if ray.nil?

      @wall_type = ray[ :map_type ]
      @wall_height = ray[ :scale ].to_i >> 1 << 1
      @wall_trim = [ ( @wall_height - @screen_height ) / 2, 0 ].max
      @wall_bottom = [ @screen_half_height + ( @wall_height / 2 ), @screen_height ].min
      @wall_top = [ @screen_half_height - ( @wall_height / 2 ), 0 ].max
      @wall_texture = ray[ :texture_id ]

      if @draw_textures
        @wall_pixels = ""

        @texture = @textures[ @wall_texture ]
        @texel_factor = @texture.height / @wall_height.to_f
        @texel_x = ( ray[ :intercept ].to_i - ray[ :offset ] ) % Cell::WIDTH 

        for i in 0..@wall_height
          next unless i.between? @wall_trim, @wall_height - @wall_trim

          @texel_y = clip_value( ( i * @texel_factor ).to_i , 0, @texture.height - 1 )
          @texel = Color.texturize(
            @texture.pixels[ @texel_y ][ @texel_x ],
            @texture.colors[ @texel_y ][ @texel_x ],
            @screen.color_mode
          )

          @wall_pixels += "#{ @texel },"
        end
      else
        @wall_color  = @wall_colors[ @wall_texture ][ ray[ :dark_wall ] ? 0 : 1 ]
        @wall_texel  = Color.colorize( @wall_type, @wall_color, @screen.color_mode )
        @wall_pixels = "#{ @wall_texel }," * clip_value( @wall_height, 0, @screen_height )
      end

      @wall_pixels = @wall_pixels.split( "," )

      for y in @wall_top...@wall_bottom
        @screen.buffer.pixels[ y ][ index ] = @wall_pixels[ y - @wall_top ]
      end
    end

    angle = ( @player_angle - @angles[ @half_fov ] + @angles[ 360 ] ) % @angles[ 360 ]

    for col in 1...@screen_width
      for row in 1...@screen_half_height
        skip_ceiling = @screen.buffer.pixels[ @screen_half_height - row ][ col ] != " "
        skip_floor   = @screen.buffer.pixels[ @screen_half_height + row ][ col ] != " "

        next if skip_ceiling && skip_floor

        dist = @span_table[ col ][ row ]
        x    = ( @player_x + ( @cos_table[ angle ] * dist ) ).to_i
        y    = ( @player_y + ( @sin_table[ angle ] * dist ) ).to_i

        next if ( x < 0 || x >= @map_x_size )
        next if ( y < 0 || y >= @map_y_size )

        @texel_x = x % Cell::WIDTH
        @texel_y = ( y % Cell::HEIGHT ) >> 1

        if ( @draw_ceiling && !skip_ceiling )
          if @draw_textures
            @screen.buffer.pixels[ @screen_half_height - row ][ col ] = Color.texturize(
              @textures[ 'E' ].pixels[ @texel_y ][ @texel_x ],
              @textures[ 'E' ].colors[ @texel_y ][ @texel_x ],
              @screen.color_mode
            )
          else
            @screen.buffer.pixels[ @screen_half_height - row ][ col ] = Color.colorize( @ceiling_texture, @ceiling_color, @screen.color_mode )
          end
        end

        if ( @draw_floor && !skip_floor )
          if @draw_textures
            @screen.buffer.pixels[ @screen_half_height + row ][ col ] = Color.texturize(
              @textures[ 'F' ].pixels[ @texel_y ][ @texel_x ],
              @textures[ 'F' ].colors[ @texel_y ][ @texel_x ],
              @screen.color_mode
            )
          else
            @screen.buffer.pixels[ @screen_half_height + row ][ col ] = Color.colorize( @floor_texture, @floor_color, @screen.color_mode )
          end
        end
      end

      angle = 0 if ( ( angle += 1 ) > @angles[ 360 ] )
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
      %w( W5 W5 W5 W5 W5 W5 W5 W5 W5 W5 W5 W5 W5 W5 W5 W5 W5 W5 W5 W4 W4 W4 W4 W4 W4 W4 W4 W4 W2 W2 W2 W2 ),
      %w( W5 .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. W4 W4 .. .. .. .. .. .. .. .. D| .. .. W2 ),
      %w( W5 .. .. .. .. .. .. .. W6 W6 W6 .. .. .. .. .. .. .. W4 W4 .. .. .. .. .. .. .. W4 W2 .. .. W2 ),
      %w( W5 .. .. .. .. .. .. .. W6 EE W6 .. .. .. .. .. .. .. W4 W4 .. >9 .. .. .. .. .. W4 W2 W2 .. W2 ),
      %w( W5 .. .. .. .. .. .. W6 W6 .. W6 W6 .. .. .. .. .. .. W4 W4 .. .. >9 .. .. .. .. W4 W2 W2 P2 W2 ),
      %w( W5 .. .. .. W6 .. .. .. .. .. .. .. .. .. W6 .. .. .. W4 W4 .. .. .. >9 .. .. .. W4 W2 .. .. W2 ),
      %w( W5 .. W6 W6 W6 .. .. .. .. .. .. .. .. .. W6 W6 W6 .. W4 W4 .. .. .. .. .. .. .. W4 W2 .. .. W2 ),
      %w( W5 .. W6 >9 .. .. .. .. W5 .. W5 .. .. .. .. <9 W6 .. W4 W4 .. W3 .. .. .. W3 .. W4 W2 .. W2 W2 ),
      %w( W5 .. W6 W6 W6 .. .. .. .. .. .. .. .. .. W6 W6 W6 .. W4 W4 .. .. .. .. .. .. .. W4 W2 .. W2 W2 ),
      %w( W5 .. .. .. W6 .. .. .. .. .. .. .. .. .. W6 .. .. .. W4 W4 .. .. .. <9 .. .. .. W4 W2 .. .. W2 ),
      %w( W5 .. .. .. .. .. .. W6 W6 .. W6 W6 .. .. .. .. .. .. W4 W4 .. .. .. .. <9 .. .. W4 W2 W2 .. W2 ),
      %w( W5 .. .. .. .. .. .. .. W6 ^9 W6 .. .. .. .. .. .. .. W4 W4 .. .. .. .. .. <9 .. W4 W2 W2 .. W2 ),
      %w( W5 .. .. .. .. .. .. .. W6 W6 W6 .. .. .. .. .. .. .. W4 W4 .. .. .. .. .. .. .. W4 W2 W2 .. W2 ),
      %w( W5 .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. W4 W4 .. .. .. .. .. .. .. W4 W2 .. .. W2 ),
      %w( W5 W5 W5 W5 W5 W5 W5 D- W5 W5 W5 W5 W5 W5 W5 W5 W5 W5 W5 W4 W4 W4 W4 D- W4 W4 W4 W4 W2 .. W2 W2 ),
      %w( W5 W5 .. .. W5 .. .. .. .. .. W5 W4 W4 W4 W4 W4 W4 W4 W4 W4 .. .. .. .. .. .. .. W4 W2 .. W2 W2 ),
      %w( W5 W5 .. .. D| .. .. .. .. .. W5 .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. W4 W2 .. W2 W2 ),
      %w( W5 .. .. .. W5 .. .. .. .. .. D| .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. .. W4 W2 .. .. W2 ),
      %w( W5 .. .. .. W5 W5 W5 W5 W5 W5 W5 W4 W4 W4 W4 W4 W4 W4 W4 W4 W4 W4 W4 W4 W4 W4 W4 W4 W2 .. .. W2 ),
      %w( W3 P3 W3 W3 W3 W3 W3 W3 W3 W3 W2 W1 W1 W1 W1 W1 W1 W1 W1 W1 W1 W1 W1 W1 W2 W2 W2 W2 W2 W2 P2 W2 ),
      %w( W3 .. .. .. W3 W3 W3 .. .. .. W2 W1 v9 W1 .. .. .. .. .. .. W1 v9 W1 W1 .. .. .. .. W2 .. .. W2 ),
      %w( W3 .. .. .. W3 W3 W3 .. .. .. W2 .. .. .. .. .. .. .. .. .. .. .. .. W1 .. .. .. .. W2 .. .. W2 ),
      %w( W3 .. .. .. W3 W3 W3 .. .. .. W2 .. .. .. .. .. .. .. .. .. .. .. .. W1 .. .. .. .. D| .. .. W2 ),
      %w( W3 W3 D- W3 W3 W3 W3 W3 D- W3 W2 .. .. .. .. .. .. .. .. .. .. .. .. W1 .. .. .. .. W2 .. .. W2 ),
      %w( W2 .. .. .. .. .. .. .. .. .. W2 .. .. .. .. W9 .. .. W9 .. .. .. .. W1 .. .. .. .. W2 W2 W2 W2 ),
      %w( W2 .. .. .. .. .. .. .. .. .. D| .. .. .. .. .. .. .. .. .. .. .. .. D| .. .. .. .. W2 W2 W2 W2 ),
      %w( W2 .. .. .. .. .. .. .. .. .. W2 .. .. .. .. W9 .. .. W9 .. .. .. .. W1 .. .. .. .. W2 W2 W2 W2 ),
      %w( W2 W2 D- W2 W2 W2 W2 W2 D- W2 W2 .. .. .. .. .. .. .. .. .. .. .. .. W1 .. .. .. .. W2 .. .. W2 ),
      %w( W2 .. .. .. W2 W2 W2 .. .. .. W2 .. .. .. .. .. .. .. .. .. .. .. .. W1 .. .. .. .. D| .. .. W2 ),
      %w( W2 .. S^ .. W2 W2 W2 .. .. .. W2 .. ^9 .. .. .. .. .. .. .. .. ^9 .. W1 .. .. .. .. W2 .. .. W2 ),
      %w( W2 .. .. .. W2 W2 W2 .. .. .. W2 W1 .. W1 .. .. .. .. .. .. W1 .. W1 W1 .. .. .. .. W2 .. .. W2 ),
      %w( W2 W2 W2 W2 W2 W2 W2 W2 W2 W2 W2 W1 W1 W1 W1 W1 W1 W1 W1 W1 W1 W1 W1 W1 W2 W2 W2 W2 W2 W2 W2 W2 )
    ]

    for y in 0...@map_rows
      for x in 0...@map_columns
        @cell_type = @map[ y ][ x ][ 0 ]
        @cell_modifier = @map[ y ][ x ][ 1 ]

        case @cell_type
        when Cell::DOOR_CELL
          @map[ y ][ x ] = Door.new(
            map: @map,
            texture_id: @cell_type,
            x_cell: x,
            y_cell: y
          )

        when Cell::MAGIC_CELL
          @map[ y ][ x ] = Cell.new(
            map: @map,
            x_cell: x,
            y_cell: y
          )

          @magic_x = x * Cell::WIDTH + ( Cell::WIDTH / 2 )
          @magic_y = y * Cell::HEIGHT + ( Cell::HEIGHT / 2 )

        when Cell::PLAYER_CELL
          case @cell_modifier
          when Cell::DIRECTION_UP
            @player_starting_angle = @angles[ 270 ]
          when Cell::DIRECTION_DOWN
            @player_starting_angle = @angles[ 90 ]
          when Cell::DIRECTION_LEFT
            @player_starting_angle = @angles[ 180 ]
          when Cell::DIRECTION_RIGHT
            @player_starting_angle = @angles[ 0 ]
          end

          @map[ y ][ x ] = Cell.new(
            map: @map,
            x_cell: x,
            y_cell: y
          )

          @player_starting_x = x * Cell::WIDTH + ( Cell::WIDTH / 2 )
          @player_starting_y = y * Cell::HEIGHT + ( Cell::HEIGHT / 2 )

        when Cell::DIRECTION_DOWN,
             Cell::DIRECTION_LEFT,
             Cell::DIRECTION_RIGHT,
             Cell::DIRECTION_UP

          case @cell_type
          when Cell::DIRECTION_DOWN
            @push_direction = Cell::MOVING_SOUTH
          when Cell::DIRECTION_LEFT
            @push_direction = Cell::MOVING_EAST
          when Cell::DIRECTION_RIGHT
            @push_direction = Cell::MOVING_WEST
          when Cell::DIRECTION_UP
            @push_direction = Cell::MOVING_NORTH
          end

          @map[ y ][ x ] = Pushwall.new(
            direction: @push_direction,
            map: @map,
            texture_id: @cell_modifier,
            type: Pushwall::TYPE_MOVE,
            x_cell: x,
            y_cell: y
          )

          @movewalls << @map[ y ][ x ]

        when Cell::PUSH_WALL
          @map[ y ][ x ] = Pushwall.new(
            map: @map,
            texture_id: @cell_modifier,
            type: Pushwall::TYPE_PUSH,
            x_cell: x,
            y_cell: y
          )

        when Cell::END_CELL, Cell::WALL_CELL
          @map[ y ][ x ] = Cell.new(
            map: @map,
            texture_id: @cell_modifier,
            value: @cell_type,
            x_cell: x,
            y_cell: y
          )

        else
          @map[ y ][ x ] = Cell.new(
            map: @map,
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
    @span_table     = []
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

    # Configure our floor/ceiling lookup table.
    #
    # NOTE: The span_scale may need to be dynamically adjusted
    # once we start allowing the user to select different
    # screen width/height combinations.
    #
    @span_scale = 27
    @scale_height = ( @screen_height * @span_scale ).to_i

    for col in 1...@screen_width
      @span_table[ col ] = []

      for row in 1...@screen_half_height
        @span_table[ col ][ row ] = ( @fish_eye_table[ col ] * ( @scale_height / row ).to_i )
      end
    end

    # Configure our textures and wall color tables.
    #
    @textures = GameData.textures.update( GameData.textures ) do |key, value|
      Texture.new( data: value )
    end

    @wall_colors = GameData.wall_colors

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
    @half_fov = @player_fov / 2
    @player_move_x = 0
    @player_move_y = 0
    @player_starting_angle = 90
    @player_starting_x = 0
    @player_starting_y = 0
    @player_x = 0
    @player_y = 0

    # Define our screen dimensions and field-of-view metrics.
    #
    @screen_width = 80
    @screen_height = 36
    @screen_half_height = @screen_height / 2
    @screen = Screen.new( height: @screen_height, width: @screen_width )
    @screen.color_mode = Color::MODE_PARTIAL

    @fixed_factor = 512
    @fixed_angles = ( 360 * @screen_width ) / @player_fov
    @fixed_step = @fixed_angles / 360.0

    @frame_rate = 0.0
    @frames_rendered = 0
    @frame_start_time = 0.0

    # Define default colors and textures.
    #
    @default_ceiling_color = Color::MAGENTA
    @default_ceiling_texture = "@"
    @default_floor_color = Color::GRAY
    @default_floor_texture = "@"
    @default_wall_texture = "#"

    @ceiling_color = @default_ceiling_color
    @ceiling_texture = @default_ceiling_texture
    @floor_color = @default_floor_color
    @floor_texture = @default_floor_texture
    @wall_texture = @default_wall_texture

    @draw_ceiling = true
    @draw_floor = true
    @draw_textures = false

    # Define miscellaneous game variables.
    #
    @delta_start_time = 0.0
    @delta_time = 0.0
    @display_message = ""
    @show_debug_info = false
    @play_count = 0
  end

  # Displays the game's debug screen, waiting for the user to
  # press a key before returning control back to the caller.
  #
  def show_debug_screen
    clear_screen

    @screen.output_line
    @screen.output_line "Super Awesome Debug Console(TM)".center( @screen_width )
    @screen.output_line
    @screen.output_line "[ Flags ]".center( @screen_width )
    @screen.output_line
    @screen.output_line ( "Color mode".ljust( 25 )          + @screen.color_mode.to_s.rjust( 25 ) ).center( @screen_width )
    @screen.output_line ( "Draw ceiling?".ljust( 25 )       + @draw_ceiling.to_s.rjust( 25 ) ).center( @screen_width )
    @screen.output_line ( "Draw floor?".ljust( 25 )         + @draw_floor.to_s.rjust( 25 ) ).center( @screen_width )
    @screen.output_line ( "Draw textures?".ljust( 25 )      + @draw_textures.to_s.rjust( 25 ) ).center( @screen_width )
    @screen.output_line
    @screen.output_line "[ Metrics ]".center( @screen_width )
    @screen.output_line
    @screen.output_line ( "active_doors".ljust( 25 )        + @doors.size.to_s.rjust( 25 ) ).center( @screen_width )
    @screen.output_line ( "active_movewalls".ljust( 25 )    + @movewalls.size.to_s.rjust( 25 ) ).center( @screen_width )
    @screen.output_line ( "active_pushwalls".ljust( 25 )    + @pushwalls.size.to_s.rjust( 25 ) ).center( @screen_width )
    @screen.output_line ( "cell_height".ljust( 25 )         + Cell::HEIGHT.to_s.rjust( 25 ) ).center( @screen_width )
    @screen.output_line ( "cell_width".ljust( 25 )          + Cell::WIDTH.to_s.rjust( 25 ) ).center( @screen_width )
    @screen.output_line ( "frames_rendered".ljust( 25 )     + @frames_rendered.to_s.rjust( 25 ) ).center( @screen_width )
    @screen.output_line ( "frame_rate".ljust( 25 )          + @frame_rate.to_s.rjust( 25 ) ).center( @screen_width )
    @screen.output_line ( "frame_total_time".ljust( 25 )    + ( Time.now - @frame_start_time ).round( 4 ).to_s.rjust( 25 ) ).center( @screen_width )
    @screen.output_line ( "play_count".ljust( 25 )          + @play_count.to_s.rjust( 25 ) ).center( @screen_width )
    @screen.output_line ( "player_angle".ljust( 25 )        + ( @player_angle / @fixed_step ).round( 2 ).to_s.rjust( 25 ) ).center( @screen_width )
    @screen.output_line ( "player_angle_raw".ljust( 25 )    + @player_angle.round( 2 ).to_s.rjust( 25 ) ).center( @screen_width )
    @screen.output_line ( "player_fov".ljust( 25 )          + @player_fov.to_s.rjust( 25 ) ).center( @screen_width )
    @screen.output_line ( "player_x".ljust( 25 )            + @player_x.to_s.rjust( 25 ) ).center( @screen_width )
    @screen.output_line ( "player_y".ljust( 25 )            + @player_y.to_s.rjust( 25 ) ).center( @screen_width )
    @screen.output_line ( "map_columns".ljust( 25 )         + @map_columns.to_s.rjust( 25 ) ).center( @screen_width )
    @screen.output_line ( "map_rows".ljust( 25 )            + @map_rows.to_s.rjust( 25 ) ).center( @screen_width )
    @screen.output_line ( "map_x_size".ljust( 25 )          + @map_x_size.to_s.rjust( 25 ) ).center( @screen_width )
    @screen.output_line ( "map_y_size".ljust( 25 )          + @map_y_size.to_s.rjust( 25 ) ).center( @screen_width )
    @screen.output_line ( "screen_width".ljust( 25 )        + @screen_width.to_s.rjust( 25 ) ).center( @screen_width )
    @screen.output_line ( "screen_height".ljust( 25 )       + @screen_height.to_s.rjust( 25 ) ).center( @screen_width )
    @screen.output_line
    @screen.output_line "Press any key to continue...".center( @screen_width )
    @screen.output_line

    Input.wait_key
    clear_screen
    update_buffer
  end

  # Shows the ending screen.
  #
  def show_end_screen
    @screen.wipe Screen::WIPE_BLINDS
    clear_screen

    position_cursor ( @screen_height / 2 ) - 7, 0

    @screen.output_line "You have reached...".center( 72 )
    @screen.output_line "                ,,                                                  ,,  "
    @screen.output_line " MMP''MM''YMM `7MM                    `7MM'''YMM                  `7MM  "
    @screen.output_line " P'   MM   `7   MM                      MM    `7                    MM  "
    @screen.output_line "      MM        MMpMMMb.  .gP'Ya        MM   d    `7MMpMMMb.   ,M''bMM  "
    @screen.output_line "      MM        MM    MM ,M'   Yb       MMmmMM      MM    MM ,AP    MM  "
    @screen.output_line "      MM        MM    MM 8M''''''       MM   Y  ,   MM    MM 8MI    MM  "
    @screen.output_line "      MM        MM    MM YM.    ,       MM     ,M   MM    MM `Mb    MM  "
    @screen.output_line "    .JMML.    .JMML  JMML.`Mbmmd'     .JMMmmmmMMM .JMML  JMML.`Wbmd'MML."
    @screen.output_line
    @screen.output_line "...or have you?".center( 72 )
    @screen.output_line
    @screen.output_line "Press any key to find out!".center( 72 )

    Input.clear_input
    Input.wait_key

    @play_count += 1

    initialize
    activate_movewalls
    reset_timers
    clear_screen
    update_buffer
  end

  # Displays the exit screen and quits the game.
  #
  def show_exit_screen
    clear_screen

    @screen.output_line
    @screen.output_line "Thanks for playing...".center( @screen_width )
    @screen.output_line
    show_logo
    @screen.output_line
    @screen.output_line
    @screen.output_line "Problems or suggestions? Visit the repo!".center( @screen_width )
    @screen.output_line "http://www.github.com/AtomicPair/wolfentext3d".center( @screen_width )
    @screen.output_line

    exit 0
  end

  # Displays the game's help screen, waiting for the user to
  # press a key before returning control back to the caller.
  #
  def show_help_screen
    clear_screen

    @screen.output_line
    @screen.output_line "Wolfentext3D Help".center( @screen_width )
    @screen.output_line
    @screen.output_line "[ Notes ]".center( @screen_width )
    @screen.output_line
    @screen.output_line "Testing has shown that running this game in color ".center( @screen_width )
    @screen.output_line "mode under some terminals will result in very poor".center( @screen_width )
    @screen.output_line "poor performance.  Thus, if you experience low    ".center( @screen_width )
    @screen.output_line "frame rates in your chosen terminal, try running  ".center( @screen_width )
    @screen.output_line "in 'no color' mode OR use a different terminal    ".center( @screen_width )
    @screen.output_line "altogether for the best possible experience. See  ".center( @screen_width )
    @screen.output_line "the README for a table of compatible terminals.   ".center( @screen_width )
    @screen.output_line
    @screen.output_line "Enjoy the game!                                   ".center( @screen_width )
    @screen.output_line
    @screen.output_line "[ Keys ]".center( @screen_width )
    @screen.output_line
    @screen.output_line ( "Move forward".ljust( 25 )   + "Up Arrow, w".rjust( 25 ) ).center( @screen_width )
    @screen.output_line ( "Move backward".ljust( 25 )  + "Down Arrow, s".rjust( 25 ) ).center( @screen_width )
    @screen.output_line ( "Strafe left".ljust( 25 )    + "a".rjust( 25 ) ).center( @screen_width )
    @screen.output_line ( "Strafe right".ljust( 25 )   + "d".rjust( 25 ) ).center( @screen_width )
    @screen.output_line ( "Turn left".ljust( 25 )      + "Left Arrow, k".rjust( 25 ) ).center( @screen_width )
    @screen.output_line ( "Turn right".ljust( 25 )     + "Right Arrow, l".rjust( 25 ) ).center( @screen_width )
    @screen.output_line
    @screen.output_line ( "Open doors/activate walls".ljust( 25 ) + "Space".rjust( 25 ) ).center( @screen_width )
    @screen.output_line
    @screen.output_line ( "Toggle ceiling".ljust( 25 )    + "c".rjust( 25 ) ).center( @screen_width )
    @screen.output_line ( "Toggle debug info".ljust( 25 ) + "i".rjust( 25 ) ).center( @screen_width )
    @screen.output_line ( "Toggle floor".ljust( 25 )      + "f".rjust( 25 ) ).center( @screen_width )
    @screen.output_line ( "Toggle texturing".ljust( 25 )  + "t".rjust( 25 ) ).center( @screen_width )
    @screen.output_line
    @screen.output_line Color.colorize( ( "No color".ljust( 25 )      + "1".rjust( 25 ) ).center( @screen_width ), Color::BLUE, 2 )
    @screen.output_line Color.colorize( ( "Partial color".ljust( 25 ) + "2".rjust( 25 ) ).center( @screen_width ), Color::GREEN, 2 )
    @screen.output_line Color.colorize( ( "Full color".ljust( 25 )    + "3".rjust( 25 ) ).center( @screen_width ), Color::YELLOW, 2 )
    @screen.output_line
    @screen.output_line ( "Debug screen".ljust( 25 )   + "?".rjust( 25 ) ).center( @screen_width )
    @screen.output_line ( "Help screen".ljust( 25 )    + "h".rjust( 25 ) ).center( @screen_width )
    @screen.output_line ( "Quit game".ljust( 25 )      + "q".rjust( 25 ) ).center( @screen_width )
    @screen.output_line
    @screen.output_line "Press any key to continue...".center( @screen_width )
    @screen.output_line

    Input.wait_key
    clear_screen
    update_buffer
  end

  # Displays the game's title screen.
  #
  def show_title_screen
    clear_screen

    @screen.output_line
    show_logo
    @screen.output_line
    @screen.output_line
    @screen.output_line "Press any key to start...".center( 88 )

    Input.wait_key
    clear_screen
  end

  # Displays the Wolfentext logo.
  #
  # Logo courtesy of PatorJK's ASCII Art Generator.
  # @see http://patorjk.com/software/taag/
  #
  def show_logo
    @screen.output_line "    .~`'888x.!**h.-``888h.               x .d88'     oec :                              "
    @screen.output_line "   dX   `8888   :X   48888>         u.    5888R     @88888                u.    u.      "
    @screen.output_line "  '888x  8888  X88.  '8888>   ...ue888b   '888R     8'*88%       .u     x@88k u@88c.    "
    @screen.output_line "  '88888 8888X:8888:   )?''`  888R Y888r   888R     8b.       ud8888.  ^'8888''8888'^   "
    @screen.output_line "   `8888>8888 '88888>.88h.    888R I888>   888R    u888888> :888'8888.   8888  888R     "
    @screen.output_line "     `8' 888f  `8888>X88888.  888R I888>   888R     8888R   d888 '88%'   8888  888R     "
    @screen.output_line "    -~` '8%'     88' `88888X  888R I888>   888R     8888P   8888.+'      8888  888R     "
    @screen.output_line "    .H888n.      XHn.  `*88! u8888cJ888    888R     *888>   8888L        8888  888R     "
    @screen.output_line "   :88888888x..x88888X.  `!   '*888*P'    .888B .   4888    '8888c. .+  '*88*' 8888'    "
    @screen.output_line "   f  ^%888888% `*88888nx'      'Y'       ^*888%    '888     '88888%      ''   'Y'      "
    @screen.output_line "        `'**'`    `'**''                    '%       88R       'YP'                     "
    @screen.output_line "                                                     88>                                "
    @screen.output_line "                                                     48                                 "
    @screen.output_line "                                                     '8                                 "
    @screen.output_line "    .....                                       s                          ....         "
    @screen.output_line " .H8888888h.  ~-.                              :8      .x~~'*Weu.      .xH888888Hx.     "
    @screen.output_line " 888888888888x  `>               uL   ..      .88     d8Nu.  9888c   .H8888888888888:   "
    @screen.output_line "X~     `?888888hx~      .u     .@88b  @88R   :888ooo  88888  98888   888*'''?''*88888X  "
    @screen.output_line "'      x8.^'*88*'    ud8888.  ''Y888k/'*P  -*8888888  '***'  9888%  'f     d8x.   ^%88k "
    @screen.output_line " `-:- X8888x       :888'8888.    Y888L       8888          ..@8*'   '>    <88888X   '?8 "
    @screen.output_line "      488888>      d888 '88%'     8888       8888       ````'8Weu    `:..:`888888>    8>"
    @screen.output_line "    .. `'88*       8888.+'        `888N      8888      ..    ?8888L         `'*88     X "
    @screen.output_line "  x88888nX'      . 8888L       .u./'888&    .8888Lu= :@88N   '8888N    .xHHhx..'      ! "
    @screen.output_line " !'*8888888n..  :  '8888c. .+ d888' Y888*'  ^%888*   *8888~  '8888F   X88888888hx. ..!  "
    @screen.output_line "'    '*88888888*    '88888%   ` 'Y   Y'       'Y'    '*8'`   9888%   !   '*888888888'   "
    @screen.output_line "        ^'***'`       'YP'                             `~===*%'`            ^'***'`     "
  end

  # Calls the main ray casting engine, updates the screen buffer,
  # and displays the updated buffer on the screen.
  #
  def update_buffer
    clear_buffer
    ray_cast @player_x, @player_y, @player_angle
    populate_buffer
    clear_screen false
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

  def update_message( message )
    @message_timer = Time.now
    @display_message = message.ljust( 40 )
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
