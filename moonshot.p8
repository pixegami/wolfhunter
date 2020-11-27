pico-8 cartridge // http://www.pico-8.com
version 29
__lua__

narrator_box_size = 48
narrator_padding = 6
narrator_box_y = 128 - narrator_box_size
col_width = 128 - (2 * narrator_padding)
narrator_index = 1

-- game constants
k_bleed_damage = 10

menu_index = {x=1, y=1}
f_count = 0

-- game state
function new_game_state()

  -- create player controlled unit
  local player_events = {"menu"}
  local player_items = {"potion", "silver sword", "gun"}
  local player = new_unit("player", 100, player_events, player_items)

  -- create enemy unit
  local enemy = new_unit("wolf", 300, {"slash", "dark charge", "strong defend", "raging strike", "ravage", "cleave"})

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
    unit_event = generate_event(this:current_unit():next_event(), this:current_unit(), this:current_target())
    sequence:add(unit_event)
    sequence:add(new_end_turn_event())
  end

  state.switch_turn = function(this)
    this:start_turn(not this.is_player_turn)
  end

  return state
end

-- units
function new_unit(name, hp, event_pool, items)
  local unit = {
    name=name,
    hp=hp,
    max_hp=hp,
    mana=5,
    max_mana=5,
    items=items,

    -- used to animate the unit
    animation=nil,
    vfx_animation=nil,

    -- event management
    event_pool=event_pool,
    event_queue={},

    --combat status
    block = 0, -- block incoming damage for 1 turn.
    bleed = 0, -- bleeding, taking damage each turn.
    blind = 0, -- if blind, unit's attacks will miss
    vulnerable = false, -- take double damage from attacks.
  }

  unit.get_random_event_id = function(this)
    rnd_index = flr(rnd(#this.event)+1)
    return this.event[rnd_index]
  end

  -- copy the event pool into the event queue
  unit.enqueue_random_events_from_pool = function(this)
    this.event_queue = {}
    for i=1, #this.event_pool do
      local r_index = flr(rnd(#this.event_queue)) + 1
      add(this.event_queue, this.event_pool[i], r_index)
    end
  end

  -- next event in the queue
  unit.next_event = function(this)
    -- randomly populate the queue again.
    if #this.event_queue == 0 then this:enqueue_random_events_from_pool() end
    -- pop first item from the queue.
    local event = this.event_queue[1]
    del(this.event_queue, event)
    return event
  end

  unit.insert_event = function(this, event)
    add(this.event_queue, event, 1)
  end

  -- do this every time the unit starts a new turn.
  unit.on_turn_start = function(this)

    -- reset unit status effects.
    if this.vulnerable then
      sequence:add(new_info_event(unit.name.." is no longer vulnerable."))
    end

    if this.bleed == 1 then
      sequence:add(new_info_event(unit.name.." is no longer bleeding."))
    end

    if this.blind == 1 then
      sequence:add(new_info_event(unit.name.." is no longer blinded."))
    end

    this.vulnerable = false
    this.block = 0
    this.bleed -= 1
    this.blind -= 1
  end

  unit.animate = function(this, animation)
    this.animation = animation
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
    e:get_tail().next = this.head.next
    this.head.next = e
  end
  return sequence
end

function print_wrapped(text, x, y)
 line_arr = split(text," ")
 cursor(x, y, 7)
 line = ""
 
 for word in all(line_arr) do
  word_str = tostring(word) -- case to string or it fails on numbers
  prospect_length = (#line + #word_str + 1) * 4
  if (prospect_length >= col_width) do
   print(line, x, y)
   line = word_str
   y += 8
  else
   if (#line == 0) do
    line = word_str
   else
    line = line.." "..word_str
   end
  end
 end
 print(line, x, y)
end

function flip_count(n_frames)
 mod_count = f_count % (n_frames * 2)
 return mod_count < n_frames
end

-- menu system
function new_menu(items, n_columns, back_action, show_desc)

  -- model the menu
  local menu = {
    items = items,
    n_columns = n_columns,
    back_action = back_action,
    show_desc = show_desc,

    -- menu positioning
    selected_index = 1,
    x_origin = 8,
    x_gap = 42,
    y_origin = narrator_box_y + 8,
    y_gap = 12,
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

    -- execute the back function
    if btnp(4) and this.back_action then
      sequence:insert(new_event("menu"))
      sequence:next()
    end
  end

  -- render the current menu
  menu.draw = function(this)

    this:draw_desc()
    draw_narrator_box()

    for i=1, #this.items do
      local pos_x = this:translate_xy(i)["x"] * this.x_gap + this.x_origin
      local pos_y = this:translate_xy(i)["y"] * this.y_gap + this.y_origin
      
      -- print the selected menu item
      if (this.selected_index == i) then prefix = "▶ " else prefix = "  " end
      print(prefix..this.items[i], pos_x, pos_y, 7)
    end
  end

  -- draw a sub-menu with description of the item.
  menu.draw_desc = function(this)
    if not this.show_desc then return end

    local gap = 1
    local height = 12
    local box_y = narrator_box_y-gap-height
    rectfill(0, box_y, 128, narrator_box_y-gap, 2)

    local text_gap = 4
    local desc = get_event_desc(this.items[this.selected_index])
    local origin_x = text_gap
    local origin_y = box_y + text_gap
    print_wrapped(desc, origin_x, origin_y)
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

  event.get_tail = function(this)
    if this.next then
      return this.next:get_tail()
    else
      return this
    end
  end

  -- add new event to the end of the chain
  event.chain_add = function(this, event)
    this:get_tail().next = event
  end

  return event
end

function new_heal_event(name, unit, value)
  local event = new_info_event(unit.name.." uses "..name..".", true)
  event.action = function(this)

    -- heal status effects
    if unit.bleed > 0 then
      sequence:insert(new_info_event(unit.name.."'s bleeding is healed!"))
      unit.bleed = 0
    end

    local hp_gap = unit.max_hp - unit.hp
    if hp_gap == 0 then
      sequence:insert(new_info_event(unit.name.." is full health already!"))
    else
      heal_value = min(hp_gap, value)
      sequence:insert(new_recovery_event(unit, heal_value))
    end
  end
  return event
end

function new_mana_event(name, unit, value)
  local event = new_info_event(unit.name.." uses "..name..".", true)
  event.action = function(this)
    local mp_gap = unit.max_mana - unit.mana
    if mp_gap == 0 then
      sequence:insert(new_info_event(unit.name.." is full mana already!"))
    else
      mana_value = min(mp_gap, value)
      sequence:insert(new_mana_recovery_event(unit, mana_value))
    end
  end
  return event
end

function new_recovery_event(unit, heal_value)
  local event = new_info_event(unit.name.." recovers "..heal_value.." hp.", true)
  event.action = function(this)
    unit:animate(new_heal_animation())
    unit.hp += heal_value
  end
  return event
end

function new_mana_recovery_event(unit, mana_value)
  local event = new_info_event(unit.name.." recovers "..mana_value.." mana.", true)
  event.action = function(this)

    unit.mana += mana_value
  end
  return event
end

function new_attack_event(name, unit, target, value)
  local event = new_info_event(unit.name.." uses "..name..".", true)

  event.action = function(this)

    -- insert special event effects
    if name == "raging strike" then insert_vulnerable_event(unit) end
    if name == "spark" then insert_blind_event(target) end

    -- create an event 'head' to append to. we won't use it
    local head_event = new_event()
    local damage = value

    -- resolve blind.
    if unit.blind > 0 then
      head_event:chain_add(new_info_event(unit.name.." is blind... the attack misses!"))
      sequence:insert(head_event.next)
      return
    end

    -- resolve cleave
    if name == "cleave" then 
      head_event:chain_add(new_info_event("a third of "..target.name.."'s life is dealt as damage."))
      damage = ceil(target.hp * 0.33)
    end

    -- resolve vulnerability.
    if target.vulnerable then
      damage *= 2
      head_event:chain_add(new_info_event(target.name.." is vulnerable. the damage is doubled."))
    end

    -- resolve the block.
    if target.block > 0 then
      -- fireball cannot be blocked, deals extra damage!
      if name == "fireball" then
        head_event:chain_add(new_info_event("fireball cannot be blocked! it deals extra damage."))
        damage += 25
      else
        blocked_damage = min(target.block, damage)
        target.block -= blocked_damage
        damage -= blocked_damage
        local block_event = new_info_event("blocked "..blocked_damage.." damage.", true)
        block_event.action = function(this) target.vfx_animation = get_vfx_for_action("block") end
        head_event:chain_add(block_event)
      end
    end

    -- resolve the damage.
    if damage > 0 then
      -- play attack vfx only if attack hits
      target.vfx_animation = get_vfx_for_action(name)

      if name == "ravage" then insert_bleed_event(target) end
      head_event:chain_add(new_damage_event(target, damage))
    else
      head_event:chain_add(new_info_event("this dealt no damage!"))
    end

    -- resolve the bleed.
    if target.bleed > 0 and damage > 0 then
      head_event:chain_add(new_info_event(target.name.." takes extra damage from bleeding."))
      head_event:chain_add(new_damage_event(target, k_bleed_damage))
      target.bleed += 1 -- unit continues to bleed another turn.
    end

    -- finally insert the event head
    sequence:insert(head_event.next)
  end

  return event
end

function insert_vulnerable_event(unit)
  local event = new_info_event(unit.name.." becomes vulnerable to attacks.", true)
  event.action = function(this) unit.vulnerable = true end
  sequence:insert(event)
end

function insert_blind_event(unit)
  local event = new_info_event(unit.name.." is blinded!", true)
  event.action = function(this) unit.blind = 2 end
  sequence:insert(event)
end

function insert_bleed_event(unit)
  local event = new_info_event(unit.name.." is bleeding, and will take extra damage when attacked.", true)
  event.action = function(this) unit.bleed = 3 end
  sequence:insert(event)
end

function new_info_event(text, executable)
  return new_event("story", text, executable)
end

function new_damage_event(unit, value)

  local desc = unit.name.." you take "..value.." damage!"
  local dmg_event = new_event("damage", desc, true)
  dmg_event.action = function(this)
    unit.hp -= value
    unit:animate(new_hit_animation())
    if unit.hp <= 0 then
      unit.hp = 0
      sequence:insert(new_end_combat_event())
      sequence:insert(new_info_event("the fight has ended!"))
    end
  end

  return dmg_event
end

function new_end_turn_event()
  local event = new_event("auto", "", true)
  event.action = function(this)
    state:switch_turn()
  end
  return event
end

function new_end_combat_event()
  local event = new_event("end_combat", "", true)
  event.action = function(this)
    global_scene = new_victory_scene():init()
  end
  return event
end

function new_defend_event(name, unit, value)
  local event = new_info_event(unit.name.." uses "..name..".", true)
  event.action = function(this)
    local block_event = new_block_event(unit, value)
    block_event.action = function(this) unit.block += value end
    unit.vfx_animation = get_vfx_for_action(name)
    sequence:insert(block_event)
  end
  return event
end

function new_block_event(unit, value)
  local desc = unit.name.." gains "..value.." block."
  local event = new_event("block", desc, true)
  event.action = function(this) unit.block += value end
  return event
end

function new_dark_charge_event(unit)
  local event = new_info_event(unit.name.." howls and leaps high into the night. beware!")
  unit:insert_event("dark flight")
  return event
end

function as_spell(unit, event)
  local spell_event = new_event("auto", "", true)
  spell_event.action = function(this)
    if unit.mana > 0 then
      unit.mana -= 1
      sequence:insert(event)
    else
      sequence:insert(new_event("menu"))
      sequence:insert(new_info_event("you don't have enough mana to cast this spell."))
    end
  end
  return spell_event
end

function as_item(item_name, unit, event)
  local item_event = new_event("auto", "", true)
  item_event.action = function(this)
    del(unit.items, item_name)
    sequence:add(event)
  end
  return item_event
end

function generate_event(event_id, unit, target)

  -- player moves
  if event_id == "menu" then return new_event("menu") end
  if event_id == "attack" then return new_attack_event(event_id, unit, target, 15) end
  if event_id == "defend" then return new_defend_event(event_id, unit, 15) end
  if event_id == "magic" then return new_event("magic") end

  -- items are a special case. we need to create a new menu.
  if event_id == "items" then
    if #unit.items == 0 then
      local no_item_event = new_info_event("you have no items left to use.")
      no_item_event:chain_add(new_event("menu"))
      return no_item_event
    else
      items_menu = new_menu(unit.items, 1, "menu", true)
      return new_event("items")
    end
  end

  -- player magic
  if event_id == "spark" then return as_spell(unit, new_attack_event(event_id, unit, target, 12)) end
  if event_id == "fireball" then return as_spell(unit, new_attack_event(event_id, unit, target, 20)) end
  if event_id == "heal" then return as_spell(unit, new_heal_event(event_id, unit, 35)) end

  -- player items
  if event_id == "potion" then return as_item(event_id, unit, new_mana_event(event_id, unit, 5)) end
  if event_id == "silver sword" then return as_item(event_id, unit, new_attack_event(event_id, unit, target, 12)) end
  if event_id == "gun" then return as_item(event_id, unit, new_attack_event(event_id, unit, target, 12)) end

  -- boss moves
  if event_id == "slash" then return new_attack_event(event_id, unit, target, 12) end
  if event_id == "strong defend" then return new_defend_event(event_id, unit, 20) end
  if event_id == "dark charge" then return new_dark_charge_event(unit) end
  if event_id == "dark flight" then return new_attack_event(event_id, unit, target, 64) end
  if event_id == "raging strike" then return new_attack_event(event_id, unit, target, 18) end
  if event_id == "ravage" then return new_attack_event(event_id, unit, target, 8) end
  if event_id == "cleave" then return new_attack_event(event_id, unit, target, 0) end

  -- unknown event id
  return new_event("story", "you use "..event_id.."... but nothing happens.")
end

function get_event_desc(event_id)
  local descriptions = {
    spark = "causes enemy to miss attacks",
    fireball = "ignores blocking defense",
    heal = "heals hp and stops bleeding"
  }

  if descriptions[event_id] ~= nil then
    return descriptions[event_id]
  else
    return "unknown description"
  end
end

-->8
--scenes

function new_combat_scene()

  local scene = {}

  scene.init = function(this)
    sequence = new_sequence()
    state = new_game_state()
    combat_menu = new_menu({"attack", "defend", "magic", "items"}, 2)
    magic_menu = new_menu({"fireball", "spark", "heal"}, 1, "menu", true)
    state:start_turn(true)
    return this
  end

  scene.draw = function(this)
    cls(5)
    draw_narrator_box()
    draw_units()

    -- show the current event.
    if event.type == "menu" then
      combat_menu:draw()
    elseif event.type == "magic" then
      magic_menu:draw()
      draw_caret("back 🅾️")
    elseif event.type == "items" then
      items_menu:draw()
      draw_caret("back 🅾️")
    else
      print_wrapped(event.desc, narrator_padding, narrator_box_y + narrator_padding)
      draw_caret()
    end
  end

  scene.update = function(this)
    event = sequence.head

    -- execute this event's action.
    if event.executable then
      event:action()
      event.executable = false
    end

    -- update the menu if we are showing one.
    if event.type == "menu" then combat_menu:update() end
    if event.type == "magic" then magic_menu:update() end
    if event.type == "items" then items_menu:update() end

    -- each time we press x, the sequence progresses.
    if btnp(5) or event.type == "auto" then sequence:next() end
  end

  return scene
end

function new_victory_scene()
  local scene = {}

  scene.init = function(this)
    return this
  end

  scene.draw = function(this)
    cls(0)
    print("you have defeated the wolf!", 5, 5, 7)
  end

  scene.update = function(this)
    -- reset to the combat scene.
    if btnp(5) then global_scene = new_combat_scene():init() end
  end

  return scene
end

-->8
-- animation
function new_animation(loop_length)
  local animation = {
    name = "default",
    n = 0,
    loop_length = loop_length,
    frames_left = 15,
    is_visible = true,
    x = 0,
    y = 0,
    color = 0,
  }
  
  animation.update = function(this, unit_x, unit_y)
    this.n += 1
    this.frames_left -= 1
    this:render(unit_x, unit_y)
  end

  animation.has_ended = function(this)
    return this.frames_left <= 0
  end

  animation.loop_frame = function(this, n)
    return this.n % this.loop_length == n
  end

  animation.render = function(this, unit_x, unit_y)
  end

  return animation
end

function new_hit_animation()
  local animation = new_animation(5)
  animation.render = function(this)
    this.color = 0
    if this:loop_frame(0) then this.color = 7 end
    if this:loop_frame(1) then this.color = 14 end
    if this:loop_frame(2) then this.color = 8 end

    this.x = sin(this.n/3.15) * 2
  end
  return animation
end

function new_heal_animation()
  local animation = new_animation(5)
  animation.render = function(this)
    this.color = 0
    if this:loop_frame(0) then this.color = 7 end
    if this:loop_frame(1) then this.color = 11 end
    if this:loop_frame(2) then this.color = 3 end
  end
  return animation
end

-->8
-- visual effects
function get_vfx_for_action(name)
  if name == "slash" then return new_slash_animation() end
  if name == "dark flight" then return new_blue_slash_animation() end
  if name == "ravage" then return new_slash_animation() end
  if name == "spark" then return new_spark_animation() end
  if name == "fireball" then return new_fire_attack_animation() end
  if name == "defend" then return new_shield_animation() end
  if name == "strong defend" then return new_shield_animation() end
  if name == "block" then return new_shield_animation() end

  return new_generic_attack_animation()
end

function new_shield_animation()
  local animation = new_animation(2)
  animation.render = function(this, unit_x, unit_y)

    if this:loop_frame(0) then 
      pal(7, 12) 
      pal(12, 7)
    end

    -- center the x and y because unit is bigger than vfx
    -- if not this:loop_frame(2) then
      local unit_offset = 4
      local start_x = unit_x + unit_offset
      local start_y = unit_y + unit_offset
      spr(128, start_x, start_y, 4, 4)
    -- end

  end
  return animation
end

function new_slash_animation()
  local animation = new_animation(3)
  animation.render = function(this, unit_x, unit_y)

    if this:loop_frame(0) then pal(9, 14) end

    -- center the x and y because unit is bigger than vfx
    if not this:loop_frame(2) then
      local unit_offset = 4
      local start_x = unit_x + unit_offset
      local start_y = unit_y + unit_offset
      spr(6, start_x, start_y, 4, 4)
    end

  end
  return animation
end

function new_blue_slash_animation()
  local animation = new_animation(3)
  animation.render = function(this, unit_x, unit_y)

    pal(10, 7)
    pal(9, 12)
    pal(8, 1)

    if this:loop_frame(0) then pal(9, 7) end

    -- center the x and y because unit is bigger than vfx
    if not this:loop_frame(2) then
      local unit_offset = 4
      local start_x = unit_x + unit_offset
      local start_y = unit_y + unit_offset
      spr(6, start_x, start_y, 4, 4)
    end

  end
  return animation
end

function new_fire_attack_animation()
  local animation = new_animation(4)
  animation.frames_left = 16
  animation.render = function(this, unit_x, unit_y)

    if this:loop_frame(1) then pal(7, 10) end
    if this:loop_frame(2) then pal(9, 7) end

    -- center the x and y because unit is bigger than vfx
    if not this:loop_frame(3) then
      local unit_offset = 4
      local start_x = unit_x + unit_offset
      local start_y = unit_y + unit_offset
      spr(75, start_x, start_y, 4, 4)
    end

  end
  return animation
end

function new_spark_animation()
  local animation = new_animation(3)
  animation.frames_left = 9
  animation.render = function(this, unit_x, unit_y)

    if this:loop_frame(1) then pal(9, 7) end

    -- center the x and y because unit is bigger than vfx
    if not this:loop_frame(2) then
      local unit_offset = 4
      local start_x = unit_x + unit_offset
      local start_y = unit_y + unit_offset
      spr(10, start_x, start_y, 4, 4)
    end

  end
  return animation
end

function new_generic_attack_animation()
  local animation = new_animation(3)
  animation.frames_left = 6
  animation.render = function(this, unit_x, unit_y)

    if this:loop_frame(1) then pal(7, 10) end

    -- center the x and y because unit is bigger than vfx
    if not this:loop_frame(2) then
      local unit_offset = 4
      local start_x = unit_x + unit_offset
      local start_y = unit_y + unit_offset
      spr(75, start_x, start_y, 4, 4)
    end

  end
  return animation
end

-->8
--rendering

function draw_caret(caret_text)
 if (flip_count(15)) then
  if not caret_text then caret_text = "press ❎" end
  caret_x = 128 - narrator_padding - #caret_text * 4
  caret_y = 128 - narrator_padding - 6
  print(caret_text, caret_x, caret_y, 7)
 end
end

function draw_narrator_box()
 -- create a background for the narrator's box.
 rectfill(0, narrator_box_y, 128, 128, 1)
end

function draw_hp_bar(unit, x, y, width)
  local height = 1

  -- draw bar base
  rectfill(x, y, x + width, y + height, 0)

  -- draw hp bar
  if unit.hp > 0 then
    local life_percent = unit.hp / unit.max_hp
    local life_width = ceil(width * life_percent)
    local life_color = 11

    if life_percent < 0.5 then life_color = 9 end
    if life_percent < 0.2 then life_color = 8 end

    rectfill(x, y, x + life_width, y + height, life_color)
  end
end

function draw_status_box(unit, spr_x, is_inverted)
  local box_pad = 4
  local side_pad = 2
  local status_box_width = 72
  local status_box_height = 24
  local pos_x = 128 - status_box_width - side_pad
  local pos_y = narrator_box_y - status_box_height - side_pad - 1

  if is_inverted then
    pos_x = side_pad
    pos_y = side_pad
  end

  rect(pos_x, pos_y, pos_x + status_box_width, pos_y + status_box_height, 7)

  local x_cursor = pos_x + box_pad
  local y_cursor = pos_y + box_pad

  print(unit.name, x_cursor, y_cursor, 7)

  local hp_str = ""..unit.hp.." hp"
  local hp_x = pos_x + status_box_width - box_pad - (#hp_str * 4) + 1
  print(hp_str, hp_x, y_cursor, 7)

  y_cursor += 8
  draw_hp_bar(unit, x_cursor, y_cursor, status_box_width - box_pad * 2)

  y_cursor += 4
  local mana_str = unit.mana.." mp"
  local mana_x = pos_x + status_box_width - box_pad - (#mana_str * 4) + 1
  print(mana_str, mana_x, y_cursor, 12)

  -- print("hp: "..unit.hp, pos_x, pos_y + 7, 11)
  -- print("mp: "..unit.mana, pos_x, pos_y + 7 * 2, 12)
end

function draw_unit(unit, is_inverted)

  local spr_blocks = 5
  local spr_size = spr_blocks * 8

  palt(0, false)
  palt(7, true)
  is_visible = true
  
  if is_inverted then
    spr_x = 128 - spr_size
    spr_y = 0
    status_x = spr_x
  else
    spr_x = 0
    spr_y = narrator_box_y - spr_size
    status_x = spr_size
  end

  anim_spr_x = spr_x
  anim_spr_y = spr_y

  -- apply unit animation
  if unit.animation then
    unit.animation:update()
    is_visible = unit.animation.is_visible
    pal(0, unit.animation.color)
    anim_spr_x = spr_x + unit.animation.x
    anim_spr_y = spr_y + unit.animation.y
    if unit.animation:has_ended() then unit.animation = nil end
  end

  -- draw the unit and reset the palettes
  if is_visible then spr(1, anim_spr_x, anim_spr_y, spr_blocks, spr_blocks) end -- draw player sprite
  pal() -- reset palette

  -- draw the vfx on top of the unit
  if unit.vfx_animation then
    unit.vfx_animation:update(spr_x, spr_y)
    if unit.vfx_animation:has_ended() then unit.vfx_animation = nil end
  end
  pal()

  -- draw hp mana and name
  draw_status_box(unit, status_x, is_inverted)
end

function draw_units()
  -- draw player unit
  draw_unit(state.player, false)
  draw_unit(state.enemy, true)
end

-->8
-- game loop

function _init()
  -- initialize scenes
  global_scene = new_combat_scene():init()
end

function _update()
  f_count += 1
  global_scene:update()
end

function _draw()
  global_scene:draw()
end

__gfx__
00000000999999999999999999999999999999999999999900000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000977777777777777777777777777777770000000900000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700977700000000007777777777777777770000000900000000000000000000000000000800000000000000000090000000000000000000000000000000
00077000977700000000007777777777777777770000000900000000000000000000000000088000000000000000000090000000000000000000000000000000
00077000977700000000007777777777777777770000000900000000000000000000000000888000000000000000000900000000000000000000000000000000
00700700977700000000007777777777777777770000000900000000000000800000000009880000000000000000000000000000000000000000000000000000
00000000977700000000007777777777777777770000000900000000000088000000000089900000000000000000000090000000000000000000000000000000
00000000900000000000000000777777777777770000000900000000000098000000000988000000000000000000000990000000000000000000000000000000
00000000900000000000000000777777777777770000000900000000089a00000000008990000000000000000000000990000000000000000000000000000000
00000000977700000000007777777777777777770000000900000000887900000000099800000000000000000000000990000000000000000000000000000000
000000009777000000000077777777777777777700000009000000009a88000000088a9000000000000000000000000990000000000000000000000000000000
00000000970000000000000077777777777777770000000900000000a980000009999800000000000000000000000099a9000000000000000000000000000000
0000000097000000000000007770000000770077000000090000008900000000899a980000000000000000000000990aa0990000000000000000000000000000
000000009700000000000000777000000077007700000009000000880000008999a9900000000000000000000000900a70099000000000000000000000000000
0000000097000000000000007777777777007777000000090000080000000889a79990000000000000000000000a00777a00a000000000000000000000000000
00000000970000000000000077777777770077770000000900000000000009977a98000000000000000909a09a0aa77777777a00a09909000000000000000000
00000000900000000000000000007777007700770000000900080000000089a77990000000000000000000009a99a7777777aa0a000000000000000000000000
000000009000000000000000000077770077007700000009000000000009997a988000000000080000000000000900a77a009000000000000000000000000000
0000000090000000000000000000770000770077000000090000000000099a999800000000000000000000000000900770090000000000000000000000000000
000000009000000000000000000077000077007700000009000000000089a9980000000000080000000000000000990aa0990000000000000000000000000000
00000000900000000000000000000000007700770000000900000000008999900000000008800000000000000000009aa9000000000000000000000000000000
0000000090000000000000000000000000770077000000090000000009a880000000000009800000000000000000000a00000000000000000000000000000000
000000009000000000000000000077000077777700000009000000008990000000000089a00000000000000000000009a0000000000000000000000000000000
00000000900000000000000000007700007777770000000900000009880000000000088790000000000000000000000aa0000000000000000000000000000000
0000000090000000000000000000770000777777000000090000008990000000000009a880000000000000000000000090000000000000000000000000000000
000000009000000000000000000077000077777700000009000009880000000000000a9800000000000000000000000090000000000000000000000000000000
00000000900000000000000000000000007777770000000900008990000000000008900000000000000000000000000000000000000000000000000000000000
00000000900000000000000000000000007777770000000900088800000000000008800000000000000000000000000090000000000000000000000000000000
00000000900000000000000000000000007777770000000900088000000000000080000000000000000000000000000000000000000000000000000000000000
00000000900000000000000000000000007777770000000900800000000000000000000000000000000000000000000090000000000000000000000000000000
00000000900000000000000000000000007777770000000900000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000900000000000000000000000007777770000000900000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000900000000000000000000000000000000000000900000000000c0000000c0000001c7c0000100c000000000000000000800000000000000000000000
00000000900000000000000000000000000000000000000900000000000c0000000c100001000010000000000000000000000000000000000000000000000000
000000009000000000000000000000000000000000000009000000000007000000c77c00c0000001c00000010000000000000008000000000000000000000000
000000009000000000000000000000000000000000000009000cc000000777cc017007cc7000000c000000000000000000000008000000000000000000000000
000000009000000000000000000000000000000000000009000cc000cc777000cc700710c0000007000000000000000000000008900000000008000000000000
000000009000000000000000000000000000000000000009000000000000700000c77c001000000c1000000c0000080008000009900000000000000000000000
000000009000000000000000000000000000000000000009000000000000c0000001c00001000010000000000000008800000099900000000808000000000000
000000009999999999999999999999999999999999999999000000000000c0000000c00000c7c10000c00100000000889080009aa98000008000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000098988999a799000088900000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000009999aa9aaa9899880000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000099aaaa77aaaaa990000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000009a77a7777aa7a998000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000889aa777777777a999000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000089aa777777777aa990000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000009aa7777777777aa90000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000088999aa777777777777a9998000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008888889a7777777777777aa9988880000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000999a7777777777aa90000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008099aa77777777aa990000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008a77777777aaa900000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008a7a77777aaa9800000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000009aaaaa77aa9a9800000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000998a99a7aa9998080000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000009990009a7999000009000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000880000099a00000000880000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008800000099909000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000080000000009800000000080000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008800000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008000000000000800000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000800000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000c000000000000c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000cccc00000000cccc00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000cc7ccc0000ccc7cc00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000c7777cccccc7777c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000c70077777777007c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000c70000000000007c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000c70000000000007c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000c70000000000007c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000c70000000000007c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000c70000000000007c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000c70000000000007c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000c77000000000077c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000cc700000000007cc00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000c700000000007c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000c700000000007c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000c700000000007c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000cc7000000007cc000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000cc70000007cc0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000cc777777cc00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000cccccccc000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000100003245032450324503245032450324503245032450324503245032450324503245022450224502245022450224502245022450224502245022450224502245022450224502245022450224502245022450
