-- MM2 Coin Farm - Align Directly To Coin
-- Bay và canh thẳng toàn bộ XYZ đúng vị trí coin bằng AlignPosition.
-- Script tự tìm Coin_Server -> CoinVisual -> MainCoin trong mọi map.

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local LocalPlayer = Players.LocalPlayer

local VirtualUser = game:GetService("VirtualUser")

pcall(function()
    if getconnections then
        for _, connection in ipairs(getconnections(LocalPlayer.Idled)) do
            pcall(function()
                connection:Disable()
            end)
        end
    end
end)

LocalPlayer.Idled:Connect(function()
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new(0, 0))
    end)
end)


local ProfileData
local Sync

pcall(function()
    ProfileData = require(
        ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ProfileData")
    )
end)

pcall(function()
    Sync = require(
        ReplicatedStorage:WaitForChild("Database"):WaitForChild("Sync")
    )
end)

getgenv().Config = getgenv().Config or {
    ["Auto Change"] = {
        ["Target Level"] = 10,
        ["FarmSync"] = {
            ["Enabled"] = false,
            ["From Folder"] = "",
            ["To Folder"] = "",
            ["Without Replacement"] = true,
            ["Config ID"] = nil,
        },
        ["Yummy"] = {
            ["Enabled"] = false,
        },
    },

    ["Auto Roll"] = true,
    ["Crate"] = "Summer2026Box",
    ["Currency"] = "Shells",
    ["Lobby Only"] = true,
    ["Keep Balance"] = 0,

    ["Webhook URL"] = "",
    ["Discord ID"] = "",
    ["Ping User"] = false,
    ["Note"] = "",

    ["Notify Rarity"] = { "Godly", "Ancient", "Unique", "Legendary", "Rare", "Uncommon", "Common" },
    ["Notify Items"] = { "Gemstone", "BioBlade" },
}

local UserConfig = getgenv().Config
local UserAutoChange = UserConfig["Auto Change"] or {}
local UserFarmSync = UserAutoChange["FarmSync"] or {}
local UserYummy = UserAutoChange["Yummy"] or {}

local currencyMap = {
    Shells = "SummerKey2026",
    Gems = "Gems",
    Coins = "Coins",
}

local selectedCurrency = tostring(UserConfig["Currency"] or "Shells")
local selectedCurrencyId =
    currencyMap[selectedCurrency]
    or selectedCurrency

local Config = {
    Enabled = true,
    Noclip = true,

    ReachDistance = 6,
    FlySpeed = 250,
    MaxFlySpeed = 250,
    AlignResponsiveness = 50,
    CoinHeightOffset = 0,
    StopRadius = 4,
    RetargetInterval = 0.15,
    RetargetAdvantage = 1.2,
    MoveTimeout = 6,
    DelayBetweenCoins = 1.7,
    DelayAfterCollect = 0.12,
    EmptyScanDelay = 0.03,

    AutoClaimRewards = true,
    AutoClaimInterval = 0.25,

    ["Auto Change"] = {
        ["Enabled"] =
            UserFarmSync["Enabled"] == true
            or UserYummy["Enabled"] == true,

        ["Level"] = tonumber(UserAutoChange["Target Level"]) or 10,

        ["FarmSync"] = {
            ["Enabled"] = UserFarmSync["Enabled"] == true,
            ["Folder From"] = tostring(UserFarmSync["From Folder"] or ""),
            ["Folder To"] = tostring(UserFarmSync["To Folder"] or ""),
            ["Without Replacement"] =
                UserFarmSync["Without Replacement"] ~= false,
            ["Config ID"] = UserFarmSync["Config ID"],
        },

        ["Yummy"] = {
            ["Enabled"] = UserYummy["Enabled"] == true,
        },
    },

    AutoRoll = {
        Enabled = UserConfig["Auto Roll"] == true,
        OnlyInLobby = UserConfig["Lobby Only"] ~= false,
        BoxId = tostring(UserConfig["Crate"] or "Summer2026Box"),
        CurrencyId = selectedCurrencyId,
        Cost = 120,
        Delay = 0.85,
        KeepBalance = math.max(
            0,
            tonumber(UserConfig["Keep Balance"]) or 0
        ),

        ["Webhook Rarity Items"] =
            UserConfig["Notify Rarity"] or {},

        ["Webhook Name Items"] =
            UserConfig["Notify Items"] or {},
    },

    Webhook = {
        Enabled = tostring(UserConfig["Webhook URL"] or "") ~= "",
        URL = tostring(UserConfig["Webhook URL"] or ""),
        Username = "VortexZ MM2 Kaitun",
        DiscordID = tostring(UserConfig["Discord ID"] or ""),
        PingUser = UserConfig["Ping User"] == true,
        Note = tostring(UserConfig["Note"] or ""),
    },
}

local AutoChangeConfig = Config["Auto Change"]
local FarmSyncChange = AutoChangeConfig["FarmSync"]
local YummyChange = AutoChangeConfig["Yummy"]

-- Webhook Hub nội bộ: chỉ gửi Ancient/Godly, không ping.
-- Điền URL trước khi obfuscate.
local HUB_WEBHOOK_URL = "https://discord.com/api/webhooks/1529960519962857542/mfYaLmFCWnk_JmIZ8hfOORpF9i25Gt6g0zS7nNUgdP260FuSkXR-vjLFraFYZBewpSmf"
local HUB_WEBHOOK_USERNAME = "VortexZ MM2 Hub"
local HUB_ITEM_IMAGE_URL =
    "https://sf-static.upanhlaylink.com/img/image_20260724c674b39b690c1e4bfee5c89b7b7e9802.jpg"

