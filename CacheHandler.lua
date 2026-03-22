-- Cache Variables.
WGLCache = {}
WGL_Request_Cache = {}
WGLCache_RetryTime = 2
WGLCache_MaxRetries = 5
WGLCache_Frequency = 0.5

WGLCacheCurrentQuery = nil
WGLCacheCacheStage = {
    Sent = 1,    -- Inspect has been sent, waiting for a response.
    Queued = 2,  -- Waiting for the previous query to finish.
    Finished = 3, -- The item has been received. This will only show if for some reason something broke with handling the item.
    Failed = 4    -- The inspect failed.
}
-- Create a debug frame with two sections: Cache Queue (top) and Debug Log (bottom).
CacheDebugFrame = CreateFrame("Frame", "WGLCacheDebugFrame", UIParent)
CacheDebugFrame:SetSize(400, 450)
CacheDebugFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
CacheDebugFrame:SetMovable(true)
CacheDebugFrame:EnableMouse(true)
CacheDebugFrame:RegisterForDrag("LeftButton")
CacheDebugFrame:SetClampedToScreen(true)
CacheDebugFrame:SetScript("OnDragStart", CacheDebugFrame.StartMoving)
CacheDebugFrame:SetScript("OnDragStop", CacheDebugFrame.StopMovingOrSizing)
CacheDebugFrame:SetFrameStrata("HIGH")
CacheDebugFrame:SetResizable(true)
CacheDebugFrame:SetResizeBounds(250, 200, 800, 800)
CacheDebugFrame:Hide()

-- Resize grip at bottom-right corner
local resizeGrip = CreateFrame("Button", nil, CacheDebugFrame)
resizeGrip:SetSize(16, 16)
resizeGrip:SetPoint("BOTTOMRIGHT", 0, 0)
resizeGrip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
resizeGrip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
resizeGrip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
resizeGrip:RegisterForDrag("LeftButton")
resizeGrip:SetScript("OnDragStart", function() CacheDebugFrame:StartSizing("BOTTOMRIGHT") end)
resizeGrip:SetScript("OnDragStop", function() CacheDebugFrame:StopMovingOrSizing() end)

CacheDebugFrame.BG = CacheDebugFrame:CreateTexture(nil, "BACKGROUND")
CacheDebugFrame.BG:SetAllPoints()
CacheDebugFrame.BG:SetColorTexture(0, 0, 0, 0.7)

-- Top section: Cache Queue
CacheDebugFrame.Title = CacheDebugFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
CacheDebugFrame.Title:SetPoint("TOPLEFT", 10, -10)
CacheDebugFrame.Title:SetText("|cFF00CCFFWGL Debug|r")
CacheDebugFrame.Title:SetJustifyH("LEFT")

CacheDebugFrame.CacheLabel = CacheDebugFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
CacheDebugFrame.CacheLabel:SetPoint("TOPLEFT", 10, -28)
CacheDebugFrame.CacheLabel:SetText("|cFFFFFF00Cache Queue|r")
CacheDebugFrame.CacheLabel:SetJustifyH("LEFT")

-- Scroll frame for cache queue (5 lines high)
local cacheScrollFrame = CreateFrame("ScrollFrame", "WGLCacheQueueScrollFrame", CacheDebugFrame, "UIPanelScrollFrameTemplate")
cacheScrollFrame:SetPoint("TOPLEFT", 10, -44)
cacheScrollFrame:SetPoint("RIGHT", CacheDebugFrame, "RIGHT", -30, 0)
cacheScrollFrame:SetHeight(60)

local cacheScrollChild = CreateFrame("Frame", nil, cacheScrollFrame)
cacheScrollChild:SetSize(340, 1)
cacheScrollFrame:SetScrollChild(cacheScrollChild)

CacheDebugFrame.Text = cacheScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
CacheDebugFrame.Text:SetPoint("TOPLEFT", 0, 0)
CacheDebugFrame.Text:SetPoint("RIGHT", cacheScrollChild, "RIGHT", 0, 0)
CacheDebugFrame.Text:SetText("")
CacheDebugFrame.Text:SetJustifyH("LEFT")
CacheDebugFrame.Text:SetWordWrap(true)

