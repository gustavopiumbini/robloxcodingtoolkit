---
name: roblox-ui
description: Interfaces no Roblox - ScreenGui, layout responsivo (Scale, UIAspectRatioConstraint, UIListLayout), suporte a mobile/console/PC, tweens, botões, BillboardGui, ProximityPrompt e UI criada por código ou no Studio. Use ao criar ou corrigir HUD, menus, lojas, inventários, popups e qualquer elemento visual 2D.
---

# UI no Roblox

## Princípios

- UI é **apresentação**: lê estado (Attributes, remotes) e envia intenções. Nunca decide preço, saldo ou recompensa.
- Fica no cliente: `src/client/Controllers/XController.luau` cria/controla a UI em `player.PlayerGui`. Templates feitos no Studio podem ficar em `ReplicatedStorage` ou `StarterGui` e são clonados.
- `ScreenGui.ResetOnSpawn = false` para HUDs persistentes (senão a UI é recriada a cada morte e conexões duplicam).

## Responsividade (mobile é ~metade dos jogadores)

- Use `UDim2.fromScale` para tamanho/posição; `Offset` só para detalhes (bordas, paddings pequenos).
- `AnchorPoint` + `Position` para alinhar (`AnchorPoint = Vector2.new(0.5, 0.5)` centraliza).
- `UIAspectRatioConstraint` em botões/ícones para não distorcer.
- `TextScaled = true` + `UITextSizeConstraint` (MaxTextSize) para texto legível.
- Layouts: `UIListLayout` (lista), `UIGridLayout` (grade de inventário), `UIPadding`, `UIScale` (escala global por tamanho de tela), `UIFlexItem` para flex.
- Respeite a área segura: `ScreenGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets` (padrão) e não cubra o joystick/jump do mobile (canto inferior).
- Botões: mínimo ~44 px de altura em mobile. Use `Activated` (funciona com toque, mouse e gamepad) em vez de `MouseButton1Click`.
- Teste com o Device Emulator do Studio (Test > Device) em celular pequeno, tablet e 1080p.

## Input multiplataforma

```lua
local ContextActionService = game:GetService("ContextActionService")
ContextActionService:BindAction("OpenInventory", function(_, state)
	if state == Enum.UserInputState.Begin then toggleInventory() end
	return Enum.ContextActionResult.Sink
end, true, Enum.KeyCode.E, Enum.KeyCode.ButtonY) -- true cria botão touch no mobile
```

`UserInputService.PreferredInput` (ou `TouchEnabled`/`GamepadEnabled`) para adaptar dicas de controles.

## Animação

```lua
local TweenService = game:GetService("TweenService")
local info = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
TweenService:Create(frame, info, { Position = UDim2.fromScale(0.5, 0.5) }):Play()
```

Não crie tweens a cada frame; cancele o anterior (`tween:Cancel()`) quando reabrir menus rapidamente.

## Estado -> UI

```lua
local function render()
	label.Text = `Moedas: {player:GetAttribute("Coins") or 0}`
end
player:GetAttributeChangedSignal("Coins"):Connect(render)
render()
```

Para listas (inventário): limpe filhos antigos (exceto layouts) e recrie, ou mantenha um mapa `id -> frame` e atualize só o que mudou. Use `Trove` por janela aberta para limpar conexões quando fechar.

## UI no mundo 3D

- `BillboardGui` (nome/vida sobre cabeças): `AlwaysOnTop`, `MaxDistance`, tamanho em Scale de studs.
- `SurfaceGui` em partes (placas, telas).
- `ProximityPrompt` para interações (“Pressione E para abrir”): o evento `Triggered` dispara NO SERVIDOR com o player — já é validado por distância pelo Roblox, mas cheque estado/cooldown.

## Checklist de UI

- [ ] Funciona em mobile pequeno (sem sobreposição, botões tocáveis)
- [ ] Texto legível e sem cortar (`TextScaled` + constraint, ou `TextWrapped`)
- [ ] `ZIndex`/`DisplayOrder` corretos para popups acima da HUD
- [ ] Sem conexões duplicadas após respawn
- [ ] Feedback imediato em botões (som/escala) mesmo esperando o servidor
- [ ] Textos de jogadores filtrados (TextService) antes de mostrar para outros
