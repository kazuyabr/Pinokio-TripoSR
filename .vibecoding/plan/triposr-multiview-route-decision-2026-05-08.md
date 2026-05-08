# Objetivo

Definir a rota de menor retrabalho para destravar a trilha `multi_view_4_canonical` do TripoSR, escolhendo entre:

- **A**: seguir diretamente com o checkpoint Florence atual;
- **B**: manter Florence como componente auxiliar e acoplar um gerador raster 4-view complementar;
- **C**: descartar o checkpoint Florence atual nesta etapa.

A recomendação deste plano é **B**.

# Contexto

As evidências atuais convergem para uma separação clara entre **runtime Florence funcional** e **geração raster 4-view ainda ausente**:

- [`app/model_runtime.py`](app/model_runtime.py) já confirma, em `validate_florence_multiview_viability()`, que o checkpoint local carrega e roda, mas retorna `viability_status="blocked"`, `raster_views_generated=False` e apenas `florence_description`;
- [`app/multiview_contract.py`](app/multiview_contract.py) exige um [`MultiViewArtifact`](app/multiview_contract.py) completo com `front`, `left`, `back`, `right`, `composite_preview` e `generation_metadata`;
- [`triposr-multiview-business-review-2026-05-07.md`](.vibecoding/plan/triposr-multiview-business-review-2026-05-07.md) já estabeleceu que Florence é hipótese técnica prioritária, não prova de gerador raster;
- o pacote local em [`LLM/Florence-2-Flux-Large`](LLM/Florence-2-Flux-Large) está sendo usado como checkpoint `image-text-to-text`, o que é coerente com o comportamento hoje exposto pelo runtime;
- [`triposr-florence-runtime-unblock-2026-05-08.md`](.vibecoding/learn/logs/triposr-florence-runtime-unblock-2026-05-08.md) confirma que o bloqueio atual não é mais carga de modelo, e sim ausência de rota verificável para síntese raster 4-view canônica.

Portanto, o gargalo atual não é mais “fazer Florence carregar”, mas sim **produzir um artefato visual aderente ao contrato** sem desperdiçar o trabalho já feito no runtime serial e na observabilidade.

# Decisões aplicadas

1. O contrato de produto continua sendo o artefato lógico de 4 vistas canônicas definido em [`app/multiview_contract.py`](app/multiview_contract.py).
2. O runtime serial já construído em [`app/model_runtime.py`](app/model_runtime.py) deve ser preservado.
3. Florence continua como componente válido do ecossistema local, mas **não** deve mais ser tratado como candidato direto ao papel de gerador raster final sem nova prova funcional.
4. A rota recomendada deve minimizar retrabalho sobre os artefatos já estabilizados: contrato, runtime serial, observabilidade experimental e fallback `single_view_legacy` em [`app/app.py`](app/app.py).
5. A adaptação profunda de [`TSR.forward()`](app/tsr/system.py:87) permanece bloqueada até existir um `MultiViewArtifact` real e verificável.

# Estratégia

## Recomendação

Seguir com a opção **B**: **adaptador complementar**.

Arquitetura alvo desta etapa:

1. Florence permanece como componente auxiliar opcional de análise/guia/metadata;
2. um gerador raster 4-view dedicado passa a ser a fonte do artefato visual canônico;
3. um adaptador normaliza a saída desse gerador para o contrato de [`build_multiview_artifact()`](app/multiview_contract.py);
4. somente depois disso a trilha `multi_view_4_canonical` pode avançar para ingestão futura no TripoSR.

## Justificativa da recomendação

### Por que **não A**

A opção A exige assumir que o checkpoint Florence atual pode ser promovido diretamente a gerador raster 4-view.

Isso conflita com as evidências já registradas em:

- [`app/model_runtime.py`](app/model_runtime.py);
- [`triposr-florence-contract-checkpoint-2026-05-08.md`](.vibecoding/learn/logs/triposr-florence-contract-checkpoint-2026-05-08.md);
- [`triposr-florence-runtime-unblock-2026-05-08.md`](.vibecoding/learn/logs/triposr-florence-runtime-unblock-2026-05-08.md).

Seguir por A agora implicaria alto risco de retrabalho em cima de uma premissa já marcada como bloqueada: o runtime Florence entrega texto, não as quatro imagens canônicas exigidas pelo contrato.

### Por que **não C**

A opção C reduz escopo imediato, mas desperdiça trabalho já consolidado:

- runtime serial Florence ↔ TripoSR em [`app/model_runtime.py`](app/model_runtime.py);
- checkpoint controlado em [`run_multiview_florence_checkpoint()`](app/app.py:99);
- observabilidade do app em [`app/app.py`](app/app.py);
- documentação e decisões locais em [`.vibecoding/`](.vibecoding/).