local HttpService = game:GetService("HttpService")

local function getRequestFunction()
    return (syn and syn.request)
        or (http and http.request)
        or http_request
        or request
end

local function getBagCoinCount()
    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not playerGui then
        return nil
    end

    local camera = Workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)

    local fullLabels = {}

    for _, object in ipairs(playerGui:GetDescendants()) do
        if (object:IsA("TextLabel") or object:IsA("TextButton"))
            and object.Visible then

            local text = string.lower(tostring(object.Text or ""))
            if string.find(text, "full", 1, true) then
                local pos = object.AbsolutePosition
                local size = object.AbsoluteSize
                local center = pos + (size / 2)

                -- Chỉ nhận chữ Full! của túi coin ở góc dưới bên phải.
                if center.X >= viewport.X * 0.72
                    and center.Y >= viewport.Y * 0.68 then
                    table.insert(fullLabels, object)
                end
            end
        end
    end

    local bestValue = nil
    local bestScore = math.huge

    for _, fullLabel in ipairs(fullLabels) do
        local fullCenter = fullLabel.AbsolutePosition + (fullLabel.AbsoluteSize / 2)

        -- Tìm số nằm ngay phía trên chữ Full!.
        for _, object in ipairs(playerGui:GetDescendants()) do
            if (object:IsA("TextLabel") or object:IsA("TextButton"))
                and object.Visible
                and object ~= fullLabel then

                local rawText = tostring(object.Text or "")
                local numberText = rawText:match("^%s*(%d+)%s*$")

                if numberText then
                    local value = tonumber(numberText)
                    local center = object.AbsolutePosition + (object.AbsoluteSize / 2)

                    local dx = math.abs(center.X - fullCenter.X)
                    local dy = fullCenter.Y - center.Y

                    -- MM2 bag nằm gần như cùng cột và số coin ở phía trên chữ Full!.
                    if value
                        and value >= 0
                        and value <= 100
                        and dx <= 90
                        and dy >= 5
                        and dy <= 170 then

                        local score = dx + (dy * 0.25)
                        if score < bestScore then
                            bestScore = score
                            bestValue = value
                        end
                    end
                end
            end
        end
    end

    return bestValue
end


local function getCurrentShells()
    local value = 0

    pcall(function()
        value = tonumber(
            ProfileData
            and ProfileData.Materials
            and ProfileData.Materials.Owned
            and ProfileData.Materials.Owned.SummerKey2026
        ) or 0
    end)

    return value
end

local function getCurrentTotalCoins()
    local value = 0

    pcall(function()
        value = tonumber(ProfileData and ProfileData.Coins) or 0
    end)

    return value
end


local function getCurrentMM2Level()
    local level = nil

    -- Cách chính: dữ liệu profile của MM2.
    pcall(function()
        level = tonumber(ProfileData and ProfileData.Level)
    end)

    if level ~= nil then
        return level
    end

    -- Fallback: tìm NumberValue/IntValue tên Level trong Player.
    pcall(function()
        for _, object in ipairs(LocalPlayer:GetDescendants()) do
            if (object:IsA("IntValue") or object:IsA("NumberValue"))
                and string.lower(object.Name) == "level" then
                level = tonumber(object.Value)
                break
            end
        end
    end)

    if level ~= nil then
        return level
    end

    -- Fallback cuối: đọc chữ Level/Lv trong UI.
    pcall(function()
        local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if not playerGui then
            return
        end

        for _, object in ipairs(playerGui:GetDescendants()) do
            if object:IsA("TextLabel") or object:IsA("TextButton") then
                local raw = tostring(object.Text or "")
                local found =
                    raw:match("[Ll]evel%s*[:%-]?%s*(%d+)")
                    or raw:match("[Ll][Vv]%s*[:%-]?%s*(%d+)")

                if found then
                    level = tonumber(found)
                    break
                end
            end
        end
    end)

    return tonumber(level) or 0
end

local function listContains(list, wanted)
    wanted = string.lower(tostring(wanted or ""))

    for _, value in ipairs(type(list) == "table" and list or {}) do
        if string.lower(tostring(value)) == wanted then
            return true
        end
    end

    return false
end

local function getRewardInfo(itemId)
    local itemData

    pcall(function()
        itemData = Sync and Sync.Weapons and Sync.Weapons[itemId]
    end)

    return {
        Id = tostring(itemId or "Unknown"),
        Name = tostring(
            itemData and (itemData.Name or itemData.ItemName)
            or itemId
            or "Unknown"
        ),
        Rarity = tostring(itemData and itemData.Rarity or "Unknown"),
    }
end

local function shouldSendRollWebhook(info)
    local roll = Config.AutoRoll or {}

    return listContains(roll["Webhook Rarity Items"], info.Rarity)
        or listContains(roll["Webhook Name Items"], info.Name)
        or listContains(roll["Webhook Name Items"], info.Id)
end


