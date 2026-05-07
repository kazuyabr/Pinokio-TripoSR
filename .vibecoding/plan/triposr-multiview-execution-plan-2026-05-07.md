# Objetivo

Executar a adaptação incremental do TripoSR para um fluxo `multi-view` de 4 vistas canônicas, com prioridade máxima para prevenção de bugs, rollback simples e validação contínua.

Fluxo-alvo de negócio:
1. upload da imagem original;
2. geração local de 4 vistas canônicas consistentes (`front`, `left`, `back`, `right`) usando [`LLM/Florence-2-Flux-Large`](LLM/Florence-2-Flux-Large);
3. descarregamento do Florence da VRAM;
4. carregamento/uso do TripoSR para `img-to-3D` a partir das 4 vistas;
5. geração de um único modelo 3D final.

Este plano sucede e consolida [`triposr-multiview-plan-2026-05-06.md`](.vibecoding/plan/triposr-multiview-plan-2026-05-06.md) e [`triposr-multiview-plan-2026-05-04.md`](.vibecoding/plan/triposr-multiview-plan-2026-05-04.md), em versão mais operacional e enxuta.

# Contexto

O estado atual ainda é `single-view`:
- [`app/app.py`](app/app.py) faz preprocess de uma imagem e envia uma única entrada ao modelo.
- [`TSR.forward()`](app/tsr/system.py:87) ainda força `Nv=1`.
- [`ImagePreprocessor.__call__()`](app/tsr/utils.py:95) já aceita lista de imagens.
- o tokenizer em [`app/tsr/models/tokenizers/image.py`](app/tsr/models/tokenizers/image.py) já indica suporte estrutural parcial a múltiplas vistas.

Logo, a adaptação deve ser incremental e reversível: primeiro preservar o fluxo atual, depois introduzir o fluxo novo em paralelo, e só então promover a nova rota se os checkpoints forem aprovados.

# Decisões aplicadas

1. O escopo desta fase é estritamente `front`, `left`, `back`, `right`.
2. `top` e `bottom` ficam fora do escopo.
3. A estratégia principal é `sem retreinamento`.
4. Fine-tuning ou retraining entram apenas como plano B.
5. Florence e TripoSR não devem permanecer carregados ao mesmo tempo na GPU nesta fase.
6. O fluxo atual `single-view` deve continuar funcionando durante toda a transição.
7. O multi-view deve entrar primeiro como caminho isolado, não como substituição imediata do pipeline atual.
8. Toda fase precisa ter critério de aceite, checkpoint e rollback explícito.

# Invariantes de negócio

1. Sempre gerar exatamente 4 vistas canônicas: `front`, `left`, `back`, `right`.
2. Sempre produzir um único modelo 3D final.
3. Nunca incluir `top` ou `bottom` nesta fase.
4. A ordem das vistas deve ser estável e imutável em todo o pipeline.
5. O personagem deve permanecer semanticamente consistente entre as 4 vistas.
6. O usuário continua com fluxo simples: upload -> processar -> gerar 3D.

# Invariantes técnicos

1. O caminho atual em [`generate()`](app/app.py:76) não deve ser quebrado cedo demais.
2. O preprocess legado deve continuar disponível enquanto o multi-view estiver em validação.
3. A adaptação multi-view não deve assumir coexistência segura de Florence e TripoSR na VRAM.
4. O contrato interno multi-view deve ser explícito, com campos nomeados por vista, e não depender apenas de uma imagem composta.
5. O pipeline só pode chamar o TripoSR após validar o contrato mínimo das 4 vistas.
6. A mudança de `Nv=1` para `Nv=4` só deve ocorrer depois de o payload multi-view estar estável e testável.
7. Toda nova etapa deve poder ser desligada sem reverter refatorações grandes.

# Estratégia

A execução deve seguir a ordem de menor risco:

1. **Preservar o baseline atual**
   - não alterar cedo o fluxo principal de [`app/app.py`](app/app.py), a UI principal nem a semântica atual de geração 3D;
   - evitar tocar cedo em [`app/tsr/system.py`](app/tsr/system.py) antes de existir payload multi-view validado.

2. **Criar a camada de contrato multi-view antes da integração profunda**
   - definir o artefato lógico: `front`, `left`, `back`, `right`, `composite_preview`, `generation_metadata`;
   - validar ordem, integridade, padding, alinhamento e consistência antes de enviar ao TripoSR.

3. **Isolar a etapa Florence**
   - carregar Florence só no estágio de geração das vistas;
   - persistir temporariamente as saídas;
   - descarregar Florence da VRAM antes de qualquer carga do TripoSR.

4. **Adaptar o TripoSR por último e de forma mínima**
   - primeiro permitir entrada multi-view controlada;
   - depois remover a suposição rígida de `Nv=1` em [`TSR.forward()`](app/tsr/system.py:87);
   - manter fallback single-view intacto.

# Fases

## Fase 0 — Congelar baseline e guardrails

### Objetivo
Definir o que não pode quebrar durante o desenvolvimento.