Além disso, C não resolve o problema principal; apenas remove um componente potencialmente útil para descrição semântica, telemetria e enriquecimento de metadata do futuro artefato.

### Por que **B** é a rota de menor retrabalho

A opção B reaproveita tudo o que já foi validado e desloca apenas o elo ausente:

- preserva o contrato 4-view já congelado;
- preserva o runtime serial já compatibilizado;
- preserva o checkpoint experimental e a UI de observabilidade;
- evita tocar cedo no núcleo do TripoSR;
- cria uma fronteira plugável entre “quem gera raster” e “quem consome `MultiViewArtifact`”.

Na prática, B transforma a limitação atual em uma troca localizada de backend gerador, em vez de exigir reinterpretação de todo o pipeline.

# Trade-offs

## Opção A — Caminho direto com Florence atual

### Vantagens
- menor número aparente de componentes;
- mantém a narrativa técnica mais simples;
- evita integrar um segundo gerador agora.

### Desvantagens
- contradiz a evidência funcional atual;
- risco alto de pesquisa improdutiva dentro de um checkpoint que hoje se comporta como `image-text-to-text`;
- pode induzir refactors prematuros em [`app/model_runtime.py`](app/model_runtime.py) e [`app/app.py`](app/app.py) sem gerar o artefato exigido;
- probabilidade alta de novo rollback.

### Veredito
Não recomendado nesta etapa.

## Opção B — Adaptador complementar com Florence auxiliar

### Vantagens
- menor retrabalho sobre o que já existe;
- melhor aderência ao contrato e à revisão de negócio;
- separa hipótese descritiva de geração raster real;
- mantém Florence útil para metadata, prompting, validação semântica ou ranking futuro;
- reduz risco arquitetural antes da etapa `Nv=4`.

### Desvantagens
- aumenta o número de componentes no curto prazo;
- exige escolha e prova de um segundo gerador raster;
- pede desenho explícito de adaptador e critérios de compatibilidade.

### Veredito
**Recomendado**.

## Opção C — Descartar Florence nesta etapa

### Vantagens
- simplifica a narrativa do experimento;
- reduz manutenção de uma trilha parcial.

### Desvantagens
- desperdiça trabalho já estabilizado;
- remove uma fonte útil de descrição e observabilidade;
- não reduz a necessidade central de encontrar um gerador 4-view confiável;
- pode forçar reabertura futura do mesmo tema com menos contexto acumulado.

### Veredito
Só faz sentido se Florence passar a atrapalhar operacionalmente, o que não é a evidência atual.

# Etapas

## Etapa 1 — Congelar a decisão arquitetural de backend gerador plugável

### Resultado esperado
Assumir formalmente que o produtor de `MultiViewArtifact` é uma dependência substituível, não sinônimo de Florence.

### Checkpoint verificável
- existe decisão registrada separando `runtime florence auxiliar` de `gerador raster principal`;
- o plano de execução deixa de afirmar que [`LLM/Florence-2-Flux-Large`](LLM/Florence-2-Flux-Large) é, por si só, o gerador final das quatro vistas.

## Etapa 2 — Especificar a interface do adaptador de geração raster

### Resultado esperado
Definir uma fronteira de código futura que receba uma imagem preprocessada e devolva um `MultiViewArtifact` validado.

### Checkpoint verificável
- a interface proposta explicita entrada, saída, falhas e metadata mínima;
- o adaptador prevê normalização para `front/left/back/right/composite_preview/generation_metadata`;
- o contrato continua centralizado em [`app/multiview_contract.py`](app/multiview_contract.py).

## Etapa 3 — Provar um gerador raster 4-view externo/complementar

### Resultado esperado
Selecionar e validar um gerador capaz de realmente produzir quatro rasters coerentes a partir de uma imagem única.

### Checkpoint verificável
- o gerador escolhido produz quatro imagens reais, não apenas descrição textual;
- as quatro imagens passam por [`build_multiview_artifact()`](app/multiview_contract.py) sem erro;
- `generation_metadata` registra origem do gerador, resolução, ordem e parâmetros de geração.

## Etapa 4 — Integrar Florence apenas como enriquecimento auxiliar

### Resultado esperado
Usar Florence somente onde ele já provou valor: descrição, observabilidade, metadados, eventual apoio a prompt/consistência.

### Checkpoint verificável
- a falha ou ausência de Florence não impede a geração raster quando o backend principal estiver disponível;
- Florence não é requisito para validar o `MultiViewArtifact`;
- o status experimental em [`run_multiview_florence_checkpoint()`](app/app.py:99) continua coerente com seu papel auxiliar.

## Etapa 5 — Somente depois preparar a ingestão multi-view no TripoSR

