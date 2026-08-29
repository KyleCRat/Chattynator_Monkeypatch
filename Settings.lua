local ADDON_NAME, NS = ...

local AddonSettings = {}
NS.Settings = AddonSettings

local category
local layout

local function ApplyBackground()
    NS.Background:ApplyAll()
end

local function RegisterProxy(categoryObject, variable, variableType, label, defaultValue, getter, setter)
    return Settings.RegisterProxySetting(
        categoryObject,
        variable,
        variableType,
        label,
        defaultValue,
        getter,
        function(value)
            setter(value)
            ApplyBackground()
        end
    )
end

local function AddSection(layout, name, tooltip)
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(name, tooltip))
end

local function CreateOpacityOptions()
    local options = Settings.CreateSliderOptions(0, 1, 0.01)
    options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
        return ("%d%%"):format(math.floor(value * 100 + 0.5))
    end)
    return options
end

local function GetModeOptions()
    local options = Settings.CreateControlTextContainer()
    options:Add("solid", "Solid")
    options:Add("gradient", "Gradient")
    return options:GetData()
end

local function GetOrientationOptions()
    local options = Settings.CreateControlTextContainer()
    options:Add("VERTICAL", "Vertical")
    options:Add("HORIZONTAL", "Horizontal")
    return options:GetData()
end

local function RegisterBackgroundSettings(categoryObject, layout)
    local defaults = NS.Defaults.background

    local mode = RegisterProxy(
        categoryObject,
        "CHATTYNATOR_MONKEYPATCH_BACKGROUND_MODE",
        Settings.VarType.String,
        "Background mode",
        defaults.mode,
        function()
            return NS.Database:GetBackground().mode
        end,
        function(value)
            NS.Database:SetBackgroundValue("mode", value)
        end
    )
    Settings.CreateDropdown(categoryObject, mode, GetModeOptions, "Choose one color or a two-color gradient.")

    AddSection(layout, "Solid background", "Used when Background mode is Solid.")

    local solidColor = RegisterProxy(
        categoryObject,
        "CHATTYNATOR_MONKEYPATCH_SOLID_COLOR",
        Settings.VarType.String,
        "Solid color",
        "FF" .. defaults.solidColor,
        function()
            return "FF" .. NS.Database:GetBackground().solidColor
        end,
        function(value)
            NS.Database:SetBackgroundValue("solidColor", value)
        end
    )
    Settings.CreateColorSwatch(
        categoryObject,
        solidColor,
        "Click the swatch to choose a color or enter its hex value in the color picker."
    )

    local solidOpacity = RegisterProxy(
        categoryObject,
        "CHATTYNATOR_MONKEYPATCH_SOLID_OPACITY",
        Settings.VarType.Number,
        "Solid opacity",
        defaults.solidOpacity,
        function()
            return NS.Database:GetBackground().solidOpacity
        end,
        function(value)
            NS.Database:SetBackgroundValue("solidOpacity", value)
        end
    )
    Settings.CreateSlider(categoryObject, solidOpacity, CreateOpacityOptions(), "Opacity of the solid background.")

    AddSection(layout, "Gradient background", "Used when Background mode is Gradient.")

    local orientation = RegisterProxy(
        categoryObject,
        "CHATTYNATOR_MONKEYPATCH_GRADIENT_ORIENTATION",
        Settings.VarType.String,
        "Gradient direction",
        defaults.gradientOrientation,
        function()
            return NS.Database:GetBackground().gradientOrientation
        end,
        function(value)
            NS.Database:SetBackgroundValue("gradientOrientation", value)
        end
    )
    Settings.CreateDropdown(
        categoryObject,
        orientation,
        GetOrientationOptions,
        "Vertical blends start to end from bottom to top; horizontal blends left to right."
    )

    local startColor = RegisterProxy(
        categoryObject,
        "CHATTYNATOR_MONKEYPATCH_GRADIENT_START_COLOR",
        Settings.VarType.String,
        "Start color",
        "FF" .. defaults.gradientStartColor,
        function()
            return "FF" .. NS.Database:GetBackground().gradientStartColor
        end,
        function(value)
            NS.Database:SetBackgroundValue("gradientStartColor", value)
        end
    )
    Settings.CreateColorSwatch(
        categoryObject,
        startColor,
        "Bottom color for a vertical gradient or left color for a horizontal gradient. Hex input is in the color picker."
    )

    local startOpacity = RegisterProxy(
        categoryObject,
        "CHATTYNATOR_MONKEYPATCH_GRADIENT_START_OPACITY",
        Settings.VarType.Number,
        "Start opacity",
        defaults.gradientStartOpacity,
        function()
            return NS.Database:GetBackground().gradientStartOpacity
        end,
        function(value)
            NS.Database:SetBackgroundValue("gradientStartOpacity", value)
        end
    )
    Settings.CreateSlider(categoryObject, startOpacity, CreateOpacityOptions(), "Opacity at the gradient start.")

    local endColor = RegisterProxy(
        categoryObject,
        "CHATTYNATOR_MONKEYPATCH_GRADIENT_END_COLOR",
        Settings.VarType.String,
        "End color",
        "FF" .. defaults.gradientEndColor,
        function()
            return "FF" .. NS.Database:GetBackground().gradientEndColor
        end,
        function(value)
            NS.Database:SetBackgroundValue("gradientEndColor", value)
        end
    )
    Settings.CreateColorSwatch(
        categoryObject,
        endColor,
        "Top color for a vertical gradient or right color for a horizontal gradient. Hex input is in the color picker."
    )

    local endOpacity = RegisterProxy(
        categoryObject,
        "CHATTYNATOR_MONKEYPATCH_GRADIENT_END_OPACITY",
        Settings.VarType.Number,
        "End opacity",
        defaults.gradientEndOpacity,
        function()
            return NS.Database:GetBackground().gradientEndOpacity
        end,
        function(value)
            NS.Database:SetBackgroundValue("gradientEndOpacity", value)
        end
    )
    Settings.CreateSlider(categoryObject, endOpacity, CreateOpacityOptions(), "Opacity at the gradient end.")
