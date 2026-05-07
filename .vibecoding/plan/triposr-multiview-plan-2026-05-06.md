# Objetivo

Revisar o planejamento técnico do multi-view no TripoSR para o novo direcionamento do usuário: incorporar uma etapa local de processamento de imagem baseada em `LLM/Florence-2-Flux-Large`, gerar exatamente 4 vistas canônicas consistentes (`front`, `left`, `back`, `right`) com o prompt canônico validado, descarregar esse modelo da VRAM e então carregar/usar o TripoSR para reconstrução img-to-3D em um único modelo 3D mais detalhado.

Este plano sucede [`triposr-multiview-plan-2026-05-04.md`](.vibecoding/plan/triposr-multiview-plan-2026-05-04.md) e refina o foco para integração local direta no fluxo do app, sem priorizar retreinamento nesta fase.

# Contexto

## Direcionamento consolidado do usuário

O escopo permanece explicitamente restrito a quatro vistas canônicas consistentes:
1. frente
2. esquerda
3. costas
4. direita

Ficam fora do escopo atual:
- top view
- bottom view
- qualquer vista adicional inferida automaticamente

O prompt canônico validado pelo usuário para geração 4-view passa a ser a referência oficial do contrato visual desta trilha:

> Create a full body orthographic turnaround sheet of this exact character, featuring four poses on a seamless solid pure white background. Image size 2048x1024. No frames, no borders, no boxes, and no outlines around the figures. Arrange in a clean horizontal row centered in the middle of the canvas. The layout must follow a strict invisible grid where each character is perfectly centered within its own 512x1024 zone. Poses: front view, left side view, back view, right side view. All views must be aligned to the same horizontal axis and ground level. Aggressively scale down the character so the entire silhouette, including wings and accessories, fits completely within its sector with at least 20% empty white space (padding) on all sides to prevent any cropping. High consistency in style and proportions. No shadows, no background noise, just the character on flat white.

## Estado técnico observado no projeto

O fluxo atual ainda é semanticamente single-view:
- [`app/app.py`](app/app.py) carrega o TripoSR no bootstrap do app, faz preprocess de uma única imagem e chama [`generate()`](app/app.py:76).
- [`TSR.forward()`](app/tsr/system.py:87) em [`app/tsr/system.py`](app/tsr/system.py) força `Nv=1` no empacotamento da entrada e também no achatamento dos tokens.
- [`ImagePreprocessor.__call__()`](app/tsr/utils.py:95) já aceita lista de imagens e consegue empilhar múltiplas vistas.
- [`DINOSingleImageTokenizer.forward()`](app/tsr/models/tokenizers/image.py:45) já lê `n_input_views` dinamicamente a partir do tensor de entrada, o que indica suporte estrutural parcial a multi-view no tokenizer.
- [`app/gpu_runtime_check.py`](app/gpu_runtime_check.py) já oferece um ponto útil para planejar medições de VRAM/latência na troca de modelos.

## Estado técnico observado no modelo local Florence

A pasta local [`LLM/Florence-2-Flux-Large`](LLM/Florence-2-Flux-Large) passa a ser a fonte oficial de integração do estágio de processamento.

Evidências relevantes:
- [`README.md`](LLM/Florence-2-Flux-Large/README.md) documenta carregamento local por Transformers com `trust_remote_code=True`.
- [`config.json`](LLM/Florence-2-Flux-Large/config.json) define arquitetura `Florence2ForConditionalGeneration` e `torch_dtype` em `float16`.
- o pacote é descrito como `image-text-to-text`, o que prova portabilidade local do componente, mas não prova sozinho a estratégia exata de síntese raster equivalente ao fluxo observado no ComfyUI.

Portanto, a arquitetura deve assumir duas possibilidades controladas:
1. o modelo local já consegue produzir diretamente o turnaround 4-view via código;
2. o modelo local cobre apenas parte da lógica observada no ComfyUI e precisará de um adaptador adicional de síntese/decodificação para reproduzir o comportamento validado.

# Decisões aplicadas

