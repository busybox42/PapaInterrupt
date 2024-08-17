local UnitGUID = UnitGUID;
local IsInInstance = IsInInstance;
local GetSpellLink = C_Spell and C_Spell.GetSpellLink or GetSpellLink
local InstanceType = "none"
local RaidIconMaskToIndex =
{
    [COMBATLOG_OBJECT_RAIDTARGET1] = 1,
    [COMBATLOG_OBJECT_RAIDTARGET2] = 2,
    [COMBATLOG_OBJECT_RAIDTARGET3] = 3,
    [COMBATLOG_OBJECT_RAIDTARGET4] = 4,
    [COMBATLOG_OBJECT_RAIDTARGET5] = 5,
    [COMBATLOG_OBJECT_RAIDTARGET6] = 6,
    [COMBATLOG_OBJECT_RAIDTARGET7] = 7,
    [COMBATLOG_OBJECT_RAIDTARGET8] = 8,
};

local function GetRaidIcon(unitFlags)
    -- Check for an appropriate icon for this unit
    local raidTarget = bit.band(unitFlags, COMBATLOG_OBJECT_RAIDTARGET_MASK);
    if (raidTarget == 0) then
        return "";
    end

    return "{rt" .. RaidIconMaskToIndex[raidTarget] .. "}";
end

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

local interr = CreateFrame("Frame", "InterruptTrackerFrame", UIParent);
interr:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
interr:RegisterEvent("PLAYER_ENTERING_WORLD");
interr:RegisterEvent("ADDON_LOADED");
interr:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        LoadPapaInterruptSettings()
    elseif (event == "COMBAT_LOG_EVENT_UNFILTERED") then
        local eventType, _, sourceGUID, sourceName, _, _, destGUID, destName, _, destRaidFlags, spellId = select(2,
            CombatLogGetCurrentEventInfo());
        if (eventType == "SPELL_INTERRUPT" and UnitGUID("player") == sourceGUID and PapaInterruptSettings.enabled) then
            local extraSpellID = select(15, CombatLogGetCurrentEventInfo());
            local destIcon = "";
            if (destName) then
                destIcon = GetRaidIcon(destRaidFlags);
            end

            local interruptingSpell = GetSpellLink(spellId);
            local interruptedSpell = GetSpellLink(extraSpellID);

            -- Error checking to ensure destName and interruptedSpell are strings
            if type(destName) ~= "string" then
                destName = ""
            end

            if type(interruptedSpell) ~= "string" then
                interruptedSpell = ""
            end

            if destName and interruptedSpell and interruptingSpell and sourceName then
                -- Select a random message from the messages array
                local randomIndex = math.random(#PapaInterruptSettings.messages)
                local msgTemplate = PapaInterruptSettings.messages[randomIndex]

                -- Replace placeholders with actual values
                local msg = msgTemplate:gsub("%%sn", interruptedSpell):gsub("%%is", interruptingSpell):gsub("%%t",
                    destName)

                if (GetNumGroupMembers() > 0) then
                    local msgType = PapaInterruptSettings.channel;
                    if (IsInRaid(LE_PARTY_CATEGORY_HOME) and msgType == "INSTANCE_CHAT") then
                        msgType = "RAID";
                    elseif (IsInGroup(LE_PARTY_CATEGORY_HOME) and msgType == "INSTANCE_CHAT") then
                        msgType = "PARTY";
                    end
                    SendChatMessage(msg, msgType);
                else
                    if InCombatLockdown() then
                        DEFAULT_CHAT_FRAME:AddMessage(msg);
                    else
                        SendChatMessage(msg, PapaInterruptSettings.channel);
                    end
                end
            else
                print("Error: destName or interruptedSpell is nil")
            end
        end
    elseif (event == "PLAYER_ENTERING_WORLD") then
        local _, iType = IsInInstance();
        InstanceType = iType;
    end
end);
