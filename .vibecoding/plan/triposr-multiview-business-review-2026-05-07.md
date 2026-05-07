# Objetivo

Revisar criticamente a formulação da regra de negócio do fluxo `multi-view` do TripoSR antes de qualquer implementação, corrigindo ambiguidades entre problema de negócio, UX desejada e desenho técnico.

Esta revisão consolida a leitura de [`triposr-multiview-execution-plan-2026-05-07.md`](.vibecoding/plan/triposr-multiview-execution-plan-2026-05-07.md), [`triposr-multiview-plan-2026-05-06.md`](.vibecoding/plan/triposr-multiview-plan-2026-05-06.md), [`triposr-multiview-plan-2026-05-04.md`](.vibecoding/plan/triposr-multiview-plan-2026-05-04.md), [`florence-local-models-2026-05-07.md`](.vibecoding/decisions/florence-local-models-2026-05-07.md) e [`LLM/README.md`](LLM/README.md).

O objetivo desta revisão não é redesenhar toda a solução, mas corrigir a formulação do plano para reduzir retrabalho e evitar que hipóteses técnicas sejam tratadas como regra de negócio.

# Contexto

Os planos anteriores evoluíram corretamente em organização, escopo e controle de risco, mas ainda mantêm três camadas parcialmente misturadas:

1. **problema de negócio**;
2. **invariantes operacionais desta fase**;
3. **hipóteses técnicas de implementação**.

Essa mistura cria risco de execução prematura sobre premissas ainda não comprovadas.

Os pontos mais sensíveis observados foram:

- o problema de negócio aparece, em alguns trechos, como se fosse “usar Florence para gerar 4 vistas”, quando o problema real é **melhorar a reconstrução 3D a partir de uma entrada visual mais informativa e consistente**;
- a documentação em [`LLM/README.md`](LLM/README.md) e a decisão em [`florence-local-models-2026-05-07.md`](.vibecoding/decisions/florence-local-models-2026-05-07.md) definem Florence como **modelo local default e referência do projeto**, mas não provam sozinhas que ele é o gerador raster final do turnaround 4-view;
- a UX é descrita como simples (`upload -> processar -> gerar 3D`), mas o plano também exige inspeção/validação do artefato 4-view sem deixar claro se isso é etapa obrigatória para o usuário ou apenas observabilidade para debug;
- o fluxo técnico proposto exige serialização de modelos em GPU, porém o estado atual do app em [`app/app.py`](app/app.py:37) carrega o TripoSR no bootstrap, o que conflita diretamente com a futura exigência de `Florence -> unload -> TripoSR`.

# Decisões aplicadas

1. O problema de negócio deve ser reformulado para ficar independente do mecanismo gerador específico.
2. Florence continua sendo a **referência prioritária** desta trilha, mas como hipótese técnica principal, não como verdade de negócio.
3. O contrato de produto desta fase continua limitado a `front`, `left`, `back`, `right`.
4. `top` e `bottom` continuam fora do escopo.
5. O usuário final não deve ganhar uma etapa manual extra obrigatória nesta fase; inspeções de preview pertencem à camada de observabilidade/controle.
6. O fluxo multi-view continua experimental e paralelo ao fluxo legado `single-view`.
7. A serialização de uso de GPU entre Florence e TripoSR passa a ser tratada como pré-requisito arquitetural explícito, não apenas detalhe de implementação.
8. O plano precisa separar claramente:
   - invariantes de negócio;
   - invariantes operacionais da fase atual;
   - hipóteses técnicas ainda dependentes de prova.

# Regra de negócio revisada

## Formulação correta do problema

A necessidade real não é “integrar Florence” nem “mudar `Nv=1` para `Nv=4`”.

A necessidade real é:

**aumentar a qualidade e a consistência do modelo 3D final, principalmente em laterais e costas, usando uma etapa intermediária que transforme uma imagem única em um conjunto canônico e coerente de 4 vistas antes da reconstrução 3D.**

## Resultado de negócio esperado

Dado um upload único do usuário, o sistema deve ser capaz de:

1. produzir uma representação intermediária 4-view canônica e consistente;
2. usar essa representação para gerar **um único modelo 3D final**;
3. preservar uma experiência simples para o usuário;
4. reduzir regressões visuais típicas do fluxo single-view, principalmente em costas, laterais, asas, acessórios e partes ocultas.

## O que NÃO é regra de negócio

Os itens abaixo não devem aparecer como regra de negócio principal:

- uso obrigatório de Florence como único gerador possível;
- necessidade definitiva de mosaico composto `2048x1024` como formato universal do produto;
- descarregamento de VRAM como objetivo de negócio;
- adoção de `Nv=4` como objetivo em si.

Esses itens pertencem à estratégia técnica da fase atual.

# Invariantes revisadas

## Invariantes de negócio

1. A entrada do usuário continua sendo uma única imagem.
2. O sistema continua entregando um único modelo 3D final.
3. A etapa intermediária deve representar exatamente quatro vistas canônicas: `front`, `left`, `back`, `right`.
4. A ordem lógica das vistas deve ser estável em todo o pipeline.
5. As quatro vistas devem preservar identidade semântica do mesmo personagem.
6. O fluxo do usuário deve permanecer simples e linear.