### Resultado esperado
Desbloquear planejamento de `Nv=4` apenas quando existir evidência de artefato canônico estável.

### Checkpoint verificável
- existe conjunto de casos de teste com `MultiViewArtifact` válido;
- o pipeline consegue diferenciar claramente `single_view_legacy` de `multi_view_4_canonical`;
- a equipe consegue medir ganho potencial antes de tocar em [`TSR.forward()`](app/tsr/system.py:87).

# Ordem de execução recomendada

1. **congelar a decisão B** em documentação/planejamento;
2. **definir a interface do adaptador** de backend raster;
3. **avaliar e escolher** um gerador raster complementar com prova mínima de quatro vistas;
4. **integrar esse gerador ao contrato** de [`app/multiview_contract.py`](app/multiview_contract.py);
5. **manter Florence como auxiliar** de metadata/descrição/observabilidade;
6. **somente então** abrir o planejamento de ingestão `Nv=4` no TripoSR;
7. **comparar** multi-view vs baseline antes de qualquer promoção do fluxo.

# Riscos

## 1. Escolher um gerador complementar sem contrato claro

Se o backend raster for integrado antes da fronteira do adaptador estar definida, o sistema troca um acoplamento implícito por outro.

## 2. Reintroduzir a hipótese “Florence gera raster” por atalho

Mesmo com B, existe risco de algum ajuste futuro voltar a misturar descrição textual com geração visual comprovada.

## 3. Adiar demais a prova do gerador raster

Sem um checkpoint real do produtor 4-view, o projeto pode continuar evoluindo em camadas periféricas sem resolver o bloqueio central.

## 4. Abrir cedo demais a adaptação do TripoSR

Tocar em [`app/tsr/system.py`](app/tsr/system.py:87) antes de estabilizar o artefato 4-view aumenta o retrabalho e mistura duas incertezas ao mesmo tempo.

# Observações

1. O trabalho já feito em [`app/model_runtime.py`](app/model_runtime.py) **não foi desperdício**; ele continua sendo base útil para coordenação serial e observabilidade.
2. O checkpoint em [`app/app.py`](app/app.py) deve continuar existindo como trilha experimental isolada, mas não como prova de readiness do multi-view final.
3. O plano vigente em [`triposr-multiview-execution-plan-2026-05-07.md`](.vibecoding/plan/triposr-multiview-execution-plan-2026-05-07.md) precisa ser reinterpretado: a “Etapa Florence local” deve virar “Etapa de backend gerador plugável”, com Florence reclassificado como auxiliar enquanto não houver prova raster.
4. A opção C só deve ser considerada se houver custo operacional comprovado para manter Florence no repositório ou no runtime experimental, o que não aparece nas evidências atuais.

# Arquivos críticos a tocar futuramente

Os pontos mais prováveis de mudança em execução futura são:

- [`app/model_runtime.py`](app/model_runtime.py) — para acomodar um backend gerador complementar e coordenar serialização de runtime;
- [`app/multiview_contract.py`](app/multiview_contract.py) — apenas se surgir necessidade de metadata adicional, sem quebrar o contrato central;
- [`app/app.py`](app/app.py) — para expor o backend multi-view recomendado sem promover cedo demais o fluxo;
- [`app/tsr/system.py`](app/tsr/system.py:87) — somente após prova estável de `MultiViewArtifact` real;
- [`app/requirements.txt`](app/requirements.txt) — para dependências do gerador raster escolhido;
- [`triposr-multiview-execution-plan-2026-05-07.md`](.vibecoding/plan/triposr-multiview-execution-plan-2026-05-07.md) — para reclassificar a fase hoje centrada em Florence;
- [`triposr-florence-runtime-unblock-2026-05-08.md`](.vibecoding/learn/logs/triposr-florence-runtime-unblock-2026-05-08.md) — como evidência histórica do papel já validado do Florence;
- [`LLM/README.md`](LLM/README.md) — apenas se o projeto passar a documentar explicitamente Florence como componente auxiliar e não como candidato implícito ao raster final.

# Verificação planejada

1. Confirmar que a próxima versão do plano de execução recomenda **B**, não A.
2. Confirmar que nenhuma etapa futura depende de Florence gerar raster 4-view sem nova prova.
3. Confirmar que o primeiro artefato aceito pelo pipeline multi-view continua sendo um [`MultiViewArtifact`](app/multiview_contract.py) válido.
4. Confirmar que [`TSR.forward()`](app/tsr/system.py:87) permanece fora de escopo até haver casos válidos de 4 vistas reais.
5. Confirmar que o fallback `single_view_legacy` em [`app/app.py`](app/app.py) continua preservado durante toda a trilha experimental.