### Escopo
- congelar o baseline do fluxo atual `single-view`;
- congelar o contrato de negócio de 4 vistas;
- registrar guardrails de prevenção de bugs.

### Não alterar cedo demais
- a assinatura pública e o comportamento principal de [`preprocess()`](app/app.py:57);
- a assinatura pública e o comportamento principal de [`generate()`](app/app.py:76);
- o caminho padrão atual de UI em [`app/app.py`](app/app.py).

### Critérios de aceite
- baseline atual identificado e tratado como referência oficial;
- escopo 4-view fixado em `front`, `left`, `back`, `right`;
- pontos sensíveis do pipeline atual listados.

### Checkpoints
- **manual:** revisar visualmente o fluxo atual e registrar o que é comportamento esperado;
- **técnico:** confirmar os pontos de acoplamento em [`app/app.py`](app/app.py) e [`app/tsr/system.py`](app/tsr/system.py).

### Rollback
- nenhum impacto funcional; fase apenas de congelamento e delimitação.

## Fase 1 — Contrato multi-view e validação preventiva

### Objetivo
Criar um contrato interno estável para o multi-view antes de tocar no TripoSR.

### Escopo
- definir o payload interno com `front`, `left`, `back`, `right`;
- definir validações mínimas de preprocess;
- definir rejeições explícitas para saídas inconsistentes.

### Guardrails de prevenção de bugs
- rejeitar composição com ordem ambígua;
- rejeitar vista cortada ou com crop evidente;
- rejeitar desalinhamento grosseiro entre as 4 vistas;
- rejeitar saída sem consistência mínima de fundo e enquadramento.

### Critérios de aceite
- existe contrato explícito e verificável antes da reconstrução;
- o pipeline pode diferenciar claramente `multi_view_validated` de `single_view_legacy`.

### Checkpoints
- **manual:** inspecionar `composite_preview` e miniaturas das 4 vistas;
- **técnico:** validar presença, ordem e dimensões esperadas de cada vista.

### Rollback
- desativar apenas a rota multi-view e manter o fluxo single-view.

## Fase 2 — Etapa Florence local com descarregamento seguro

### Objetivo
Planejar a etapa de geração 4-view com Florence sem contaminar o restante do app.

### Escopo
- usar [`LLM/Florence-2-Flux-Large`](LLM/Florence-2-Flux-Large) como fonte local da etapa de geração;
- aplicar o prompt canônico já validado pelo usuário;
- salvar artefato composto e vistas lógicas;
- descarregar Florence explicitamente antes do TripoSR.

### Guardrails de prevenção de bugs
- não compartilhar instância de modelo entre Florence e TripoSR;
- não seguir para reconstrução se a liberação de VRAM falhar ou ficar ambígua;
- manter metadados suficientes para reprocessar sem nova inferência, se necessário.

### Critérios de aceite
- Florence gera um artefato 4-view válido;
- o pipeline consegue encerrar a etapa Florence antes de iniciar o TripoSR;
- o artefato fica pronto para reuso e debug.

### Checkpoints
- **manual:** verificar se as 4 vistas correspondem a frente, esquerda, costas e direita;
- **técnico:** medir uso de VRAM antes/depois da descarga e confirmar ausência de coexistência desnecessária.

### Rollback
- desligar a etapa Florence e voltar a operar somente com a trilha single-view.

## Fase 3 — Integração multi-view no TripoSR sem retreinamento

### Objetivo
Adaptar o pipeline para aceitar 4 vistas sem alterar pesos do modelo.

### Escopo
- permitir que [`generate()`](app/app.py:76) aceite o payload multi-view validado;
- adaptar [`TSR.forward()`](app/tsr/system.py:87) para `Nv` dinâmico;
- preservar modo legado.

### Guardrails de prevenção de bugs
- não substituir o modo legado; manter os dois caminhos explicitamente separados;
- não misturar parsing do mosaico com lógica de inferência;
- não alterar tokenizer/preprocess além do mínimo necessário enquanto `Nv=4` ainda estiver sendo provado.

### Critérios de aceite
- o TripoSR executa com `Nv=4` sem quebrar `Nv=1`;
- o caminho multi-view usa ordem canônica estável;
- a geração de mesh continua produzindo um único resultado final.

### Checkpoints
- **manual:** comparar o resultado visual do 3D multi-view com o baseline atual;
- **técnico:** confirmar shapes, ordem de vistas e ausência de regressão do fluxo legado.

### Rollback
- retornar imediatamente ao caminho `single_view_legacy` sem remover código novo isolado.

## Fase 4 — Exposição controlada na UI

### Objetivo
Refletir o novo fluxo na interface sem quebrar a UX existente.

### Escopo
- exibir preview do artefato composto;
- opcionalmente exibir miniaturas das vistas para debug;
- manter o fluxo simples para o usuário.

### Guardrails de prevenção de bugs
- não trocar o fluxo padrão cedo demais;
- evitar renomeações amplas antes da estabilidade funcional;
- preferir ativação explícita do caminho multi-view durante a validação.

### Critérios de aceite
- o usuário entende o que foi processado antes de gerar o 3D;
- a UI continua simples e sem passos ambíguos.