CacheDebugFrame.CacheScrollChild = cacheScrollChild

-- Divider line
CacheDebugFrame.Divider = CacheDebugFrame:CreateTexture(nil, "ARTWORK")
CacheDebugFrame.Divider:SetHeight(1)
CacheDebugFrame.Divider:SetPoint("LEFT", 10, 0)
CacheDebugFrame.Divider:SetPoint("RIGHT", -10, 0)
CacheDebugFrame.Divider:SetPoint("TOP", 0, -110)
CacheDebugFrame.Divider:SetColorTexture(0.4, 0.4, 0.4, 0.8)

-- Bottom section: Debug Log
CacheDebugFrame.LogLabel = CacheDebugFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
CacheDebugFrame.LogLabel:SetPoint("TOPLEFT", 10, -118)
CacheDebugFrame.LogLabel:SetText("|cFFFFFF00Debug Log|r")
CacheDebugFrame.LogLabel:SetJustifyH("LEFT")

-- Scroll frame for debug log
local scrollFrame = CreateFrame("ScrollFrame", "WGLDebugLogScrollFrame", CacheDebugFrame, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", 10, -134)
scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)

local scrollChild = CreateFrame("Frame", nil, scrollFrame)
scrollChild:SetSize(360, 1)
scrollFrame:SetScrollChild(scrollChild)

local logText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
logText:SetPoint("TOPLEFT", 0, 0)
logText:SetPoint("RIGHT", scrollChild, "RIGHT", 0, 0)
logText:SetJustifyH("LEFT")
logText:SetWordWrap(true)
logText:SetText("")

-- Keep scroll child width in sync when frame is resized
scrollFrame:SetScript("OnSizeChanged", function(self, width, height)
	scrollChild:SetWidth(width)
end)

-- Store references for WGLU.AddDebugLog to use
WGLU.DebugLogText = logText
WGLU.DebugLogScrollFrame = scrollFrame
WGLU.DebugLogScrollChild = scrollChild


-- This is called when an item that another player is wearing hasn't been cached by the client.
-- We're going to add in the request data to the cache.
-- Each entry is basically an attempt to try GetInventoryItemLink until it no longer returns nil, then update the frame it was shown on.
function WGLCache.CreateRequest(unitName, request)

    local playerGUID = UnitGUID(unitName)
    if playerGUID then
        request.Time = 0
        request.Tries = 0
        request.UnitName = unitName
        request.PlayerGUID = playerGUID
        
        -- Generate a random ID
        local ID = math.floor(GetTime())
        
        -- Make sure we don't already have this ID.
        while WGL_Request_Cache[ID] do ID = ID + 1 end
        request.ID = ID

        -- Add the request to the cache.
        WGL_Request_Cache[ID] = request
        
        -- If we're not currently querying, then we can send the inspect request.
        if WGLCacheCurrentQuery == nil then
            WGLCacheCurrentQuery = request
            NotifyInspect(unitName)
            request.QueryStage = WGLCacheCacheStage.Sent
        else
            WGLU.DebugPrint("Can't queue now, waiting for " .. playerGUID)
            request.QueryStage = WGLCacheCacheStage.Queued
        end

        UpdateQueueDebugList()
        return ID
    end
end

local function PrepareNextQuery()
    WGLCacheCurrentQuery = nil
    for ID, request in pairs(WGL_Request_Cache) do
        if request.QueryStage == WGLCacheCacheStage.Queued then
            WGLCacheCurrentQuery = request
            NotifyInspect(request.UnitName)
            request.QueryStage = WGLCacheCacheStage.Sent
            break
        end
    end
end

function WGLCache.RemoveRequest(ID)
    if WGL_Request_Cache[ID] then WGL_Request_Cache[ID] = nil end

    -- If we've removed the current query, then we can prepare the next one.
    if WGLCacheCurrentQuery and WGLCacheCurrentQuery["ID"] == ID then
        PrepareNextQuery()
    end
