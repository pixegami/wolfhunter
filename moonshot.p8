pico-8 cartridge // http://www.pico-8.com
version 29
__lua__

narrator_box_size = 48
narrator_padding = 8
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
  local player_items = {"crossbow", "elixir", "silver knife"}
  local player = new_unit("player", 100, player_events, player_items)

  -- create enemy unit
  local enemy = new_unit("werewolf", 400, {"slash", "dark charge", "strong defend", "raging strike", "ravage", "cleave"})

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

function print_wrapped(text, x, y, color)
 line_arr = split(text," ")
 cursor(x, y, 7)
 line = ""
 
 for word in all(line_arr) do
  word_str = tostring(word) -- case to string or it fails on numbers
  prospect_length = (#line + #word_str + 1) * 4
  if (prospect_length >= col_width) do
   print(line, x, y, color)
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
 print(line, x, y, color)
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
    rectfill(0, box_y, 128, narrator_box_y-gap, 0)

    local text_gap = 4
    local desc = get_event_desc(this.items[this.selected_index])
    local origin_x = text_gap
    local origin_y = box_y + text_gap
    print_wrapped(desc, origin_x, origin_y, 7)
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
    sfx(1)
    unit.vfx_animation = new_heal_vfx_animation("green")

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
  
    unit.vfx_animation = new_heal_vfx_animation()

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
    unit:animate(new_mana_animation())
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

    -- resolve crossbow
    if name == "crossbow" then 
      head_event:chain_add(new_info_event("a quarter of "..target.name.."'s life is dealt as damage."))
      damage = ceil(target.hp * 0.25)
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

    -- resolve wolf immunity
    if target.name == "werewolf" and damage > target.hp and name ~= "silver knife" then
      damage = min(target.hp - 1, damage)
      if damage == 0 then
        local immune_event = new_info_event(target.name.." cannot be killed by "..name.."!", true)
        immune_event.action = function(this) target.vfx_animation = new_shield_animation() end
        head_event:chain_add(immune_event)
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

  local desc = unit.name.." takes "..value.." damage!"
  local dmg_event = new_event("damage", desc, true)
  dmg_event.action = function(this)
    unit.hp -= value
    unit:animate(new_hit_animation())
    if unit.hp <= 0 then
      unit.hp = 0
      sequence:insert(new_end_combat_event(unit.name))
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

function new_end_combat_event(unit_name) -- who was defeated?
  local event = new_event("end_combat", "", true)
  event.action = function(this)
    if unit_name == "werewolf" then
      global_scene = new_victory_scene():init()
    else
      global_scene = new_gameover_scene():init()
    end
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
  if event_id == "elixir" then return as_item(event_id, unit, new_mana_event(event_id, unit, 5)) end
  if event_id == "crossbow" then return as_item(event_id, unit, new_attack_event(event_id, unit, target, 0)) end
  if event_id == "silver knife" then return as_item(event_id, unit, new_attack_event(event_id, unit, target, 5)) end

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
    spark = "causes enemy to miss",
    fireball = "ignores blocking defense",
    heal = "heals hp and stops bleeding",
    elixir = "recovers 5 mana",
    crossbow = "damages 25% hp",
  }

  descriptions["silver knife"] = "deal 5 fatal damage"

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
    cls(0)

    -- if we don't have an 'event' we can't draw anything.
    if not event then return end

    -- draw background
    map(0, 0, 0, 0)

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
      print_wrapped(event.desc, narrator_padding, narrator_box_y + narrator_padding, 7)
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