1. O contrato multi-view desta fase continua limitado a `front`, `left`, `back`, `right`.
2. `top` e `bottom` permanecem fora do escopo e não devem aparecer no payload interno desta revisão.
3. O prompt canônico validado pelo usuário torna-se referência obrigatória do estágio de geração 4-view.
4. A pasta local [`LLM/Florence-2-Flux-Large`](LLM/Florence-2-Flux-Large) passa a ser a fonte prioritária de integração do estágio de processamento de imagem.
5. O pipeline-alvo passa a ser sequencial e mutuamente exclusivo na GPU: Florence primeiro, descarregamento de VRAM, depois TripoSR.
6. A estratégia principal desta fase é `sem retreinamento`, com adaptação por código para consumo de quatro vistas canônicas.
7. Fine-tuning ou retraining ficam documentados apenas como plano B, acionado somente se os checkpoints mostrarem que o TripoSR pré-treinado não aproveita adequadamente as quatro vistas.
8. A integração deve depender de um contrato de saída validado, e não da semântica interna do ComfyUI.
9. O fallback single-view deve permanecer disponível durante toda a transição.

# Estratégia

## Estratégia principal recomendada

A recomendação é dividir a solução em três camadas desacopladas:

### 1. Camada de geração 4-view local

Responsável por:
- receber a foto enviada pelo usuário;
- aplicar o prompt canônico ao modelo local Florence;
- produzir um artefato 4-view validável em layout horizontal 2048x1024;
- emitir tanto a imagem composta quanto as quatro vistas lógicas nomeadas.

### 2. Camada de orquestração de memória/GPU

Responsável por:
- carregar Florence apenas durante o estágio de processamento;
- salvar o artefato 4-view e os metadados necessários;
- liberar explicitamente o modelo Florence da VRAM após a geração;
- carregar o TripoSR somente depois da liberação;
- evitar coexistência desnecessária dos dois modelos grandes na GPU.

### 3. Camada de ingestão multi-view no TripoSR

Responsável por:
- decompor ou receber as quatro vistas em ordem canônica;
- montar um payload multi-view explícito;
- substituir a suposição `Nv=1` por `Nv` dinâmico no caminho de inferência;
- preservar fallback single-view sem regressão funcional.

# Análise de viabilidade: cenário sem treino

## Conclusão de planejamento

É tecnicamente plausível tentar primeiro uma integração sem retreinamento.

Base para essa conclusão:
- [`ImagePreprocessor.__call__()`](app/tsr/utils.py:95) já aceita listas de imagens.
- [`DINOSingleImageTokenizer.forward()`](app/tsr/models/tokenizers/image.py:45) já calcula `n_input_views` a partir do tensor, sem estar rigidamente preso a uma única vista.
- o bloqueio mais explícito está em [`TSR.forward()`](app/tsr/system.py:87), que hoje injeta artificialmente `Nv=1` ao reorganizar a entrada e ao achatar os tokens.

## Interpretação arquitetural

Isso sugere que o TripoSR atual provavelmente aceita uma prova de conceito multi-view com adaptação de código, mesmo sem retreinamento, desde que:
- o payload preserve ordem canônica estável;
- o empacotamento de múltiplas imagens respeite o formato esperado do backbone;
- a UI e o preprocess deixem de tratar “imagem processada” como único tensor final;
- a validação compare sistematicamente qualidade versus baseline single-view.

## Limite dessa conclusão

Essa leitura não prova que o modelo pré-treinado produzirá a melhor geometria possível com quatro vistas.
Ela prova apenas que existe base estrutural suficiente para priorizar uma trilha de integração por código antes de considerar fine-tuning.

# Análise de viabilidade: cenário com fine-tuning ou retraining

## Quando considerar

Fine-tuning ou retraining só devem entrar na trilha se ocorrer pelo menos um dos cenários abaixo:
- o fluxo multi-view sem treino falhar funcionalmente por incompatibilidade de shape/condicionamento que não possa ser resolvida sem alterar pesos;
- o modelo aceitar `Nv=4`, mas a malha final continuar equivalente ou pior que o baseline single-view de forma consistente;
- surgirem artefatos de fusão entre vistas que indiquem ausência de generalização do condicionamento multi-view no backbone atual.

## Papel desse cenário

Este cenário é fallback posterior, não etapa da fase atual.

## Resultado esperado do fallback

Caso seja necessário, o plano B deve focar em:
- fine-tuning do condicionamento multi-view antes de qualquer retraining amplo;
- preservar o contrato de quatro vistas canônicas como dataset supervisionado de entrada;
- avaliar custo computacional, curadoria de pares imagem->4-view->3D e impacto de manutenção antes de comprometer produto e infraestrutura.

# Contrato técnico do artefato 4-view

## Saída física esperada

Formato canônico da imagem composta:
- resolução: `2048x1024`
- fundo: branco puro
- layout: uma linha horizontal
- zonas lógicas: 4 setores de `512x1024`
- ordem fixa: `front`, `left`, `back`, `right`

## Requisitos obrigatórios

