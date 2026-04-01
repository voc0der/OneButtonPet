-- OneButtonPet
-- Toggle pet attack/follow with one button press.

local addonName = "OneButtonPet"
local REMEMBER_TARGET_WINDOW = 1.0
local LEGACY_TOGGLE_BINDING = "ONEBUTTONPET_TOGGLE"
local SECURE_TOGGLE_BUTTON_NAME = "OneButtonPetSecureToggleButton"
local SECURE_TOGGLE_BINDING = "CLICK " .. SECURE_TOGGLE_BUTTON_NAME .. ":LeftButton"
local SECURE_ATTACK_MACRO = "/petattack"
local SECURE_FOLLOW_MACRO = "/petfollow"
local SECURE_TOGGLE_PRECLICK = [=[
    local hasPet = UnitExists("pet")
    local hasHostileTarget = UnitExists("target") and PlayerCanAttack("target") and not UnitIsDead("target")
    local action = self:GetAttribute("obp_synced_action")
    local reason = self:GetAttribute("obp_synced_reason")

    if not hasPet then
        action = "none"
        reason = "no_pet"
        self:SetAttribute("obp_combat_next_action", "attack")
    elseif not hasHostileTarget then
        action = "follow"
        reason = "invalid_target"
        self:SetAttribute("obp_combat_next_action", "attack")
    elseif PlayerInCombat() then
        if UnitExists("pettarget") then
            action = "follow"
            reason = "combat_pettarget_exists"
            self:SetAttribute("obp_combat_next_action", "attack")
        else
            local nextAction = self:GetAttribute("obp_combat_next_action") or "attack"
            action = nextAction
            if nextAction == "follow" then
                reason = "combat_toggle_follow"
                self:SetAttribute("obp_combat_next_action", "attack")
            else
                reason = "combat_toggle_attack"
                self:SetAttribute("obp_combat_next_action", "follow")
            end
        end
    else
        if action == "follow" then
            reason = reason or "synced_follow"
            self:SetAttribute("obp_combat_next_action", "attack")
        else
            action = "attack"
            reason = reason or "synced_attack"
            self:SetAttribute("obp_combat_next_action", "follow")
        end
    end

    if action == "attack" then
        self:SetAttribute("type", "macro")
        self:SetAttribute("macrotext", "/petattack")
    elseif action == "follow" then
        self:SetAttribute("type", "macro")
        self:SetAttribute("macrotext", "/petfollow")
    else
        self:SetAttribute("type", "macro")
        self:SetAttribute("macrotext", "")
    end

    if not PlayerInCombat() then
        if action == "attack" then
            self:SetAttribute("obp_synced_action", "follow")
            self:SetAttribute("obp_synced_reason", "toggle_to_follow")
        elseif action == "follow" and hasHostileTarget then
            self:SetAttribute("obp_synced_action", "attack")
            self:SetAttribute("obp_synced_reason", "attack_target")
        elseif action == "follow" then
            self:SetAttribute("obp_synced_action", "follow")
            self:SetAttribute("obp_synced_reason", "invalid_target")
        else
            self:SetAttribute("obp_synced_action", "none")
            self:SetAttribute("obp_synced_reason", "no_pet")
        end
    end

    self:CallMethod("OnSecurePreClick", action or "none", reason or "unknown", PlayerInCombat() and "combat" or "out_of_combat")
]=]

local OneButtonPet = {
    addonName = addonName,
    hasMigratedLegacyBinding = false,
    hasWarnedAboutSlashInCombat = false,
    lastAttackTargetToken = nil,
    lastAttackAt = 0,
    secureToggleButton = nil,
}

_G.OneButtonPet = OneButtonPet

_G["BINDING_NAME_" .. LEGACY_TOGGLE_BINDING] = "Toggle Pet Attack/Follow"
_G["BINDING_NAME_" .. SECURE_TOGGLE_BINDING] = "Toggle Pet Attack/Follow"

local function Print(message)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ccff[OneButtonPet]|r " .. message)
    end
end

local function EnsureSavedVariables()
    if type(_G.OneButtonPetDB) ~= "table" then
        _G.OneButtonPetDB = {}
    end

    if _G.OneButtonPetDB.debug == nil then
        _G.OneButtonPetDB.debug = false
    end

    return _G.OneButtonPetDB
end

local function NormalizeBoolean(value)
    return value == true or value == 1
end

local function GetNow()
    if GetTime then
        return GetTime()
    end
    return 0
end

local function IsInCombat()
    return InCombatLockdown and InCombatLockdown() or false
end

local function GetUnitToken(unit)
    if UnitGUID then
        local guid = UnitGUID(unit)
        if guid and guid ~= "" then
            return guid
        end
    end

    if UnitName then
        local name = UnitName(unit)
        if name and name ~= "" then
            return "name:" .. name
        end
    end

    return nil
end

local function IsUnitDead(unit)
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit) then
        return true
    end

    if UnitIsDead and UnitIsDead(unit) then
        return true
    end

    return false
end

