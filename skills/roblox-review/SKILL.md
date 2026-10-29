---
name: roblox-review
description: Auditoria de código Roblox - segurança de remotes, confiança no cliente, perda/duplicação de dados, memory leaks, APIs depreciadas, performance e boas práticas. Use quando o usuário pedir revisão, "tem algo errado?", "meu jogo foi hackeado", antes de publicar uma atualização, ou ao herdar código de outra pessoa/modelo grátis.
---

# Revisão de código Roblox

## 1. Varredura automática

```
node tools/rbxkit.mjs check --json     # ou sem --json para leitura humana
```

Use o resultado como ponto de partida, não como lista final: confirme cada achado lendo o código.

## 2. Revisão manual por prioridade

### Crítico (segurança/economia)
- [ ] Todo `OnServerEvent`/`OnServerInvoke` valida tipos, faixas, posse, distância, cooldown (skill `roblox-networking`).
- [ ] Nenhum valor econômico (preço, dano, recompensa, quantidade) vem do cliente.
- [ ] `InvokeClient` não é usado no servidor.
- [ ] Não há `require(<número>)`, `loadstring`, `getfenv`/`setfenv` vindos de modelos grátis (backdoors). Procure também scripts escondidos em modelos do workspace (via MCP: `script_search`).
- [ ] `ProcessReceipt` idempotente e só retorna `PurchaseGranted` depois de salvar.
- [ ] Lógica autoritativa não está em LocalScripts.

### Alto (dados)
- [ ] DataStore com `pcall`, retry, `UpdateAsync`, session lock, save em `PlayerRemoving` + `BindToClose`.
- [ ] Falha no load não resulta em salvar dados padrão por cima.
- [ ] Nada não-serializável no save (Instances, funções, chaves mistas).

### Médio (estabilidade/performance)
- [ ] Conexões e tabelas por jogador limpas no `PlayerRemoving`/`Destroying`.
- [ ] `WaitForChild` com timeout onde o objeto pode não existir (StreamingEnabled).
- [ ] Sem `while true` sem yield; sem trabalho pesado por frame desnecessário.
- [ ] Remotes não disparados em frequência excessiva.

### Baixo (manutenção)
- [ ] `--!strict` e tipos; APIs modernas (tabela na skill `roblox-luau`).
- [ ] Nomes claros, constantes nomeadas, sem código morto.

## 3. Formato do relatório

Agrupe por severidade. Para cada item: `arquivo:linha`, o problema em uma frase, o cenário de exploração/falha concreto ("um exploiter chama BuyItem com price = -1000 e ganha moedas") e a correção sugerida (trecho de código curto). Termine com os 3 itens que o usuário deve corrigir primeiro. Só aplique correções se o usuário pedir.
