---
name: roblox-architecture
description: Estrutura de projeto Roblox com Rojo - onde cada script fica (ServerScriptService, ReplicatedStorage, StarterPlayerScripts), fronteira cliente/servidor, padrão Services/Controllers com Init/Start, e como adicionar novos sistemas. Use ao criar arquivos novos, organizar código, ou decidir se algo roda no cliente ou no servidor.
---

# Arquitetura de projeto

## Mapa Rojo (default.project.json)

| Pasta no disco | No Studio | Quem roda / vê |
|---|---|---|
| `src/server/` (`init.server.luau`) | `ServerScriptService.Server` (Script) | Só servidor. Cliente NUNCA vê. |
| `src/server/Services/*.luau` | ModuleScripts filhos do Server | Só servidor |
| `src/server/Config/` | ModuleScripts (dados secretos, tabelas de drop, templates de save) | Só servidor |
| `src/client/` (`init.client.luau`) | `StarterPlayerScripts.Client` (LocalScript) | Cada cliente |
| `src/client/Controllers/*.luau` | ModuleScripts filhos do Client | Cliente |
| `src/shared/` | `ReplicatedStorage.Shared` (Folder) | Os dois lados |

Convenção de nomes do Rojo: `X.server.luau` -> Script, `X.client.luau` -> LocalScript, `X.luau` -> ModuleScript, pasta com `init.*.luau` -> o script vira a pasta. `*.model.json`/`.rbxm` para Instances que não são scripts.

Coisas físicas (mapas, modelos, peças) normalmente ficam no arquivo .rbxl/Studio e NÃO no Rojo. Se o usuário quiser versionar assets, use `.rbxm` em `assets/` e mapeie no project.

## Fronteira cliente/servidor (a regra mais importante)

- **Servidor** é a autoridade: dinheiro, inventário, dano, vida, progresso, compras, spawn de itens, DataStore, MarketplaceService.ProcessReceipt.
- **Cliente** cuida de: input, câmera, UI, efeitos visuais/sonoros, animações locais, predição visual.
- O cliente PEDE (RemoteEvent com intenção mínima: "quero comprar Sword"); o servidor DECIDE e replica o resultado.
- Mudanças feitas pelo cliente em Instances do workspace NÃO replicam para o servidor (FilteringEnabled), exceto física de partes com network ownership do cliente e o próprio personagem. Por isso o servidor valida posição/velocidade.
- Não coloque segredos/lógica sensível em `ReplicatedStorage` (cliente pode ler todo o código lá). `ServerStorage` e `ServerScriptService` são invisíveis ao cliente.

## Padrão Services/Controllers

Os bootstraps (`init.server.luau`, `init.client.luau`) fazem `require` de todos os módulos em `Services/` (ou `Controllers/`), chamam `:Init()` em ordem alfabética e depois `:Start()` de cada um em paralelo.

- `Init`: síncrono, sem yields longos. Crie remotes, conecte sinais de outros serviços, prepare estado.
- `Start`: pode fazer loops/yields. Conexões de `Players.PlayerAdded` normalmente aqui (ou no Init se outros serviços dependerem).
- Serviços se usam via `require(script.Parent.OutroService)`. Evite dependências circulares: se A precisa de B e B de A, extraia um terceiro módulo ou use um `Signal`.

Para gerar arquivos já no padrão:

```
node tools/rbxkit.mjs new service Inventory      # src/server/Services/InventoryService.luau
node tools/rbxkit.mjs new controller Camera      # src/client/Controllers/CameraController.luau
node tools/rbxkit.mjs new module Util/Math       # src/shared/Util/Math.luau
```

## Blocos prontos em `src/shared`

- `Net` — remotes nomeados (`Net.Names`), `Net.onServerEvent` com `Guard` + `RateLimiter`.
- `Util/Guard` — validação de argumentos vindos do cliente.
- `Util/RateLimiter` — token bucket por jogador.
- `Util/Signal` — eventos entre módulos.
- `Util/Trove` — limpeza de conexões/instances por ciclo de vida.
- `Config/` — dados compartilhados (catálogos de itens, constantes de balanceamento visíveis).

## Onde colocar um sistema novo (checklist)

1. Estado autoritativo e regras -> `src/server/Services/XService.luau`.
2. Dados que o cliente precisa saber (catálogo, preços para exibir) -> `src/shared/Config/`.
3. Comunicação -> adicione o nome em `Net.Names`, crie o handler no serviço (Init) com `Guard`.
4. UI/input -> `src/client/Controllers/XController.luau`.
5. Estado replicado simples (moedas, nível, flags) -> `player:SetAttribute` no servidor, cliente escuta `GetAttributeChangedSignal`. Para estado complexo -> RemoteEvent com snapshot.
6. Objetos do mapa com comportamento (portas, moedas no chão, armadilhas) -> marque com tags (`CollectionService`) no Studio e um serviço trata `GetTagged` + `GetInstanceAddedSignal`.

## Pacotes externos

Se o projeto usar Wally, pacotes ficam em `Packages/` mapeado para `ReplicatedStorage.Packages`. Bibliotecas consolidadas: ProfileStore (dados), Promise, Fusion/React-lua/Vide (UI declarativa), Jecs (ECS). Não adicione dependências sem o usuário pedir.