1. Personagem exato e consistente nas quatro vistas.
2. Corpo inteiro visível em cada setor.
3. Pelo menos 20% de padding branco em todos os lados de cada setor.
4. Nenhum cropping.
5. Alinhamento no mesmo eixo horizontal e no mesmo nível de chão.
6. Sem sombras, ruído, molduras, caixas ou bordas.
7. Consistência de proporções, silhueta, acessórios e asas.
8. Orientações realmente distintas, sem duplicação ou espelhamento incorreto.

## Payload lógico interno recomendado

O sistema não deve tratar a imagem composta apenas como um bitmap.
O payload planejado deve conter:
- `front`
- `left`
- `back`
- `right`
- `composite_preview`
- `source_prompt`
- `source_model`
- `image_size`
- `zone_size`
- `padding_policy`
- `generation_metadata`

# Arquitetura recomendada

## Fluxo-alvo

1. upload da foto
2. validação mínima da entrada
3. carregamento do adaptador local Florence
4. geração da imagem 4-view com o prompt canônico
5. validação do contrato visual
6. persistência temporária do artefato composto e das quatro vistas
7. descarregamento explícito de Florence da VRAM
8. carregamento do TripoSR
9. ingestão multi-view com `Nv=4`
10. extração de malha
11. entrega de um único modelo 3D

## Princípio de isolamento de modelos

A aplicação não deve manter Florence e TripoSR residentes ao mesmo tempo na GPU, exceto se uma futura medição provar que isso é seguro e útil. Nesta fase, a estratégia padrão deve ser serial:
- fase Florence ocupa VRAM;
- flush/liberação;
- fase TripoSR ocupa VRAM.

## Princípio de isolamento de integração

A aplicação deve depender de um adaptador local do Florence e de um contrato multi-view, não do ComfyUI.
O ComfyUI permanece apenas como evidência comportamental de referência.

# Fases

## Fase 0 — Revisão do contrato e baseline

### Objetivo
Congelar o contrato canônico 4-view e o baseline single-view atual.

### Escopo
- consolidar o prompt canônico oficial;
- registrar a ordem `front`, `left`, `back`, `right`;
- preservar baseline de saída atual do TripoSR single-view.

### Checkpoint
Há um documento único de referência para contrato visual e comparação futura.

## Fase 1 — Planejamento do adaptador local Florence

### Objetivo
Desenhar o adaptador que usa [`LLM/Florence-2-Flux-Large`](LLM/Florence-2-Flux-Large) dentro do app.

### Escopo
- definir interface de carregamento local por Transformers;
- definir entrada: foto + prompt canônico;
- definir saída: `composite_preview` + quatro vistas canônicas + metadados;
- prever ponto explícito de validação do contrato visual.

### Checkpoint
Existe um contrato de integração do Florence independente do restante do app.

## Fase 2 — Planejamento da orquestração de VRAM

### Objetivo
Desenhar a sequência segura de uso de GPU entre Florence e TripoSR.

### Escopo
- definir ciclo de vida de carregamento e descarregamento dos modelos;
- planejar limpeza de objetos, cache CUDA e arquivos temporários;
- planejar métricas de pico de VRAM e latência usando a base de [`app/gpu_runtime_check.py`](app/gpu_runtime_check.py).

### Checkpoint
O fluxo serial de modelos está definido e é verificável por telemetria simples.

## Fase 3 — Planejamento da ingestão multi-view no TripoSR sem treino

### Objetivo
Adaptar conceitualmente o TripoSR para aceitar 4 vistas canônicas com alteração de código, sem mexer em pesos.

### Escopo
- revisar [`generate()`](app/app.py:76) para aceitar payload multi-view em vez de uma única imagem processada;
- revisar [`TSR.forward()`](app/tsr/system.py:87) para parar de forçar `Nv=1`;
- revisar a composição dos tensores que entram em [`image_tokenizer()`](app/tsr/system.py:104);
- preservar fallback legado single-view.

### Checkpoint
Existe um caminho arquitetural coerente para `single_view_legacy` e `multi_view_4_canonical`.

## Fase 4 — Planejamento da UI e do fluxo do usuário

### Objetivo
Refletir no app que a etapa de preprocess agora pode produzir um conjunto 4-view.

### Escopo
- renomear semanticamente a saída visual de preprocess;
- expor preview da imagem composta;
- opcionalmente expor miniaturas das quatro vistas para debug;
- manter UX simples: upload -> processar -> gerar 3D.

### Checkpoint
A UI planejada deixa claro que o insumo do TripoSR passou a ser multi-view.

## Fase 5 — Validação comparativa sem treino

