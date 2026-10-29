---
name: roblox-docs
description: Consulta a documentação oficial da Roblox (create.roblox.com) antes de usar uma API em vez de confiar na memória - assinaturas de métodos, propriedades, enums, datatypes, APIs depreciadas e guias. Use sempre que houver qualquer dúvida sobre uma classe/método/evento/enum do Roblox ou do Luau, ao planejar uma feature com APIs pouco usadas ou recentes (Audio API, Input Action System, TextChatService, MatchmakingService...), ou quando o usuário perguntar "como faz X no Roblox".
---

# Documentação oficial da Roblox

A API da Roblox muda mais rápido que o conhecimento de qualquer modelo. Uma assinatura inventada custa ao usuário um ciclo inteiro de "não funciona". **Na dúvida, consulte** — é barato.

A Roblox publica toda a documentação em Markdown para agentes:
- Qualquer página: acrescente `.md` à URL (`https://create.roblox.com/docs/reference/engine/classes/TweenService.md`).
- Busca semântica: `https://create.roblox.com/docs/api/search?q=<pergunta em inglês, percent-encoded>` -> JSON com `title`, `summary` e `url` (já em `.md`).
- Índices: `https://create.roblox.com/docs/llms.txt` (geral), `/docs/reference/engine/llms.txt` (Engine API, Luau), `/docs/cloud/llms.txt` (Open Cloud, HTTP externo).
- Depreciados: `https://create.roblox.com/docs/reference/engine/deprecated.md`.

## Como consultar (do mais econômico ao mais completo)

### 1. `rbxkit docs` (recomendado: retorna só o trecho necessário)

```
node tools/rbxkit.mjs docs --api TweenService:Create      # só a seção do método (assinatura, parâmetros, exemplos)
node tools/rbxkit.mjs docs --api task.wait                # bibliotecas e globais também
node tools/rbxkit.mjs docs --api CFrame.new               # todos os overloads
node tools/rbxkit.mjs docs --api Humanoid                 # resumo da classe + lista de membros
node tools/rbxkit.mjs docs --deprecated LoadAnimation     # está depreciado? qual o substituto?
node tools/rbxkit.mjs docs "how do I filter player text"  # busca por pergunta (EM INGLÊS)
```

Busque **em inglês** e com uma pergunta completa (o índice é semântico e em inglês; buscas em português trazem lixo). Depois leia a `url` de um resultado com `curl -s <url>` ou a ferramenta de fetch do agente.

### 2. MCP do Studio (se conectado)

- `http_get` busca páginas da documentação da Roblox (só domínios de docs). Use as mesmas URLs `.md`.
- `skill` lista e carrega as **skills oficiais da Roblox** embutidas no Studio (prefixo `rbx-`). Consulte-as para tarefas de Studio (assets, geração de mesh/material, testes); elas acompanham a versão do Studio instalada.

### 3. Fetch direto

Ferramentas de fetch (WebFetch etc.) com as URLs `.md`. Páginas de classes grandes (Instance, BasePart, Humanoid) têm dezenas de KB: prefira `rbxkit docs --api Classe:membro` ou peça ao fetch só a seção do membro.

## Regras

- **Nunca adivinhe URLs.** Classe/enum/datatype/library/global têm caminho previsível (`/docs/reference/engine/{classes|enums|datatypes|libraries|globals}/Nome.md`); para todo o resto, busque. 404 = caminho errado, não "tópico inexistente".
- Engine API (Luau dentro do jogo) e Open Cloud (HTTP de fora do Roblox, com `x-api-key`) são sistemas diferentes: não misture.
- Confira na página: **Security** (ex.: `PluginSecurity`/`RobloxScriptSecurity` não pode ser usado em scripts de jogo), **Thread Safety** (para Parallel Luau), se é **yielding** (precisa de `pcall`/não chame em callbacks que não podem ceder) e tags **Deprecated**/**NotCreatable**/**Service**.
- Ao responder ao usuário sobre comportamento de API, cite a URL (sem o `.md`).
- Se a documentação contradiz uma skill deste projeto, a documentação vence; avise o usuário da divergência.
