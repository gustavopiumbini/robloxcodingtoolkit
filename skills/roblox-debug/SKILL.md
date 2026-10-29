---
name: roblox-debug
description: Depuração de erros no Roblox - interpretar mensagens do Output, stack traces, "attempt to index nil", "Infinite yield possible", erros de require, scripts que não rodam, problemas de replicação e de Rojo. Use quando o usuário colar um erro, disser que "não funciona", ou um play test mostrar erros.
---

# Depuração

## Primeiro: onde o script roda?

Muitos "não funciona" são script no lugar errado:
- `Script` só roda em `Workspace`, `ServerScriptService` (e alguns outros containers do servidor) — não em `ReplicatedStorage`/`StarterPlayerScripts`.
- `LocalScript` só roda em `StarterPlayerScripts`, `StarterCharacterScripts`, `StarterGui`, `StarterPack`/Backpack, ou dentro do personagem. Não roda em `Workspace` (fora do personagem) nem em `ServerScriptService`.
- Script com `RunContext = Client` roda no cliente mesmo em `ReplicatedStorage`/`Workspace`.
- ModuleScript não roda sozinho: precisa de `require`.
- Com Rojo: confira o nome do arquivo (`.server.luau`/`.client.luau`) e o mapeamento no `default.project.json`; rode `rojo serve` e conecte o plugin.

## Erros comuns

| Mensagem | Causa usual | Correção |
|---|---|---|
| `attempt to index nil with 'X'` | Objeto ainda não existe (replicação/streaming), `FindFirstChild` retornou nil, personagem nil | `WaitForChild(name, timeout)`, checar nil, usar `CharacterAdded` |
| `Infinite yield possible on 'X:WaitForChild("Y")'` | Nome errado, objeto criado só no servidor/cliente, ou streaming | Conferir hierarquia (MCP `search_game_tree`), timeout |
| `X is not a valid member of Y` | Typo, ou acessando antes de existir | `FindFirstChild`, conferir maiúsculas |
| `Requested module experienced an error while loading` | O módulo requerido deu erro no topo | Ver o erro anterior no Output |
| `Attempted to call require with invalid argument(s)` | require de algo que não é ModuleScript | Conferir o caminho |
| `Module code did not return exactly one value` | Esqueceu `return Modulo` | Adicionar return |
| `Loop/cyclic require` (trava ou nil) | A requer B que requer A | Extrair dependência comum |
| `DataStore request was added to queue` | Muitas requisições | Reduzir frequência, ver budget |
| `HTTP 403 (Forbidden)` em DataStore no Studio | API Services desativado | Game Settings > Security > Enable Studio Access to API Services |
| `Script timeout: exhausted allowed execution time` | Loop sem yield | `task.wait()` no loop |
| Remote "não dispara" | Remote criado em lados diferentes, nome errado, handler conectado tarde | Criar no servidor, `Net.Names`, conectar no Init |
| Mudança do cliente "some" | FilteringEnabled: cliente não replica para o servidor | Fazer a mudança no servidor via remote |

## Método

1. Reproduza: obtenha a mensagem exata e a linha (`Script 'ServerScriptService.Server.Services.ShopService', Line 42`). O caminho do Studio mapeia para `src/` pelo `default.project.json`.
2. Leia o arquivo/linha e o stack trace completo.
3. Formule a hipótese e confirme com evidência: `print`/`warn` temporários com contexto, ou `execute_luau` via MCP para inspecionar estado ao vivo.
4. Corrija a causa, não o sintoma (não embrulhe tudo em `pcall` para esconder erros).
5. Remova prints temporários e rode `node tools/rbxkit.mjs check`.
