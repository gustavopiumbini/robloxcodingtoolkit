---
name: roblox-gameplay
description: Receitas de sistemas de gameplay no Roblox - personagens e Humanoid, ferramentas (Tools), combate e hitboxes, projéteis com raycast, NPCs com PathfindingService, sistema de rounds, checkpoints/obby, coletáveis com CollectionService, física e network ownership, animações e sons. Use ao implementar mecânicas de jogo.
---

# Receitas de gameplay

Todas as receitas seguem: servidor tem a autoridade, cliente dá feedback imediato.

## Personagem

```lua
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		local root = character:WaitForChild("HumanoidRootPart") :: BasePart
		humanoid.Died:Connect(function() ... end)
	end)
end)
```

- Velocidade/pulo: `humanoid.WalkSpeed`, `humanoid.JumpPower` (ou `JumpHeight` se `UseJumpPower=false`). Mude no servidor.
- Respawn: `Players.RespawnTime`, `player:LoadCharacter()`.
- Teleporte: `character:PivotTo(cframe)` (servidor).
- Ponto de spawn por time/checkpoint: `SpawnLocation` com `TeamColor`, ou `player.RespawnLocation`.

## Coletáveis e objetos marcados (CollectionService)

No Studio, marque as partes com a tag `Coin` (Tag Editor / Properties > Tags).

```lua
local CollectionService = game:GetService("CollectionService")
local function setup(part: BasePart)
	local debounce = false
	part.Touched:Connect(function(hit)
		if debounce then return end
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player then return end
		debounce = true
		CoinService:Add(player, 1)
		part.Transparency = 1
		task.delay(10, function() part.Transparency = 0; debounce = false end)
	end)
end
for _, p in CollectionService:GetTagged("Coin") do setup(p) end
CollectionService:GetInstanceAddedSignal("Coin"):Connect(setup)
```

## Combate corpo a corpo

1. Cliente: input -> animação -> `FireServer` com o alvo (ou nada, e o servidor faz a hitbox).
2. Servidor: cooldown por jogador, hitbox autoritativa com `workspace:GetPartBoundsInBox(cframe, size, overlapParams)` à frente do `HumanoidRootPart`, filtra personagens únicos, aplica `humanoid:TakeDamage(dano)`.
3. `OverlapParams.FilterDescendantsInstances = { attackerCharacter }` com `FilterType = Exclude`.

## Projéteis / armas de fogo

- Cliente: raycast local para efeito instantâneo (tracer, impacto).
- Servidor: recebe `origin` e `direction` (valide: `origin` perto da cabeça do atirador, direção unitária finita), refaz `workspace:Raycast` com `RaycastParams` excluindo o atirador, aplica dano. Limite cadência no servidor.
- Projéteis lentos: simule no servidor (posição por tempo) e replique visual pelos clientes; evite partes físicas com ownership do cliente.

## NPC com pathfinding

```lua
local PathfindingService = game:GetService("PathfindingService")
local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true })
local ok = pcall(path.ComputeAsync, path, npcRoot.Position, targetPosition)
if ok and path.Status == Enum.PathStatus.Success then
	for _, waypoint in path:GetWaypoints() do
		if waypoint.Action == Enum.PathWaypointAction.Jump then humanoid.Jump = true end
		humanoid:MoveTo(waypoint.Position)
		humanoid.MoveToFinished:Wait() -- trate timeout (8 s) e recalcule se path.Blocked
	end
end
```

NPC deve ter `root:SetNetworkOwner(nil)` para não engasgar. Recalcule o caminho a cada ~0.5-1 s quando persegue, não a cada frame. Muitos NPCs: um loop central em vez de um script por NPC.

## Sistema de rounds

Máquina de estados no servidor: `Intermission -> Starting -> Playing -> Ended`. Exponha o estado em `workspace:SetAttribute("RoundState", ...)` e `"RoundEndsAt"` (`workspace:GetServerTimeNow() + duração`) — o cliente calcula o timer localmente, sem remote por segundo. Use um `Trove` por round para limpar mapa, conexões e jogadores.

## Obby / checkpoints

Partes `Checkpoint` com atributo `Stage` (número). No `Touched`, só avance se `stage == atual + 1` (evita pular). Salve `Stage` no DataService e use como spawn (`player.RespawnLocation` ou `PivotTo` no CharacterAdded).

## Ferramentas (Tools)

Tool em `StarterPack` ou dada por `tool:Clone().Parent = player.Backpack` (servidor). `tool.Activated` no LocalScript para feedback; no servidor valide e aplique efeito. `RequiresHandle = false` para ferramentas sem parte.

## Física

- Partes estáticas: `Anchored = true`. Muitas partes soltas = lag.
- Constraints modernos: `LinearVelocity`, `AlignPosition`, `AlignOrientation`, `HingeConstraint`, `SpringConstraint`, `VectorForce`.
- Grupos de colisão: `PhysicsService:RegisterCollisionGroup` + `part.CollisionGroup = "Nome"`.

## Animação e som

- `Animator:LoadAnimation(animation)` (Animator dentro do Humanoid/AnimationController). Anims do personagem do jogador podem rodar no cliente (replicam).
- Sons: `SoundService`/`Sound` em partes (som 3D) ou em `SoundService` (2D). `SoundService:PlayLocalSound` para UI.
- Ids de assets (`rbxassetid://`) precisam ser do criador do jogo ou públicos; peça ao usuário os ids ou use placeholders claramente marcados com `-- TODO: id`.
