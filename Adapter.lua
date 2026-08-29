local ADDON_NAME, NS = ...

local Adapter = {}
NS.Adapter = Adapter

local frames = {}
local framesByID = {}

local function IsFrameObject(value)
    return value
        and type(value.IsObjectType) == "function"
        and value:IsObjectType("Frame")
end

local function GetFrameID(frame)
    local id = tonumber(frame:GetID())

    if not id or id < 1 then
        return nil
    end

    return math.floor(id)
end

local function IsChattynatorWindow(frame)
    if not IsFrameObject(frame) then
        return false
    end

    local wrapper = frame.ScrollingMessagesWrapper
    local tabs = frame.TabsBar
    local buttons = frame.ButtonsBar

    return IsFrameObject(wrapper)
        and IsFrameObject(tabs)
        and IsFrameObject(buttons)
        and type(frame.SetBackgroundColor) == "function"
        and GetFrameID(frame) ~= nil
end

local function AddCandidate(results, seen, frame)
    if not seen[frame] and IsChattynatorWindow(frame) then
        seen[frame] = true
        results[#results + 1] = frame
    end
end

local function ScanKnownRoot(results, seen)
    local root = _G.ChattynatorHyperlinkHandler

    if not IsFrameObject(root) then
        return
    end

    local children = {root:GetChildren()}

    for _, child in ipairs(children) do
        AddCandidate(results, seen, child)
    end
end

local function ScanAllFrames(results, seen)
    if type(EnumerateFrames) ~= "function" then
        return
    end

    local frame = EnumerateFrames()

    while frame do
        AddCandidate(results, seen, frame)
        frame = EnumerateFrames(frame)
    end
end

function Adapter:Scan()
    local results = {}
    local seen = {}

    ScanKnownRoot(results, seen)

    if #results == 0 then
        ScanAllFrames(results, seen)
    end

    table.sort(results, function(left, right)
        return GetFrameID(left) < GetFrameID(right)
    end)

    wipe(frames)
    wipe(framesByID)

    for _, frame in ipairs(results) do
        local id = GetFrameID(frame)
        frames[#frames + 1] = frame
        framesByID[id] = frame
    end

    return frames
end

function Adapter:GetFrames()
    return frames
end

function Adapter:GetFrame(id)
    return framesByID[tonumber(id)]
end

function Adapter:GetFrameID(frame)
    return GetFrameID(frame)
end

function Adapter:GetBackgroundAnchor(frame)
    if IsChattynatorWindow(frame) then
        return frame.ScrollingMessagesWrapper
    end

    return nil
end

function Adapter:GetNativeBackgroundTexture(frame)
    local function IsTexture(candidate)
        return candidate
            and type(candidate.IsObjectType) == "function"
            and candidate:IsObjectType("Texture")
    end

    if IsTexture(frame.background) then
        return frame.background
    end

    if IsTexture(frame.backgroundTex) then
        return frame.backgroundTex
    end

    if frame.visuals and IsTexture(frame.visuals.backgroundTex) then
        return frame.visuals.backgroundTex
    end

    return nil
end

function Adapter:SaveUpstreamPosition(frame)
    if type(frame.SavePosition) == "function" then
        pcall(frame.SavePosition, frame)
    end
end

function Adapter:SaveUpstreamSize(frame)
    if type(frame.SaveSize) == "function" then
        pcall(frame.SaveSize, frame)
    end
end