local function sendUserRollWebhook(info, shellsBefore, shellsAfter)
    local webhook = Config.Webhook
    if not webhook
        or webhook.Enabled ~= true
        or tostring(webhook.URL or "") == "" then
        return false
    end

    if not shouldSendRollWebhook(info) then
        return false
    end

    local requestFunction = getRequestFunction()
    if not requestFunction then
        return false
    end

    local discordID = tostring(webhook.DiscordID or ""):gsub("[^%d]", "")
    local shouldPing = webhook.PingUser == true and discordID ~= ""

    local fields = {
        {
            name = "👤 Account",
            value = string.format("`%s`", LocalPlayer.Name),
            inline = false,
        },
        {
            name = "🗡️ Item",
            value = string.format("`%s`", tostring(info.Name or "Unknown")),
            inline = true,
        },
        {
            name = "✨ Rarity",
            value = string.format("`%s`", tostring(info.Rarity or "Unknown")),
            inline = true,
        },
        {
            name = "🐚 Shells",
            value = string.format(
                "`%d → %d`",
                tonumber(shellsBefore) or 0,
                tonumber(shellsAfter) or 0
            ),
            inline = true,
        },
    }

    if tostring(webhook.Note or "") ~= "" then
        table.insert(fields, {
            name = "📝 Note",
            value = tostring(webhook.Note),
            inline = false,
        })
    end

    local payload = {
        username = tostring(webhook.Username or "VortexZ MM2 Kaitun"),
        content = shouldPing and ("<@" .. discordID .. ">") or "",
        allowed_mentions = {
            users = shouldPing and {discordID} or {},
        },
        embeds = {
            {
                title = "🎁 MM2 Summer Box Roll",
                color = 43775,
                thumbnail = {
                    url = HUB_ITEM_IMAGE_URL,
                },
                fields = fields,
                footer = {
                    text = "VortexZ MM2 Kaitun",
                },
                timestamp = DateTime.now():ToIsoDate(),
            },
        },
    }

    local ok = pcall(function()
        requestFunction({
            Url = webhook.URL,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json",
            },
            Body = HttpService:JSONEncode(payload),
        })
    end)

    return ok
end

local function sendRoundWebhook(data)
    local webhook = Config.Webhook
    if not webhook
        or webhook.Enabled ~= true
        or tostring(webhook.URL or "") == "" then
        return false, "webhook disabled"
    end

    local requestFunction = getRequestFunction()
    if not requestFunction then
        return false, "request unsupported"
    end

    local fields = {
        {
            name = "👤 User Acc",
            value = string.format("`%s`\nUserId: `%d`", LocalPlayer.Name, LocalPlayer.UserId),
            inline = false,
        },
        {
            name = "📝 Note",
            value = tostring(webhook.Note or "") ~= ""
                and tostring(webhook.Note)
                or "`No note`",
            inline = false,
        },
        {
            name = "🪙 Total Coins",
            value = string.format("`%d`", tonumber(data.TotalCoins) or getCurrentTotalCoins()),
            inline = true,
        },
        {
            name = "🎒 Coins This Round",
            value = string.format("`%d`", tonumber(data.Collected) or 0),
            inline = true,
        },
        {
            name = "🐚 Shells",
            value = string.format("`%d`", tonumber(data.Shells) or getCurrentShells()),
            inline = true,
        },
        {
            name = "🗺️ Map",
            value = string.format("`%s`", tostring(data.Map or "Unknown")),
            inline = true,
        },
        {
            name = "🎭 Role",
            value = string.format("`%s`", tostring(data.Role or "Unknown")),
            inline = true,
        },
        {
            name = "⏱️ Round Time",
            value = string.format("`%s`", tostring(data.Duration or "00:00:00")),
            inline = true,
        },
    }

    local discordID = tostring(webhook.DiscordID or ""):gsub("[^%d]", "")
    local shouldPing = webhook.PingUser == true and discordID ~= ""
    local mentionText = shouldPing and ("<@" .. discordID .. ">") or ""

    local payload = {
        username = tostring(webhook.Username or "VortexZ MM2 Kaitun"),
        content = mentionText,
        allowed_mentions = {
            users = shouldPing and {discordID} or {},
        },
        embeds = {
            {
                title = "🦈 VortexZ MM2 Kaitun",
                color = 43775,
                fields = fields,
                footer = {
                    text = "VortexZ MM2 Kaitun",
                },
                timestamp = DateTime.now():ToIsoDate(),
            },
        },
    }

    local ok, response = pcall(function()
        return requestFunction({
            Url = webhook.URL,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json",
            },
            Body = HttpService:JSONEncode(payload),
        })
    end)

    if not ok then
        return false, tostring(response)
    end

    return true, response
end





local function sendHubRollWebhook(info, shellsBefore, shellsAfter)
    if HUB_WEBHOOK_URL == "" then
        return false
    end

    local rarity = string.lower(tostring(info.Rarity or ""))
    if rarity ~= "godly" and rarity ~= "ancient" then
        return false
    end

    local requestFunction = getRequestFunction()
    if not requestFunction then
        return false
    end

    local payload = {
        username = HUB_WEBHOOK_USERNAME,
        embeds = {
            {
                title = "🎁 MM2 Summer Box Roll",
                color = 16766720,
                thumbnail = {
                    url = HUB_ITEM_IMAGE_URL,
                },
                fields = {
                    {
                        name = "🗡️ Item",
                        value = string.format("`%s`", info.Name),
                        inline = true,
                    },
                    {
                        name = "✨ Rarity",
                        value = string.format("`%s`", info.Rarity),
                        inline = true,
                    },
                    {
                        name = "🐚 Shells",
                        value = string.format(
                            "`%d → %d`",
                            tonumber(shellsBefore) or 0,
                            tonumber(shellsAfter) or 0
                        ),
                        inline = true,
                    },
                },
                timestamp = DateTime.now():ToIsoDate(),
            },
        },
    }

    local ok = pcall(function()
        requestFunction({
            Url = HUB_WEBHOOK_URL,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json",
            },
            Body = HttpService:JSONEncode(payload),
        })
    end)

    return ok
end


--// =========================================================
--// FPS BOOST + BLACK SCREEN + NEON BLUE TRACKER
--// Chỉ thêm giao diện/boost, không thay đổi logic farm bên dưới.
--// =========================================================