end

local function GetLowestItemLink(unitName, slot1, slot2)
    local itemLink1 = GetInventoryItemLink(unitName, slot1)
    local itemLink2 = GetInventoryItemLink(unitName, slot2)

    if itemLink1 and itemLink2 then
        local itemLevel1 = C_Item.GetDetailedItemLevelInfo(itemLink1)
        local itemLevel2 = C_Item.GetDetailedItemLevelInfo(itemLink2)
        return itemLevel1 < itemLevel2 and itemLink1 or itemLink2
    end
    return nil
end

-- TODO: This was using the old text, need to update it to use the new text.
local function SetText(request, text, itemLevel)
    if not request.Frame then return end
    request.Frame.LoadingIcon:FadeOut()
end

local function HandleInspections(fromTimer)
    local keysToRemove = {}

    for ID, request in pairs(WGL_Request_Cache) do
        if request.QueryStage == WGLCacheCacheStage.Sent then
            if fromTimer then
                request.Time = request.Time + WGLCache_Frequency
            end

            -- Keep updating the unit name, in case people leave/join
            request.UnitName = WGLU.GetPlayerUnitByGUID(request.PlayerGUID)

            -- Attempt to get the item link.
            if request.UnitName and request.QueryStage ~= WGLCacheCacheStage.Finished then
                local itemLink
                if request.ItemLocation == INVSLOT_FINGER1 or request.ItemLocation == INVSLOT_FINGER2 then
                    itemLink = GetLowestItemLink(request.UnitName, INVSLOT_FINGER1, INVSLOT_FINGER2)
                elseif request.ItemLocation == INVSLOT_TRINKET1 or request.ItemLocation == INVSLOT_TRINKET2 then
                    itemLink = GetLowestItemLink(request.UnitName, INVSLOT_TRINKET1, INVSLOT_TRINKET2)
                else
                    itemLink = GetInventoryItemLink(request.UnitName, request.ItemLocation)
                end

                if itemLink then
                    table.insert(keysToRemove, ID)
                    request.QueryStage = WGLCacheCacheStage.Finished

                    local theirItemLevel = C_Item.GetDetailedItemLevelInfo(itemLink)

                    -- Get upgrade text from UIBuilder - pass their item level first, then the dropped item level
                    local upgradeText = WhoLootData.MainFrame:SetItemUpgradeStatus(request, theirItemLevel)
                    
                    if theirItemLevel < request.ItemLevel then
                        WGLUIBuilder.AddStatToBreakdown(request.Frame, "|cFFFFFFFFThem: |cFFe28743" .. upgradeText .. "|r", "prepend", nil, 2, "primary")
                    else
                        if request.GoodForPlayer then
                            WGLUIBuilder.AddStatToBreakdown(request.Frame, "|cFFFFFFFFThem:|r |cFFb7d672" .. upgradeText, "prepend", nil, 2, "primary")
                        else
                            WGLUIBuilder.AddStatToBreakdown(request.Frame, "|cFFFFFFFFThem:|r " .. upgradeText, "prepend", nil, 2, "primary")
                        end
                    end

                    request.Frame.LoadingIcon:FadeOut()
                    UpdateQueueDebugList()
                end
            end

            if not request.UnitName then
                table.insert(keysToRemove, ID)
                SetText(request, "Couldn't find player")
            end

            if request.QueryStage == WGLCacheCacheStage.Failed then
                table.insert(keysToRemove, ID)
                SetText(request, "Inspect timed out")
            end

            -- If we've been waiting for a while, then we'll retry the inspect.
            if request.Time > WGLCache_RetryTime and request.UnitName and request.QueryStage ~= WGLCacheCacheStage.Finished then
                if CanInspect(request.UnitName) then
                    WGLU.DebugPrint("Can inspect " .. request.UnitName)
                    request.Tries = request.Tries + 1
                    request.Time = 0

                    if request.Tries < WGLCache_MaxRetries then
                        NotifyInspect(request.UnitName)
                        WGLU.DebugPrint("Retrying inspect for " .. request.UnitName)
                    else
                        table.insert(keysToRemove, ID)
                        SetText(request, "Inspect timed out.")
                        request.QueryStage = WGLCacheCacheStage.Failed
                        ClearInspectPlayer()
                    end
                else
                    WGLU.DebugPrint("Can't inspect " .. request.UnitName)
                end
            end
        end
    end

    UpdateQueueDebugList()
    for _, ID in ipairs(keysToRemove) do
        WGLCache.RemoveRequest(ID)
    end