### Checkpoints
- **manual:** validar clareza do fluxo na interface;
- **técnico:** confirmar que a UI não quebra o fluxo atual nem cria acoplamento indevido.

### Rollback
- ocultar os elementos multi-view e manter a interface anterior.

## Fase 5 — Validação comparativa e decisão

### Objetivo
Confirmar se o fluxo novo entrega ganho real sem regressão inaceitável.

### Escopo
- comparar multi-view vs single-view;
- avaliar qualidade geométrica, consistência lateral/costas e estabilidade;
- avaliar custo adicional de tempo e VRAM.

### Critérios de aceite
- multi-view iguala ou supera o baseline em qualidade percebida;
- não há regressão crítica no fluxo atual;
- o custo operacional permanece aceitável.

### Checkpoints
- **manual:** comparação visual de casos de teste;
- **técnico:** comparação de tempo, memória e integridade dos outputs.

### Rollback
- manter multi-view como experimental ou desligado por padrão.

## Fase 6 — Plano B

### Objetivo
Delimitar o uso de fine-tuning/retraining apenas se a trilha principal falhar.

### Gatilhos
- falha estrutural persistente da ingestão `Nv=4` sem solução limpa por código;
- ausência consistente de ganho geométrico mesmo com vistas corretas;
- artefatos recorrentes de fusão entre vistas.

### Diretriz
- tentar primeiro fine-tuning focalizado;
- deixar retraining amplo como último recurso.

# Riscos principais

## 1. Preprocess inconsistente
Risco de crop, padding irregular ou ordem errada.

**Mitigação:** contrato rígido, validação antes da inferência e rejeição explícita.

## 2. Pico de VRAM
Risco de Florence e TripoSR competirem por memória.

**Mitigação:** execução serial obrigatória, descarregamento explícito e medição por checkpoint.

## 3. Segmentação ou parsing incorreto das 4 vistas
Risco de alimentar o TripoSR com vistas trocadas ou ambíguas.

**Mitigação:** ordem canônica fixa e validação lógica independente da imagem composta.

## 4. Desalinhamento entre vistas
Risco de costas/laterais inconsistentes degradarem a reconstrução.

**Mitigação:** bloquear avanço quando o contrato visual mínimo falhar.

## 5. Regressão do fluxo atual
Risco de quebrar o pipeline single-view ao adaptar [`app/app.py`](app/app.py) e [`app/tsr/system.py`](app/tsr/system.py).

**Mitigação:** manter caminhos separados, ativação controlada e rollback imediato por fase.

# Checkpoints mínimos obrigatórios

## Checkpoint A — Contrato visual
- as 4 vistas existem;
- a ordem é `front`, `left`, `back`, `right`;
- não há crop relevante;
- há alinhamento mínimo aceitável.

## Checkpoint B — VRAM
- Florence é descarregado antes do TripoSR;
- não há coexistência desnecessária na GPU;
- o pico de memória fica dentro do limite da máquina alvo.

## Checkpoint C — Integração funcional
- o caminho multi-view roda com `Nv=4`;
- o caminho legado continua rodando com `Nv=1`.

## Checkpoint D — Qualidade
- o 3D final não regrede de forma crítica;
- há ganho ou preservação clara nas vistas laterais e traseiras.

# Arquivos críticos para futura execução

Arquivos mais prováveis de mudança:
- [`app/app.py`](app/app.py)
- [`app/tsr/system.py`](app/tsr/system.py)
- [`app/tsr/utils.py`](app/tsr/utils.py)
- potencial novo módulo de contrato/validação multi-view em [`app/`](app)
- potencial novo módulo de integração Florence em [`app/`](app)

Arquivos de referência:
- [`triposr-multiview-plan-2026-05-06.md`](.vibecoding/plan/triposr-multiview-plan-2026-05-06.md)
- [`triposr-multiview-plan-2026-05-04.md`](.vibecoding/plan/triposr-multiview-plan-2026-05-04.md)
- [`LLM/Florence-2-Flux-Large/README.md`](LLM/Florence-2-Flux-Large/README.md)

# Observações

1. O maior cuidado desta execução é evitar mudança estrutural prematura em [`TSR.forward()`](app/tsr/system.py:87) antes de o contrato multi-view estar estável.
2. O segundo maior cuidado é evitar regressão funcional em [`generate()`](app/app.py:76) durante a transição.
3. O novo fluxo deve nascer como trilha controlada, verificável e reversível.
4. O plano só recomenda expansão de escopo depois que a trilha `front/left/back/right` estiver estável.
5. Fine-tuning não faz parte da execução principal desta fase.

# Verificação end-to-end planejada

1. Confirmar baseline single-view funcional.
2. Confirmar geração local de `front`, `left`, `back`, `right` com Florence.
3. Confirmar validação do contrato multi-view antes da reconstrução.
4. Confirmar descarga de Florence da VRAM.
5. Confirmar inferência do TripoSR com `Nv=4`.
6. Confirmar preservação do fallback single-view.
7. Comparar o modelo 3D final contra o baseline atual antes de qualquer decisão de promoção do novo fluxo.