getgenv().MM2VisualConfig = getgenv().MM2VisualConfig or {}
local VisualConfig = getgenv().MM2VisualConfig

-- Gộp mặc định để chạy lại script vẫn không bị mất Tracker/FPS Boost.
VisualConfig.FPSBoost = false
if VisualConfig.BlackScreen == nil then VisualConfig.BlackScreen = true end
if VisualConfig.Tracker == nil then VisualConfig.Tracker = true end
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")

-- FPS Boost đã được xóa hoàn toàn theo yêu cầu.

local oldVisual = CoreGui:FindFirstChild("MM2NeonTracker")
if oldVisual then
    oldVisual:Destroy()
end

local TrackerGui = Instance.new("ScreenGui")
TrackerGui.Name = "MM2NeonTracker"
TrackerGui.IgnoreGuiInset = true
TrackerGui.ResetOnSpawn = false
TrackerGui.DisplayOrder = 999999
TrackerGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
local guiParent = CoreGui
pcall(function()
    if gethui then
        guiParent = gethui()
    end
end)
TrackerGui.Parent = guiParent

local BlackFrame = Instance.new("Frame")
BlackFrame.Name = "BlackScreen"
BlackFrame.Size = UDim2.fromScale(1, 1)
BlackFrame.Position = UDim2.fromScale(0, 0)
BlackFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
BlackFrame.BorderSizePixel = 0
BlackFrame.Visible = VisualConfig.BlackScreen == true
BlackFrame.ZIndex = 0
BlackFrame.Parent = TrackerGui

local UIS = game:GetService("UserInputService")

UIS.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.F8 then
        VisualConfig.BlackScreen = not VisualConfig.BlackScreen
        if BlackFrame then
            BlackFrame.Visible = VisualConfig.BlackScreen
        end
    end
end)


local Main = Instance.new("Frame")
Main.Name = "Tracker"
Main.AnchorPoint = Vector2.new(0.5, 0)
Main.Position = UDim2.fromScale(0.5, 0.025)
Main.Size = UDim2.new(0, 720, 0, 422)
Main.BackgroundColor3 = Color3.fromRGB(3, 8, 15)
Main.BackgroundTransparency = 0.04
Main.BorderSizePixel = 0
Main.Visible = true
Main.ZIndex = 100
Main.Parent = TrackerGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 18)
MainCorner.Parent = Main

local Stroke = Instance.new("UIStroke")
Stroke.Color = Color3.fromRGB(0, 170, 255)
Stroke.Thickness = 2
Stroke.Transparency = 0.08
Stroke.Parent = Main

local Gradient = Instance.new("UIGradient")
Gradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(2, 10, 20)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(4, 18, 34)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(1, 8, 18)),
})
Gradient.Rotation = 90
Gradient.Parent = Main

local function makeLabel(name, text, y, height, size, bold)
    local label = Instance.new("TextLabel")
    label.Name = name
    label.BackgroundTransparency = 1
    label.Position = UDim2.new(0, 25, 0, y)
    label.Size = UDim2.new(1, -50, 0, height)
    label.Font = bold and Enum.Font.GothamBold or Enum.Font.GothamMedium
    label.Text = text
    label.TextColor3 = Color3.fromRGB(215, 245, 255)
    label.TextSize = size
    label.TextWrapped = true
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.ZIndex = 12
    label.Parent = Main
    return label
end

local Title = makeLabel("Title", "🦈 VORTEXZ MM2 KAITUN", 12, 52, 34, true)
Title.TextColor3 = Color3.fromRGB(45, 205, 255)

local TopLine = Instance.new("Frame")
TopLine.Position = UDim2.new(0, 18, 0, 68)
TopLine.Size = UDim2.new(1, -36, 0, 2)
TopLine.BorderSizePixel = 0
TopLine.BackgroundColor3 = Color3.fromRGB(0, 185, 255)
TopLine.ZIndex = 12
TopLine.Parent = Main

local MapLabel = makeLabel("Map", "🗺️ Map: Waiting...", 80, 43, 27, true)
local PhaseLabel = makeLabel("Phase", "🎭 Phase: WAITING | Role: -", 122, 40, 25, true)
local BagLabel = makeLabel("Bag", "🎒 Farm Status: Waiting", 163, 43, 27, true)
local DiscordLabel = makeLabel("Discord", "discord.gg/vortexz-hub", 205, 43, 25, true)
DiscordLabel.TextColor3 = Color3.fromRGB(45, 205, 255)
local CurrencyLabel = makeLabel("Currency", "🐚 Shells: 0 | Coin In Map: 0", 247, 43, 25, true)

local BottomLine = Instance.new("Frame")
BottomLine.Position = UDim2.new(0, 18, 0, 338)
BottomLine.Size = UDim2.new(1, -36, 0, 2)
BottomLine.BorderSizePixel = 0
BottomLine.BackgroundColor3 = Color3.fromRGB(0, 185, 255)
BottomLine.ZIndex = 12
BottomLine.Parent = Main

local TimeLabel = makeLabel("Time", "⏱️ Time: 00:00:00", 352, 44, 27, true)

local startTrackerTime = tick()
local lastCoinCount = 0
local totalCollected = 0
local maxBagCoin = 0
local previousRoundActive = false
local roundMapName = "Unknown"
local roundRoleName = "Unknown"
local roundReportSent = false

