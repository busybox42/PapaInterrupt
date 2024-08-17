-- Create the main menu frame
local menu = CreateFrame("Frame", "PapaInterruptMenu", UIParent, "BasicFrameTemplate")
menu:SetSize(360, 320)
menu:SetPoint("CENTER")
menu:SetFrameStrata("DIALOG")
menu:SetMovable(true)
menu:EnableMouse(true)
menu:RegisterForDrag("LeftButton")
menu:SetScript("OnDragStart", menu.StartMoving)
menu:SetScript("OnDragStop", menu.StopMovingOrSizing)
menu:Hide() -- Menu is hidden by default

-- Create the "Add Interrupt Message" edit box
local addMessageEditBox = CreateFrame("EditBox", "PapaInterruptAddMessageEditBox", menu, "InputBoxTemplate")
addMessageEditBox:SetPoint("TOPLEFT", menu, "TOPLEFT", 10, -30)
addMessageEditBox:SetSize(250, 20)

-- Create the "Add Message" button
local addMessageButton = CreateFrame("Button", "PapaInterruptAddMessageButton", menu, "GameMenuButtonTemplate")
addMessageButton:SetPoint("LEFT", addMessageEditBox, "RIGHT", 10, 0)
addMessageButton:SetSize(80, 20)
addMessageButton:SetText("Add")

-- Create the "Select Message to Delete" dropdown menu
local deleteDropdown = CreateFrame("Frame", "PapaInterruptDeleteDropdown", menu, "UIDropDownMenuTemplate")
deleteDropdown:SetPoint("TOPLEFT", addMessageEditBox, "BOTTOMLEFT", 0, -10)
deleteDropdown:SetSize(150, 20)

-- Create the "Delete" button
local deleteButton = CreateFrame("Button", "PapaInterruptDeleteButton", menu, "GameMenuButtonTemplate")
deleteButton:SetPoint("LEFT", deleteDropdown, "RIGHT", 10, 0)
deleteButton:SetSize(80, 20)
deleteButton:SetText("Delete")

-- Create the "Enabled" check box
local enabledCheckBox = CreateFrame("CheckButton", "PapaInterruptEnabledCheckBox", menu, "UICheckButtonTemplate")
enabledCheckBox:SetPoint("TOPLEFT", deleteDropdown, "BOTTOMLEFT", 0, -20)
enabledCheckBox:SetSize(20, 20)
local enabledText = enabledCheckBox:CreateFontString(nil, "ARTWORK", "GameFontNormal")
enabledText:SetPoint("LEFT", enabledCheckBox, "RIGHT", 5, 0)
enabledText:SetText("Enabled")

-- Create the group condition check boxes
local groupConditionsCheckBoxes = {}
local groupConditions = { "Dungeon", "Raid", "Arena", "Battleground" }
for i, condition in ipairs(groupConditions) do
    local checkBox = CreateFrame("CheckButton", "PapaInterruptGroupConditionsCheckBox" .. i, menu,
        "UICheckButtonTemplate")
    checkBox:SetPoint("TOPLEFT", enabledCheckBox, "BOTTOMLEFT", 0, -20 * i)
    checkBox:SetSize(20, 20)
    local conditionText = checkBox:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    conditionText:SetPoint("LEFT", checkBox, "RIGHT", 5, 0)
    conditionText:SetText(condition)
    table.insert(groupConditionsCheckBoxes, checkBox)
end

-- Create the "Channel" dropdown menu
local channelDropdown = CreateFrame("Frame", "PapaInterruptChannelDropdown", menu, "UIDropDownMenuTemplate")
channelDropdown:SetPoint("TOPLEFT", enabledCheckBox, "TOPRIGHT", 150, 0)
channelDropdown:SetSize(140, 20)
local channels = { "SAY", "PARTY", "INSTANCE_CHAT", "GUILD" }
local function InitializeChannelDropdown(self, level)
    for i, channel in ipairs(channels) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = channel
        info.value = channel
        info.func = function(self)
            PapaInterruptSettings.channel = self.value
            UIDropDownMenu_SetSelectedValue(channelDropdown, self.value)
        end
        UIDropDownMenu_AddButton(info, level)
    end
end
UIDropDownMenu_Initialize(channelDropdown, InitializeChannelDropdown)

