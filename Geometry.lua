local ADDON_NAME, NS = ...

local Geometry = {}
NS.Geometry = Geometry

local validPoints = {
    TOPLEFT = true,
    TOP = true,
    TOPRIGHT = true,
    LEFT = true,
    CENTER = true,
    RIGHT = true,
    BOTTOMLEFT = true,
    BOTTOM = true,
    BOTTOMRIGHT = true,
}

local pendingApply = false

local function Clamp(value, minimum, maximum)
    if minimum and value < minimum then
        value = minimum
    end

    if maximum and maximum > 0 and value > maximum then
        value = maximum
    end

    return value
end

local function NormalizePoint(point)
    return validPoints[point] and point or "CENTER"
end

local function ApproximatelyEqual(left, right)
    return math.abs(left - right) < 0.01
end

local function ReadPosition(frame)
    local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)

    if point and (relativeTo == nil or relativeTo == UIParent) and type(x) == "number" and type(y) == "number" then
        return NormalizePoint(point), NormalizePoint(relativePoint or point), x, y
    end

    local frameX, frameY = frame:GetCenter()
    local parentX, parentY = UIParent:GetCenter()

    if frameX and frameY and parentX and parentY then
        local frameScale = frame:GetEffectiveScale()
        local parentScale = UIParent:GetEffectiveScale()
        local centerX = (frameX * frameScale - parentX * parentScale) / parentScale
        local centerY = (frameY * frameScale - parentY * parentScale) / parentScale
        return "CENTER", "CENTER", centerX, centerY
    end

    return "CENTER", "CENTER", 0, 0
end

local function ReadGeometry(frame)
    local point, relativePoint, x, y = ReadPosition(frame)
    local width, height = frame:GetSize()

    return {
        point = point,
        relativePoint = relativePoint,
        x = x,
        y = y,
        width = width,
        height = height,
    }
end

local function CanChangeGeometry()
    return not InCombatLockdown()
end

local function PersistUpstream(frame)
    NS.Adapter:SaveUpstreamPosition(frame)
    NS.Adapter:SaveUpstreamSize(frame)
end

function Geometry:Attach(frame)
    local id = NS.Adapter:GetFrameID(frame)

    if id then
        NS.Database:CaptureOriginalGeometry(id, ReadGeometry(frame))
    end
end

function Geometry:ApplyToFrame(frame)
    local id = NS.Adapter:GetFrameID(frame)
    local saved = id and NS.Database:GetGeometry(id)

    if not saved then
        return
    end

    if not CanChangeGeometry() then
        pendingApply = true
        return
    end

    if type(saved.width) == "number" and type(saved.height) == "number" then
        local minWidth, minHeight, maxWidth, maxHeight = frame:GetResizeBounds()
        local width = Clamp(saved.width, minWidth, maxWidth)
        local height = Clamp(saved.height, minHeight, maxHeight)

        if not ApproximatelyEqual(frame:GetWidth(), width) or not ApproximatelyEqual(frame:GetHeight(), height) then
            frame:SetSize(width, height)
        end
    end

    local point = NormalizePoint(saved.point)
    local relativePoint = NormalizePoint(saved.relativePoint or saved.point)
    local x = tonumber(saved.x) or 0
    local y = tonumber(saved.y) or 0
    local currentPoint, currentRelativeTo, currentRelativePoint, currentX, currentY = frame:GetPoint(1)
    local positionChanged = currentPoint ~= point
        or currentRelativeTo ~= UIParent
        or currentRelativePoint ~= relativePoint
        or type(currentX) ~= "number"
        or type(currentY) ~= "number"
        or not ApproximatelyEqual(currentX, x)
        or not ApproximatelyEqual(currentY, y)

    if positionChanged then
        frame:ClearAllPoints()
        frame:SetPoint(point, UIParent, relativePoint, x, y)
    end

    PersistUpstream(frame)
end

function Geometry:ApplyAll()
    for _, frame in ipairs(NS.Adapter:GetFrames()) do
        self:ApplyToFrame(frame)
    end
end

function Geometry:ApplyPending()
    if pendingApply then
        pendingApply = false
        self:ApplyAll()
    end
end

function Geometry:GetPosition(id)
    local frame = NS.Adapter:GetFrame(id)
    local saved = NS.Database:GetGeometry(id)

    if saved then
        return {
            point = NormalizePoint(saved.point),
            relPoint = NormalizePoint(saved.relativePoint or saved.point),
            x = tonumber(saved.x) or 0,
            y = tonumber(saved.y) or 0,
        }
    end

    if frame then
        local point, relativePoint, x, y = ReadPosition(frame)
        return {point = point, relPoint = relativePoint, x = x, y = y}
    end

    return nil
end

function Geometry:GetSize(id)
    local frame = NS.Adapter:GetFrame(id)

    if frame then
        return frame:GetWidth(), frame:GetHeight()
    end

    local saved = NS.Database:GetGeometry(id) or NS.Database:GetOriginalGeometry(id)

    if saved then
        return saved.width, saved.height
    end

    return 1, 1
end

function Geometry:SavePosition(id, point, relativePoint, x, y)
    local frame = NS.Adapter:GetFrame(id)

    if not frame then
        return
    end

    local geometry = NS.Database:GetGeometry(id) or ReadGeometry(frame)
    geometry.point = NormalizePoint(point)
    geometry.relativePoint = NormalizePoint(relativePoint or point)
    geometry.x = tonumber(x) or 0
    geometry.y = tonumber(y) or 0
    geometry.width, geometry.height = frame:GetSize()
    NS.Database:SetGeometry(id, geometry)
    self:ApplyToFrame(frame)
end

function Geometry:SetWidth(id, width)
    local frame = NS.Adapter:GetFrame(id)

    if not frame or type(width) ~= "number" then
        return
    end

    local minWidth, _, maxWidth = frame:GetResizeBounds()
    local geometry = NS.Database:GetGeometry(id) or ReadGeometry(frame)
    geometry.width = Clamp(width, minWidth, maxWidth)
    geometry.height = frame:GetHeight()
    NS.Database:SetGeometry(id, geometry)
    self:ApplyToFrame(frame)
end

function Geometry:SetHeight(id, height)
    local frame = NS.Adapter:GetFrame(id)

    if not frame or type(height) ~= "number" then
        return
    end

    local _, minHeight, _, maxHeight = frame:GetResizeBounds()
    local geometry = NS.Database:GetGeometry(id) or ReadGeometry(frame)
    geometry.width = frame:GetWidth()
    geometry.height = Clamp(height, minHeight, maxHeight)
    NS.Database:SetGeometry(id, geometry)
    self:ApplyToFrame(frame)
end

function Geometry:Reset(id)
    NS.Database:ResetGeometry(id)

    local frame = NS.Adapter:GetFrame(id)

    if frame then
        self:ApplyToFrame(frame)
    end
end
