---
name: roblox-luau
description: Regras de Luau moderno para Roblox - tipagem (--!strict), APIs atuais vs. depreciadas, task library, padrões de módulo e armadilhas comuns. Use ao escrever ou editar QUALQUER código .lua/.luau de Roblox.
---

# Luau moderno para Roblox

## Regras obrigatórias

- Todo arquivo começa com `--!strict`. Tipos em parâmetros e retornos públicos; `export type` para tipos compartilhados.
- Serviços sempre via `game:GetService("Nome")` no topo do arquivo, nunca `game.Players`, `game.Workspace` (use `workspace` ou `game:GetService("Workspace")`).
- Use a biblioteca `task`: `task.wait`, `task.spawn`, `task.defer`, `task.delay`, `task.cancel`.
- Strings interpoladas: `` `Olá {player.Name}` `` em vez de concatenações longas.
- Iteração genérica: `for _, x in lista do` (sem `ipairs/pairs`, ambos ainda funcionam mas não são necessários).
- Operadores compostos: `x += 1`, `s ..= "a"`.
- `if cond then a else b` como expressão, em vez de `cond and a or b` (que quebra quando `a` é falsy).
- Crie a Instance, configure TODAS as propriedades, e só então defina `Parent` (por último).
- Conecte eventos com `:Connect` (maiúsculo). Guarde as conexões e desconecte (ou use `Trove`).

## Tabela de substituição (depreciado -> atual)

| Não use | Use |
|---|---|
| `wait(n)` | `task.wait(n)` |
| `spawn(f)` / `coroutine.wrap(f)()` para fire-and-forget | `task.spawn(f)` |
| `delay(t, f)` | `task.delay(t, f)` |
| `Instance.new("Part", parent)` | `Instance.new("Part")` ... `part.Parent = parent` |
| `model:SetPrimaryPartCFrame(cf)` | `model:PivotTo(cf)` |
| `model:GetModelCFrame()` / `GetPrimaryPartCFrame` | `model:GetPivot()` |
| `Humanoid:LoadAnimation(a)` | `humanoid:FindFirstChildOfClass("Animator"):LoadAnimation(a)` |
| `BodyVelocity`, `BodyPosition`, `BodyGyro`, `BodyForce` | `LinearVelocity`, `AlignPosition`, `AlignOrientation`, `VectorForce` |
| `workspace:FindPartOnRay(...)` | `workspace:Raycast(origin, direction, params)` |
| `Ray.new` + FindPartOnRay | `RaycastParams.new()` + `workspace:Raycast` |
| `table.getn(t)` / `unpack(t)` | `#t` / `table.unpack(t)` |
| `game:GetService("Players").LocalPlayer` em script de servidor | o `player` recebido do evento |
| `string.len(s)` | `#s` (bytes) ou `utf8.len(s)` (caracteres) |
| `math.random()` para gameplay determinístico | `Random.new(seed)` |
| `loadstring`, `getfenv`, `setfenv` | não use (desativam otimizações/segurança) |
| `require(123456)` (asset id) | módulos locais; ids de terceiros são vetor de backdoor |
| `BindableEvent` para eventos internos de módulo | `Signal` (`Shared.Util.Signal`) |
| `.Changed` para uma propriedade | `:GetPropertyChangedSignal("Prop")` |
| `Instance:WaitForChild` sem timeout em código opcional | `WaitForChild(name, timeout)` e trate `nil` |

## Padrão de módulo

```lua
--!strict
local Players = game:GetService("Players")

local MyModule = {}

export type Options = { speed: number, label: string? }

local DEFAULT_SPEED = 16 -- constantes em UPPER_SNAKE

local function helper(x: number): number -- funções locais em camelCase
	return x * 2
end

function MyModule.doThing(options: Options): boolean -- API pública em camelCase ou PascalCase, mas consistente no projeto
	return helper(options.speed) > DEFAULT_SPEED
end

return MyModule
```

Classes (objetos com estado):

```lua
local Car = {}
Car.__index = Car

export type Car = typeof(setmetatable({} :: { speed: number, model: Model }, Car))

function Car.new(model: Model): Car
	return setmetatable({ speed = 0, model = model }, Car)
end

function Car.accelerate(self: Car, amount: number)
	self.speed += amount
end

return Car
```

## Armadilhas que geram bugs silenciosos

- `WaitForChild` infinito trava o script inteiro; em Studio aparece "Infinite yield possible".
- `while true do` sem `task.wait()` congela o servidor.
- `player.Character` pode ser `nil` e muda a cada respawn: use `player.CharacterAdded` e pegue `Humanoid` com `FindFirstChildOfClass("Humanoid")`.
- `Touched` dispara várias vezes por contato: use debounce por jogador (`local cooldown: {[Player]: number} = {}`).
- Tabelas com chaves `Player` vazam memória se você não limpar no `Players.PlayerRemoving`.
- `task.spawn` engole o retorno; erros aparecem só no Output.
- Comparar floats com `==` (posições, CFrames) falha: use tolerância (`(a - b).Magnitude < 0.01`).
- `#t` não funciona para dicionários; conte com loop.
- Números do cliente podem ser `NaN` (`x ~= x`) ou `math.huge`: valide antes de usar.
- `require` retorna a MESMA tabela para todos os scripts no mesmo lado (cache por ModuleScript); estado do módulo é compartilhado.
- ModuleScripts em `ReplicatedStorage` rodam no cliente E no servidor (cada lado tem sua cópia de estado).

## Ao terminar

Rode `node tools/rbxkit.mjs check` (lint específico de Roblox) e, se instalados, `selene src` e `stylua --check src`.