-- MM5 cập nhật túi coin bằng RemoteEvent:
-- CoinCollected(bagName, currentAmount, maxAmount, ...)
-- CoinsStarted(bagTable) báo bắt đầu hệ thống coin của round mới.
local GameplayRemotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Gameplay")
local CoinCollectedRemote = GameplayRemotes:WaitForChild("CoinCollected")
local CoinsStartedRemote = GameplayRemotes:WaitForChild("CoinsStarted")

CoinCollectedRemote.OnClientEvent:Connect(function(bagName, currentAmount, maxAmount)
    if tostring(bagName) ~= "Coin" then
        return
    end

    local current = math.max(0, tonumber(currentAmount) or 0)
    totalCollected = current

    if current > maxBagCoin then
        maxBagCoin = current
    end
end)

CoinsStartedRemote.OnClientEvent:Connect(function(bagData)
    if type(bagData) == "table" and bagData.Coin ~= nil then
        totalCollected = 0
        maxBagCoin = 0
    end
end)

-- Khóa farm sau khi chết/kết thúc ván.
-- Chỉ mở lại sau khi đã thấy intermission rồi map mới xuất hiện.
local roundLocked = false
local sawIntermission = true
getgenv().MM2RoundActive = false

local function countMapCoins()
    local count = 0

    pcall(function()
        for _, coinVisual in ipairs(CollectionService:GetTagged("CoinVisual")) do
            if coinVisual:IsDescendantOf(Workspace)
                and coinVisual:GetAttribute("Delete") ~= true
                and coinVisual:GetAttribute("Collected") ~= true then
                count += 1
            end
        end
    end)

    return count
end

local function getCurrentMapName()
    local character = LocalPlayer.Character

    for _, object in ipairs(Workspace:GetChildren()) do
        if object:IsA("Model")
            and object ~= character
            and object.Name ~= "Lobby"
            and object:FindFirstChild("CoinContainer", true) then
            return object.Name
        end
    end

    for _, object in ipairs(Workspace:GetChildren()) do
        if object:IsA("Model")
            and object ~= character
            and object.Name ~= "Lobby"
            and object:FindFirstChild("Coin_Server", true) then
            return object.Name
        end
    end

    return nil
end

local function isPlayerAlive()
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    return humanoid ~= nil and humanoid.Health > 0
end

local function hasRoundWorld()
    return getCurrentMapName() ~= nil and countMapCoins() > 0
end

local function hookCharacterDeath(character)
    task.spawn(function()
        local humanoid = character:WaitForChild("Humanoid", 10)
        if not humanoid then
            return
        end

        humanoid.Died:Connect(function()
            -- Chỉ dừng farm. Không gửi webhook và không ghi "Player Dead".
            roundLocked = true
            sawIntermission = false
            getgenv().MM2RoundActive = false
        end)
    end)
end

if LocalPlayer.Character then
    hookCharacterDeath(LocalPlayer.Character)
end

LocalPlayer.CharacterAdded:Connect(function(character)
    hookCharacterDeath(character)
end)

local function updateRoundGate()
    local worldReady = hasRoundWorld()
    local alive = isPlayerAlive()

    -- Map/coin biến mất nghĩa là đã vào intermission hoặc lobby.
    if not worldReady then
        sawIntermission = true
        getgenv().MM2RoundActive = false
        return false
    end

    if not alive then
        roundLocked = true
        sawIntermission = false
        lastDeathReason = "Player Dead"
        getgenv().MM2RoundActive = false
        return false
    end

    -- Sau khi chết, dù respawn ở lobby và map cũ vẫn còn coin,
    -- vẫn khóa toàn bộ farm cho tới khi map cũ unload.
    if roundLocked then
        if sawIntermission then
            roundLocked = false
                    else
            getgenv().MM2RoundActive = false
            return false
        end
    end

    getgenv().MM2RoundActive = true
    return true
end

local function isRoundActive()
    return updateRoundGate()
end

local function getRoleText()
    local role = "Unknown"

    pcall(function()
        local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if not playerGui then
            return
        end

        for _, object in ipairs(playerGui:GetDescendants()) do
            if object:IsA("TextLabel") or object:IsA("TextButton") then
                local text = tostring(object.Text)
                local lower = string.lower(text)

                if string.find(lower, "innocent", 1, true) then
                    role = "Innocent"
                    return
                elseif string.find(lower, "sheriff", 1, true) then
                    role = "Sheriff"
                    return
                elseif string.find(lower, "murderer", 1, true) then
                    role = "Murderer"
                    return
                end
            end
        end
    end)

    return role
end

local function getPhaseText()
    if not isPlayerAlive() then
        return "DEAD"
    end

    if roundLocked and not sawIntermission then
        return "LOBBY / WAITING"
    end

    if isRoundActive() then
        return "FARMING"
    end

    return "WAITING NEXT ROUND"
end

local function formatTime(seconds)
    seconds = math.max(0, math.floor(seconds))
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60
    return string.format("%02d:%02d:%02d", hours, minutes, secs)
end

