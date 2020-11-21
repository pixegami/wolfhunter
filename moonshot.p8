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

-- game state
function new_game_state()

  local player = new_unit("player", 100, {"menu"})
  local enemy = new_unit("wolf", 120, {"slash", "howl"})

  local state = {
    player = player,
    enemy = enemy,
    is_player_turn = true
  }

  state.current_unit = function(this)
    if this.is_player_turn then
      return this.player
    else
      return this.enemy
    end
  end

  state.current_target = function(this)
    if this.is_player_turn then
      return this.enemy
    else
      return this.player
    end
  end

  state.start_turn = function(this, is_player_turn)
    this.is_player_turn = is_player_turn
    this:current_unit():on_turn_start()
    unit_event = generate_event(this:current_unit():get_random_event_id(), this:current_unit(), this:current_target())
    sequence:add(unit_event)
    sequence:add(new_end_turn_event())
  end

  state.switch_turn = function(this)
    this:start_turn(not this.is_player_turn)
    sequence:next()
  end

  return state
end

-- units
function new_unit(name, hp, event)
  local unit = {
    name=name,
    hp=hp,
    event=event,

    --combat status
    block = 24, -- block incoming damage for 1 turn.
  }

  unit.get_random_event_id = function(this)
    rnd_index = flr(rnd(#this.event)+1)
    return this.event[rnd_index]
  end

  -- do this every time the unit starts a new turn.
  unit.on_turn_start = function(this)
    this.block = 0
  end

  return unit
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

-- menu system
function new_menu(items, n_columns)

  -- model the menu
  local menu = {
    items = items,
    n_columns = 2,
    selected_index = 1,

    -- menu positioning
    x_origin = 8,
    x_gap = 42,

    y_origin = narrator_box_y + 8,
    y_gap = 12
  }

  -- update the menu with arrow keys
  menu.update = function(this)

    -- translate selected index into x and y.
    local translated_xy = this:translate_xy(this.selected_index)
    local pos_x = translated_xy["x"]
    local pos_y = translated_xy["y"]

    -- move the cursor and cap its positions.
     if btnp(0) then pos_x = max(0, pos_x - 1) end
     if btnp(1) then pos_x = min(this.n_columns - 1, pos_x + 1) end
     if btnp(2) then pos_y = max(0, pos_y - 1) end
     if btnp(3) then pos_y = min(flr(#this.items / this.n_columns) - 1, pos_y + 1) end

    -- translate x and y back into selected index.
    this.selected_index = this.n_columns * pos_y + pos_x + 1

    -- execute the selected event
    if btnp(5) then 
      local selected_event_id = this.items[this.selected_index]
      local selected_event = generate_event(selected_event_id, state.player, state.enemy)
      sequence:insert(selected_event)
    end
  end

  -- render the current menu
  menu.draw = function(this)
    for i=1, #this.items do
      local pos_x = this:translate_xy(i)["x"] * this.x_gap + this.x_origin
      local pos_y = this:translate_xy(i)["y"] * this.y_gap + this.y_origin
      
      -- print the selected menu item
      if (this.selected_index == i) then prefix = "▶ " else prefix = "  " end
      print(prefix..this.items[i], pos_x, pos_y, 7)
    end
  end

  menu.translate_xy = function(this, i)
    local x_index = (i - 1) % this.n_columns
    local y_index = ceil(i / this.n_columns) - 1
    return {x = x_index, y = y_index}
  end

  return menu
end

-->8
--event generators

-- events
function new_event(type, desc, executable)
  -- Create an "event" object.
  local event = {
    type = type,
    desc = desc,
    next = nil,
    executable = executable
  }
  return event
end

function new_attack_event(name, unit, target, value)
  local event = new_event("story", unit.name.." uses "..name..".", true)

  event.action = function(this)
    -- when the action is used, we evalute block and damage as separate events.
    local damage = value
    local block_event = nil
    if target.block > 0 then
      blocked_damage = min(target.block, value)
      target.block -= blocked_damage
      damage -= blocked_damage
      block_event = new_event("story", "blocked "..blocked_damage.." damage.")
    end

    -- resolve the damage.
    if damage > 0 then
      local dmg_event = new_damage_event(target, damage)
      sequence:insert(dmg_event)
    else
      local dmg_event = new_event("story", "this dealt no damage!")
      sequence:insert(dmg_event)
    end

    -- finally insert the block event so it resolves first.
    if block_event then sequence:insert(block_event) end
  end

  return event
end

function new_damage_event(unit, value)

  local desc = unit.name.." you take "..value.." damage!"
  local dmg_event = new_event("damage", desc, true)
  dmg_event.action = function(this)
    unit.hp -= value
    if unit.hp <= 0 then
      unit.hp = 0
      sequence:insert(new_event("end_combat", "the fight has ended!"))
    end
  end

  return dmg_event
end

function new_end_turn_event()
  local event = new_event("end_turn", "", true)
  event.action = function(this)
    state:switch_turn()
  end
  return event
end

function new_block_event(unit, value)
  local desc = unit.name.." gains "..value.." block."
  local event = new_event("block", desc, true)
  event.action = function(this) unit.block += value end
  return event
end

function generate_event(event_id, unit, target)
  if event_id == "menu" then return new_event("menu") end
  if event_id == "slash" then return new_attack_event(event_id, unit, target, 32) end
  if event_id == "howl" then return new_attack_event(event_id, unit, target, 5) end
  if event_id == "attack" then return new_attack_event(event_id, unit, target, 64) end
  if event_id == "defend" then return new_block_event(unit, 12) end

  -- unknown event id
  return new_event("story", "you use "..event_id.."... but nothing happens.")
end

-->8
--rendering

function draw_menu(menu)
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

function draw_unit(unit, pos_x, pos_y)
  print(unit.name..": "..unit.hp, pos_x, pos_y, 7)
end

function draw_units()
  -- draw player unit
  draw_unit(state.player, 5, 5)
  draw_unit(state.enemy, 84, 5)
end

-->8
-- game loop

function _init()
  sequence = new_sequence()
  state = new_game_state()
  combat_menu = new_menu({"attack", "defend", "magic", "items"})

  -- start the player's turn.
  state:start_turn(true)
end

function _update()

  f_count += 1
  event = sequence.head

  -- execute this event's action.
  if event.executable then
    event:action()
    event.executable = false
  end

  -- update the menu if we are showing one.
  if event.type == "menu" then combat_menu:update() end

  -- each time we press x, the sequence progresses.
  if btnp(5) then sequence:next() end
end

function _draw()
  cls(5)
  draw_narrator_box()
  draw_units()

  -- show the current event.
  if (event.type == "menu") then
    combat_menu:draw()
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