## Invariantes operacionais desta fase

1. `top` e `bottom` ficam fora do escopo.
2. O fluxo `single-view` deve permanecer disponível como fallback.
3. O fluxo `multi-view` deve entrar primeiro como trilha controlada e reversível.
4. O pipeline não deve prosseguir para reconstrução se o contrato mínimo das quatro vistas falhar.
5. Florence e TripoSR não devem coexistir na GPU nesta fase, salvo prova futura em contrário.

## Hipóteses técnicas que ainda precisam de validação

1. [`LLM/Florence-2-Flux-Large`](LLM/Florence-2-Flux-Large) conseguirá produzir diretamente, por código local, o artefato 4-view necessário.
2. O TripoSR atual conseguirá converter ganho informacional de 4 vistas em ganho geométrico real sem ajuste de pesos.
3. O formato composto em linha horizontal é suficiente como representação física padrão sem introduzir ambiguidade de parsing.

Esses pontos não devem ser tratados como já resolvidos.

# Critérios de aceite revisados

## Critérios de aceite da formulação de negócio

1. O plano descreve o valor esperado em termos de qualidade de reconstrução 3D, e não em termos de ferramenta específica.
2. O plano distingue claramente o que é requisito do produto e o que é hipótese técnica.
3. O plano não trata Florence como prova definitiva de geração raster final apenas com base em [`LLM/README.md`](LLM/README.md) e na decisão atual.
4. O plano preserva UX linear sem transformar debug/preview em etapa obrigatória para o usuário.
5. O plano reconhece explicitamente que o ciclo de vida atual do modelo em [`app/app.py`](app/app.py:37) conflita com a arquitetura serial desejada.

## Critérios de aceite da fase experimental

1. Existe um contrato lógico explícito para `front`, `left`, `back`, `right`.
2. Existe um checkpoint específico para validar a viabilidade real do gerador 4-view antes da integração profunda com o TripoSR.
3. Existe um checkpoint específico para validar a mudança de ciclo de vida dos modelos na GPU.
4. Existe separação explícita entre `single_view_legacy` e `multi_view_4_canonical`.
5. A promoção do multi-view depende de ganho percebido no 3D final, não apenas de sucesso técnico do pipeline.

# Ambiguidades, conflitos e lacunas identificados

## 1. Confusão entre problema de negócio e solução técnica

Os planos mais recentes, especialmente [`triposr-multiview-execution-plan-2026-05-07.md`](.vibecoding/plan/triposr-multiview-execution-plan-2026-05-07.md), descrevem corretamente o fluxo alvo, mas ainda sugerem que a regra de negócio é “gerar 4 vistas com Florence”.

**Correção:** reescrever o framing principal como melhoria de reconstrução 3D por canonicalização multi-view, mantendo Florence apenas como estratégia prioritária da fase.

## 2. Prova insuficiente sobre o papel exato do Florence

[`LLM/README.md`](LLM/README.md) e [`florence-local-models-2026-05-07.md`](.vibecoding/decisions/florence-local-models-2026-05-07.md) documentam modelo local default e política de armazenamento, mas não confirmam que o modelo sozinho reproduz o mesmo comportamento validado anteriormente via ComfyUI.

**Correção:** inserir um checkpoint anterior chamado `Viabilidade do gerador 4-view`, antes de assumir Florence como etapa implementável direta.

## 3. Conflito entre UX simples e preview/validação

Os planos pedem que o usuário “entenda o que foi processado antes de gerar o 3D”, mas também afirmam que a UX continua simples.

**Correção:** definir que preview do artefato 4-view é **observabilidade passiva** ou modo debug, não uma aprovação manual obrigatória do usuário nesta fase.

## 4. Conflito entre arquitetura serial e estado atual do app

O app atual carrega o TripoSR no bootstrap em [`app/app.py`](app/app.py:37), enquanto o plano futuro exige ciclo de vida serial entre modelos.

**Correção:** elevar essa mudança para pré-requisito arquitetural explícito. Sem isso, o plano subestima o impacto da integração.

## 5. Critérios de aceite ainda muito técnicos em partes do plano atual

Alguns critérios medem sucesso por `Nv=4`, shape tensorial e unload de VRAM. Isso é importante, mas não basta para validar a regra de negócio.

**Correção:** os critérios precisam começar pelo valor final: melhoria ou preservação do resultado 3D em comparação ao baseline `single-view`.

## 6. Mosaico composto ainda tratado com peso excessivo

Os planos usam `2048x1024` e zonas `512x1024` como parte central do contrato. Isso é útil como forma canônica atual, mas pode virar acoplamento prematuro.

**Correção:** o contrato principal deve ser lógico (`front`, `left`, `back`, `right`). O composto horizontal deve ser tratado como representação física preferencial da fase, não como essência do produto.

# Estratégia de correção do plano principal

A recomendação é atualizar o plano operacional vigente com a seguinte hierarquia:

## Camada 1 — Regra de negócio

