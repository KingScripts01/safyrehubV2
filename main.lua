local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local silentAimEnabled = false
local aimFOV = 150
local espEnabled = false
local gunModActive = false

local espColors = {
    Outlaw = Color3.fromRGB(255,255,255),
    OutlawHighlight = Color3.fromRGB(255,0,0),
    Sheriff = Color3.fromRGB(255,255,0),
    Civilian = Color3.fromRGB(0,255,0),
}

local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 2
FOVCircle.NumSides = 64
FOVCircle.Color = Color3.new(1, 1, 1)
FOVCircle.Filled = false
FOVCircle.Radius = aimFOV
FOVCircle.Transparency = 1
FOVCircle.Visible = false

local Window = Fluent:CreateWindow({
    Title = "SafyreHub & Company",
    SubTitle = "by AI Assistant",
    TabWidth = 160,
    Size = UDim2.fromOffset(600, 480),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    SilentAim = Window:AddTab({ Title = "Silent Aim", Icon = "target" }),
    ESP       = Window:AddTab({ Title = "ESP", Icon = "eye" }),
    GunMod    = Window:AddTab({ Title = "Gun Mod", Icon = "gun" }),
    Teleport  = Window:AddTab({ Title = "Teleport", Icon = "map" }),
    Misc      = Window:AddTab({ Title = "Misc", Icon = "settings" }),
}

-- === Silent Aim ===
local SilentSection = Tabs.SilentAim:AddSection("Silent Aim")
SilentSection:AddToggle("SilentAimToggle", {
    Title = "Enable Silent Aim", Default = false,
    Callback = function(v)
        silentAimEnabled = v
        FOVCircle.Visible = v
    end,
})
SilentSection:AddSlider("SilentAimFOV", {
    Title = "FOV", Default = aimFOV, Min = 10, Max = 300, Rounding = 1,
    Callback = function(v) aimFOV = v; FOVCircle.Radius = v end,
})

RunService.RenderStepped:Connect(function()
    if silentAimEnabled then
        local viewport = Camera.ViewportSize
        local mid = Vector2.new(viewport.X/2, viewport.Y/2)
        FOVCircle.Position = mid
        FOVCircle.Radius = aimFOV
        FOVCircle.Visible = true
    else
        FOVCircle.Visible = false
    end
end)

-- Silent Aim leve e otimizado
local oldMeta = hookmetamethod(game, "__namecall", function(self, ...)
    if silentAimEnabled and getnamecallmethod() == "FireServer" and tostring(self) == "Shoot" then
        local args = {...}
        local viewport = Camera.ViewportSize
        local mid = Vector2.new(viewport.X/2, viewport.Y/2)
        local closest, minDist = nil, aimFOV
        for _,player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("Head") then
                local pos,onScreen = Camera:WorldToViewportPoint(player.Character.Head.Position)
                if onScreen then
                    local dist = (Vector2.new(pos.X,pos.Y) - mid).Magnitude
                    if dist < minDist then
                        minDist = dist
                        closest = player
                    end
                end
            end
        end
        if closest then
            args[2] = closest.Character.Head.Position
            return oldMeta(self, unpack(args))
        end
    end
    return oldMeta(self, ...)
end)

-- === ESP ===
local ESPSection = Tabs.ESP:AddSection("Team Colors")
ESPSection:AddColorpicker("Outlaw", { Title = "Outlaw", Default = espColors.Outlaw, Callback = function(v) espColors.Outlaw = v end })
ESPSection:AddColorpicker("OutlawHighlight", { Title = "Outlaw Bordas", Default = espColors.OutlawHighlight, Callback = function(v) espColors.OutlawHighlight = v end })
ESPSection:AddColorpicker("Sheriff", { Title = "Sheriff", Default = espColors.Sheriff, Callback = function(v) espColors.Sheriff = v end })
ESPSection:AddColorpicker("Civilian", { Title = "Civilian", Default = espColors.Civilian, Callback = function(v) espColors.Civilian = v end })
ESPSection:AddToggle("ESPToggle", { Title = "Enable ESP", Default = false, Callback = function(v) espEnabled = v end })

local highlights = {}
local function getHighlightColor(player)
    if tostring(player.Team) == "Outlaw" then return espColors.Outlaw, espColors.OutlawHighlight
    elseif tostring(player.Team) == "Sheriff" then return espColors.Sheriff, espColors.Sheriff
    elseif tostring(player.Team) == "Civilian" then return espColors.Civilian, espColors.Civilian
    end
    return Color3.fromRGB(255,255,255), Color3.fromRGB(255,255,255)
end

local function createHighlight(player)
    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") and not highlights[player] then
        local highlight = Instance.new("Highlight")
        highlight.Name = "westboundHighlight"
        highlight.Adornee = player.Character
        local fill, outline = getHighlightColor(player)
        highlight.FillColor = fill
        highlight.OutlineColor = outline
        highlight.Parent = player.Character
        highlights[player] = highlight
    end
end
local function removeHighlight(player)
    if highlights[player] then
        highlights[player]:Destroy()
        highlights[player] = nil
    end
end

RunService.RenderStepped:Connect(function()
    if espEnabled then
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Team and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                createHighlight(player)
            else
                removeHighlight(player)
            end
        end
    else
        for player,_ in pairs(highlights) do
            removeHighlight(player)
        end
    end
end)

-- === Gun Mod ===
local GunModSection = Tabs.GunMod:AddSection("Gun Mod")
GunModSection:AddToggle("GunModActive", {
    Title = "Fast Gun Mod",
    Default = false,
    Callback = function(state)
        gunModActive = state
        local success, list = pcall(function()
            return require(game:GetService("ReplicatedStorage").GunScripts.GunStats)
        end)
        if success and type(list) == "table" then
            for i,v in pairs(list) do
                if state then
                    v.Spread = 0
                    v.prepTime = 0.02
                    v.eqTime = 0.02
                    v.MaxShots = math.huge
                    v.ReloadSpeed = 0.02
                    v.BulletSpeed = 500
                    v.HipFireAccuracy = 0
                    v.ZoomAccuracy = 0
                else
                    v.Spread = 2
                    v.prepTime = 1
                    v.eqTime = 1
                    v.MaxShots = 6
                    v.ReloadSpeed = 1
                    v.BulletSpeed = 80
                    v.HipFireAccuracy = 2
                    v.ZoomAccuracy = 1
                end
            end
        end
    end,
})

-- === Teleport ===
local TeleSection = Tabs.Teleport:AddSection("Locations")
local locations = {
    ["Tumbleweed"] = Vector3.new(-746, 18, 1516),
    ["Grayridge"] = Vector3.new(-1380, 19, 1174),
    ["Stone Creek Mine"] = Vector3.new(-1113, 18, 1914),
    ["Red Rocks Camp"] = Vector3.new(-1700, 18, 1200),
    ["Fort Cassidy"] = Vector3.new(-1180, 18, 1345),
    ["Bank"] = Vector3.new(-769, 18, 1325),
}
for name, pos in pairs(locations) do
    TeleSection:AddButton({
        Title = name,
        Description = "Teleport to "..name,
        Callback = function()
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(pos)
            end
        end,
    })
end

-- === Misc ===
local MiscSection = Tabs.Misc:AddSection("Miscellaneous")
MiscSection:AddDropdown("ThemeDropdown", {
    Title = "Theme",
    Description = "Choose theme (restart script to apply)",
    Values = {"Dark", "Light", "Rose", "Aqua", "Amethyst", "Darker"},
    Default = "Dark",
    Callback = function(v)
        print("Restart script to apply "..v.." theme.")
    end,
})

print("SafyreHub & Company loaded: Silent Aim, Fast Gun Mod, ESP, Teleport, Misc all active.")
