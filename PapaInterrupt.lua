-- PapaInterrupt.lua

local addonName, addonTable = ...
local playerGUID = UnitGUID("player")
local petGUID = UnitGUID("pet")

-- Localized WoW API functions
local UnitGUID = UnitGUID
local IsInInstance = IsInInstance
local GetSpellLink = C_Spell and C_Spell.GetSpellLink or GetSpellLink
local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo
local SendChatMessage = SendChatMessage
local GetNumGroupMembers = GetNumGroupMembers
local IsInRaid = IsInRaid
local IsInGroup = IsInGroup
local InCombatLockdown = InCombatLockdown
local DEFAULT_CHAT_FRAME = DEFAULT_CHAT_FRAME
local bit_band = bit.band

-- Raid icon mapping
local RaidIconMaskToIndex = {
    [COMBATLOG_OBJECT_RAIDTARGET1] = 1,
    [COMBATLOG_OBJECT_RAIDTARGET2] = 2,
    [COMBATLOG_OBJECT_RAIDTARGET3] = 3,
    [COMBATLOG_OBJECT_RAIDTARGET4] = 4,
    [COMBATLOG_OBJECT_RAIDTARGET5] = 5,
    [COMBATLOG_OBJECT_RAIDTARGET6] = 6,
    [COMBATLOG_OBJECT_RAIDTARGET7] = 7,
    [COMBATLOG_OBJECT_RAIDTARGET8] = 8,
}

local function GetRaidIcon(unitFlags)
    local raidTarget = bit_band(unitFlags, COMBATLOG_OBJECT_RAIDTARGET_MASK)
    if raidTarget == 0 then return "" end
    return "{rt" .. RaidIconMaskToIndex[raidTarget] .. "}"
end

-- Load or initialize settings
local function LoadPapaInterruptSettings()
    if PapaInterruptDB and PapaInterruptDB.settings then
        PapaInterruptSettings = PapaInterruptDB.settings
    else
        PapaInterruptSettings = {
            enabled = true,
            messages = {
                "Interrupted %t's %sn with %is!",
                "%t’s attempt to cast %sn was thwarted!",
                "%t’s %sn was disrupted by %is!",
                "%t’s %sn has been interrupted!",
                "%t’s %sn was halted mid-cast!"
            },
            groupConditions = { Raid = true, Dungeon = true, Battleground = true, Arena = true },
            channel = "SAY"
        }
    end
end

LoadPapaInterruptSettings()

local lastMessageIndex = nil

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("UNIT_PET")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == addonName then
            LoadPapaInterruptSettings()
            print(addonName .. " has been loaded and initialized.")
        end
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        if not PapaInterruptSettings.enabled then return end

        local _, eventType, _, sourceGUID, sourceName, _, _, destGUID, destName, _, destRaidFlags, spellId, _, _, extraSpellID = CombatLogGetCurrentEventInfo()

        -- Adjust the condition to account for player or pet interrupts
        if eventType == "SPELL_INTERRUPT" and (sourceGUID == playerGUID or sourceGUID == petGUID) then
            local destIcon = destName and GetRaidIcon(destRaidFlags) or ""
            local interruptingSpell = GetSpellLink(spellId) or ""
            local interruptedSpell = GetSpellLink(extraSpellID) or ""

            if destName and interruptedSpell and interruptingSpell and sourceName then
                local randomIndex
                if #PapaInterruptSettings.messages > 1 then
                    repeat
                        randomIndex = math.random(#PapaInterruptSettings.messages)
                    until randomIndex ~= lastMessageIndex
                else
                    randomIndex = 1
                end
                lastMessageIndex = randomIndex

                local msgTemplate = PapaInterruptSettings.messages[randomIndex]
                local msg = msgTemplate
                    :gsub("%%sn", interruptedSpell)
                    :gsub("%%is", interruptingSpell)
                    :gsub("%%t", destName)

                if GetNumGroupMembers() > 0 then
                    local msgType = PapaInterruptSettings.channel
                    if IsInRaid() and msgType == "INSTANCE_CHAT" then
                        msgType = "RAID"
                    elseif IsInGroup() and msgType == "INSTANCE_CHAT" then
                        msgType = "PARTY"
                    end
                    SendChatMessage(msg, msgType)
                else
                    if InCombatLockdown() then
                        DEFAULT_CHAT_FRAME:AddMessage(msg)
                    else
                        SendChatMessage(msg, PapaInterruptSettings.channel)
                    end
                end
            else
                print("Error: destName or interruptedSpell is invalid")
            end
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        local _, iType = IsInInstance()
        InstanceType = iType
    elseif event == "UNIT_PET" then
        -- Update petGUID when the pet changes or is summoned
        local unit = ...
        if unit == "player" then
            petGUID = UnitGUID("pet")
        end
    end
end)
