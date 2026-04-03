local function assert_equal(actual, expected, message)
    if actual ~= expected then
        error((message or "assert_equal failed") .. string.format(" (expected=%s, actual=%s)", tostring(expected), tostring(actual)))
    end
end

local function assert_true(value, message)
    if not value then
        error(message or "assert_true failed")
    end
end

local unpack_values = table.unpack or unpack

local function make_unit(opts)
    if not opts then
        return nil
    end

    return {
        exists = opts.exists ~= false,
        guid = opts.guid,
        name = opts.name,
        can_attack = opts.can_attack or false,
        dead = opts.dead or false,
    }
end

local function copy_bindings(bindings)
    local result = {}

    for command, keys in pairs(bindings or {}) do
        result[command] = {}
        for index, key in ipairs(keys) do
            result[command][index] = key
        end
    end

    return result
end

local function remove_key_from_bindings(bindings, key)
    for command, keys in pairs(bindings) do
        for index = #keys, 1, -1 do
            if keys[index] == key then
                table.remove(keys, index)
            end
        end

        if #keys == 0 then
            bindings[command] = nil
        end
    end
end

local function setup_env(opts)
    opts = opts or {}

    local state = {
        bindings = copy_bindings(opts.bindings),
        frames = {},
        named_frames = {},
        chat = {},
        in_combat = opts.in_combat or false,
        time = opts.time or 100,
        pet_attack_calls = 0,
        pet_follow_calls = 0,
        pet_attack_active = opts.pet_attack_active or false,
        pet_in_combat = opts.pet_in_combat or false,
        auto_update_pet_state_on_attack = opts.auto_update_pet_state_on_attack ~= false,
        units = {
            player = make_unit({ guid = "Player-1", name = "Player", exists = true }),
            pet = make_unit(opts.pet or { guid = "Pet-1", name = "Pet", exists = true }),
            target = make_unit(opts.target),
        },
        pettarget_guid = opts.pettarget_guid,
        set_binding_click_calls = {},
        saved_bindings_calls = {},
        current_binding_set = opts.current_binding_set or 1,
    }

    _G.OneButtonPet = nil
    _G.OneButtonPet_ToggleBinding = nil
    _G.BINDING_HEADER_ONEBUTTONPET = nil
    _G.BINDING_NAME_ONEBUTTONPET_TOGGLE = nil
    _G["BINDING_NAME_CLICK OneButtonPetSecureToggleButton:LeftButton"] = nil
    _G.SLASH_PETTOGGLE1 = nil
    _G.SLASH_PETTOGGLE2 = nil
    _G.SLASH_PETTOGGLE3 = nil
    _G.OneButtonPetDB = opts.saved_variables
    _G.UIParent = {}

    _G.DEFAULT_CHAT_FRAME = {
        AddMessage = function(_, message)
            state.chat[#state.chat + 1] = message
        end,
    }

    local function new_frame(frame_type, name, parent, template)
        local frame = {
            attributes = {},
            events = {},
            frame_type = frame_type,
            mouse_enabled = false,
            name = name,
            parent = parent,
            registered_clicks = {},
            scripts = {},
            template = template,
            wrapped_scripts = {},
        }

        function frame:RegisterEvent(event)
            self.events[event] = true
        end

        function frame:RegisterForClicks(...)
            self.registered_clicks = { ... }
        end

        function frame:SetScript(script_name, fn)
            self.scripts[script_name] = fn
        end

        function frame:EnableMouse(enabled)
            self.mouse_enabled = enabled ~= false
        end

        function frame:SetAttribute(attribute_name, value)
            self.attributes[attribute_name] = value
        end

        function frame:GetAttribute(attribute_name)
            return self.attributes[attribute_name]
        end

        function frame:WrapScript(target, script_name, pre_body, post_body)
            self.wrapped_scripts[#self.wrapped_scripts + 1] = {
                target = target,
                script_name = script_name,
                pre_body = pre_body,
                post_body = post_body,
            }
        end

        state.frames[#state.frames + 1] = frame
        if name ~= nil then
            state.named_frames[name] = frame
        end
        return frame
    end

    _G.CreateFrame = function(frame_type, name, parent, template)
        return new_frame(frame_type, name, parent, template)
    end

    _G.SlashCmdList = {}
    _G.NUM_PET_ACTION_SLOTS = 10

    _G.GetTime = function()
        return state.time
    end

    _G.InCombatLockdown = function()
        return state.in_combat
    end

    _G.PlayerCanAttack = function(unit)
        local info = state.units[unit]
        return info and info.can_attack or false
    end

    _G.UnitExists = function(unit)
        if unit == "pettarget" then
            return state.pettarget_guid ~= nil
        end

        local info = state.units[unit]
        return info ~= nil and info.exists ~= false
    end

    _G.UnitGUID = function(unit)
        if unit == "pettarget" then
            return state.pettarget_guid
        end

        local info = state.units[unit]
        return info and info.guid or nil
    end

    _G.UnitName = function(unit)
        if unit == "pettarget" then
            return state.pettarget_guid and "PetTarget" or nil
        end

        local info = state.units[unit]
        return info and info.name or nil
    end

    _G.UnitCanAttack = function(_, unit)
        local info = state.units[unit]
        return info and info.can_attack or false
    end

    _G.UnitIsDead = function(unit)
        local info = state.units[unit]
        return info and info.dead or false
    end

    _G.UnitIsDeadOrGhost = _G.UnitIsDead

    _G.UnitIsUnit = function(unit_a, unit_b)
        local guid_a = _G.UnitGUID(unit_a)
        local guid_b = _G.UnitGUID(unit_b)
        return guid_a ~= nil and guid_a == guid_b
    end

    _G.UnitAffectingCombat = function(unit)
        if unit == "pet" then
            return state.pet_in_combat
        end
        return false
    end

    _G.IsPetAttackAction = function(slot)
        return slot == 1
    end

    _G.GetPetActionInfo = function(slot)
        if slot ~= 1 then
            return nil
        end

        return "Attack", nil, nil, false, state.pet_attack_active
    end

    _G.PetAttack = function()
        state.pet_attack_calls = state.pet_attack_calls + 1
        if state.auto_update_pet_state_on_attack then
            state.pet_attack_active = true
            state.pet_in_combat = true
            state.pettarget_guid = state.units.target and state.units.target.guid or nil
        end
    end

    _G.PetFollow = function()
        state.pet_follow_calls = state.pet_follow_calls + 1
        state.pet_attack_active = false
        state.pet_in_combat = false
        state.pettarget_guid = nil
    end

    _G.GetBindingKey = function(command)
        local keys = state.bindings[command]
        if keys == nil then
            return nil
        end

        return unpack_values(keys)
    end

    _G.SetBindingClick = function(key, button_name, mouse_button)
        local command = "CLICK " .. button_name .. ":" .. (mouse_button or "LeftButton")
        remove_key_from_bindings(state.bindings, key)
        state.bindings[command] = state.bindings[command] or {}
        state.bindings[command][#state.bindings[command] + 1] = key
        state.set_binding_click_calls[#state.set_binding_click_calls + 1] = {
            key = key,
            button_name = button_name,
            mouse_button = mouse_button or "LeftButton",
        }
        return true
    end

    _G.SaveBindings = function(binding_set)
        state.saved_bindings_calls[#state.saved_bindings_calls + 1] = binding_set
    end

    _G.GetCurrentBindingSet = function()
        return state.current_binding_set
    end

    dofile("OneButtonPet.lua")

    function state:advance(seconds)
        self.time = self.time + seconds
    end

    function state:set_target(target)
        self.units.target = make_unit(target)
    end

    function state:fire(event, ...)
        for _, frame in ipairs(self.frames) do
            if frame.events[event] and frame.scripts["OnEvent"] then
                frame.scripts["OnEvent"](frame, event, ...)
            end
        end
    end

    function state:get_frame(name)
        return self.named_frames[name]
    end

    function state:get_secure_toggle_button()
        return self.named_frames["OneButtonPetSecureToggleButton"]
    end

    state:fire("PLAYER_ENTERING_WORLD")

    return state
end

local failures = 0
local total = 0

local function run_test(name, fn)
    total = total + 1
    local ok, err = pcall(fn)
    if ok then
        print("PASS " .. name)
    else
        failures = failures + 1
        print("FAIL " .. name .. ": " .. tostring(err))
    end
end

run_test("first press attacks a hostile target", function()
    local state = setup_env({
        target = { guid = "Target-1", name = "Enemy", can_attack = true },
    })

    SlashCmdList["PETTOGGLE"]("")

    assert_equal(state.pet_attack_calls, 1, "first press should attack")
    assert_equal(state.pet_follow_calls, 0, "first press should not follow")
end)

run_test("second rapid press follows via remembered target", function()
    local state = setup_env({
        target = { guid = "Target-1", name = "Enemy", can_attack = true },
        auto_update_pet_state_on_attack = false,
    })

    SlashCmdList["PETTOGGLE"]("")
    state:advance(0.25)
    SlashCmdList["PETTOGGLE"]("")

    assert_equal(state.pet_attack_calls, 1, "second press should not re-attack")
    assert_equal(state.pet_follow_calls, 1, "second press should follow")
end)

run_test("remembered target expires so stale state does not block later attack", function()
    local state = setup_env({
        target = { guid = "Target-1", name = "Enemy", can_attack = true },
        auto_update_pet_state_on_attack = false,
    })

    SlashCmdList["PETTOGGLE"]("")
    state:advance(2.0)
    SlashCmdList["PETTOGGLE"]("")

    assert_equal(state.pet_attack_calls, 2, "expired remembered target should allow another attack")
    assert_equal(state.pet_follow_calls, 0, "expired remembered target should not force follow")
end)

run_test("changing target clears remembered state for a new enemy", function()
    local state = setup_env({
        target = { guid = "Target-1", name = "Enemy A", can_attack = true },
        auto_update_pet_state_on_attack = false,
    })

    SlashCmdList["PETTOGGLE"]("")
    state:set_target({ guid = "Target-2", name = "Enemy B", can_attack = true })
    state:fire("PLAYER_TARGET_CHANGED")
    SlashCmdList["PETTOGGLE"]("")

    assert_equal(state.pet_attack_calls, 2, "new target should get a fresh attack command")
    assert_equal(state.pet_follow_calls, 0, "new target should not immediately follow")
end)

run_test("invalid target falls back to follow and clears toggle state", function()
    local state = setup_env({
        target = { guid = "Target-1", name = "Enemy", can_attack = true },
        auto_update_pet_state_on_attack = false,
    })

    SlashCmdList["PETTOGGLE"]("")
    state:set_target({ guid = "Friend-1", name = "Friend", can_attack = false })
    state:fire("PLAYER_TARGET_CHANGED")
    SlashCmdList["PETTOGGLE"]("")
    state:set_target({ guid = "Target-1", name = "Enemy", can_attack = true })
    state:fire("PLAYER_TARGET_CHANGED")
    SlashCmdList["PETTOGGLE"]("")

    assert_equal(state.pet_follow_calls, 1, "friendly target should follow")
    assert_equal(state.pet_attack_calls, 2, "attack state should be cleared for the next hostile target")
end)

run_test("actual pet attack state follows even after remember window expires", function()
    local state = setup_env({
        target = { guid = "Target-1", name = "Enemy", can_attack = true },
        pettarget_guid = "Target-1",
        pet_attack_active = true,
        pet_in_combat = true,
    })

    state:advance(5.0)
    SlashCmdList["PETTOGGLE"]("")

    assert_equal(state.pet_attack_calls, 0, "live pet attack state should not attack again")
    assert_equal(state.pet_follow_calls, 1, "live pet attack state should toggle to follow")
end)

run_test("binding wrapper triggers the toggle", function()
    local state = setup_env({
        target = { guid = "Target-3", name = "Enemy", can_attack = true },
    })

    OneButtonPet_ToggleBinding()

    assert_equal(state.pet_attack_calls, 1, "binding should issue attack")
end)

run_test("secure toggle button is created and synced for hostile targets", function()
    local state = setup_env({
        target = { guid = "Target-5", name = "Enemy", can_attack = true },
    })

    local button = state:get_secure_toggle_button()

    assert_true(button ~= nil, "secure toggle button should exist")
    assert_true(button.template:find("SecureActionButtonTemplate", 1, true) ~= nil, "button should inherit SecureActionButtonTemplate")
    assert_true(button.template:find("SecureHandlerBaseTemplate", 1, true) ~= nil, "button should inherit SecureHandlerBaseTemplate")
    assert_equal(button.attributes.obp_synced_action, "attack", "secure button should sync the attack action")
    assert_equal(button.attributes.obp_synced_reason, "attack_target", "secure button should explain the synced action")
    assert_equal(button.attributes.macrotext, "/petattack", "secure button should prime the attack macro")
end)

run_test("player entering world migrates legacy bindings to the secure click binding", function()
    local state = setup_env({
        bindings = {
            ONEBUTTONPET_TOGGLE = { "CTRL-F" },
        },
        current_binding_set = 2,
    })

    assert_equal(#state.set_binding_click_calls, 1, "legacy keybind should be migrated once")
    assert_equal(state.set_binding_click_calls[1].key, "CTRL-F", "legacy key should be reused")
    assert_equal(state.set_binding_click_calls[1].button_name, "OneButtonPetSecureToggleButton", "migration should target the secure button")
    assert_equal(state.saved_bindings_calls[1], 2, "migration should save the active binding set")
    assert_equal(select(1, GetBindingKey("CLICK OneButtonPetSecureToggleButton:LeftButton")), "CTRL-F", "secure click binding should now own the key")
end)

run_test("toc relies on automatic loading for bindings xml", function()
    local toc = assert(io.open("OneButtonPet.toc", "r"))
    local lua_line
    local bindings_line
    local line_number = 0

    for line in toc:lines() do
        line_number = line_number + 1
        if line == "OneButtonPet.lua" then
            lua_line = line_number
        elseif line == "Bindings.xml" then
            bindings_line = line_number
        end
    end

    toc:close()

    assert_true(lua_line ~= nil, "toc should list OneButtonPet.lua")
    assert_true(bindings_line == nil, "toc should not list Bindings.xml because the client auto-loads it")
end)

run_test("toc stores per-character debug settings", function()
    local toc = assert(io.open("OneButtonPet.toc", "r"))
    local contents = toc:read("*a")
    toc:close()

    assert_true(contents:find("## SavedVariablesPerCharacter: OneButtonPetDB", 1, true) ~= nil, "toc should persist the debug toggle")
end)

run_test("bindings xml uses addons category without a custom header", function()
    local file = assert(io.open("Bindings.xml", "r"))
    local contents = file:read("*a")
    file:close()

    assert_true(contents:find('category="ADDONS"', 1, true) ~= nil, "Bindings.xml should place the binding under AddOns")
    assert_true(contents:find('CLICK OneButtonPetSecureToggleButton:LeftButton', 1, true) ~= nil, "Bindings.xml should bind through the secure click button")
    assert_true(contents:find('header="ONEBUTTONPET"', 1, true) == nil, "Bindings.xml should not rely on a custom header")
end)

run_test("slash toggle warns in combat instead of issuing protected pet commands", function()
    local state = setup_env({
        in_combat = true,
        target = { guid = "Target-4", name = "Enemy", can_attack = true },
    })

    SlashCmdList["PETTOGGLE"]("")

    assert_equal(state.pet_attack_calls, 0, "slash toggle should not attack in combat")
    assert_equal(state.pet_follow_calls, 0, "slash toggle should not follow in combat")
    assert_equal(#state.chat, 2, "slash toggle should explain the binding recommendation")
    assert_true(state.chat[1]:find("addon keybind", 1, true) ~= nil, "warning should point to the addon keybind")
end)

run_test("help command prints usage without issuing commands", function()
    local state = setup_env({
        target = { guid = "Target-1", name = "Enemy", can_attack = true },
    })

    SlashCmdList["PETTOGGLE"]("help")

    assert_true(#state.chat >= 4, "help should print usage")
    assert_equal(state.pet_attack_calls, 0, "help should not attack")
    assert_equal(state.pet_follow_calls, 0, "help should not follow")
end)

run_test("debug commands toggle saved state and report status", function()
    local state = setup_env({
        target = { guid = "Target-6", name = "Enemy", can_attack = true },
    })

    SlashCmdList["PETTOGGLE"]("debug status")
    assert_true(state.chat[#state.chat]:find("off", 1, true) ~= nil, "debug status should default to off")

    SlashCmdList["PETTOGGLE"]("debug on")
    assert_true(OneButtonPetDB.debug == true, "debug on should persist to saved variables")
    assert_true(state.chat[#state.chat]:find("enabled", 1, true) ~= nil, "debug on should confirm enablement")

    SlashCmdList["PETTOGGLE"]("debug off")
    assert_true(OneButtonPetDB.debug == false, "debug off should persist to saved variables")
    assert_true(state.chat[#state.chat]:find("disabled", 1, true) ~= nil, "debug off should confirm disablement")
end)

run_test("status reports missing pet cleanly", function()
    local state = setup_env({
        pet = { exists = false, guid = nil, name = nil },
        target = { guid = "Target-1", name = "Enemy", can_attack = true },
    })

    SlashCmdList["PETTOGGLE"]("status")

    assert_equal(#state.chat, 1, "status should print one line")
    assert_true(state.chat[1]:find("No active pet", 1, true) ~= nil, "status should mention missing pet")
    assert_equal(state.pet_attack_calls, 0, "status should not attack")
    assert_equal(state.pet_follow_calls, 0, "status should not follow")
end)

print(string.format("Ran %d tests, %d failures", total, failures))

if failures > 0 then
    os.exit(1)
end
