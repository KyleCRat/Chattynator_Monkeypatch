local ADDON_NAME, NS = ...

local Unlock = {}
NS.Unlock = Unlock

local registeredIDs = {}
local initialized = false

local function GetEllesmereUI()
    local ellesmereUI = _G.EllesmereUI

    if not ellesmereUI
        or type(ellesmereUI.RegisterUnlockElements) ~= "function"
        or type(ellesmereUI.MakeUnlockElement) ~= "function"
    then
        return nil
    end

    return ellesmereUI
end

local function RegisterFrame(frame)
    local ellesmereUI = GetEllesmereUI()
    local id = NS.Adapter:GetFrameID(frame)

    if not ellesmereUI or not id or registeredIDs[id] then
        return
    end

    local key = "ChattynatorMonkeypatch_Window" .. id
    local element = ellesmereUI.MakeUnlockElement({
        key = key,
        label = "Chattynator Chat " .. id,
        group = "Chat",
        order = 650 + id,
        getFrame = function()
            return NS.Adapter:GetFrame(id)
        end,
        getSize = function()
            return NS.Geometry:GetSize(id)
        end,
        savePos = function(_, point, relativePoint, x, y)
            NS.Geometry:SavePosition(id, point, relativePoint, x, y)
        end,
        loadPos = function()
            return NS.Geometry:GetPosition(id)
        end,
        clearPos = function()
            NS.Geometry:Reset(id)
        end,
        applyPos = function()
            local currentFrame = NS.Adapter:GetFrame(id)

            if currentFrame then
                NS.Geometry:ApplyToFrame(currentFrame)
            end
        end,
        setWidth = function(_, width)
            NS.Geometry:SetWidth(id, width)
        end,
        setHeight = function(_, height)
            NS.Geometry:SetHeight(id, height)
        end,
        isHidden = function()
            return NS.Adapter:GetFrame(id) == nil
        end,
    })

    ellesmereUI:RegisterUnlockElements({element}, ADDON_NAME)
    registeredIDs[id] = true
end

function Unlock:RegisterAvailableFrames()
    for _, frame in ipairs(NS.Adapter:GetFrames()) do
        RegisterFrame(frame)
    end
end

function Unlock:Initialize()
    if initialized then
        return
    end

    initialized = true
    local ellesmereUI = GetEllesmereUI()

    if not ellesmereUI then
        return
    end

    if type(ellesmereUI.RegisterUnlockModeListener) == "function" then
        ellesmereUI:RegisterUnlockModeListener(ADDON_NAME, function(active)
            if active then
                NS:RefreshIntegration(true)
            else
                NS.Geometry:ApplyAll()
            end
        end)
    end
end

function Unlock:IsAvailable()
    return GetEllesmereUI() ~= nil
end