Definir explicitamente:
- entrada única do usuário;
- canonicalização para 4 vistas coerentes;
- reconstrução de um único 3D final;
- objetivo de melhorar consistência geométrica e visual.

## Camada 2 — Regras operacionais da fase

Definir explicitamente:
- escopo restrito a `front`, `left`, `back`, `right`;
- fallback single-view;
- trilha experimental e reversível;
- serialização de GPU como política da fase.

## Camada 3 — Hipóteses técnicas a provar

Definir explicitamente:
- Florence como candidato principal do gerador 4-view local;
- necessidade de validar se ele gera ou apenas participa do pipeline validado anteriormente;
- viabilidade do TripoSR sem fine-tuning.

## Camada 4 — Sequência de execução revisada

A ordem recomendada do plano passa a ser:

1. congelar regra de negócio revisada;
2. congelar contrato lógico 4-view;
3. validar viabilidade do gerador 4-view local;
4. validar arquitetura serial de modelos;
5. integrar payload multi-view ao TripoSR;
6. expor observabilidade mínima na UI;
7. comparar qualidade final contra baseline;
8. só depois discutir promoção do fluxo ou plano B.

# Etapas

1. Atualizar o enunciado principal do plano vigente para refletir o problema de negócio revisado.
2. Separar, no plano vigente, três blocos explícitos: `Invariantes de negócio`, `Invariantes operacionais da fase` e `Hipóteses técnicas`.
3. Inserir uma fase/checkpoint anterior de `Viabilidade do gerador 4-view local`.
4. Inserir no plano vigente um pré-requisito arquitetural explícito sobre ciclo de vida dos modelos, referenciando o estado atual em [`app/app.py`](app/app.py:37).
5. Reclassificar preview/miniaturas da UI como observabilidade, não como passo obrigatório do usuário.
6. Reescrever critérios de aceite para começarem pelo valor de negócio e só depois cobrirem telemetria e shapes.
7. Manter Florence como estratégia prioritária da fase, mas sem tratá-lo como premissa comprovada de ponta a ponta.

# Riscos

## 1. Implementação guiada por hipótese não comprovada

Se Florence for tratado cedo como gerador raster final garantido, a implementação pode ser construída sobre uma premissa falsa.

## 2. Acoplamento prematuro ao formato composto

Se o mosaico horizontal virar contrato principal, o sistema fica menos flexível para futuras fontes multi-view.

## 3. UX degradada por excesso de controle manual

Se preview/validação visual virar etapa obrigatória, o fluxo deixa de ser simples.

## 4. Subestimação do impacto arquitetural

Se a carga antecipada do TripoSR não for tratada como pré-requisito, a execução pode avançar com conflito estrutural escondido.

## 5. Critérios de sucesso enviesados para implementação

Se o aceite se concentrar só em `Nv=4` e VRAM, o projeto pode declarar sucesso mesmo sem melhorar o 3D final.

# Observações

1. Entre os três planos lidos, [`triposr-multiview-execution-plan-2026-05-07.md`](.vibecoding/plan/triposr-multiview-execution-plan-2026-05-07.md) já é a melhor base operacional, mas precisa dessa limpeza conceitual.
2. [`triposr-multiview-plan-2026-05-06.md`](.vibecoding/plan/triposr-multiview-plan-2026-05-06.md) foi o plano que melhor explicitou a incerteza sobre o papel exato do Florence; essa cautela não deve se perder.
3. [`triposr-multiview-plan-2026-05-04.md`](.vibecoding/plan/triposr-multiview-plan-2026-05-04.md) continua útil como origem da distinção entre artefato canônico, contrato lógico e gerador plugável.
4. A revisão aqui registrada não invalida a direção multi-view; ela apenas corrige sua formulação para que a implementação futura não confunda produto com mecanismo.
5. A próxima versão do plano de execução deve usar este documento como revisão de negócio e coerência antes de qualquer mudança em código.

# Recomendação consolidada

O plano deve seguir adiante, mas com os seguintes ajustes obrigatórios antes da implementação:

1. reformular o problema de negócio para focar em melhoria de reconstrução 3D, não em Florence;
2. separar claramente requisito, política de fase e hipótese técnica;
3. inserir checkpoint explícito de viabilidade do gerador 4-view local;
4. explicitar o conflito arquitetural atual de carregamento precoce do TripoSR;
5. preservar UX simples com preview apenas como observabilidade;
6. promover o multi-view somente se houver ganho real no resultado 3D final.

# Verificação planejada desta revisão

1. Confirmar que o plano principal revisado deixa Florence como estratégia prioritária, não como regra de negócio.
2. Confirmar que o contrato principal é lógico (`front`, `left`, `back`, `right`) e não apenas físico (`2048x1024`).
3. Confirmar que a UX continua `upload -> processar -> gerar 3D`, sem aprovação manual obrigatória do preview.
4. Confirmar que a arquitetura futura reconhece o conflito com o bootstrap atual em [`app/app.py`](app/app.py:37).
5. Confirmar que os critérios de aceite passam a medir primeiro o valor do 3D final e depois os detalhes técnicos da integração.