pico-8 cartridge // http://www.pico-8.com
version 29
__lua__

narrator_box_size = 48
narrator_padding = 6
narrator_box_y = 128 - narrator_box_size
col_width = 128 - (2 * narrator_padding)
narrator_index = 1

menu_index = {x=1, y=1}
f_count = 0

function new_event(type, desc)
  -- Create an "event" object.
  event = {
    type = type,
    desc = desc,
    next = nil
  }
  return event
end

-- game state
function new_game_state()
  local state = {
    player = new_unit("player", 100, new_event("menu", "")),
    enemy = new_unit("wolf", 120, new_event("story", "the wolf attacks you!")),
    is_player_turn = true
  }

  state.current_unit = function(this)
    if this.is_player_turn then
      return this.player
    else
      return this.enemy
    end
  end

  state.start_turn = function(this, is_player_turn)
    this.is_player_turn = is_player_turn
    sequence:add(this:current_unit().event)
    sequence:add(new_event("end_turn"))
  end

  state.switch_turn = function(this)
    this:start_turn(not this.is_player_turn)
    sequence:next()
  end

  return state
end

-- units
function new_unit(name, hp, event)
  return {
    name=name,
    hp=hp,
    event=event
  }
end

-- create the event sequence object, we will use to manage our gameplay flow.
function new_sequence()
  local first_event = new_event("story", "it's your turn to move!")
  local sequence = {
    head = first_event,
    tail = first_event
  }

  sequence.next = function(this)
    -- move sequence cursor to the next event.
    this.head = this.head.next
  end

  sequence.add = function(this, e)
    -- add an event to the end of the sequence.
    this.tail.next = e
    this.tail = e
  end

  sequence.insert = function(this, e)
    -- move sequence cursor to the next event.
    e.next = this.head.next
    this.head.next = e
  end
  return sequence
end

function print_wrapped(text)
 line_arr = split(text," ")
 cursor(narrator_padding, narrator_box_y + narrator_padding, 7)
 line = ""
 
 for word in all(line_arr) do
  word_str = tostring(word) -- case to string or it fails on numbers
  prospect_length = (#line + #word_str + 1) * 4
  if (prospect_length >= col_width) do
   print(line)
   line = word_str
  else
   if (#line == 0) do
    line = word_str
   else
    line = line.." "..word_str
   end
  end
 end
 print(line)
end

function flip_count(n_frames)
 mod_count = f_count % (n_frames * 2)
 return mod_count < n_frames
end

function draw_menu()

 menu_col_size = 2
 -- move the menu cursor
 for i=0,3 do
  if btnp(i) then sfx(0) end
 end
 if btnp(0) then menu_index.x = menu_index.x - 1 end
 if btnp(1) then menu_index.x = menu_index.x + 1 end
 if btnp(2) then menu_index.y = menu_index.y - 1 end
 if btnp(3) then menu_index.y = menu_index.y + 1 end
 -- cap the positions
 menu_index.x = max(1, menu_index.x)
 menu_index.x = min(2, menu_index.x)
 menu_index.y = max(1, menu_index.y)
 menu_index.y = min(2, menu_index.y)
 -- render the selected
 selected_menu_index = (menu_index.x - 1) * menu_col_size + menu_index.y

 x_offset = 12
 x_gap = 42
 y_offset = 8
 menu_options = {"attack", "defend", "magic", "item"}
 menu_y = narrator_box_y + narrator_padding + y_offset
 menu_line_height = 12
 menu_pos_x = {x_offset, x_offset, x_offset + x_gap, x_offset + x_gap}
 menu_pos_y = {menu_y, menu_y + menu_line_height, menu_y, menu_y + menu_line_height}

 for i=1,#menu_options do
  if (selected_menu_index == i) then
   local_option_text = "▶ "..menu_options[i]
  else
   local_option_text = "  "..menu_options[i]
  end
  print(local_option_text, menu_pos_x[i], menu_pos_y[i], 7)
 end
end

function draw_caret()
 if (flip_count(15)) then
  caret = "press ❎"
  caret_x = 128 - narrator_padding - #caret * 4
  caret_y = 128 - narrator_padding - 6
  print(caret, caret_x, caret_y)
 end
end

function draw_narrator_box()
 -- create a background for the narrator's box.
 rectfill(0, narrator_box_y, 128, 128, 1)
end

-->8
-- game loop

function _init()
  sequence = new_sequence()
  state = new_game_state()

  -- start the player's turn.
  state:start_turn(true)
end

function _update()

  f_count += 1
  event = sequence.head

  -- check for end-turn.
  if event.type == "end_turn" then
    state:switch_turn()
  elseif btnp(5) then
    if event.type == "menu" then 
      sequence:insert(new_event("story", "you attacked the wolf"))
    end
    sequence:next()
  end
end

function _draw()
  cls(5)
  draw_narrator_box()

  -- Show the current event.
  if (event.type == "menu") then
    draw_menu() 
  else
    print_wrapped(event.desc)
    draw_caret()
  end
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000100003245032450324503245032450324503245032450324503245032450324503245022450224502245022450224502245022450224502245022450224502245022450224502245022450224502245022450
