local function DeepCopy(value)
    if type(value) ~= "table" then
        return value
    end

    local result = {}

    for key, child in pairs(value) do
        result[DeepCopy(key)] = DeepCopy(child)
    end

    return result
end

function CopyTable(value)
    return DeepCopy(value)
end

function wipe(value)
    for key in pairs(value) do
        value[key] = nil
    end

    return value
end

function CreateColor(red, green, blue, alpha)
    return {r = red, g = green, b = blue, a = alpha or 1}
end

local combatLocked = false

function InCombatLockdown()
    return combatLocked
end

function hooksecurefunc(object, methodName, callback)
    local original = object[methodName]
    object[methodName] = function(...)
        local results = {original(...)}
        callback(...)
        return unpack(results)
    end
end

UIParent = {
    GetCenter = function()
        return 960, 540
    end,
    GetEffectiveScale = function()
        return 1
    end,
}

local function NewTexture()
    local texture = {}

    function texture:IsObjectType(objectType)
        return objectType == "Texture"
    end

    function texture:SetPoint()
    end

    function texture:SetBlendMode()
    end

    function texture:SetTexCoord()
    end

    function texture:SetVertexColor()
    end

    function texture:SetAlpha(alpha)
        self.alpha = alpha
    end

    function texture:Show()
        self.shown = true
    end

    function texture:Hide()
        self.shown = false
    end

    function texture:SetTexture(path)
        self.path = path
    end

    function texture:SetGradient(orientation, startColor, endColor)
        self.gradient = {
            orientation = orientation,
            startColor = startColor,
            endColor = endColor,
        }
    end

    function texture:SetColorTexture(red, green, blue, alpha)
        self.solid = {red = red, green = green, blue = blue, alpha = alpha}
    end

    return texture
end

local function NewSimpleFrame()
    local frame = {}

    function frame:IsObjectType(objectType)
        return objectType == "Frame"
    end

    return frame
end

local function NewChatWindow(id)
    local frame = NewSimpleFrame()
    frame.id = id
    frame.width = 420
    frame.height = 220
    frame.point = "BOTTOMLEFT"
    frame.relativeTo = UIParent
    frame.relativePoint = "BOTTOMLEFT"
    frame.x = 30
    frame.y = 40
    frame.ScrollingMessagesWrapper = NewSimpleFrame()
    frame.TabsBar = NewSimpleFrame()
    frame.ButtonsBar = NewSimpleFrame()
    frame.backgroundTex = NewTexture()

    function frame:GetID()
        return self.id
    end

    function frame:SetBackgroundColor()
        self.upstreamBackgroundCalls = (self.upstreamBackgroundCalls or 0) + 1
    end

    function frame:CreateTexture()
        self.createdTexture = NewTexture()
        return self.createdTexture
    end

    function frame:HookScript(scriptName, callback)
        self.hooks = self.hooks or {}
        self.hooks[scriptName] = callback
    end

    function frame:GetPoint()
        return self.point, self.relativeTo, self.relativePoint, self.x, self.y
    end

    function frame:GetCenter()
        return self.x + self.width / 2, self.y + self.height / 2
    end

    function frame:GetEffectiveScale()
        return 1
    end

    function frame:GetSize()
        return self.width, self.height
    end

    function frame:GetWidth()
        return self.width
    end

    function frame:GetHeight()
        return self.height
    end

    function frame:GetResizeBounds()
        return 240, 140, 1000, 800
    end

    function frame:SetSize(width, height)
        self.width = width
        self.height = height
        self.sizeChanges = (self.sizeChanges or 0) + 1
    end

    function frame:ClearAllPoints()
        self.point = nil
    end

    function frame:SetPoint(point, relativeTo, relativePoint, x, y)
        self.point = point
        self.relativeTo = relativeTo
        self.relativePoint = relativePoint
        self.x = x
        self.y = y
        self.positionChanges = (self.positionChanges or 0) + 1
    end

    function frame:SavePosition()
        self.savedPosition = true
    end

    function frame:SaveSize()
        self.savedSize = true
    end

    return frame
end

local window = NewChatWindow(1)
ChattynatorHyperlinkHandler = NewSimpleFrame()

function ChattynatorHyperlinkHandler:GetChildren()
    return window
end

local addonName = "Chattynator_Monkeypatch"
local namespace = {}