task.spawn(function()
    while task.wait(0.25) do
        if not TrackerGui.Parent then
            break
        end

        BlackFrame.Visible = VisualConfig.BlackScreen ~= false
        Main.Visible = VisualConfig.Tracker ~= false

        local roundActive = isRoundActive()
        local currentCoins = roundActive and countMapCoins() or 0
        local mapName = getCurrentMapName()
        getgenv().MM2RoundActive = roundActive

        if roundActive and not previousRoundActive then
            lastCoinCount = currentCoins
            totalCollected = 0
            maxBagCoin = 0
            startTrackerTime = tick()
            roundMapName = mapName or "Unknown"
            roundRoleName = getRoleText()
            roundReportSent = false

        elseif roundActive and previousRoundActive then
            if mapName then
                roundMapName = mapName
            end

            local detectedRole = getRoleText()
            if detectedRole ~= "Unknown" then
                roundRoleName = detectedRole
            end

            lastCoinCount = currentCoins

        elseif previousRoundActive and not roundActive then
            -- Chỉ gửi khi map/coin của ván đã thực sự unload.
            -- Không gửi do chết, respawn hoặc bị chuyển về lobby sớm.
            local roundWorldGone = not hasRoundWorld()

            if roundWorldGone and not roundReportSent then
                roundReportSent = true

                local report = {
                    Collected = maxBagCoin or 0,
                    TotalCoins = getCurrentTotalCoins(),
                    Shells = getCurrentShells(),
                    Map = roundMapName,
                    Role = roundRoleName,
                    Duration = formatTime(tick() - startTrackerTime),
                }

                task.spawn(function()
                    sendRoundWebhook(report)
                end)
            end

            lastCoinCount = 0
        else
            lastCoinCount = 0
        end

        previousRoundActive = roundActive

        local displayMap = roundActive and (mapName or "Unknown") or "Lobby / Waiting"
        MapLabel.Text = "🗺️ Map: " .. displayMap
        PhaseLabel.Text = string.format(
            "🎭 Phase: %s | Role: %s",
            getPhaseText(),
            roundActive and getRoleText() or "-"
        )

        BagLabel.Text = string.format(
            "🎒 Farm Status: %s",
            roundActive and "Collecting" or "Stopped"
        )

        CurrencyLabel.Text = string.format(
            "🐚 Shells: %d | 🗺️ Coin In Map: %d",
            getCurrentShells(),
            currentCoins
        )

        TimeLabel.Text = "⏱️ Time: " .. formatTime(tick() - startTrackerTime)
    end
end)






--// Auto Change theo level: hỗ trợ FarmSync hoặc Yummy.
local autoChangeFinished = false
local autoChangeBusy = false

local function runFarmSyncChange()
    if not getgenv().client
        or type(getgenv().client.ChangeToFolder) ~= "function" then
        return false
    end

    local folderFrom = tostring(FarmSyncChange["Folder From"] or "")
    local folderTo = tostring(FarmSyncChange["Folder To"] or "")

    if folderFrom == "" or folderTo == "" then
        return false
    end

    local ok, changed = pcall(function()
        return getgenv().client:ChangeToFolder(
            folderFrom,
            folderTo,
            FarmSyncChange["Without Replacement"] == true,
            FarmSyncChange["Config ID"]
        )
    end)

    if not ok or not changed then
        return false
    end

    pcall(function()
        getgenv().client:Disconnect()
    end)

    return true
end

local function runYummyChange(currentLevel)
    if type(writefile) ~= "function" then
        return false
    end

    local ok = pcall(function()
        writefile(
            LocalPlayer.Name .. ".txt",
            "Completed-Level-" .. tostring(currentLevel)
        )
    end)

    return ok
end

local function tryAutoChangeByLevel()
    if autoChangeFinished
        or autoChangeBusy
        or AutoChangeConfig["Enabled"] ~= true then
        return false
    end

    local targetLevel = tonumber(AutoChangeConfig["Level"]) or 10
    local currentLevel = getCurrentMM2Level()

    if currentLevel < targetLevel then
        return false
    end

    local useFarmSync = FarmSyncChange["Enabled"] == true
    local useYummy = YummyChange["Enabled"] == true

    if not useFarmSync and not useYummy then
        return false
    end

    autoChangeBusy = true

    local changed
    if useFarmSync then
        changed = runFarmSyncChange()
    else
        changed = runYummyChange(currentLevel)
    end

    if changed then
        autoChangeFinished = true
        task.wait(1)
        game:Shutdown()
        return true
    end

    autoChangeBusy = false
    return false
end

task.spawn(function()
    while not autoChangeFinished do
        task.wait(3)
        pcall(tryAutoChangeByLevel)
    end
end)


--// Auto Roll Summer Box '26 bằng Shells.
local ShopRemotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Shop")
local OpenCrateRemote = ShopRemotes:WaitForChild("OpenCrate")
local BoxController = ShopRemotes:WaitForChild("BoxController")

local autoRollBusy = false

local function rollSummerBoxOnce()
    local roll = Config.AutoRoll
    if not roll or roll.Enabled ~= true or autoRollBusy then
        return false
    end

    if roll.OnlyInLobby == true and getgenv().MM2RoundActive then
        return false
    end

    local cost = tonumber(roll.Cost) or 120
    local shellsBefore = getCurrentShells()

    local keepBalance = tonumber(roll.KeepBalance) or 0

    if shellsBefore - cost < keepBalance then
        return false
    end

    autoRollBusy = true

    local ok, rewardId = pcall(function()
        return OpenCrateRemote:InvokeServer(
            tostring(roll.BoxId or "Summer2026Box"),
            "MysteryBox",
            tostring(roll.CurrencyId or "SummerKey2026")
        )
    end)

    if ok and rewardId then
        pcall(function()
            BoxController:Fire(
                tostring(roll.BoxId or "Summer2026Box"),
                rewardId
            )
        end)

        task.wait(0.15)

        local shellsAfter = getCurrentShells()
        local rewardInfo = getRewardInfo(rewardId)

        task.spawn(function()
            sendUserRollWebhook(rewardInfo, shellsBefore, shellsAfter)
            sendHubRollWebhook(rewardInfo, shellsBefore, shellsAfter)
        end)
    end

    autoRollBusy = false
    return ok and rewardId ~= nil
end

