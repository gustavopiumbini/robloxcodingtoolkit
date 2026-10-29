---
name: roblox-performance
description: Performance e otimização no Roblox - lag de servidor e cliente, memory leaks, loops por frame, StreamingEnabled, contagem de partes, física, remotes em excesso, Parallel Luau (Actors) e uso do MicroProfiler/Developer Console. Use quando o jogo travar, tiver FPS baixo, ping alto, crescimento de memória, ou ao escalar para muitos jogadores/NPCs.
---

# Performance

## Diagnóstico primeiro

- **Developer Console** (F9 no jogo): Memory (por categoria), Network (bytes por remote), ServerStats, Scripts (atividade %).
- **MicroProfiler** (Ctrl+F6): identifique o que ocupa o frame. Marque seções com `debug.profilebegin("Nome")` / `debug.profileend()`.
- **Script Profiler** no Studio (View > Script Profiler) para hotspots de CPU por função.
- Via MCP do Studio: rode um play test e use `get_console_output`; `execute_luau` pode medir `os.clock()` em trechos e contar instâncias.

## Causas mais comuns (e correção)

| Sintoma | Causa provável | Correção |
|---|---|---|
| Memória cresce sem parar | Conexões nunca desconectadas, tabelas por jogador não limpas, instances clonadas e esquecidas | `Trove` por ciclo de vida; limpar em `PlayerRemoving`; `Destroy()` em vez de `Parent = nil` |
| Servidor com "lag" geral | Loops `while true` com wait curto em muitos scripts; `Heartbeat` fazendo trabalho pesado | Um loop central; reduzir frequência; processar em lotes |
| Ping/rede alto | `FireAllClients` todo frame, tabelas grandes | Enviar só deltas, limitar Hz, `UnreliableRemoteEvent`, attributes |
| FPS baixo no cliente | Muitas partes/meshes, sombras, partículas, UI recriada | StreamingEnabled, LOD, `CastShadow=false` em detalhes, MeshParts com `RenderFidelity` automático, reutilizar UI |
| Física travando | Muitas partes não ancoradas, ownership trocando | Ancorar o que não se move, `SetNetworkOwner`, constraints em vez de CFrame por frame |
| Picos ao spawnar | `Clone` de modelos grandes de uma vez | Pré-carregar/pooling, spawn espalhado em vários frames |

## Boas práticas de código

- Cache: guarde `GetService`, referências a instances e resultados em variáveis locais fora de loops.
- Evite `FindFirstChild` recursivo (`true`) e `GetDescendants` em loops quentes.
- Use `RunService.Heartbeat` (pós-física) para lógica por frame; `RenderStepped`/`BindToRenderStep` só no cliente e só para câmera/visual imediato.
- Object pooling para projéteis/efeitos: reutilize em vez de `Instance.new`+`Destroy` em rajada.
- Spatial queries (`GetPartBoundsInBox`, `Raycast`) são baratas comparadas a checar distância contra todos os objetos; para muitos alvos use uma grade espacial.
- Strings: `table.concat` para concatenar muitas partes.
- `table.create(n)` para pré-alocar arrays grandes; `buffer` para dados binários compactos (ex.: serializar para rede).
- Evite `task.wait()` em centenas de threads; prefira um agendador central.

## StreamingEnabled

Ligado por padrão em lugares novos. Clientes recebem só o que está perto. Consequência para código: no cliente, objetos distantes podem não existir — use `WaitForChild` com timeout, `CollectionService:GetInstanceAddedSignal`, e `Model.ModelStreamingMode = Persistent` para modelos que o cliente sempre precisa (ex.: lobby). Servidor vê tudo.

## Parallel Luau (Actors)

Para cálculo pesado paralelizável (pathfinding de muitos NPCs, geração procedural, IA): coloque scripts dentro de `Actor`s, use `task.desynchronize()` para a parte paralela (só leitura do DataModel) e `task.synchronize()` antes de escrever em instances. Comunicação entre Actors via `actor:SendMessage` / `SharedTable`. Só vale a pena com trabalho realmente pesado.

## Metas de referência

- Servidor: Heartbeat ~60 Hz estável; scripts somando < 20-30% em ServerStats.
- Cliente mobile: < ~1.5 GB de memória total; manter instâncias visíveis baixas.