local function LoadAddonFile(path)
    local chunk, errorMessage = loadfile(path)
    assert(chunk, errorMessage)
    chunk(addonName, namespace)
end

LoadAddonFile("Defaults.lua")
LoadAddonFile("Database.lua")
LoadAddonFile("Adapter.lua")
LoadAddonFile("Background.lua")
LoadAddonFile("Geometry.lua")

ChattynatorMonkeypatchDB = {}
namespace.Database:Initialize()

local frames = namespace.Adapter:Scan()
assert(#frames == 1, "expected one Chattynator window")
assert(namespace.Adapter:GetNativeBackgroundTexture(window) == window.backgroundTex, "alternate background texture was skipped")

namespace.Background:Attach(window)
assert(window.backgroundTex.solid.alpha == 0.80, "solid opacity was not applied")

namespace.Database:SetBackgroundValue("mode", "gradient")
namespace.Database:SetBackgroundValue("gradientStartColor", "#336699")
namespace.Database:SetBackgroundValue("gradientStartOpacity", 0.25)
namespace.Database:SetBackgroundValue("gradientEndColor", "FFCC3300")
namespace.Database:SetBackgroundValue("gradientEndOpacity", 0.75)
namespace.Background:ApplyAll()

local gradient = window.backgroundTex.gradient
assert(gradient.orientation == "VERTICAL", "gradient orientation mismatch")
assert(math.abs(gradient.startColor.r - 0x33 / 255) < 0.001, "gradient start red mismatch")
assert(gradient.startColor.a == 0.25, "gradient start opacity mismatch")
assert(gradient.endColor.a == 0.75, "gradient end opacity mismatch")

window.backgroundTex:SetAlpha(0.10)
assert(window.backgroundTex.alpha == 1, "upstream alpha mutation was not repaired")
window.backgroundTex:SetColorTexture(1, 0, 1, 1)
assert(window.backgroundTex.gradient.orientation == "VERTICAL", "upstream texture mutation was not repaired")

namespace.Geometry:Attach(window)
namespace.Geometry:SavePosition(1, "TOPLEFT", "TOPLEFT", 80, -90)
assert(window.point == "TOPLEFT" and window.x == 80 and window.y == -90, "position was not applied")

namespace.Geometry:SetWidth(1, 100)
assert(window.width == 240, "minimum width was not enforced")

local sizeChanges = window.sizeChanges
local positionChanges = window.positionChanges
namespace.Geometry:ApplyToFrame(window)
assert(window.sizeChanges == sizeChanges, "idempotent apply changed size")
assert(window.positionChanges == positionChanges, "idempotent apply changed position")

combatLocked = true
namespace.Geometry:SavePosition(1, "CENTER", "CENTER", 12, 34)
assert(window.point == "TOPLEFT", "combat-locked position changed immediately")
combatLocked = false
namespace.Geometry:ApplyPending()
assert(window.point == "CENTER" and window.x == 12 and window.y == 34, "deferred position was not applied")

local unlockElements = {}
EllesmereUI = {}

function EllesmereUI.MakeUnlockElement(options)
    return options
end

function EllesmereUI:RegisterUnlockElements(elements, folder)
    for _, element in ipairs(elements) do
        unlockElements[element.key] = element
        element.folder = folder
    end
end

function EllesmereUI:RegisterUnlockModeListener(owner, callback)
    self.listenerOwner = owner
    self.listener = callback
end

namespace.RefreshIntegration = function()
    return #namespace.Adapter:GetFrames()
end

LoadAddonFile("Unlock.lua")
namespace.Unlock:Initialize()
namespace.Unlock:RegisterAvailableFrames()
namespace.Unlock:RegisterAvailableFrames()

local unlockElement = unlockElements.ChattynatorMonkeypatch_Window1
assert(unlockElement, "EllesmereUI element was not registered")
assert(unlockElement.folder == addonName, "EllesmereUI registration folder mismatch")
assert(unlockElement.getFrame() == window, "unlock element did not resolve the live frame")
unlockElement.setHeight(nil, 100)
assert(window.height == 140, "minimum height was not enforced through unlock callback")

SlashCmdList = {}
MinimalSliderWithSteppersMixin = {Label = {Right = "RIGHT"}}

function strtrim(value)
    return value:match("^%s*(.-)%s*$")
end

local settingsByVariable = {}
local registeredInitializers = {}
local settingsCategory = {
    GetID = function()
        return 42
    end,
}
local settingsLayout = {
    AddInitializer = function(_, initializer)
        registeredInitializers[#registeredInitializers + 1] = initializer
    end,
}

Settings = {
    VarType = {String = "string", Number = "number"},
}

function Settings.RegisterVerticalLayoutCategory()
    return settingsCategory, settingsLayout
end

function Settings.RegisterProxySetting(_, variable, variableType, label, defaultValue, getter, setter)
    local setting = {
        variable = variable,
        variableType = variableType,
        label = label,
        defaultValue = defaultValue,
        getValue = getter,
        setValue = setter,
    }
    settingsByVariable[variable] = setting
    return setting
end

function Settings.CreateControlTextContainer()
    local values = {}
    return {
        Add = function(_, value, label)
            values[#values + 1] = {value = value, label = label}
        end,
        GetData = function()
            return values
        end,
    }
end

function Settings.CreateSliderOptions(minimum, maximum, step)
    return {
        minimum = minimum,
        maximum = maximum,
        step = step,
        SetLabelFormatter = function(self, labelType, formatter)
            self.labelType = labelType
            self.formatter = formatter
        end,
    }
end

function Settings.CreateDropdown()
end

function Settings.CreateColorSwatch()
end

function Settings.CreateSlider()
end

function Settings.RegisterAddOnCategory(registeredCategory)
    assert(registeredCategory == settingsCategory, "wrong Settings category registered")
end

function Settings.OpenToCategory(categoryID)
    assert(categoryID == 42, "wrong Settings category opened")
end

function CreateSettingsListSectionHeaderInitializer(name)
    return {name = name}
end

function CreateSettingsButtonInitializer(name, buttonText, callback, tooltip, addSearchTags)
    assert(addSearchTags ~= nil, "Settings button omitted addSearchTags")
    return {
        name = name,
        buttonText = buttonText,
        callback = callback,
        tooltip = tooltip,
    }
end

namespace.Print = function()
end

LoadAddonFile("Settings.lua")
namespace.Settings:Register()
namespace.Settings:Open()
assert(settingsByVariable.CHATTYNATOR_MONKEYPATCH_BACKGROUND_MODE, "background mode setting was not registered")
assert(settingsByVariable.CHATTYNATOR_MONKEYPATCH_GRADIENT_END_OPACITY, "gradient end opacity setting was not registered")
settingsByVariable.CHATTYNATOR_MONKEYPATCH_SOLID_COLOR.setValue("FFABCDEF")
assert(namespace.Database:GetBackground().solidColor == "ABCDEF", "Settings color setter did not normalize AARRGGBB")

local eventFrames = {}
C_Timer = {
    After = function(_, callback)
        callback()
    end,
}

function CreateFrame()
    local frame = {registeredEvents = {}}

    function frame:RegisterEvent(event)
        self.registeredEvents[event] = true
    end

    function frame:UnregisterEvent(event)
        self.registeredEvents[event] = nil
    end

    function frame:SetScript(scriptName, callback)
        self[scriptName] = callback
    end

    eventFrames[#eventFrames + 1] = frame
    return frame
end

LoadAddonFile("Core.lua")
local lifecycleFrame = eventFrames[#eventFrames]
assert(lifecycleFrame.registeredEvents.ADDON_LOADED, "core did not register ADDON_LOADED")
lifecycleFrame.OnEvent(lifecycleFrame, "ADDON_LOADED", "DifferentAddon")
assert(lifecycleFrame.registeredEvents.ADDON_LOADED, "core consumed another addon's ADDON_LOADED")
lifecycleFrame.OnEvent(lifecycleFrame, "ADDON_LOADED", addonName)
assert(not lifecycleFrame.registeredEvents.ADDON_LOADED, "core did not unregister its ADDON_LOADED")
assert(lifecycleFrame.registeredEvents.PLAYER_ENTERING_WORLD, "core did not register PLAYER_ENTERING_WORLD")
assert(lifecycleFrame.registeredEvents.PLAYER_REGEN_ENABLED, "core did not register PLAYER_REGEN_ENABLED")

print("PASS adapter, background, geometry, Unlock Mode, and Settings tests")