-- Create a save button
local saveButton = CreateFrame("Button", "PapaInterruptSaveButton", menu, "GameMenuButtonTemplate")
saveButton:SetPoint("BOTTOM", menu, "BOTTOM", -30, 10)
saveButton:SetSize(120, 27)
saveButton:SetText("Save")

-- Create a hints text
local hintsText = menu:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
hintsText:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -40, 60)
hintsText:SetText("Available variables:\n%t - Target\n%is - My interrupting spell\n%sn - Spell interrupted")

-- Set the script for the "Add Message" button
addMessageButton:SetScript("OnClick", function()
    local newMessage = addMessageEditBox:GetText()
    if newMessage and newMessage ~= "" then
        table.insert(PapaInterruptSettings.messages, newMessage)
        addMessageEditBox:SetText("")
        -- Update the dropdown menu with new messages
        UIDropDownMenu_Initialize(deleteDropdown, InitializeDeleteDropdown)
    end
end)

-- Set the script for the "Delete" button
deleteButton:SetScript("OnClick", function()
    local selectedMessage = UIDropDownMenu_GetSelectedValue(deleteDropdown)
    if selectedMessage then
        for i, message in ipairs(PapaInterruptSettings.messages) do
            if message == selectedMessage then
                table.remove(PapaInterruptSettings.messages, i)
                break
            end
        end
        -- Update the dropdown menu with remaining messages
        UIDropDownMenu_Initialize(deleteDropdown, InitializeDeleteDropdown)
    end
end)

-- Initialize the delete dropdown
local function InitializeDeleteDropdown(self, level)
    for i, message in ipairs(PapaInterruptSettings.messages) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = message
        info.value = message
        info.func = function(self)
            UIDropDownMenu_SetSelectedValue(deleteDropdown, self.value)
        end
        UIDropDownMenu_AddButton(info, level)
    end
end
UIDropDownMenu_Initialize(deleteDropdown, InitializeDeleteDropdown)

-- Define a function to load the saved variables and refresh the menu
function LoadPapaInterruptSavedVariablesAndRefresh()
    if PapaInterruptDB and PapaInterruptDB.settings then
        PapaInterruptSettings = PapaInterruptDB.settings
    else
        PapaInterruptDB = {
            settings = {
                enabled = true,
                messages = {
                    "Interrupted %t's %sn with %is!",
                    "%t’s attempt to cast %sn was thwarted!",
                    "%t’s %sn was disrupted by %is!",
                    "%t’s %sn has been interrupted!",
                    "%t’s %sn was halted mid-cast!"
                },
                groupConditions = { Dungeon = true, Raid = true, Arena = true, Battleground = true },
                channel = "SAY"
            }
        }
        PapaInterruptSettings = PapaInterruptDB.settings
    end

    RefreshPapaInterruptMenu()
end

-- Define a function to refresh the menu
function RefreshPapaInterruptMenu()
    enabledCheckBox:SetChecked(PapaInterruptSettings.enabled)

    for i, condition in ipairs(groupConditions) do
        local checkBox = groupConditionsCheckBoxes[i]
        checkBox:SetChecked(PapaInterruptSettings.groupConditions[condition])
    end

    UIDropDownMenu_SetSelectedValue(channelDropdown, PapaInterruptSettings.channel)
    UIDropDownMenu_SetText(channelDropdown, PapaInterruptSettings.channel)

    UIDropDownMenu_Initialize(deleteDropdown, InitializeDeleteDropdown)
end

-- Set the script for the save button
saveButton:SetScript("OnClick", function()
    PapaInterruptSettings.enabled = enabledCheckBox:GetChecked()

    for i, condition in ipairs(groupConditions) do
        PapaInterruptSettings.groupConditions[condition] = groupConditionsCheckBoxes[i]:GetChecked()
    end

    PapaInterruptSettings.channel = UIDropDownMenu_GetSelectedValue(channelDropdown)

    PapaInterruptDB.settings = PapaInterruptSettings

    print("PapaInterrupt settings saved!")
end)

menu:SetScript("OnShow", RefreshPapaInterruptMenu)

-- Register slash commands
SLASH_PAPAINTER1 = "/papainterrupt"
SLASH_PAPAINTER2 = "/pi"
SlashCmdList["PAPAINTER"] = function(msg)
    if menu:IsShown() then
        menu:Hide()
    else
        menu:Show()
    end
end

LoadPapaInterruptSavedVariablesAndRefresh()
