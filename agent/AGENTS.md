# Instruções para agentes (Codex, Claude Code e outros)

Este é um jogo **Roblox** escrito em **Luau**, sincronizado com o Roblox Studio pelo **Rojo**.
Responda no idioma do usuário. O usuário pode não ser programador: explique o que fez em linguagem simples e diga o que ele precisa fazer no Studio.

## Mapa do projeto

- `default.project.json` — mapeamento Rojo (disco -> Studio).
- `src/server/` -> `ServerScriptService.Server` — só servidor. `Services/*.luau` são carregados pelo `init.server.luau` (Init depois Start).
- `src/client/` -> `StarterPlayer.StarterPlayerScripts.Client` — cliente. `Controllers/*.luau` carregados pelo `init.client.luau`.
- `src/shared/` -> `ReplicatedStorage.Shared` — os dois lados. `Net` (remotes), `Util/Guard` (validação), `Util/RateLimiter`, `Util/Signal`, `Util/Trove`, `Config/`.
- `src/server/Config/DataTemplate.luau` — formato dos dados salvos do jogador (`DataService`).

## Regras inegociáveis

1. **Servidor é a autoridade.** Moedas, dano, inventário, compras e progresso são decididos no servidor. O cliente só envia intenções mínimas.
2. **Todo remote é validado** com `Net.onServerEvent`/`Net.onServerInvoke` + `Guard` (tipos, faixas, posse, distância, cooldown). Registre o nome em `Net.Names`. Nunca use `InvokeClient`.
3. **Dados do jogador só via `DataService:Update`.** Campo novo -> adicione em `DataTemplate` (valor e tipo).
4. **Luau moderno e `--!strict`**: `task.*`, `GetService`, `Parent` por último, `:Connect`, sem APIs depreciadas.
5. Projeto com Rojo: **edite os arquivos em `src/`**, não os scripts dentro do Studio via MCP.
6. Não adicione dependências, não apague arquivos e não mude o schema de save existente (renomear/remover campos) sem o usuário pedir.

## Comandos

```
node tools/rbxkit.mjs check                 # lint específico de Roblox (rode SEMPRE antes de terminar)
node tools/rbxkit.mjs new service Nome      # gera src/server/Services/NomeService.luau
node tools/rbxkit.mjs new controller Nome   # gera src/client/Controllers/NomeController.luau
node tools/rbxkit.mjs new module Pasta/Nome # gera src/shared/Pasta/Nome.luau
node tools/rbxkit.mjs docs --api Classe:membro  # referência oficial de uma API (ex.: TweenService:Create)
node tools/rbxkit.mjs docs "pergunta em inglês" # busca na documentação oficial
node tools/rbxkit.mjs mcp                   # mostra como conectar o MCP do Roblox Studio
rokit install                               # instala rojo, selene, stylua, luau-lsp
rojo serve                                  # sincroniza com o Studio (plugin Rojo)
selene src && stylua --check src            # lint e formatação (se instalados)
```

## Skills disponíveis

Leia a skill relevante antes de começar (em `.claude/skills/` e `.agents/skills/`):

| Skill | Quando |
|---|---|
| `roblox-feature` | Implementar qualquer mecânica/sistema novo (fluxo completo) |
| `roblox-luau` | Escrever qualquer código Luau |
| `roblox-architecture` | Criar arquivos, decidir cliente vs. servidor |
| `roblox-networking` | Remotes, segurança, anti-exploit |
| `roblox-datastore` | Salvar dados, leaderboards |
| `roblox-monetization` | Game Passes, Developer Products |
| `roblox-ui` | HUD, menus, mobile |
| `roblox-gameplay` | Combate, NPCs, rounds, coletáveis, física |
| `roblox-performance` | Lag, memória, otimização |
| `roblox-studio-mcp` | Testar/inspecionar no Studio pelo MCP |
| `roblox-debug` | Erros e "não funciona" |
| `roblox-review` | Auditoria/revisão de código |
| `roblox-docs` | Conferir qualquer API na documentação oficial antes de usar |
| `roblox-testing` | Testes (Jest Lua, Lune), QA, playtests com vários clientes |
| `roblox-characters-animation` | Humanoid, spawn, aparência, animações, ferramentas |
| `roblox-input` | Teclado/mouse, touch, gamepad, câmera customizada |
| `roblox-physics` | Raycasts/spatial queries, constraints, network ownership |
| `roblox-npc-ai` | Pathfinding, máquinas de estado, muitos NPCs |
| `roblox-audio` | Música e efeitos (Audio API) |
| `roblox-text-chat` | TextChatService, filtragem obrigatória de texto, PolicyService |
| `roblox-teleport-matchmaking` | Vários places, lobby -> partida, servidores reservados |
| `roblox-world-building` | Construir mapa por código, iluminação, terreno |
| `roblox-open-cloud` | APIs REST, HttpService, webhooks, publicação |
| `roblox-tooling` | Rokit, Rojo, Wally, Selene, StyLua, luau-lsp, CI |
| `roblox-creator-store-security-audit` | Auditar modelos da Toolbox/Creator Store (backdoors) |

Se uma skill e o template divergirem (ex.: ProfileStore vs. `DataService`, nomes de pastas), **siga o padrão do template** já usado no projeto, a menos que o usuário peça para mudar. Se a documentação oficial (`roblox-docs`) contradizer uma skill, a documentação vence.

## Definição de pronto

- `node tools/rbxkit.mjs check` sem erros.
- Se o MCP do Studio estiver conectado: play test sem erros no Output (skill `roblox-studio-mcp`).
- Resumo final ao usuário: arquivos alterados, passos no Studio, como testar.
