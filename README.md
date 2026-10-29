# Roblox Vibe Coding Toolkit

Kit para criar jogos Roblox conversando com um agente de IA — **Claude Code** ou **Codex CLI** — conectado ao **Roblox Studio**.

Você descreve o que quer ("faz uma loja com espada e escudo", "cria um obby com checkpoints"), o agente escreve o código Luau seguindo boas práticas de Roblox (servidor autoritativo, remotes validados, dados salvos com segurança), roda o lint e testa no Studio pelo MCP.

## O que vem no kit

| Parte | O que é |
|---|---|
| `skills/` | 25 **skills** (formato `SKILL.md`, funcionam no Claude Code e no Codex) com o conhecimento de Roblox que o agente consulta |
| `template/` | Projeto **Rojo** pronto: bootstraps de servidor/cliente, `DataService` com session lock, `Net` + `Guard` + `RateLimiter` para remotes seguros, `Signal`, `Trove`, exemplo de loja e HUD |
| `agent/` | `AGENTS.md` (lido pelo Codex e outros) e `CLAUDE.md` (Claude Code) com as regras do projeto |
| `tools/rbxkit.mjs` | CLI sem dependências: cria projetos, gera services/controllers, **lint específico de Roblox**, configuração do MCP do Studio |

### Skills

| Skill | Para quê |
|---|---|
| `roblox-feature` | Fluxo completo de vibe coding: entender → planejar cliente/servidor → implementar → verificar → entregar |
| `roblox-luau` | Luau moderno, `--!strict`, tabela de APIs depreciadas → atuais, armadilhas |
| `roblox-architecture` | Estrutura Rojo, onde cada script roda, padrão Services/Controllers |
| `roblox-networking` | RemoteEvents seguros, validação, rate limit, anti-exploit |
| `roblox-datastore` | Salvar dados sem perder/duplicar, leaderboards, MemoryStore |
| `roblox-monetization` | Game Passes, Developer Products, `ProcessReceipt` idempotente |
| `roblox-ui` | HUD/menus responsivos, mobile, input multiplataforma |
| `roblox-gameplay` | Combate, projéteis, NPC com pathfinding, rounds, obby, coletáveis, física |
| `roblox-performance` | Lag, memory leaks, StreamingEnabled, Parallel Luau |
| `roblox-studio-mcp` | Usar o MCP do Studio: play test, Output, `execute_luau`, screenshots |
| `roblox-debug` | Interpretar erros do Output e achar a causa |
| `roblox-review` | Auditoria de segurança/dados/performance antes de publicar |
| `roblox-docs` | Consulta a documentação oficial da Roblox antes de usar uma API (via `rbxkit docs`) |

Skills de terceiros (MIT, veja [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)):

