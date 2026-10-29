---
name: roblox-datastore
description: Persistência de dados no Roblox - DataStoreService, UpdateAsync, session locking, retries, limites de orçamento, BindToClose, OrderedDataStore para rankings, MemoryStoreService e migração de schema. Use ao salvar/carregar progresso, moedas, inventário, leaderboards globais, ou ao investigar perda/duplicação de dados.
---

# DataStores

## Regras de ouro

1. Toda chamada de DataStore pode falhar: sempre `pcall` + retry com backoff.
2. Use `UpdateAsync` para escrever (lê e escreve atomicamente). `SetAsync` sobrescreve às cegas e causa perda de dados entre servidores.
3. Uma chave por jogador (`"Player_" .. userId`), dados em uma tabela só. Salve em intervalos (autosave 1-5 min), no `PlayerRemoving` e no `game:BindToClose`.
4. Session lock: impede que dois servidores escrevam o mesmo jogador (troca rápida de servidor = duplicação de itens).
5. Se o load falhar, NÃO deixe o jogador jogar com dados padrão (ao salvar, apagaria o progresso). Kick com mensagem ou modo sem save.
6. Nunca salve Instances, funções ou tabelas com metatables. Apenas tipos JSON (string, number, boolean, tabela). Limite de 4 MB por chave.
7. Chaves de dicionário devem ser strings; arrays devem ser contínuos.

## No template

`src/server/Services/DataService.luau` já implementa: UpdateAsync com lock (expira em 30 min), retries, reconcile com `src/server/Config/DataTemplate.luau`, autosave, BindToClose e fallback em memória no Studio sem acesso a API.

```lua
local DataService = require(script.Parent.DataService)

-- ler
local data = DataService:Get(player)          -- nil se ainda carregando
local data = DataService:WaitForData(player)  -- yield até carregar (nil se saiu)

-- escrever (sempre por Update, para disparar DataService.Changed)
DataService:Update(player, function(data)
	data.Coins += 50
end)
```

Para adicionar campo novo: só adicione em `DataTemplate` (e no `export type PlayerData`). O reconcile preenche perfis antigos. Para renomear/transformar campos, adicione um campo `Version` e uma função de migração aplicada no load.

**Em produção para jogos sérios** recomende ProfileStore (MadStudio), que trata locks, MessagingService e edge cases melhor.

## Testando no Studio

- Game Settings > Security > **Enable Studio Access to API Services** (senão todas as chamadas falham; o DataService do template cai para memória).
- Studio usa os MESMOS DataStores do jogo publicado. Use um nome de store diferente para testes (`PlayerData_dev`) se for apagar/alterar dados.
- Ao parar o play test, o BindToClose roda; chamadas pendentes podem atrasar o stop (normal).

## Limites (orçamento por servidor)

Requisições por minuto ~ `60 + numPlayers * 10` para Get e Set/Update cada; mesma chave só pode ser escrita a cada 6 s. Use `DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.UpdateAsync)` antes de rajadas. Não salve a cada mudança de moeda: mude em memória, salve periodicamente.

## Leaderboard global

```lua
local ordered = DataStoreService:GetOrderedDataStore("TopCoins_v1")
-- salvar (junto do save do jogador, valor inteiro)
pcall(function() ordered:SetAsync(tostring(player.UserId), math.floor(coins)) end)
-- ler top 10 (servidor, a cada ~60 s, não por jogador)
local ok, pages = pcall(function() return ordered:GetSortedAsync(false, 10) end)
if ok then
	for rank, entry in pages:GetCurrentPage() do
		local name = Players:GetNameFromUserIdAsync(tonumber(entry.key)) -- também em pcall, faça cache
	end
end
```

## Dados efêmeros entre servidores

- `MemoryStoreService` (SortedMap, Queue, HashMap): matchmaking, filas, leaderboards de sessão. Expira (TTL), não é permanente.
- `MessagingService`: anúncios entre servidores (global shout), invalidação de cache.

## GDPR / direito ao esquecimento

Se o jogo receber um pedido de remoção de dados do Roblox, apague a chave do jogador (`RemoveAsync`) em todas as stores e OrderedDataStores que usem o UserId.
