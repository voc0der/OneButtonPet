-- OneButtonPet
-- Toggle pet attack/follow with one button press.

local addonName = "OneButtonPet"
local REMEMBER_TARGET_WINDOW = 1.0

local OneButtonPet = {
    addonName = addonName,
    hasWarnedAboutSlashInCombat = false,
    lastAttackTargetToken = nil,
    lastAttackAt = 0,
}

_G.OneButtonPet = OneButtonPet

BINDING_NAME_ONEBUTTONPET_TOGGLE = "Toggle Pet Attack/Follow"

local function Print(message)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ccff[OneButtonPet]|r " .. message)
    end
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

function OneButtonPet:Toggle()
    if not HasPet() then
        ClearRememberedTarget()
        return false, "no_pet"
    end

    if not HasValidAttackTarget() then
        return false, self:Follow()
    end

    if self:ShouldToggleToFollow() then
        return false, self:Follow()
    end

    return true, self:AttackCurrentTarget()
end

function OneButtonPet:HandleSlash(input)
    local command = string.lower((input or ""):match("^%s*(.-)%s*$"))

    if command == "help" then
        Print("Usage: /pettoggle toggles pet attack and follow on your current target.")
        Print("Aliases: /onebuttonpet, /obp")
        Print("Use Key Bindings -> AddOns, then bind Toggle Pet Attack/Follow.")
        Print("Slash commands remain available for help and status, but pet control is through the addon keybind.")
        return
    end

    if command == "status" then
        if not HasPet() then
            Print("No active pet.")
            return
        end

        local nextAction = self:ShouldToggleToFollow() and "follow" or "attack"
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
eventFrame:RegisterEvent("UNIT_PET")
eventFrame:SetScript("OnEvent", function(_, event, unit)
    if event == "UNIT_PET" and unit ~= "player" then
        return
    end

    if event == "PLAYER_TARGET_CHANGED" and OneButtonPet:IsCurrentTargetRemembered() then
        return
    end

    ClearRememberedTarget()
end)