local function HasPet()
    return UnitExists and UnitExists("pet")
end

local function HasValidAttackTarget()
    return UnitExists
        and UnitExists("target")
        and UnitCanAttack
        and UnitCanAttack("player", "target")
        and not IsUnitDead("target")
end

local function IsPetAttackActionActive()
    if not IsPetAttackAction or not GetPetActionInfo then
        return false
    end

    local maxSlots = NUM_PET_ACTION_SLOTS or 10
    for slot = 1, maxSlots do
        if IsPetAttackAction(slot) then
            local _, _, _, fourth, fifth = GetPetActionInfo(slot)
            if fifth ~= nil then
                return NormalizeBoolean(fifth)
            end
            return NormalizeBoolean(fourth)
        end
    end

    return false
end

local function IsPetOnCurrentTarget()
    return UnitExists
        and UnitExists("pettarget")
        and UnitIsUnit
        and UnitIsUnit("pettarget", "target")
end

local function IsPetInCombat()
    return UnitAffectingCombat and UnitAffectingCombat("pet")
end

local function ClearRememberedTarget()
    OneButtonPet.lastAttackTargetToken = nil
    OneButtonPet.lastAttackAt = 0
end

local function GetButtonActionMacro(action)
    if action == "attack" then
        return SECURE_ATTACK_MACRO
    end

    if action == "follow" then
        return SECURE_FOLLOW_MACRO
    end

    return ""
end

function OneButtonPet:IsDebugEnabled()
    return EnsureSavedVariables().debug == true
end

function OneButtonPet:SetDebugEnabled(enabled)
    EnsureSavedVariables().debug = enabled == true
    Print("Debug mode " .. (enabled and "enabled." or "disabled."))
end

function OneButtonPet:Debug(message)
    if self:IsDebugEnabled() then
        Print("Debug: " .. message)
    end
end

function OneButtonPet:PrintDebugStatus()
    Print("Debug mode is " .. (self:IsDebugEnabled() and "on." or "off."))
end

function OneButtonPet:IsCurrentTargetRemembered()
    local targetToken = GetUnitToken("target")
    if not targetToken or targetToken ~= self.lastAttackTargetToken then
        return false
    end

    return (GetNow() - (self.lastAttackAt or 0)) <= REMEMBER_TARGET_WINDOW
end

function OneButtonPet:ShouldToggleToFollow()
    if not HasValidAttackTarget() then
        return true
    end

    if IsPetOnCurrentTarget() and (IsPetAttackActionActive() or IsPetInCombat()) then
        return true
    end

    return self:IsCurrentTargetRemembered()
end

function OneButtonPet:SelectAction()
    if not HasPet() then
        return "none", "no_pet"
    end

    if not HasValidAttackTarget() then
        return "follow", "invalid_target"
    end

    if self:ShouldToggleToFollow() then
        return "follow", "toggle_to_follow"
    end

    return "attack", "attack_target"
end

function OneButtonPet:AttackCurrentTarget()
    local targetToken = GetUnitToken("target")
    if PetAttack then
        PetAttack()
    end
    self.lastAttackTargetToken = targetToken
    self.lastAttackAt = GetNow()
    return "attack"
end

function OneButtonPet:Follow()
    if PetFollow then
        PetFollow()
    end
    ClearRememberedTarget()
    return "follow"
end

function OneButtonPet:ApplyAction(action, reason)
    self:Debug("Applying action " .. action .. " (" .. reason .. ")")

    local didAttack = false
    local result = "no_pet"

    if action == "attack" then
        didAttack = true
        result = self:AttackCurrentTarget()
    elseif action == "follow" then
        result = self:Follow()
    else
        ClearRememberedTarget()
    end

    if not IsInCombat() then
        self:SyncSecureButtonState()
    end

    return didAttack, result
end

function OneButtonPet:Toggle()
    local action, reason = self:SelectAction()
    return self:ApplyAction(action, reason)
end

function OneButtonPet:GetSecureToggleButton()
    if self.secureToggleButton then
        return self.secureToggleButton
    end

    if not CreateFrame then
        return nil
    end

    local button = CreateFrame("Button", SECURE_TOGGLE_BUTTON_NAME, UIParent, "SecureActionButtonTemplate,SecureHandlerBaseTemplate")
    if not button then
        return nil
    end

    if button.EnableMouse then
        button:EnableMouse(true)
    end

    if button.RegisterForClicks then
        button:RegisterForClicks("AnyUp")
    end

    if button.SetAttribute then
        button:SetAttribute("type", "macro")
        button:SetAttribute("macrotext", "")
        button:SetAttribute("obp_combat_next_action", "attack")
    end

    function button:OnSecurePreClick(action, reason, mode)
        OneButtonPet:HandleSecurePreClick(action, reason, mode)
    end

    if button.WrapScript then
        button:WrapScript(button, "PreClick", SECURE_TOGGLE_PRECLICK)
    end

    self.secureToggleButton = button
    return button
end