function print_x_centered(text, y, color)
  local x = (128 - #text * 4) / 2
  print(text, x, y, color)
end

function new_victory_scene()
  local scene = {}

  scene.init = function(this)
    return this
  end

  scene.draw = function(this)
    cls(0)
    print_x_centered("victory", 60, 11)
    print_x_centered("you have defeated the monster!", 68, 7)
  end

  scene.update = function(this)
    -- reset to the combat scene.
    if btnp(5) then global_scene = new_splash_scene():init() end
  end

  return scene
end

function new_gameover_scene()
  local scene = {}

  scene.init = function(this)
    return this
  end

  scene.draw = function(this)
    cls(0)
    print_x_centered("gameover", 60, 8)
    print_x_centered("you have lost!", 68, 7)
  end

  scene.update = function(this)
    -- reset to the combat scene.
    if btnp(5) then global_scene = new_splash_scene():init() end
  end

  return scene
end

function new_splash_scene()
  local scene = {}

  scene.init = function(this)
    return this
  end

  scene.draw = function(this)
    cls(0)
    print_x_centered("wolf hunter", 60, 8)
    print_x_centered("press ❎ to start", 68, 7)
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

function new_mana_animation()
  local animation = new_animation(5)
  animation.render = function(this)
    this.color = 0
    if this:loop_frame(0) then this.color = 7 end
    if this:loop_frame(1) then this.color = 12 end
    if this:loop_frame(2) then this.color = 1 end
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
  if name == "silver knife" then return new_blue_slash_animation() end

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

function new_particle(x, y)
  local particle = {
    x=x,
    y=y,
    f=0,
  }
  return particle
end

function new_heal_vfx_animation(color_override)

  local animation = new_animation(3)
  animation.frames_left = 30
  animation.particles = {}
  animation.color_override = color_override

  animation.render = function(this, unit_x, unit_y)

    local loop_frame_n = this.n % this.loop_length
    local dead_list = {}
    local particle_life = 4

    local anchor_x = unit_x + 16
    local anchor_y = unit_y + 16

    if this.frames_left > particle_life * 2 then
      -- add a new particle
      local t_factor = this.n/1.8
      local circle_factor = sin(t_factor)
      local radius_factor = 5 + this.n / 2
      local spawn_x = sin(t_factor) * radius_factor
      local spawn_y = cos(t_factor) * radius_factor
      add(this.particles, new_particle(spawn_x, spawn_y))
    end

    if this.color_override == "green" then
      pal(1, 3)
      pal(12, 11)
    end

    for p in all(this.particles) do
      px = anchor_x + p.x
      py = anchor_y + p.y
      spr_i = 70 + p.f % particle_life
      spr(spr_i, px, py)

      p.f += 1
      if p.f == particle_life * 2 then
        add(dead_list, p)
      end
    end

    for p in all(dead_list) do
        del(this.particles, p)
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
  caret_x = 128 - narrator_padding - #caret_text * 4 - 3
  caret_y = 128 - narrator_padding - 6
  print(caret_text, caret_x, caret_y, 7)
 end
end

function draw_narrator_box()
 -- create a background for the narrator's box.
 rectfill(0, narrator_box_y, 128, 128, 0)

 local border_pad = 1
 rect(border_pad, narrator_box_y + border_pad, 127 - border_pad, 127 - border_pad, 7)
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

  local text_color = 7

  -- rectfill(pos_x, pos_y, pos_x + status_box_width, pos_y + status_box_height, 1)
  -- rect(pos_x, pos_y, pos_x + status_box_width, pos_y + status_box_height, 1)

  local x_cursor = pos_x + box_pad
  local y_cursor = pos_y + box_pad

  print(unit.name, x_cursor, y_cursor, text_color)

  local hp_str = ""..unit.hp.." hp"
  local hp_x = pos_x + status_box_width - box_pad - (#hp_str * 4) + 1
  print(hp_str, hp_x, y_cursor, text_color)

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
  palt(12, true)
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
    unit.animation:update(spr_x, spr_y)
    is_visible = unit.animation.is_visible
    pal(0, unit.animation.color)
    anim_spr_x = spr_x + unit.animation.x
    anim_spr_y = spr_y + unit.animation.y
    if unit.animation:has_ended() then unit.animation = nil end
  end

  -- draw the unit and reset the palettes
  local spr_id = 1
  if unit.name == "werewolf" then spr_id = 132 end
  if is_visible then spr(spr_id, anim_spr_x, anim_spr_y, spr_blocks, spr_blocks) end -- draw player sprite
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
  global_scene = new_splash_scene():init()
end

function _update()
  f_count += 1
  global_scene:update()
end

function _draw()
  global_scene:draw()
end

__gfx__
00000000cccccccccccccccccccccccccccccccccccccccc00000000000000000000000000000000000000000000000000000000000000001111111100010000
00000000cccccccccccccccccccccccccccccccccccccccc00000000000000000000000000000000000000000000000000000000000000001111111100000000
00700700cccccccccccccccccccccccccccccccccccccccc00000000000000000000000000000800000000000000000090000000000000001111111101000100
00077000cccccccccccccccccccccccccccccccccccccccc00000000000000000000000000088000000000000000000090000000000000001111111100000000
00077000cccccccccccccccccccccccccccccccccccccccc00000000000000000000000000888000000000000000000900000000000000001111111110101010
00700700cccccccccccccccccccccccccccccccccccccccc00000000000000800000000009880000000000000000000000000000000000001111111101010101
00000000cccccccccccccccccccccccccccccccccccccccc00000000000088000000000089900000000000000000000090000000000000001111111111111111
00000000cccccccccccccccccccccccccccccccccccccccc00000000000098000000000988000000000000000000000990000000000000001111111111101110
00000000cccccccccccccccccccccccccccccccccccccccc00000000089a00000000008990000000000000000000000990000000000000001511151100000000
00000000cccccc00cccc00cccccccccccccccccccccccccc00000000887900000000099800000000000000000000000990000000000000001111111100000000
00000000cccccc0b0cc055000ccccccccccccccccccccccc000000009a88000000088a9000000000000000000000000990000000000000005151515100000000
00000000ccccccc0b005555dd0cccccccccccccccccccccc00000000a980000009999800000000000000000000000099a9000000000000001515151500000000
00000000ccccccc037b00055dd000ccccccccccccccccccc0000008900000000899a980000000000000000000000990aa0990000000000005151515100000000
00000000cccccccc033b330555ddd0cccccccccccccccccc000000880000008999a9900000000000000000000000900a70099000000000005555555500000000
00000000ccccccccc03033700556d0cccccccccccccccccc0000080000000889a79990000000000000000000000a00777a00a000000000005515551500000000
00000000ccc00cc00003003b05056d0ccccccccccccccccc00000000000009977a98000000000000000909a09a0aa77777777a00a09909005555555500000000
00000000cc0dd00d0000000300505d0ccccccccccccccccc00080000000089a77990000000000000000000009a99a7777777aa0a000000005555555555555555
00000000ccc0dd55500000000005dd000ccccccccccccccc000000000009997a988000000000080000000000000900a77a009000000000005555555555155515
00000000cccc00dddd55000000dd00ddd000cccccccccccc0000000000099a999800000000000000000000000000900770090000000000005555555555555555
00000000cccccc0000d5550005555556dddd0ccccccccccc000000000089a9980000000000080000000000000000990aa0990000000000005555555551515151
00000000ccccccccc0000555550000555500cccccccccccc00000000008999900000000008800000000000000000009aa9000000000000005555555515151515
00000000ccccccc0000660000004000000cccccccccccccc0000000009a880000000000009800000000000000000000a00000000000000005555555551515151
00000000ccccccc0880066660004000ccccccccccccccccc000000008990000000000089a00000000000000000000009a0000000000000005555555511111111
00000000cccccccc02880077000f0440cccccccccccccccc00000009880000000000088790000000000000000000000aa0000000000000005555555515111511
00000000ccccccccc022880700404ff0cccccccccccccccc0000008990000000000009a880000000000000000000000090000000000000003333333310111011
00000000ccccccc00022228044ffff0ccccccccccccccccc000009880000000000000a9800000000000000000000000090000000000000003333333311111111
00000000cccccc0dd022227000f000cccccccccccccccccc00008990000000000008900000000000000000000000000000000000000000003333333311101110
00000000ccccc0d5002228280800cccccccccccccccccccc000888000000000000088000000000000000000000000000900000000000000033333b3311111111
00000000cccc0dd050228280820800cccccccccccccccccc000880000000000000800000000000000000000000000000000000000000000033b3b33301010101
00000000cccc0d05020208202227880ccccccccccccccccc0080000000000000000000000000000000000000000000009000000000000000333b333310101010
00000000ccc0d5500020208222228080cc000ccccccccccc00000000000000000000000000000000000000000000000000000000000000003333333300000000
00000000ccc0d500000002002028088800dd70cccccccccc00000000000000000000000000000000000000000000000000000000000000003333333301000100
00000000cc075d00d500000000208888005dd0cccccccccc00000000000c0000000c0000001c7c0000100c000000000000000000800000000000000000000000
00000000cc0d5d00d5000000020028878005d50ccccccccc00000000000c0000000c100001000010000000000000000000000000000000000000000000000000
00000000cc0d50d00d0000010000288880d0550ccccccccc000000000007000000c77c00c0000001c00000010000000000000008000000000000000000000000
00000000cc00555d0050010d1102088880d0050ccccccccc000cc000000777cc017007cc7000000c000000000000000000000008000000000000000000000000
00000000ccc00dd5500000d1d0102088200000cccccccccc000cc000cc777000cc700710c0000007000000000000000000000008900000000008000000000000
00000000cc0d5005d000000d0d000222000ccccccccccccc000000000000700000c77c001000000c1000000c0000080008000009900000000000000000000000
00000000c0d500005d000000d00000000ccccccccccccccc000000000000c0000001c00001000010000000000000008800000099900000000808000000000000
000000000d50000005dd00000000000ccccccccccccccccc000000000000c0000000c00000c7c10000c00100000000889080009aa98000008000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000098988999a799000088900000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000009999aa9aaa9899880000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000099aaaa77aaaaa990000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000009a77a7777aa7a998000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000889aa777777777a999000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000089aa777777777aa990000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000009aa7777777777aa90000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000088999aa777777777777a9998000000000000
000000009a70009800aaa8000a000000a0000980700009000a0009789000099890000098097aa0a8900aaa0008888889a7777777777777aa9988880000000000
0000000088a00a7807808a809870000097aaa88089000898987008a88a0008a8897aaa80a8888980897888980000000999a7777777777aa90000000000000000
000000000a0008a8a800089888a00000898880000a0000a880a000a807a00078088a8800890008000a8000980000008099aa77777777aa990000000000000000
00000000a80000a8900000a80a8000000a00098009a7aa800a800a800a8a00a800090000097a000009aa0a800000000008a77777777aaa900000000000000000
00000000900900a8900000a80a00009809aa9880a8888a00a8000a00a808a09800a80000988800007888a8000000000008a7a77777aaa9800000000000000000
00000000890900988900078098000a80a888800090000a0090000900a0008a800090000090000098a00090a80000000009aaaaa77aa9a9800000000000000000
0000000008989980089998008999780090000000990009a889a7989899009998008a900089aaa9809900899800000000998a99a7aa9998080000000000000000
000000000080880000888000088880008000000088000880088880808800888000088000088888008800088000000009990009a7999000009000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000880000099a00000000880000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008800000099909000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000080000000009800000000080000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008800000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008000000000000800000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000800000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000cccccccccccccccccccccccccccccccccccccccc00000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000cccccccccccccccccccccccccccccccccccccccc00000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000cccccccccccccccccccccccccccccccccccccccc00000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000cccccccccccccccccccccccccccccccccccccccc00000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000cccccccccccccccccccccccccccccccccccccccc00000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000cccccccccccccccccccccccccccccc00cccccccc00000000000000000000000000000000000000000000000000000000
000000000c000000000000c000000000ccccccccccccccccccccc0cccccc00660ccccccc00000000000000000000000000000000000000000000000000000000
00000000cccc00000000cccc00000000ccccc0cccccccccccccc00cccc00066670cccccc00000000000000000000000000000000000000000000000000000000
00000000cc7ccc0000ccc7cc00000000ccccc00ccccccccccccc050cc0766666670ccccc00000000000000000000000000000000000000000000000000000000
00000000c7777cccccc7777c00000000cccccc00ccccccccccc0050c07666665660ccccc00000000000000000000000000000000000000000000000000000000
00000000c70077777777007c00000000ccccc0550ccc000cccc0750c076666566650cccc00000000000000000000000000000000000000000000000000000000
00000000c70000000000007c00000000cccccc0570c06650cc0650c0066765600050cccc00000000000000000000000000000000000000000000000000000000
00000000c70000000000007c00000000ccccc0566006656600660cc07575650cc050cccc00000000000000000000000000000000000000000000000000000000
00000000c70000000000007c00000000cccccc0555666666656550c0775665cccc00cccc00000000000000000000000000000000000000000000000000000000
00000000c70000000000007c00000000ccccccc05566666655550ccc0575660ccccccccc00000000000000000000000000000000000000000000000000000000
00000000c70000000000007c00000000cccccccc0056666506550cccc006560ccccccccc00000000000000000000000000000000000000000000000000000000
00000000c70000000000007c00000000cccccccc070000007655000cc00560cccccccccc00000000000000000000000000000000000000000000000000000000
00000000c77000000000077c00000000ccccccc0568000087665555000650ccccccccccc00000000000000000000000000000000000000000000000000000000
00000000cc700000000007cc00000000cccccccc0667056666665567766500cccccccccc00000000000000000000000000000000000000000000000000000000
000000000c700000000007c000000000ccccccc05660066666555667665500cccccccccc00000000000000000000000000000000000000000000000000000000
000000000c700000000007c000000000cccccccc006666666555667666000ccccccccccc00000000000000000000000000000000000000000000000000000000
000000000c700000000007c000000000cccccccccc570007557666656650cccccccccccc00000000000000000000000000000000000000000000000000000000
000000000cc7000000007cc000000000ccccccccc050777077656555665000cccccccccc00000000000000000000000000000000000000000000000000000000
0000000000cc70000007cc0000000000ccccccccc0577777765605066666650ccccccccc00000000000000000000000000000000000000000000000000000000
00000000000cc777777cc00000000000ccccccccc055767766605055656650000ccccccc00000000000000000000000000000000000000000000000000000000
000000000000cccccccc000000000000cccccccccc0566676655000556650000000ccccc00000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000cccccccccc056565656000005665000000cccccc00000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000cccccccc0055555566500006660000000ccccccc00000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000ccccccc0005550556655000766000000cccccccc00000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000cccccc0006550005666500000000000ccccccccc00000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000ccccccc000000000666000000000cccccccccccc00000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000cccccccc0000000075600000cccccccccccccccc00000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000cccccccccc00000000000ccccccccccccccccccc00000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000cccccccccccc00000000cccccccccccccccccccc00000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000cccccccccccccccccccccccccccccccccccccccc00000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000cccccccccccccccccccccccccccccccccccccccc00000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000cccccccccccccccccccccccccccccccccccccccc00000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000cccccccccccccccccccccccccccccccccccccccc00000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000cccccccccccccccccccccccccccccccccccccccc00000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000cccccccccccccccccccccccccccccccccccccccc00000000000000000000000000000000000000000000000000000000
__label__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000070700770700077700000000000000000000000000707077707770000070707770000000000000000000000000000000000000000000000006600000000
00000070707070700070000000000000000000000000000707070707070000070707070000000000000000000000000000000000000000000000066670000000
00000070707070700077000000000000000000000000000777070707070000077707770000000000000000000000000000000000000005000076666667000000
00000077707070700070000000000000000000000000000007070707070000070707000000000000000000000000000000000000000005000766666566000000
00000077707700777070000000000000000000000000000007077707770000070707000000000000000000000000005500000000000075000766665666500000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000570006650000650000667656000500000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005660066566006600007575650000500000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000555666666656550007756650000000000
000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb000000000000000000000000055666666555500000575660000000000
000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb000000000000000000000000000566665065500000006560000000000
00010000000100000001000000010000000100000001000000010000000100000001000000010000000100000001000007000000765500000005600000010000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000056800008766555500065000000000000
0100010001000100010001000100010001000100010001000100010ccc00010ccc0ccc0001000100010001000100010006670566666655677665000001000100
0000000000000000000000000000000000000000000000000000000c0000000ccc0c0c0000000000000000000000000056600666665556676655000000000000
1010101010101010101010101010101010101010101010101010101ccc10101c1c1ccc1010101010101010101010101000666666655566766600001010101010
010101010101010101010101010101010101010101010101010101010c01010c0c0c010101010101010101010101010101570007557666656650010101010101
1111111111111111111111111111111111111111111111111111111ccc11111c1c1c111111111111111111111111111110507770776565556650001111111111
11101110111011101110111011101110111011101110111011101110111011101110111011101110111011101110111010577777765605066666650011101110
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111110557677666050556566500001111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111056667665500055665000000011111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111056565656000005665000000111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111100555555665000066600000001111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111000555055665500076600000011111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111110006550005666500000000000111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111000000000666000000000111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111100000000756000001111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111000000000001111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111110000000011111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111100111100111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1111110b011055000111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111110b005555dd011111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1111111037b00055dd00011111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111033b330555ddd01111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111103033700556d01111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
111001100003003b05056d0111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
110dd00d0000000300505d0111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1110dd55500000000005dd0001111111111111111111111111111111117771711177717171777177711111111111111111177117771777111117171777111111
111100dddd55000000dd00ddd0001111111111111111111111111111117171711171717171711171711111111111111111117117171717111117171717111111
1111110000d5550005555556dddd0111111111111111111111111111117771711177717771771177111111111111111111117117171717111117771777111111
11111111100005555500005555001111111111111111111111111111117111711171711171711171711111111111111111117117171717111117171711111111
11111110000660000004000000111111111111111111111111111111117111777171717771777171711111111111111111177717771777111117171711111111
11111110880066660004000111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1111111102880077000f044011111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
111111111022880700404ff011111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
111111100022228044ffff011111111111111111111111111111111111bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb11111
1111110dd022227000f000111111111111111111111111111111111111bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb11111
111110d5002228280800111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11110dd0502282808208001111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11110d05020208202227880111111111111111111111111111111111111111111111111111111111111111111111111111111111111ccc11111ccc1ccc111111
1110d550002020822222808011000111111111111111111111111111111111111111111111111111111111111111111111111111111c1111111ccc1c1c111111
1110d500000002002028088800dd7011111111111111111111111111111111111111111111111111111111111111111111111111111ccc11111c1c1ccc111111
10075d00d500000000208888005dd01110111011101110111011101110111011101110111011101110111011101110111011101110111c11101c1c1c10111011
110d5d00d5000000020028878005d501111111111111111111111111111111111111111111111111111111111111111111111111111ccc11111c1c1c11111111
110d50d00d0000010000288880d05500111011101110111011101110111011101110111011101110111011101110111011101110111011101110111011101110
1100555d0050010d1102088880d00501111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
01000dd5500000d1d010208820000001010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101
100d5005d000000d0d00022200001010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
00d500005d000000d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0d50000005dd00000000000001000100010001000100010001000100010001000100010001000100010001000100010001000100010001000100010001000100
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777770
07000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000070
07000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000070
07000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000070
07000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000070
07000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000070
07000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000070
07000000777077700700077000007070077070707770000077707070777077000000777007700000777007707070777007000000000000000000000000000070
07000000070007007000700000007070707070707070000007007070707070700000070070700000777070707070700007000000000000000000000000000070
07000000070007000000777000007770707070707700000007007070770070700000070070700000707070707070770007000000000000000000000000000070
07000000070007000000007000000070707070707070000007007070707070700000070070700000707070707770700000000000000000000000000000000070
07000000777007000000770000007770770007707070000007000770707070700000070077000000707077000700777007000000000000000000000000000070
07000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000070
07000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000070
07000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000070
07000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000070
07000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000070
07000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000070
07000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000070
07000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000070
07000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000070
07000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000070
07000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000070
07000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000070
07000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000070
07000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000070
07000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000070
07000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000070
07000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000070
07000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000070
07000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000070
07000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000070
07000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000070
07000000000000000000000000000000000000000000000000000000000000000000000000000000000000000777077707770077007700000077777000000070
07000000000000000000000000000000000000000000000000000000000000000000000000000000000000000707070707000700070000000770707700000070
07000000000000000000000000000000000000000000000000000000000000000000000000000000000000000777077007700777077700000777077700000070
07000000000000000000000000000000000000000000000000000000000000000000000000000000000000000700070707000007000700000770707700000070
07000000000000000000000000000000000000000000000000000000000000000000000000000000000000000700070707770770077000000077777000000070
07000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000070
07000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000070
07000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000070
07000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000070
07000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000070
07000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000070
07000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000070
07777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777770
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

__map__
1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f1f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000100003245032450324503245032450324503245032450324503245032450324503245022450224502245022450224502245022450224502245022450224502245022450224502245022450224502245022450
000201012905029050290501505014050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00100000225551c555185551555516555175551a5551d5551c5551b5551a555165550b55508555075550652506525000050000500005000050000500005000050000500005000050000500005000050000500005
