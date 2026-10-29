---
name: roblox-studio-mcp
description: Como usar o servidor MCP do Roblox Studio (Roblox_Studio) para inspecionar o jogo aberto, ler/editar scripts, executar Luau, fazer play tests, ler o Output, simular input e capturar a tela. Use sempre que as ferramentas MCP do Studio estiverem disponíveis, para verificar mudanças de verdade no Studio, ou quando o usuário pedir para testar, depurar ou ver algo no jogo.
---

# Roblox Studio via MCP

O Roblox Studio tem um servidor MCP embutido. Ferramentas típicas (nomes podem ter prefixo `mcp__Roblox_Studio__`):

| Grupo | Ferramentas |
|---|---|
| Sessão | `list_roblox_studios` (pegue o `studio_id`; toda chamada exige `studio_id`), `get_studio_state` |
| Exploração | `search_game_tree`, `inspect_instance`, `subagent` |
| Scripts | `script_read`, `script_search`, `script_grep`, `multi_edit` |
| Execução | `execute_luau` |
| Play test | `start_stop_play`, `get_console_output`, `screen_capture` |
| Input simulado | `character_navigation`, `user_keyboard_input`, `user_mouse_input` |
| Assets | `search_asset`, `insert_asset`, `generate_mesh`, `generate_material`, `generate_procedural_model`, `wait_job_finished`, `upload_image`, `store_image` |
| Docs | `http_get`, `skill` |

Se as ferramentas não aparecerem, veja a seção Setup abaixo e avise o usuário.

## Regra de ouro: Rojo vs. edição direta

- **Projeto com Rojo** (`default.project.json` existe e `rojo serve` está rodando): edite os arquivos em `src/` no disco. O Rojo sincroniza para o Studio. NÃO edite esses scripts via `multi_edit` — a próxima sincronização sobrescreve (ou o código diverge do repositório).
- Use MCP para: ler o estado do jogo (partes, mapa, hierarquia que não está no Rojo), executar código de inspeção, rodar play tests e ler logs.
- **Projeto sem Rojo**: aí sim edite scripts direto com `script_read` + `multi_edit`, sempre lendo antes de editar.

## Loop de verificação (use após implementar uma feature)

1. `list_roblox_studios` -> escolha o `studio_id` (pergunte se houver mais de um).
2. `get_studio_state` para saber se está em edit ou play.
3. Se Rojo: confirme que o script sincronizou (`script_grep` por um trecho novo).
4. `start_stop_play` para iniciar o play test.
5. Aguarde alguns segundos e use `get_console_output`: procure erros (vermelho), `warn`s e `Infinite yield possible`.
6. Para testar comportamento: `execute_luau` (ex.: ler `game.Players:GetPlayers()[1]:GetAttribute("Coins")`), `character_navigation`/`user_keyboard_input` para agir como jogador, `screen_capture` para conferir UI.
7. `start_stop_play` para parar. Corrija e repita até não haver erros.
8. Relate ao usuário o que foi verificado e o que não foi possível verificar.

## execute_luau: cuidados

- Em modo edit, mudanças feitas por `execute_luau` alteram o place (como a Command Bar). Prefira código **somente leitura** para inspecionar, a não ser que o usuário peça a mudança.
- Mudanças no workspace durante play test são descartadas ao parar.
- Retorne dados resumidos (contagens, nomes, poucos valores) para não estourar o contexto:

```lua
local count = 0
for _, d in workspace:GetDescendants() do if d:IsA("BasePart") then count += 1 end end
return `parts={count}, players={#game:GetService("Players"):GetPlayers()}`
```

## Construindo mapa/objetos

Para gerar estruturas (plataformas de obby, paredes, lojas), use `execute_luau` com código que cria instances em `workspace` dentro de um `Model`/`Folder` nomeado, ancoradas, e confirme com `screen_capture`. Diga ao usuário que salve o place (Ctrl+S) — o MCP não substitui o save. Prefira `insert_asset`/`search_asset` para modelos prontos apenas se o usuário aprovar (assets de terceiros podem ter scripts maliciosos: inspecione scripts dentro do modelo inserido com `search_game_tree` e remova os suspeitos, ex.: `require(id)`, `getfenv`, `loadstring`).

## Setup (para explicar ao usuário)

1. Studio atualizado. Assistant > `...` > **Manage MCP Servers** > ligar **Enable Studio as MCP server**.
2. Em **Quick connect**, ligar **Claude Code** e/ou **Codex CLI**, e reiniciar o cliente.
3. Manual:
   - Windows: `claude mcp add Roblox_Studio -- cmd.exe /c %LOCALAPPDATA%\Roblox\mcp.bat`
   - macOS: `claude mcp add Roblox_Studio -- /Applications/RobloxStudio.app/Contents/MacOS/StudioMCP`
   - Codex: troque `claude mcp add` por `codex mcp add`.
   - Ou rode `node tools/rbxkit.mjs mcp` para imprimir a config.
4. O MCP pode ler e modificar o place aberto: só conecte clientes confiáveis.
