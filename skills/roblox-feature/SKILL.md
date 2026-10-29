---
name: roblox-feature
description: Fluxo de "vibe coding" para implementar uma feature completa em um jogo Roblox, do pedido em linguagem natural até código testado - entender, planejar a divisão cliente/servidor, implementar com os módulos do template, rodar o lint e verificar no Studio. Use quando o usuário pedir uma mecânica/sistema novo ("faz uma loja", "quero um sistema de pets", "cria um obby", "adiciona double jump").
---

# Implementando uma feature (fluxo completo)

## 1. Entender (rápido)

- Leia `AGENTS.md`, `default.project.json` e liste `src/` para saber o que já existe (serviços, Net.Names, Config).
- Se o pedido for vago, assuma o padrão mais comum em jogos Roblox populares e diga a suposição em uma linha. Pergunte só o que muda o design (ex.: "os pets dão bônus ou são só cosméticos?").

## 2. Planejar (mostre ao usuário em 3-8 linhas)

Para cada feature, defina:
- **Estado e regras (servidor)**: qual Service, quais dados salvos (DataTemplate), quais validações.
- **Remotes**: nome em `Net.Names`, argumentos e o `Guard` de cada um. Mínimo de dados vindos do cliente.
- **Dados compartilhados**: o que vai em `src/shared/Config/`.
- **Cliente**: Controller, UI, input, efeitos.
- **Coisas no Studio**: partes, tags (CollectionService), assets que o usuário precisa criar/fornecer.

## 3. Implementar

- Gere esqueletos com `node tools/rbxkit.mjs new service X` / `new controller X` / `new module Pasta/X`.
- Siga as skills: `roblox-luau` (estilo), `roblox-networking` (todo remote validado), `roblox-datastore` (dados por DataService:Update), `roblox-ui`, `roblox-gameplay`.
- Números de balanceamento como constantes no topo ou em `Config`.
- Mantenha cada arquivo focado; não reescreva arquivos não relacionados.

## 4. Verificar (obrigatório antes de dizer "pronto")

```
node tools/rbxkit.mjs check          # lint Roblox: APIs depreciadas, remotes sem validação, etc.
selene src                           # se instalado (rokit install)
stylua --check src                   # se instalado; use `stylua src` para formatar
rojo build -o build.rbxl             # se instalado: confirma que o projeto monta
```

Corrija todos os erros. Avisos: corrija ou justifique.

Se o MCP do Studio estiver disponível, siga o loop da skill `roblox-studio-mcp` (play test + Output). Se não estiver, diga ao usuário como testar manualmente (passo a passo curto: "rode `rojo serve`, conecte o plugin, aperte Play, clique no botão X, deve aparecer Y").

## 5. Entregar

Resumo curto para o usuário:
- O que foi criado/alterado (arquivos).
- O que ele precisa fazer no Studio (tags, partes, ids de assets/gamepass, Enable API Services).
- Como testar.
- Limitações conhecidas / próximos passos sugeridos (1-3 itens).

## Exemplos de decomposição

**"Sistema de pets que seguem o jogador e dão bônus de moedas"**
- Servidor `PetService`: inventário `Pets` e `EquippedPet` no DataTemplate; remotes `EquipPet(petId)` com `Guard.keyOf(OwnedPets)` + checagem de posse; multiplicador aplicado no `CoinService:Add`.
- Shared `Config/Pets`: nome, raridade, multiplicador, modelo.
- Cliente `PetController`: clona o modelo do pet e o faz seguir (AlignPosition/lerp no `RenderStepped`) — visual local; outros jogadores veem via atributo `EquippedPet` replicado e cada cliente renderiza.

**"Double jump"**
- Puramente cliente (movimento do próprio personagem replica): `UserInputService.JumpRequest` + `Humanoid.StateChanged`; servidor só precisa limitar se houver anti-cheat de voo.

**"Loja com Robux"**
- Ver skill `roblox-monetization` (ProcessReceipt idempotente) + `roblox-ui`.