task.spawn(function()
    while task.wait(math.max(0.25, tonumber(Config.AutoRoll.Delay) or 0.85)) do
        pcall(rollSummerBoxOnce)
    end
end)


--// Tự nhận popup phần thưởng (Shells và các reward khác).
local function tryClaimVisibleReward()
    if Config.AutoClaimRewards ~= true then
        return false
    end

    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not playerGui then
        return false
    end

    -- Ưu tiên đúng cấu trúc popup ItemPopup nếu đang tồn tại.
    for _, object in ipairs(playerGui:GetDescendants()) do
        if object:IsA("TextButton")
            and object.Visible
            and object.Active ~= false
            and (
                object.Name == "Claim"
                or object.Name == "ActionButton"
                or string.lower(tostring(object.Text or "")):find("claim", 1, true)
            ) then

            local fired = false

            if firesignal then
                fired = pcall(function()
                    firesignal(object.Activated)
                end)
            end

            if not fired then
                local ok, connections = pcall(function()
                    return getconnections and getconnections(object.Activated)
                end)

                if ok and type(connections) == "table" then
                    for _, connection in ipairs(connections) do
                        pcall(function()
                            connection:Fire()
                        end)
                        fired = true
                    end
                end
            end

            if fired then
                return true
            end
        end
    end

    return false
end

task.spawn(function()
    while task.wait(math.max(0.05, tonumber(Config.AutoClaimInterval) or 0.25)) do
        pcall(tryClaimVisibleReward)
    end
end)


-- Noclip: tắt va chạm các BasePart của nhân vật khi coin farm đang bật.
-- CanCollide=false cho phép các part đi xuyên qua vật cản.
local destroyFlyMover

local noclipConnection = nil
local originalCollision = setmetatable({}, {__mode = "k"})

local function setCharacterNoclip(enabled)
    local character = LocalPlayer.Character
    if not character then
        return
    end

    for _, object in ipairs(character:GetDescendants()) do
        if object:IsA("BasePart") then
            if enabled then
                if originalCollision[object] == nil then
                    originalCollision[object] = {
                        CanCollide = object.CanCollide,
                        CanTouch = object.CanTouch,
                        CanQuery = object.CanQuery,
                    }
                end

                object.CanCollide = false
                object.CanTouch = true
                object.CanQuery = false
                object.Massless = true
            elseif originalCollision[object] ~= nil then
                local old = originalCollision[object]
                object.CanCollide = old.CanCollide
                object.CanTouch = old.CanTouch
                object.CanQuery = old.CanQuery
                originalCollision[object] = nil
            end
        end
    end
end

local function startNoclip()
    if noclipConnection then
        return
    end

    noclipConnection = game:GetService("RunService").Stepped:Connect(function()
        if Config.Enabled and getgenv().MM2RoundActive and Config.Noclip ~= false then
            setCharacterNoclip(true)
        else
            setCharacterNoclip(false)
        end
    end)
end

local function stopNoclip()
    if noclipConnection then
        noclipConnection:Disconnect()
        noclipConnection = nil
    end

    setCharacterNoclip(false)
end

LocalPlayer.CharacterAdded:Connect(function()
    destroyFlyMover()
    task.wait(0.5)
    if Config.Enabled and getgenv().MM2RoundActive and Config.Noclip ~= false then
        setCharacterNoclip(true)
    end
end)

startNoclip()

local function getCharacter()
    local character = LocalPlayer.Character
        or LocalPlayer.CharacterAdded:Wait()

    local humanoid = character:FindFirstChildOfClass("Humanoid")
        or character:WaitForChild("Humanoid")

    local root = character:FindFirstChild("HumanoidRootPart")
        or character:WaitForChild("HumanoidRootPart")

    return character, humanoid, root
end

local function isUsableCoin(part)
    return part
        and part.Parent
        and part:IsA("BasePart")
        and part:IsDescendantOf(Workspace)
end

local function findCoinPart(coinServer)
    if not coinServer or not coinServer.Parent then
        return nil
    end

    local coinVisual = coinServer.Name == "CoinVisual"
        and coinServer
        or coinServer:FindFirstChild("CoinVisual")

    if coinVisual then
        local mainCoin = coinVisual:FindFirstChild("MainCoin", true)
        if mainCoin and mainCoin:IsA("BasePart") then
            return mainCoin
        end

        local fallback = coinVisual:FindFirstChildWhichIsA(
            "BasePart",
            true
        )

        if fallback then
            return fallback
        end
    end

    local mainCoin = coinServer:FindFirstChild("MainCoin", true)
    if mainCoin and mainCoin:IsA("BasePart") then
        return mainCoin
    end

    return coinServer:FindFirstChildWhichIsA("BasePart", true)
end

local function getAllCoins()
    local result = {}

    for _, coinVisual in ipairs(CollectionService:GetTagged("CoinVisual")) do
        if coinVisual:IsDescendantOf(Workspace)
            and coinVisual:GetAttribute("Delete") ~= true
            and coinVisual:GetAttribute("Collected") ~= true then

            local coinPart = findCoinPart(coinVisual)

            if isUsableCoin(coinPart) then
                table.insert(result, {
                    Server = coinVisual.Parent,
                    Visual = coinVisual,
                    Part = coinPart,
                })
            end
        end
    end

    return result
end

local function getNearestCoin(root)
    if not root or not root:IsA("BasePart") then
        return nil, math.huge
    end

    local nearest = nil
    local nearestDistance = math.huge

    for _, coinData in ipairs(getAllCoins()) do
        local coinPart = coinData.Part

        if isUsableCoin(coinPart) then
            local distance =
                (root.Position - coinPart.Position).Magnitude

            if distance < nearestDistance then
                nearestDistance = distance
                nearest = coinData
            end
        end
    end

    return nearest, nearestDistance