function OneButtonPet:SyncSecureButtonState()
    local button = self:GetSecureToggleButton()
    if not button or not button.SetAttribute then
        return
    end

    if IsInCombat() then
        self:Debug("Skipped secure binding sync during combat; secure fallback state remains active.")
        return
    end

    local action, reason = self:SelectAction()
    local nextAction = action == "attack" and "follow" or "attack"

    button:SetAttribute("obp_synced_action", action)
    button:SetAttribute("obp_synced_reason", reason)
    button:SetAttribute("obp_combat_next_action", nextAction)
    button:SetAttribute("type", "macro")
    button:SetAttribute("macrotext", GetButtonActionMacro(action))

    self:Debug("Synced secure binding to " .. action .. " (" .. reason .. ")")
end

function OneButtonPet:HandleSecurePreClick(action, reason, mode)
    if action == "attack" then
        self.lastAttackTargetToken = GetUnitToken("target")
        self.lastAttackAt = GetNow()
    else
        ClearRememberedTarget()
    end

    self:Debug("Binding press selected " .. action .. " (" .. reason .. ", " .. mode .. ")")
end

function OneButtonPet:MigrateLegacyBinding()
    if self.hasMigratedLegacyBinding then
        return
    end

    self.hasMigratedLegacyBinding = true

    if not GetBindingKey or not SetBindingClick then
        return
    end

    local secureKeys = { GetBindingKey(SECURE_TOGGLE_BINDING) }
    if secureKeys[1] ~= nil then
        return
    end

    local legacyKeys = { GetBindingKey(LEGACY_TOGGLE_BINDING) }
    if legacyKeys[1] == nil then
        return
    end

    for _, key in ipairs(legacyKeys) do
        SetBindingClick(key, SECURE_TOGGLE_BUTTON_NAME, "LeftButton")
    end

    if SaveBindings and GetCurrentBindingSet then
        SaveBindings(GetCurrentBindingSet())
    end

    Print("Migrated your existing Toggle Pet Attack/Follow keybind to the secure binding.")
    self:Debug("Migrated legacy binding keys: " .. table.concat(legacyKeys, ", "))
end

function OneButtonPet:HandleSlash(input)
    local command = string.lower((input or ""):match("^%s*(.-)%s*$"))

    if command == "help" then
        Print("Usage: /pettoggle toggles pet attack and follow on your current target.")
        Print("Aliases: /onebuttonpet, /obp")
        Print("Use Key Bindings -> AddOns, then bind Toggle Pet Attack/Follow.")
        Print("Debug: /pettoggle debug on|off|status")
        Print("Slash commands remain available for help and status, but pet control is through the addon keybind.")
        return
    end

    if command == "debug" or command == "debug status" then
        self:PrintDebugStatus()
        return
    end

    if command == "debug on" then
        self:SetDebugEnabled(true)
        return
    end

    if command == "debug off" then
        self:SetDebugEnabled(false)
        return
    end

    if command == "status" then
        if not HasPet() then
            Print("No active pet.")
            return
        end

        local nextAction = self:SelectAction()
        Print("Next press will issue: " .. nextAction)
        return
    end

    if IsInCombat() then
        if not self.hasWarnedAboutSlashInCombat then
            Print("OneButtonPet pet control uses the addon keybind, not slash macros.")
            Print("Set Key Bindings -> AddOns -> Toggle Pet Attack/Follow.")
            self.hasWarnedAboutSlashInCombat = true
        end
        return
    end

    self:Toggle()
end

function OneButtonPet_ToggleBinding()
    OneButtonPet:Debug("Legacy toggle binding fallback invoked.")
    OneButtonPet:Toggle()
end

SLASH_PETTOGGLE1 = "/pettoggle"
SLASH_PETTOGGLE2 = "/onebuttonpet"
SLASH_PETTOGGLE3 = "/obp"
SlashCmdList["PETTOGGLE"] = function(input)
    OneButtonPet:HandleSlash(input)
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("PET_BAR_UPDATE")
eventFrame:RegisterEvent("UNIT_PET")
eventFrame:RegisterEvent("UNIT_TARGET")
eventFrame:SetScript("OnEvent", function(_, event, unit)
    if event == "UNIT_PET" and unit ~= "player" then
        return
    end

    if event == "UNIT_TARGET" and unit ~= "pet" then
        return
    end

    EnsureSavedVariables()
    OneButtonPet:GetSecureToggleButton()

    if event == "PLAYER_ENTERING_WORLD" then
        OneButtonPet:MigrateLegacyBinding()
    end

    local shouldClearRememberedTarget = event == "PLAYER_ENTERING_WORLD"
        or event == "UNIT_PET"
        or event == "PLAYER_TARGET_CHANGED"

    if event == "PLAYER_TARGET_CHANGED" and OneButtonPet:IsCurrentTargetRemembered() then
        shouldClearRememberedTarget = false
    end

    if shouldClearRememberedTarget then
        ClearRememberedTarget()
    end

    OneButtonPet:SyncSecureButtonState()
end)