### Objetivo
Medir se a adaptação por código entrega ganho suficiente sem retreinamento.

### Escopo
- comparar resultado com baseline single-view;
- medir integridade geométrica;
- medir consistência de membros, asas, acessórios e costas;
- medir custo extra de tempo e VRAM.

### Checkpoint
Decisão objetiva sobre continuar sem treino ou acionar plano B.

## Fase 6 — Plano B com fine-tuning/retraining

### Objetivo
Só existir como fallback posterior.

### Escopo
- documentar gatilhos de ativação;
- definir escopo mínimo preferencial: fine-tuning do condicionamento multi-view;
- deixar retraining amplo como último recurso.

### Checkpoint
Plano B delimitado, sem contaminar a fase principal.

# Etapas

1. Revisar o plano anterior e registrar esta revisão como sucessora.
2. Congelar o prompt canônico como contrato obrigatório do gerador 4-view.
3. Planejar um adaptador local para [`LLM/Florence-2-Flux-Large`](LLM/Florence-2-Flux-Large).
4. Definir o payload interno canônico: `front`, `left`, `back`, `right`, `composite_preview`, metadados.
5. Planejar a validação automática do contrato visual antes de chamar o TripoSR.
6. Planejar a troca serial de modelos na GPU com descarregamento explícito de Florence.
7. Planejar a remoção da suposição `Nv=1` em [`TSR.forward()`](app/tsr/system.py:87).
8. Planejar a adaptação de [`generate()`](app/app.py:76) para aceitar o payload multi-view.
9. Planejar a UI para exibir `Processed Multi-View` como insumo principal.
10. Definir checkpoints objetivos para validar a estratégia sem treino.
11. Documentar o fallback de fine-tuning/retraining somente após falha dos checkpoints.

# Arquivos críticos para futura execução

Arquivos com maior probabilidade de mudança na fase de implementação:
- [`app/app.py`](app/app.py)
- [`app/tsr/system.py`](app/tsr/system.py)
- [`app/tsr/utils.py`](app/tsr/utils.py)
- [`app/tsr/models/tokenizers/image.py`](app/tsr/models/tokenizers/image.py)
- [`app/gpu_runtime_check.py`](app/gpu_runtime_check.py)
- potencial novo módulo de adaptação local Florence em `app/`
- potencial novo módulo de contrato/validação multi-view em `app/`

Arquivos de referência de contexto:
- [`LLM/Florence-2-Flux-Large/README.md`](LLM/Florence-2-Flux-Large/README.md)
- [`LLM/Florence-2-Flux-Large/config.json`](LLM/Florence-2-Flux-Large/config.json)
- [`triposr-multiview-plan-2026-05-04.md`](.vibecoding/plan/triposr-multiview-plan-2026-05-04.md)

# Critérios de aceite

1. O plano registra explicitamente o novo pipeline: upload -> Florence local -> unload VRAM -> TripoSR -> 3D.
2. O plano adota [`LLM/Florence-2-Flux-Large`](LLM/Florence-2-Flux-Large) como fonte prioritária de integração do estágio de processamento.
3. O contrato continua limitado a quatro vistas canônicas.
4. O prompt canônico validado está incorporado ao plano como referência oficial.
5. O cenário sem retreinamento é tratado como caminho principal.
6. O cenário com fine-tuning/retraining aparece apenas como fallback posterior.
7. O plano registra análise fundamentada de que o TripoSR atual provavelmente pode ser testado com 4 vistas por adaptação de código, porque o tokenizer já aceita múltiplas vistas e o principal bloqueio observado é o `Nv=1` fixo em [`TSR.forward()`](app/tsr/system.py:87).
8. O plano separa claramente integração do Florence, orquestração de VRAM e ingestão multi-view no TripoSR.
9. O plano define fases, riscos, checkpoints e critérios de validação.
10. O fallback single-view permanece previsto.

# Riscos

## Risco 1 — Florence local não reproduzir sozinho o comportamento observado no ComfyUI

O pacote local pode não sintetizar diretamente a imagem 4-view final sem componentes adicionais.

### Mitigação
- encapsular Florence atrás de um adaptador;
- validar primeiro a capacidade real de saída do modelo local;
- se necessário, mapear o passo complementar sem contaminar o contrato downstream.

## Risco 2 — O TripoSR aceitar `Nv=4`, mas não melhorar a geometria

A entrada multi-view pode ser tecnicamente aceita e mesmo assim não render ganho perceptível.

### Mitigação
- manter baseline single-view;
- definir comparação objetiva de qualidade;
- só promover o fluxo novo após validação.

