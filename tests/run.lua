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

local function setup_env(opts)
    opts = opts or {}

    local state = {
        frames = {},
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
    }

    _G.OneButtonPet = nil
    _G.OneButtonPet_ToggleBinding = nil
    _G.BINDING_HEADER_ONEBUTTONPET = nil
    _G.BINDING_NAME_ONEBUTTONPET_TOGGLE = nil
    _G.SLASH_PETTOGGLE1 = nil
    _G.SLASH_PETTOGGLE2 = nil
    _G.SLASH_PETTOGGLE3 = nil

    _G.DEFAULT_CHAT_FRAME = {
        AddMessage = function(_, message)
            state.chat[#state.chat + 1] = message
        end,
    }

    local function new_frame()
        local frame = {
            events = {},
            scripts = {},
        }

        function frame:RegisterEvent(event)
            self.events[event] = true
        end

        function frame:SetScript(script_name, fn)
            self.scripts[script_name] = fn
        end

        state.frames[#state.frames + 1] = frame
        return frame
    end

    _G.CreateFrame = function()
        return new_frame()
    end

    _G.SlashCmdList = {}
    _G.NUM_PET_ACTION_SLOTS = 10

    _G.GetTime = function()
        return state.time
    end

    _G.InCombatLockdown = function()
        return state.in_combat
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

run_test("toc loads addon lua before bindings xml", function()
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
    assert_true(bindings_line ~= nil, "toc should list Bindings.xml")
    assert_true(lua_line < bindings_line, "OneButtonPet.lua should load before Bindings.xml")
end)

run_test("bindings xml uses addons category without a custom header", function()
    local file = assert(io.open("Bindings.xml", "r"))
    local contents = file:read("*a")
    file:close()

    assert_true(contents:find('category="ADDONS"', 1, true) ~= nil, "Bindings.xml should place the binding under AddOns")
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

    assert_true(#state.chat >= 3, "help should print usage")
    assert_equal(state.pet_attack_calls, 0, "help should not attack")
    assert_equal(state.pet_follow_calls, 0, "help should not follow")
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