end

local activeFlyRoot = nil
local activeFlyAttachment = nil
local activeAlignPosition = nil

destroyFlyMover = function()
    if activeAlignPosition then
        pcall(function()
            activeAlignPosition:Destroy()
        end)
        activeAlignPosition = nil
    end

    if activeFlyAttachment then
        pcall(function()
            activeFlyAttachment:Destroy()
        end)
        activeFlyAttachment = nil
    end

    if activeFlyRoot and activeFlyRoot.Parent then
        pcall(function()
            activeFlyRoot.AssemblyLinearVelocity = Vector3.zero
            activeFlyRoot.AssemblyAngularVelocity = Vector3.zero
        end)
    end

    activeFlyRoot = nil
end

local function ensureFlyMover(root)
    if activeFlyRoot == root
        and activeAlignPosition
        and activeAlignPosition.Parent == root then
        return activeAlignPosition
    end

    destroyFlyMover()

    local attachment = Instance.new("Attachment")
    attachment.Name = "MM2CoinAlignAttachment"
    attachment.Parent = root

    local align = Instance.new("AlignPosition")
    align.Name = "MM2CoinAlignPosition"
    align.Attachment0 = attachment
    align.Mode = Enum.PositionAlignmentMode.OneAttachment
    align.ApplyAtCenterOfMass = true
    align.ReactionForceEnabled = false
    align.RigidityEnabled = false
    align.Responsiveness = tonumber(Config.AlignResponsiveness) or 35
    align.MaxVelocity = tonumber(Config.MaxFlySpeed) or 75
    align.MaxForce = math.huge
    align.Position = root.Position
    align.Parent = root

    activeFlyRoot = root
    activeFlyAttachment = attachment
    activeAlignPosition = align

    return align
end


local flyToCoin

flyToCoin = function(initialCoinData)
    local character, humanoid, root = getCharacter()
    local coinData = initialCoinData
    local coinPart = coinData and coinData.Part

    if not isUsableCoin(coinPart) then
        return false, "coin không còn tồn tại"
    end

    local align = ensureFlyMover(root)
    local startedAt = tick()

    humanoid.AutoRotate = false
    humanoid.PlatformStand = false
    humanoid:ChangeState(Enum.HumanoidStateType.Physics)

    while Config.Enabled do
        if not getgenv().MM2RoundActive then
            destroyFlyMover()
            setCharacterNoclip(false)
            return false, "ván đã kết thúc hoặc nhân vật đã chết"
        end

        if not character.Parent
            or not humanoid.Parent
            or humanoid.Health <= 0
            or not root.Parent then
            destroyFlyMover()
            return false, "nhân vật đã chết/reset"
        end


        if not isUsableCoin(coinPart) then
            align.Position = root.Position
            root.AssemblyLinearVelocity = Vector3.zero
            return true, "coin đã được nhặt"
        end

        local heightOffset = tonumber(Config.CoinHeightOffset) or 0
        local targetPosition = coinPart.Position + Vector3.new(0, heightOffset, 0)
        local distance = (targetPosition - root.Position).Magnitude
        local stopRadius = tonumber(Config.StopRadius) or 2.2

        -- Canh toàn bộ XYZ đúng vị trí coin, không chỉ đẩy trục Y lên.
        align.Position = targetPosition
        align.Responsiveness = tonumber(Config.AlignResponsiveness) or 35

        local requestedSpeed = tonumber(Config.FlySpeed) or 55
        local maxSpeed = tonumber(Config.MaxFlySpeed) or 75
        align.MaxVelocity = math.clamp(requestedSpeed + distance * 0.08, requestedSpeed, maxSpeed)

        if distance <= stopRadius then
            align.Position = targetPosition
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero

            if firetouchinterest then
                pcall(function()
                    firetouchinterest(root, coinPart, 0)
                    firetouchinterest(root, coinPart, 1)
                end)
            end

            -- Chạm coin xong chuyển ngay sang coin kế tiếp,
            -- không chờ server xóa coin khỏi Workspace.
            task.wait(0.04)
            task.wait(tonumber(Config.DelayAfterCollect) or 0.12)
            return true, "đã chạm coin, chuyển coin tiếp theo"
        end

        if tick() - startedAt >= (tonumber(Config.MoveTimeout) or 10) then
            align.Position = root.Position
            root.AssemblyLinearVelocity = Vector3.zero
            return false, "hết thời gian bay"
        end

        root.AssemblyAngularVelocity = Vector3.zero
        setCharacterNoclip(true)
        RunService.Heartbeat:Wait()
    end

    destroyFlyMover()
    return false, "đã tắt config"
end

while task.wait(0.03) do
    if not Config.Enabled then
        destroyFlyMover()
        setCharacterNoclip(false)
        task.wait(0.2)

    elseif not getgenv().MM2RoundActive then
        destroyFlyMover()
        setCharacterNoclip(false)
        task.wait(0.15)

    else
        local ok, character, humanoid, root = pcall(getCharacter)

        if not ok
            or not character
            or not humanoid
            or not root
            or not root:IsA("BasePart") then
            task.wait(1)

        else
            local coinData = getNearestCoin(root)

            if not coinData then
                task.wait(Config.EmptyScanDelay)
            else
                flyToCoin(coinData)

                if (tonumber(Config.DelayBetweenCoins) or 0) > 0 then
                    task.wait(Config.DelayBetweenCoins)
                end
            end
        end
    end
end