## Risco 3 — Pico de VRAM inviável

Florence e TripoSR podem pressionar memória se coexistirem ou se a limpeza for incompleta.

### Mitigação
- fluxo serial obrigatório;
- checkpoints de telemetria;
- descarregamento explícito antes de carregar o próximo modelo.

## Risco 4 — Parsing inconsistente do composto 4-view

Se a imagem não respeitar rigorosamente o grid lógico, o payload pode nascer desalinhado.

### Mitigação
- contrato visual rígido;
- validação de zonas 512x1024;
- rejeição de artefatos que não respeitem padding e ordem.

## Risco 5 — Regressão de UX

O fluxo pode ficar mais lento ou complexo para o usuário final.

### Mitigação
- manter UX linear;
- esconder complexidade de troca de modelos;
- preservar fallback single-view como escape operacional.

## Risco 6 — Expansão prematura para top/bottom

Adicionar vistas extras agora aumentaria a ambiguidade do payload e o custo da validação.

### Mitigação
- manter escopo restrito a quatro vistas canônicas até a conclusão dos checkpoints da fase principal.

# Checkpoints de validação

## Checkpoint A — Validação do gerador local

Responder objetivamente:
- o adaptador local de Florence produz o turnaround 4-view no formato esperado?
- a saída respeita ordem, padding, alinhamento e ausência de crop?

## Checkpoint B — Validação da troca de VRAM

Responder objetivamente:
- Florence pode ser descarregado completamente antes da carga do TripoSR?
- o pico de VRAM permanece dentro do envelope aceitável da máquina alvo?

## Checkpoint C — Validação funcional do TripoSR sem treino

Responder objetivamente:
- o TripoSR executa inferência com `Nv=4` após a adaptação?
- não há quebra do fallback single-view?

## Checkpoint D — Validação de qualidade

Responder objetivamente:
- o modelo 3D final melhora ou pelo menos preserva qualidade em relação ao single-view?
- há melhora visível em costas, laterais, asas e acessórios?

## Checkpoint E — Gatilho do plano B

Acionar somente se:
- Checkpoint C falhar estruturalmente sem solução limpa por código; ou
- Checkpoint D falhar repetidamente em qualidade.

# Observações

1. Esta revisão muda a fonte prioritária de integração do estágio de processamento: sai a dependência conceitual do ComfyUI e entra o modelo local [`LLM/Florence-2-Flux-Large`](LLM/Florence-2-Flux-Large).
2. O ComfyUI continua relevante apenas como referência de comportamento já observado pelo usuário.
3. A evidência mais forte para priorizar o cenário sem treino é a existência de suporte parcial nativo a múltiplas vistas no preprocess/tokenizer, contrastando com o gargalo explícito em [`TSR.forward()`](app/tsr/system.py:87).
4. Esta revisão não assume que o modelo local Florence seja, por si só, definitivamente suficiente para síntese raster final; ela planeja essa verificação como checkpoint obrigatório.
5. A prioridade desta fase é reduzir risco por integração incremental e reversível, não maximizar ambição arquitetural.

# Recomendação final

A recomendação é executar a futura implementação nesta ordem:

1. integrar o gerador local baseado em [`LLM/Florence-2-Flux-Large`](LLM/Florence-2-Flux-Large) como estágio de processamento;
2. validar o contrato rígido do turnaround 4-view com o prompt canônico;
3. serializar o uso de GPU: Florence primeiro, descarregar, TripoSR depois;
4. adaptar o TripoSR para `Nv=4` por código, sem retreinamento como primeira tentativa;
5. comparar contra o baseline single-view;
6. só considerar fine-tuning ou retraining se os checkpoints mostrarem que o TripoSR pré-treinado não converte bem o ganho informacional das quatro vistas em ganho geométrico real.

Essa ordem minimiza retrabalho, respeita o escopo restrito de quatro vistas canônicas e preserva a reversibilidade técnica da integração.

# Verificação end-to-end planejada

1. Confirmar que o prompt canônico está congelado como fonte de verdade do gerador.
2. Confirmar que o adaptador local Florence recebe uma foto e produz `composite_preview` + `front` + `left` + `back` + `right`.
3. Confirmar que o composto respeita `2048x1024` e zonas de `512x1024`.
4. Confirmar que Florence é descarregado antes da carga do TripoSR.
5. Confirmar que o payload multi-view entra no TripoSR com `Nv=4`.
6. Confirmar que o fallback single-view continua funcional.
7. Comparar o modelo 3D resultante com o baseline atual antes de qualquer discussão sobre fine-tuning.