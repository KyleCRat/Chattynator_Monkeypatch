local ADDON_NAME, NS = ...

local Background = {}
NS.Background = Background

local WHITE_TEXTURE = "Interface\\Buttons\\WHITE8X8"
local overlays = setmetatable({}, {__mode = "k"})
local hookedFrames = setmetatable({}, {__mode = "k"})
local hookedTargets = setmetatable({}, {__mode = "k"})
local applyingFrames = setmetatable({}, {__mode = "k"})

local function HexToRGB(hex)
    local red = tonumber(hex:sub(1, 2), 16) / 255
    local green = tonumber(hex:sub(3, 4), 16) / 255
    local blue = tonumber(hex:sub(5, 6), 16) / 255
    return red, green, blue
end

local function GetOverlay(frame)
    local overlay = overlays[frame]

    if overlay then
        return overlay
    end

    local anchor = NS.Adapter:GetBackgroundAnchor(frame)

    if not anchor then
        return nil
    end

    overlay = frame:CreateTexture(nil, "BACKGROUND", nil, 7)
    overlay:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
    overlay:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 0, 0)
    overlay:SetBlendMode("BLEND")
    overlays[frame] = overlay
    return overlay
end

local function GetTarget(frame)
    local native = NS.Adapter:GetNativeBackgroundTexture(frame)
    local overlay = overlays[frame]

    if native then
        if overlay then
            overlay:Hide()
        end

        return native, true
    end

    return GetOverlay(frame), false
end

local function ApplyTexture(target)
    local config = NS.Database:GetBackground()
    target:SetTexCoord(0, 1, 0, 1)
    target:SetVertexColor(1, 1, 1, 1)
    target:SetAlpha(1)
    target:Show()

    if config.mode == "gradient" then
        local startRed, startGreen, startBlue = HexToRGB(config.gradientStartColor)
        local endRed, endGreen, endBlue = HexToRGB(config.gradientEndColor)
        local startColor = CreateColor(startRed, startGreen, startBlue, config.gradientStartOpacity)
        local endColor = CreateColor(endRed, endGreen, endBlue, config.gradientEndOpacity)

        target:SetTexture(WHITE_TEXTURE)
        target:SetGradient(config.gradientOrientation, startColor, endColor)
    else
        local red, green, blue = HexToRGB(config.solidColor)
        target:SetColorTexture(red, green, blue, config.solidOpacity)
    end
end

local function HookNativeTarget(frame, target)
    if hookedTargets[target] then
        return
    end

    hookedTargets[target] = true
    local mutationMethods = {
        "SetAlpha",
        "SetColorTexture",
        "SetGradient",
        "SetTexture",
        "SetTexCoord",
        "SetVertexColor",
        "Hide",
    }

    for _, methodName in ipairs(mutationMethods) do
        hooksecurefunc(target, methodName, function()
            if not applyingFrames[frame] then
                Background:ApplyToFrame(frame)
            end
        end)
    end
end

function Background:ApplyToFrame(frame)
    if applyingFrames[frame] then
        return
    end

    local target, isNative = GetTarget(frame)

    if not target then
        return
    end

    if isNative then
        HookNativeTarget(frame, target)
    end

    applyingFrames[frame] = true
    local success, errorMessage = pcall(ApplyTexture, target)
    applyingFrames[frame] = nil

    if not success then
        error(errorMessage, 0)
    end
end

function Background:Attach(frame)
    if not hookedFrames[frame] then
        hookedFrames[frame] = true

        hooksecurefunc(frame, "SetBackgroundColor", function(changedFrame)
            Background:ApplyToFrame(changedFrame)
        end)

        frame:HookScript("OnShow", function(shownFrame)
            Background:ApplyToFrame(shownFrame)
        end)
    end

    self:ApplyToFrame(frame)
end

function Background:ApplyAll()
    for _, frame in ipairs(NS.Adapter:GetFrames()) do
        self:ApplyToFrame(frame)
    end
end
