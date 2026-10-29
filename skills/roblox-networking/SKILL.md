---
name: roblox-networking
description: Comunicação cliente-servidor segura no Roblox - RemoteEvent, RemoteFunction, UnreliableRemoteEvent, validação de argumentos, rate limiting, anti-exploit e replicação de estado. Use ao criar ou revisar qualquer remote, ou quando o usuário falar de exploits, hackers, cheats ou "o cliente manda".
---

# Networking seguro

## Premissa

Exploiters executam código arbitrário no cliente. Eles podem disparar QUALQUER remote, com QUAISQUER argumentos, em QUALQUER frequência, e ler todo código em `ReplicatedStorage`/cliente. Todo handler de servidor deve ser escrito como se o cliente fosse hostil.

## Qual remote usar

| Caso | Use |
|---|---|
| Cliente pede ação (comprar, atacar, interagir) | `RemoteEvent` cliente->servidor |
| Servidor notifica cliente(s) | `RemoteEvent` `FireClient`/`FireAllClients` |
| Dados de alta frequência e descartáveis (posição de mira, efeitos) | `UnreliableRemoteEvent` |
| Cliente precisa de uma resposta (abrir loja e buscar dados) | `RemoteFunction` `InvokeServer` |
| Servidor perguntar algo ao cliente | **Nunca** `InvokeClient` (cliente pode travar o servidor para sempre ou erro). Use RemoteEvent de ida e volta. |
| Estado simples replicado | `player:SetAttribute`, `Instance:SetAttribute`, ValueObjects |

## Checklist de todo handler `OnServerEvent` / `OnServerInvoke`

1. **Rate limit** por jogador.
2. **Tipo e forma** de cada argumento (`typeof`), número exato de argumentos.
3. **Números finitos** (rejeite `NaN`, `inf`) e dentro de faixa; inteiros quando for quantidade.
4. **Strings** com tamanho máximo; ids validados contra uma tabela do servidor (`Guard.keyOf(Items)`).
5. **Instances**: confirme que existem, estão onde deveriam (`IsDescendantOf`), pertencem ao jogador/estão ao alcance (distância do `HumanoidRootPart`).
6. **Estado do jogo**: o jogador está vivo? Tem cooldown? Tem saldo/item? Está na fase certa do round?
7. **Nunca** aceite do cliente: preço, dano, quantidade de recompensa, resultado de hit, `UserId` alvo de outro jogador para dar coisas, posição para teleporte sem checar.
8. O primeiro parâmetro é SEMPRE o `player` (injetado pelo Roblox). O cliente não envia o player.

## Usando o `Net` do template

```lua
local Net = require(Shared.Net)
local Guard = require(Shared.Util.Guard)

-- Em Net.Names adicione: Attack = "Attack"
Net.onServerEvent(Net.Names.Attack, {
	check = Guard.tuple(Guard.instance("Model")),
	rate = 4, burst = 4,
}, function(player, target: Model)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local targetRoot = target:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = target:FindFirstChildOfClass("Humanoid")
	if not (root and targetRoot and humanoid) or humanoid.Health <= 0 then return end
	if (root.Position - targetRoot.Position).Magnitude > 12 then return end -- alcance + folga de latência
	if CombatService:IsOnCooldown(player) then return end
	humanoid:TakeDamage(WEAPON_DAMAGE) -- dano definido NO SERVIDOR
end)
```

Validadores disponíveis em `Guard`: `any`, `boolean`, `number{min,max}`, `integer{min,max}`, `string{minLength,maxLength,pattern}`, `literal(...)`, `keyOf(dict)`, `vector3{maxMagnitude}`, `cframe`, `instance(className)`, `optional(c)`, `array(c, max)`, `shape{campo=c}`, `tuple(...)`.

## Sem o template (código mínimo)

```lua
local lastCall: { [Player]: number } = {}
remote.OnServerEvent:Connect(function(player, itemId)
	local now = os.clock()
	if lastCall[player] and now - lastCall[player] < 0.5 then return end
	lastCall[player] = now
	if type(itemId) ~= "string" or #itemId > 50 or not Items[itemId] then return end
	-- ...
end)
Players.PlayerRemoving:Connect(function(p) lastCall[p] = nil end)
```

## Padrões anti-exploit

- **Movimento**: o cliente controla o próprio personagem. Para speed/teleport hacks, cheque no servidor a distância percorrida entre heartbeats com tolerância (não chute por um único pico; use contagem de violações).
- **Network ownership**: partes soltas perto do jogador podem ficar com ownership do cliente (ele controla a física). Para objetos críticos: `part:SetNetworkOwner(nil)` (servidor).
- **Projéteis**: cliente mostra o efeito na hora (feedback); servidor refaz o raycast/validação com tolerância de latência antes de aplicar dano.
- **Ferramentas**: lógica de dano em Script de servidor ou serviço, nunca em LocalScript da Tool.
- **Chat/texto livre do jogador** exibido para outros: filtre com `TextService:FilterStringAsync` (obrigatório pelas regras do Roblox).
- **Logs**: `warn` com nome do jogador em rejeições ajuda a detectar abuso; não kicke por uma única falha de validação (pode ser lag).

## Replicação de estado

- Prefira Attributes para valores simples (aparecem no Properties, replicam automaticamente do servidor).
- Para listas (inventário): envie um snapshot inicial e depois deltas por RemoteEvent; ou um RemoteFunction "Get" quando a UI abre.
- `FireAllClients` com tabelas grandes a cada frame = lag. Agrupe, limite frequência, use `UnreliableRemoteEvent` para efeitos.
- Limites: payload de remote ~ algumas centenas de KB por segundo por jogador; evite enviar Instances desnecessárias; tabelas com chaves mistas (array + dict) perdem dados ao serializar; chaves não-string em dicionários são convertidas.
