local ADDON_NAME, NS = ...

local Adapter = {}
NS.Adapter = Adapter

local frames = {}
local movableFrames = {}
local framesByID = {}
local COPY_FRAME_ID = "CopyChat"
local copyFrame
local COPY_MESSAGE_LIMIT = 1000
local copyPatches = setmetatable({}, {__mode = "k"})
local messageSource

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
    wipe(movableFrames)
    wipe(framesByID)

    for _, frame in ipairs(results) do
        local id = GetFrameID(frame)
        frames[#frames + 1] = frame
        movableFrames[#movableFrames + 1] = frame
        framesByID[id] = frame
    end

    -- Copy Chat is movable, but is not a chat window: do not pass it to the
    -- background patches or include it in the reported chat-window count.
    copyFrame = nil
    local dialog = _G.ChattynatorCopyChatDialog

    if IsFrameObject(dialog)
        and type(dialog.LoadMessages) == "function"
        and IsFrameObject(dialog.textBox)
    then
        copyFrame = dialog
        movableFrames[#movableFrames + 1] = dialog
        framesByID[COPY_FRAME_ID] = dialog
    end

    return frames
end

function Adapter:GetFrames()
    return frames
end

function Adapter:GetMovableFrames()
    return movableFrames
end

function Adapter:GetFrame(id)
    return framesByID[tonumber(id) or id]
end

function Adapter:GetFrameID(frame)
    if copyFrame and frame == copyFrame then
        return COPY_FRAME_ID
    end

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

function Adapter:InstallCopyDragging()
    if InCombatLockdown() then
        return false
    end

    local title = copyFrame and copyFrame.TitleContainer
    local closeButton = copyFrame and copyFrame.CloseButton

    if not IsFrameObject(title) or not IsFrameObject(closeButton) or closeButton:IsProtected() then
        return false
    end

    -- Hiding the portrait expands TitleContainer across the close button.
    -- Once the title accepts mouse input, its higher frame level intercepts
    -- those clicks unless the native close button is placed above it.
    local titleLevel = title:GetFrameLevel()

    if closeButton:GetFrameLevel() <= titleLevel then
        closeButton:SetFrameLevel(titleLevel + 1)
    end

    -- Keep the native close handler and text/scroll input unchanged.
    return NS.Geometry:AttachDragHandle(copyFrame, title)
end

function Adapter:InstallCopyScrollBar()
    -- Creating the control and reserving its gutter both change geometry.
    -- Core retries after combat as well as on integration refreshes.
    if InCombatLockdown() then
        return false
    end

    local dialog = _G.ChattynatorCopyChatDialog
    local textBox = IsFrameObject(dialog) and dialog.textBox

    if not IsFrameObject(textBox) or type(textBox.GetScrollBox) ~= "function" then
        return false
    end

    local scrollBox = textBox:GetScrollBox()

    if not IsFrameObject(scrollBox)
        or type(scrollBox.GetView) ~= "function"
        or not scrollBox:GetView()
        or not ScrollUtil
        or type(ScrollUtil.RegisterScrollBoxWithScrollBar) ~= "function"
        or type(ScrollUtil.InitScrollBar) ~= "function"
    then
        return false
    end

    -- This also respects a scrollbar supplied by Chattynator or another addon.
    -- ScrollUtil owns the one-to-one pairing, so refreshes cannot add duplicates.
    if scrollBox.registeredScrollBar then
        return true
    end

    local rightAnchors = {}
    local hasLeftAnchor = false

    for index = 1, textBox:GetNumPoints() do
        local point, relativeTo, relativePoint, x, y = textBox:GetPoint(index)

        if point:find("RIGHT", 1, true) then
            rightAnchors[#rightAnchors + 1] = {point, relativeTo, relativePoint, x - 24, y}
        elseif point:find("LEFT", 1, true) then
            hasLeftAnchor = true
        end
    end

    -- Leave an unfamiliar fixed-width or centered layout alone.
    if not hasLeftAnchor or #rightAnchors == 0 then
        return false
    end

    local scrollBar = CreateFrame("EventFrame", nil, dialog, "MinimalScrollBar")

    for _, anchor in ipairs(rightAnchors) do
        textBox:SetPoint(unpack(anchor, 1, 5))
    end

    scrollBar:SetPoint("TOPLEFT", textBox, "TOPRIGHT", 12, 0)
    scrollBar:SetPoint("BOTTOMLEFT", textBox, "BOTTOMRIGHT", 12, 0)

    -- Bind the already initialized native edit-box view; do not recreate it,
    -- replace its input handlers, or reformat the copied text when scrolling.
    ScrollUtil.RegisterScrollBoxWithScrollBar(scrollBox, scrollBar)
    ScrollUtil.InitScrollBar(scrollBox, scrollBar)
    scrollBar:SetScrollPercentage(scrollBox:GetScrollPercentage(), ScrollBoxConstants.NoScrollInterpolation)
    return true
end

local function IsMessageSource(frame)
    return IsFrameObject(frame)
        and type(frame.GetMessageRaw) == "function"
        and type(frame.GetMessageProcessed) == "function"
        and type(frame.ReduceMessages) == "function"
end

local function FindMessageSource()
    if IsMessageSource(messageSource) then
        return messageSource
    end

    if type(EnumerateFrames) ~= "function" then
        return nil
    end

    local frame = EnumerateFrames()

    while frame do
        if IsMessageSource(frame) then
            messageSource = frame
            return frame
        end

        frame = EnumerateFrames(frame)
    end

    return nil
end

local function CollectCopyMessages(dialog, originalLoad, source, arguments, argumentCount)
    local textBox = dialog.textBox
    local editBox = textBox:GetEditBox()
    local originalGetRaw = source.GetMessageRaw
    local originalSetText = textBox.SetText
    local originalSetFont = textBox.SetFontObject
    local originalHighlight = editBox.HighlightText
    local originalFilter = arguments[1]
    local originalOffset = arguments[2]
    local nextIndex = originalOffset or 1
    local lastIndex = nextIndex - 1
    local matched = 0
    local exhausted = false
    local reading = false
    local pageText
    local fontObject

    -- Ask the native copy method for successive pages. Its character/tab
    -- filters, modifiers, timestamps, and escape/secret cleanup remain in use.
    -- These substitutions exist only for this synchronous copy request; chat
    -- rendering, logging, and all later calls keep their original methods.
    source.GetMessageRaw = function(self, index, ...)
        if not reading then
            return originalGetRaw(self, index, ...)
        end

        if matched >= COPY_MESSAGE_LIMIT and index > lastIndex then
            return nil
        end

        local record = originalGetRaw(self, index, ...)
        lastIndex = index

        if not record then
            exhausted = true
        end

        return record
    end

    arguments[1] = function(record)
        local accepted = not originalFilter or originalFilter(record)

        if accepted then
            matched = matched + 1
        end

        return accepted
    end

    textBox.SetText = function(_, text)
        reading = false
        pageText = text
    end

    textBox.SetFontObject = function(_, font)
        reading = false
        fontObject = font
    end

    editBox.HighlightText = function()
    end

    local success, result = pcall(function()
        local pages = {}

        while matched < COPY_MESSAGE_LIMIT and not exhausted do
            local previousCount = matched
            pageText = nil
            arguments[2] = nextIndex
            reading = true
            originalLoad(dialog, unpack(arguments, 1, argumentCount))
            reading = false

            if (issecretvalue and issecretvalue(pageText)) or type(pageText) ~= "string" then
                error("Chattynator's copy output contract changed")
            end

            if matched == previousCount then
                if pageText ~= "" then
                    error("Chattynator's copy filtering contract changed")
                end

                break
            end

            if lastIndex < nextIndex or matched > COPY_MESSAGE_LIMIT then
                error("Chattynator's copy pagination contract changed")
            end

            pages[#pages + 1] = pageText
            nextIndex = lastIndex + 1
        end

        -- Each native page is already oldest-first; reverse only the page
        -- order. The edit box receives one combined update, even for 5 pages.
        for index = 1, math.floor(#pages / 2) do
            local opposite = #pages - index + 1
            pages[index], pages[opposite] = pages[opposite], pages[index]
        end

        return table.concat(pages, "\n")
    end)

    -- Restore before updating the UI or propagating any error, including a
    -- filter/formatter failure in the dependency.
    source.GetMessageRaw = originalGetRaw
    textBox.SetText = originalSetText
    textBox.SetFontObject = originalSetFont
    editBox.HighlightText = originalHighlight
    arguments[1] = originalFilter
    arguments[2] = originalOffset

    if not success then
        error(result, 0)
    end

    if fontObject then
        originalSetFont(textBox, fontObject)
    end

    originalSetText(textBox, result)
    originalHighlight(editBox, 0, #editBox:GetText())
end

function Adapter:InstallCopyMessagesPatch()
    local dialog = _G.ChattynatorCopyChatDialog

    if not IsFrameObject(dialog) or type(dialog.LoadMessages) ~= "function" then
        return false
    end

    local existing = copyPatches[dialog]

    if existing then
        -- Do not stack wrappers if another addon takes ownership later.
        return dialog.LoadMessages == existing.wrapper and not existing.disabled
    end

    local textBox = dialog.textBox

    if not textBox
        or type(textBox.GetEditBox) ~= "function"
        or type(textBox.SetText) ~= "function"
        or type(textBox.SetFontObject) ~= "function"
    then
        return false
    end

    local editBox = textBox:GetEditBox()
    local source = FindMessageSource()

    if not source or not editBox
        or type(editBox.HighlightText) ~= "function"
        or type(editBox.GetText) ~= "function"
    then
        return false
    end

    local originalLoad = dialog.LoadMessages
    local patch = {active = false, disabled = false}
    patch.wrapper = function(self, ...)
        if patch.active or patch.disabled then
            return originalLoad(self, ...)
        end

        local arguments = {...}
        local argumentCount = math.max(2, select("#", ...))
        patch.active = true
        local success = pcall(CollectCopyMessages, self, originalLoad, source, arguments, argumentCount)
        patch.active = false

        if not success then
            patch.disabled = true
            NS:Print("Expanded Copy Messages is unavailable; using Chattynator's normal copy limit until reload.")
            return originalLoad(self, ...)
        end
    end

    copyPatches[dialog] = patch
    dialog.LoadMessages = patch.wrapper
    return true
end
