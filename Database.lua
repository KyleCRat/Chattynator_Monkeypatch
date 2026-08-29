local ADDON_NAME, NS = ...

local Database = {}
NS.Database = Database

local function ApplyDefaults(target, defaults)
    for key, defaultValue in pairs(defaults) do
        local currentValue = target[key]

        if currentValue == nil then
            if type(defaultValue) == "table" then
                target[key] = CopyTable(defaultValue)
            else
                target[key] = defaultValue
            end
        elseif type(currentValue) == "table" and type(defaultValue) == "table" then
            ApplyDefaults(currentValue, defaultValue)
        end
    end
end

local function Clamp(value, minimum, maximum)
    value = tonumber(value)

    if not value then
        return minimum
    end

    return math.min(math.max(value, minimum), maximum)
end

local function NormalizeHex(value, fallback)
    value = tostring(value or ""):upper():gsub("^#", "")

    if #value == 8 and value:match("^%x%x%x%x%x%x%x%x$") then
        value = value:sub(3)
    elseif #value == 3 and value:match("^%x%x%x$") then
        value = value:sub(1, 1):rep(2)
            .. value:sub(2, 2):rep(2)
            .. value:sub(3, 3):rep(2)
    end

    if #value ~= 6 or not value:match("^%x%x%x%x%x%x$") then
        return fallback
    end

    return value
end

local function NormalizeBackground(background)
    local defaults = NS.Defaults.background

    if background.mode ~= "solid" and background.mode ~= "gradient" then
        background.mode = defaults.mode
    end

    if background.gradientOrientation ~= "VERTICAL" and background.gradientOrientation ~= "HORIZONTAL" then
        background.gradientOrientation = defaults.gradientOrientation
    end

    background.solidColor = NormalizeHex(background.solidColor, defaults.solidColor)
    background.solidOpacity = Clamp(background.solidOpacity, 0, 1)
    background.gradientStartColor = NormalizeHex(background.gradientStartColor, defaults.gradientStartColor)
    background.gradientStartOpacity = Clamp(background.gradientStartOpacity, 0, 1)
    background.gradientEndColor = NormalizeHex(background.gradientEndColor, defaults.gradientEndColor)
    background.gradientEndOpacity = Clamp(background.gradientEndOpacity, 0, 1)
end

function Database:Initialize()
    if type(ChattynatorMonkeypatchDB) ~= "table" then
        ChattynatorMonkeypatchDB = {}
    end

    ApplyDefaults(ChattynatorMonkeypatchDB, NS.Defaults)
    NormalizeBackground(ChattynatorMonkeypatchDB.background)
    ChattynatorMonkeypatchDB.schemaVersion = NS.Defaults.schemaVersion
    self.data = ChattynatorMonkeypatchDB
end

function Database:GetBackground()
    return self.data.background
end

function Database:SetBackgroundValue(key, value)
    local background = self.data.background
    local defaults = NS.Defaults.background

    if key == "mode" then
        background.mode = value == "gradient" and "gradient" or "solid"
    elseif key == "gradientOrientation" then
        background.gradientOrientation = value == "HORIZONTAL" and "HORIZONTAL" or "VERTICAL"
    elseif key == "solidColor" or key == "gradientStartColor" or key == "gradientEndColor" then
        background[key] = NormalizeHex(value, defaults[key])
    elseif key == "solidOpacity" or key == "gradientStartOpacity" or key == "gradientEndOpacity" then
        background[key] = Clamp(value, 0, 1)
    end
end

function Database:GetGeometry(id)
    return self.data.geometry[tostring(id)]
end

function Database:SetGeometry(id, geometry)
    self.data.geometry[tostring(id)] = geometry
end

function Database:GetOriginalGeometry(id)
    return self.data.originalGeometry[tostring(id)]
end

function Database:CaptureOriginalGeometry(id, geometry)
    local key = tostring(id)

    if self.data.originalGeometry[key] == nil then
        self.data.originalGeometry[key] = CopyTable(geometry)
    end
end

function Database:ResetGeometry(id)
    local original = self:GetOriginalGeometry(id)

    if original then
        self:SetGeometry(id, CopyTable(original))
    else
        self.data.geometry[tostring(id)] = nil
    end
end