end

local function RegisterIntegrationControls(layout)
    AddSection(layout, "Integration")
    local initializer = CreateSettingsButtonInitializer(
        "Chattynator windows",
        "Rescan",
        function()
            local count = NS:RefreshIntegration(true)
            NS:Print(("Integrated %d Chattynator window(s)."):format(count))
        end,
        "Detect newly created Chattynator windows and add them to EllesmereUI Unlock Mode.",
        true
    )
    layout:AddInitializer(initializer)
end

function AddonSettings:Register()
    category, layout = Settings.RegisterVerticalLayoutCategory("Chattynator Monkeypatch")
    RegisterBackgroundSettings(category, layout)
    RegisterIntegrationControls(layout)
    Settings.RegisterAddOnCategory(category)
end

function AddonSettings:Open()
    Settings.OpenToCategory(category:GetID())
end

local commands = {
    {
        triggers = {"options", "o", ""},
        name = "Options",
        description = "Open the background settings",
        func = function()
            AddonSettings:Open()
        end,
    },
    {
        triggers = {"rescan", "r"},
        name = "Rescan",
        description = "Detect Chattynator windows again",
        func = function()
            local count = NS:RefreshIntegration(true)
            NS:Print(("Integrated %d Chattynator window(s)."):format(count))
        end,
    },
    {
        triggers = {"status", "s"},
        name = "Status",
        description = "Show integration status",
        func = function()
            local count = #NS.Adapter:GetFrames()
            local unlockStatus = NS.Unlock:IsAvailable() and "available" or "unavailable"
            NS:Print(("%d window(s) detected; EllesmereUI Unlock Mode is %s."):format(count, unlockStatus))
        end,
    },
}

local function RegisterSlashCommands()
    _G.SLASH_CHATTYNATORMONKEYPATCH1 = "/cmp"
    _G.SLASH_CHATTYNATORMONKEYPATCH2 = "/chattynatormp"
    SlashCmdList.CHATTYNATORMONKEYPATCH = function(message)
        message = strtrim(message or ""):lower()

        for _, command in ipairs(commands) do
            for _, trigger in ipairs(command.triggers) do
                if message == trigger then
                    command.func()
                    return
                end
            end
        end

        for _, command in ipairs(commands) do
            NS:Print(("/cmp %s - %s"):format(command.triggers[1], command.description))
        end
    end
end

RegisterSlashCommands()
