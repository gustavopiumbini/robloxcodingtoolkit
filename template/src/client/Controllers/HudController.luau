--!strict
-- Exemplo de UI criada por código: mostra moedas, notificações e um botão de
-- compra. A UI é só apresentação; o servidor valida tudo.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)

local player = Players.LocalPlayer

local HudController = {}

local function makeLabel(parent: Instance, name: string, position: UDim2): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = position
	label.Size = UDim2.fromScale(0.3, 0.06)
	label.BackgroundTransparency = 0.3
	label.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Text = ""
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.25, 0)
	corner.Parent = label
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = 28
	constraint.Parent = label
	label.Parent = parent
	return label
end

function HudController:Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false

	local coinsLabel = makeLabel(gui, "Coins", UDim2.fromScale(0.5, 0.02))
	local toast = makeLabel(gui, "Toast", UDim2.fromScale(0.5, 0.1))
	toast.Visible = false

	local buyButton = Instance.new("TextButton")
	buyButton.Name = "BuySword"
	buyButton.AnchorPoint = Vector2.new(1, 1)
	buyButton.Position = UDim2.fromScale(0.98, 0.95)
	buyButton.Size = UDim2.fromScale(0.15, 0.07)
	buyButton.TextScaled = true
	buyButton.Font = Enum.Font.GothamBold
	buyButton.Text = "Comprar Espada (50)"
	buyButton.Parent = gui

	gui.Parent = player:WaitForChild("PlayerGui")

	local function refreshCoins()
		local coins = player:GetAttribute("Coins")
		coinsLabel.Text = if type(coins) == "number" then `Moedas: {coins}` else "Carregando..."
	end
	player:GetAttributeChangedSignal("Coins"):Connect(refreshCoins)
	refreshCoins()

	local toastToken = 0
	Net.event(Net.Names.Notify).OnClientEvent:Connect(function(message: string)
		toastToken += 1
		local token = toastToken
		toast.Text = message
		toast.Visible = true
		toast.TextTransparency = 0
		task.delay(2, function()
			if token ~= toastToken then
				return
			end
			local tween = TweenService:Create(toast, TweenInfo.new(0.4), { TextTransparency = 1 })
			tween:Play()
			tween.Completed:Wait()
			if token == toastToken then
				toast.Visible = false
			end
		end)
	end)

	buyButton.Activated:Connect(function()
		Net.event(Net.Names.BuyItem):FireServer("Sword")
	end)
end

return HudController