| Skill | Para quê | Origem |
|---|---|---|
| `roblox-testing` | Jest Lua, Lune, testes no Open Cloud, QA com vários clientes | [EL4CTEO](https://github.com/EL4CTEO/roblox-skills) |
| `roblox-characters-animation` | Humanoid, spawn, aparência, animações, ferramentas | EL4CTEO |
| `roblox-input` | Input Action System, UserInputService, câmeras | EL4CTEO |
| `roblox-physics` | Spatial queries, constraints, network ownership | EL4CTEO |
| `roblox-npc-ai` | Pathfinding, máquinas de estado, escala | EL4CTEO |
| `roblox-audio` | Audio API, música, som 3D | EL4CTEO |
| `roblox-text-chat` | TextChatService, filtragem de texto, PolicyService | EL4CTEO |
| `roblox-teleport-matchmaking` | Vários places, servidores reservados, matchmaking | EL4CTEO |
| `roblox-world-building` | Mapas por código, iluminação, terreno | EL4CTEO |
| `roblox-open-cloud` | APIs REST, HttpService, webhooks, Secrets | EL4CTEO |
| `roblox-tooling` | Rokit, Rojo, Wally, luau-lsp, CI | EL4CTEO |
| `roblox-creator-store-security-audit` | Auditoria de modelos da Toolbox (backdoors) | [AshExplained](https://github.com/AshExplained/roblox-skills) |

Outras coleções que avaliamos e você pode instalar à parte: [Roblox/roblox-studio-agent-plugin](https://github.com/Roblox/roblox-studio-agent-plugin) (plugin oficial de conexão com o Studio), [nonlooped/roblox-suite](https://github.com/nonlooped/roblox-suite), [AshExplained/roblox-skills](https://github.com/AshExplained/roblox-skills) (design, economia, live ops) e [m4bwav/roblox-agent](https://github.com/m4bwav/roblox-agent).

## Começando

Pré-requisitos: [Roblox Studio](https://create.roblox.com/), [Node.js 18+](https://nodejs.org/), [Rokit](https://github.com/rojo-rbx/rokit) e [Claude Code](https://claude.com/claude-code) e/ou [Codex CLI](https://developers.openai.com/codex).

### 1. Criar um jogo novo

```bash
npx github:gustavopiumbini/robloxcodingtoolkit init MeuJogo
# ou: git clone https://github.com/gustavopiumbini/robloxcodingtoolkit && node robloxcodingtoolkit/tools/rbxkit.mjs init MeuJogo

cd MeuJogo
rokit install        # instala rojo, selene, stylua, luau-lsp
rojo serve           # deixe rodando
```

No Studio: instale o [plugin do Rojo](https://rojo.space/docs/v7/getting-started/installation/), abra um place e clique em **Connect**. O código de `src/` aparece no Studio e é atualizado a cada mudança.

### 2. Conectar o agente ao Studio (MCP)

No Studio: **Assistant → ⋯ → Manage MCP Servers → Enable Studio as MCP server**, depois em **Quick connect** ligue **Claude Code** e/ou **Codex CLI** e reinicie o agente.

Configuração manual (ou `node tools/rbxkit.mjs mcp` para ver tudo):

```bash
# Windows
claude mcp add Roblox_Studio -- cmd.exe /c %LOCALAPPDATA%\Roblox\mcp.bat
codex  mcp add Roblox_Studio -- cmd.exe /c %LOCALAPPDATA%\Roblox\mcp.bat

# macOS
claude mcp add Roblox_Studio -- /Applications/RobloxStudio.app/Contents/MacOS/StudioMCP
codex  mcp add Roblox_Studio -- /Applications/RobloxStudio.app/Contents/MacOS/StudioMCP
```

Com o MCP o agente consegue apertar Play, ler o Output, executar Luau, simular input e tirar screenshots — ou seja, testar o que escreveu. O MCP pode ler e modificar o place aberto: conecte só clientes confiáveis.

Para salvar dados no Studio, ative **Game Settings → Security → Enable Studio Access to API Services** (sem isso o `DataService` guarda os dados só em memória).

### 3. Vibe coding

```bash
claude      # ou: codex
```

Exemplos de pedidos:

- "Use a skill roblox-feature e crie um sistema de pets que seguem o jogador e dão bônus de moedas"
- "Faz um obby com 10 estágios e checkpoints salvos"
- "Adiciona um Game Pass VIP que dá o dobro de moedas"
- "/roblox-review — revise o projeto antes de eu publicar"
- "Meu jogo dá esse erro: `attempt to index nil with 'Humanoid'`"

No Claude Code as skills também viram comandos: `/roblox-feature`, `/roblox-review`, etc. No Codex, cite a skill pelo nome ou use `$roblox-feature`.

### Projeto que já existe

```bash
npx github:gustavopiumbini/robloxcodingtoolkit install caminho/do/projeto
```

Copia as skills para `.claude/skills/` (Claude Code) e `.agents/skills/` (Codex), `AGENTS.md`, `CLAUDE.md` (sem sobrescrever os seus, a menos que use `--force`) e `tools/rbxkit.mjs`. As skills assumem a estrutura Rojo do template; se seu projeto for diferente, ajuste o "Mapa do projeto" no `AGENTS.md`. Os módulos de `template/src/shared/` podem ser copiados à mão.

Sem Node? Copie `skills/*` para `.claude/skills/` e/ou `.agents/skills/` e `agent/AGENTS.md` + `agent/CLAUDE.md` para a raiz do projeto.

## CLI `rbxkit`

Dentro de um projeto, rode `node tools/rbxkit.mjs <comando>`:

```text
init <pasta> [--name Nome]          cria um jogo novo
install [pasta] [--force]           instala skills/AGENTS.md num projeto existente
new service <Nome>                  src/server/Services/<Nome>Service.luau
new controller <Nome>               src/client/Controllers/<Nome>Controller.luau
new module <Pasta/Nome>             src/shared/<Pasta>/<Nome>.luau
check [caminhos] [--json] [--strict] [--quiet]
docs "<pergunta em inglês>"         busca na documentação oficial da Roblox
docs --api Classe[:membro]          referência de API (TweenService:Create, task.wait, CFrame.new)
docs --deprecated <Nome>            está depreciado? qual o substituto?
mcp [--client claude|codex] [--os windows|mac] [--write]
doctor                              confere rojo/selene/stylua/claude/codex instalados
```

### `rbxkit check` — lint de Roblox

Complementa o Selene com regras específicas de Roblox, pensadas para pegar os erros que agentes (e humanos) mais cometem:

| Severidade | Regras |
|---|---|
| erro | `wait`/`spawn`/`delay` depreciados, `:connect` minúsculo, `loadstring`, `require(assetId)` (backdoor), `InvokeClient`, `LocalPlayer` no servidor, `DataStoreService`/`ServerStorage` no cliente, `RenderStepped` no servidor, `while true` sem yield |
| aviso | handler de remote sem validação, `Instance.new(classe, parent)`, `FireServer(player, …)`, `SetPrimaryPartCFrame`, `Humanoid:LoadAnimation`, Body movers, `FindPartOnRay`, `getfenv`/`setfenv`, DataStore sem `pcall` |
| info | `SetAsync` (prefira `UpdateAsync`), `game.Players` sem `GetService`, `unpack` global, falta de `--!strict` |

Silencie com `-- rbxkit-ignore: regra` na linha ou `-- rbxkit-ignore-next-line` na linha anterior. Sai com código 1 se houver erros (`--strict` inclui avisos), então dá para usar em CI ou em um hook.

## Estrutura do template

```text
src/
  server/                     -> ServerScriptService.Server
    init.server.luau          bootstrap: require de Services/, Init() e Start()
    Config/DataTemplate.luau  formato dos dados salvos
    Services/
      DataService.luau        DataStore com UpdateAsync, session lock, retries, autosave
      CoinService.luau        moedas + leaderstats + Attribute para a HUD
      ShopService.luau        exemplo de remote seguro (Net + Guard)
  client/                     -> StarterPlayerScripts.Client
    init.client.luau          bootstrap de Controllers/
    Controllers/HudController.luau
  shared/                     -> ReplicatedStorage.Shared
    Net.luau                  remotes nomeados com validação e rate limit
    Config/Items.luau
    Util/Guard.luau  Util/RateLimiter.luau  Util/Signal.luau  Util/Trove.luau
```

## Desenvolvendo o toolkit

```bash
npm test                                   # testes da CLI e das skills (node:test)
npm run check:template                     # o template precisa passar no próprio lint
lune run tests/luau/utils.spec.luau        # testes dos módulos Luau (https://lune-org.github.io)
```

O CI (`.github/workflows/ci.yml`) roda os três e o Selene no template.

## Licença

MIT
