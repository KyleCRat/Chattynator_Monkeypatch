local ADDON_NAME, NS = ...

function NS:Print(message)
    print(("|cff0cd29f%s|r %s"):format(ADDON_NAME, message))
end

function NS:RefreshIntegration(applyGeometry)
    local frames = self.Adapter:Scan()

    for _, frame in ipairs(frames) do
        self.Geometry:Attach(frame)
        self.Background:Attach(frame)
    end

    self.Unlock:RegisterAvailableFrames()

    if applyGeometry then
        self.Geometry:ApplyAll()
    end

    self.Background:ApplyAll()
    return #frames
end

local handlers = {}
local eventFrame = CreateFrame("Frame")

handlers.ADDON_LOADED = function(self, loadedAddon)
    if loadedAddon ~= ADDON_NAME then
        return
    end

    self:UnregisterEvent("ADDON_LOADED")
    NS.Database:Initialize()
    NS.Settings:Register()
    NS.Unlock:Initialize()

    local count = NS:RefreshIntegration(true)

    if count == 0 then
        C_Timer.After(0, function()
            NS:RefreshIntegration(true)
        end)
    end

    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
end

handlers.PLAYER_ENTERING_WORLD = function()
    C_Timer.After(0, function()
        NS:RefreshIntegration(true)
    end)
end

handlers.PLAYER_REGEN_ENABLED = function()
    NS.Geometry:ApplyPending()
end

eventFrame:SetScript("OnEvent", function(self, event, ...)
    handlers[event](self, ...)
end)
eventFrame:RegisterEvent("ADDON_LOADED")