end



-- Create a frame that handles the GET_ITEM_INFO_RECEIVED event.
-- This event is fired when the client receives information about an item from the server.
-- We'll use this event to update the item frame's bottom text with the item's stats.
local CacheHandler = CreateFrame("Frame")
CacheHandler:RegisterEvent("INSPECT_READY")

CacheHandler:SetScript("OnEvent", function(self, event, ...)
    if event == "INSPECT_READY" then
        HandleInspections(false)
    end
end)

-- Maintain a second list of requests that we can use to debug the cache.
-- We want these to expire slower than the actual cache requests.
-- We'll update this list every 1 second.
WGL_Request_Debug_Cache = {}

function UpdateQueueDebugList()

    if WGLU.DebugMode then CacheDebugFrame:Show() else CacheDebugFrame:Hide() end
    if WGLU.DebugMode == false then return end

    -- Copy the cache requests to the debug cache, except time.
    for ID, request in pairs(WGL_Request_Cache) do
        if not WGL_Request_Debug_Cache[ID] then
            WGL_Request_Debug_Cache[ID] = {
                UnitName = request.UnitName and UnitName(request.UnitName) or "Unknown",
                ItemLocation = request.ItemLocation,
                ItemLevel = request.ItemLevel,
                QueryStage = request.QueryStage,
                Time = 0
            }
        else
            WGL_Request_Debug_Cache[ID].UnitName = UnitName(request.UnitName)
            WGL_Request_Debug_Cache[ID].ItemLocation = request.ItemLocation
            WGL_Request_Debug_Cache[ID].ItemLevel = request.ItemLevel
            WGL_Request_Debug_Cache[ID].QueryStage = request.QueryStage
        end
    end

    local cacheLines = {}
    for ID, request in pairs(WGL_Request_Debug_Cache) do
        local stageNames = {
            [WGLCacheCacheStage.Sent] = "|cFFFFFF00Sent|r",
            [WGLCacheCacheStage.Queued] = "|cFFAAAAAQueued|r",
            [WGLCacheCacheStage.Finished] = "|cFF00FF00Finished|r"
        }
        local stageName = stageNames[request.QueryStage] or "Unknown"
        local text = "|cFFFFFFFFUnit:|r " .. request.UnitName .. " |cFFFFFFFFSlot:|r " .. request.ItemLocation .. " |cFFFFFFFFilvl:|r " .. request.ItemLevel .. " |cFFFFFFFFStage:|r " .. stageName
        table.insert(cacheLines, text)

        request.Time = request.Time + WGLCache_Frequency
    end
    local cacheText = #cacheLines > 0 and table.concat(cacheLines, "\n") or "|cFF666666(empty)|r"
    CacheDebugFrame.Text:SetText(cacheText)
    CacheDebugFrame.CacheScrollChild:SetHeight(CacheDebugFrame.Text:GetStringHeight() + 4)

    -- Remove any entries whose time is above 20 seconds.
    for ID, request in pairs(WGL_Request_Debug_Cache) do
        if request.Time > 60 then WGL_Request_Debug_Cache[ID] = nil end
    end

end

-- Register a timer to the frame, that will check for requests every 1 seconds.
CacheHandler:SetScript("OnUpdate", function(self, elapsed)
    self.TimeSinceLastUpdate = (self.TimeSinceLastUpdate or 0) + elapsed
    if self.TimeSinceLastUpdate > WGLCache_Frequency then
        self.TimeSinceLastUpdate = 0
        HandleInspections(true)

        UpdateQueueDebugList()
    end
end)
