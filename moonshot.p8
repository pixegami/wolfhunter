pico-8 cartridge // http://www.pico-8.com
version 29
__lua__

narrator_box_size = 48
narrator_padding = 6
narrator_box_y = 128 - narrator_box_size
col_width = 128 - (2 * narrator_padding)
narrator_index = 1

menu_index = {x=1, y=1}

-- One of menu | info
phase = "menu"

f_count = 0

-- history={"red attacks blue for 10 damage and blue faints!","item2","item3"}
example_lines = {
 "this is an example of a very long sentence. try to break this up!",
 "we should really do something about that.",
 "what did you say?"
}

function new_event(desc)
  -- Create an "event" object.
  event = {
    desc = desc,
    e = nil
  }
  return event
end

-- create the event sequence object, we will use to manage our gameplay flow.
event_sequence = {
  current_event = new_event("it's your turn to move!")
}

event_sequence.next = function(this)
 -- move sequence cursor to the next event.
 this.current_event = this.current_event.next
end

event_sequence.add = function(this, e)
 -- move sequence cursor to the next event.
 this.current_event.next = e
end

event_sequence:add(new_event("this is how you do it"))

function print_wrapped(text)
 line_arr = split(text," ")
 cursor(narrator_padding, narrator_box_y + narrator_padding, 7)
 line = ""
 
 for word in all(line_arr) do
  prospect_length = (#line + #word + 1) * 4
  if (prospect_length >= col_width) do
   print(line)
   line = word
  else
   if (#line == 0) do
    line = word
   else
    line = line.." "..word
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

function _update()

  f_count += 1
  event = event_sequence.current_event

  if (btnp(5)) then 
    event_sequence:next()
  end
end

function _draw()
  cls(5)
  draw_narrator_box()

  -- Show the current event.
  print_wrapped(event.desc)
  draw_caret()

  -- if (phase == "menu") then
  --     draw_menu()
  --   else
  --     print_wrapped(example_lines[narrator_index])
  --     draw_caret()
  -- end
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
