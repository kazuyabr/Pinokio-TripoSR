# Objetivo

Atualizar o planejamento técnico do multi-view do TripoSR para incorporar uma evidência validada de geração local 4-view, tratando `anjinho-all-sides.png` como artefato canônico de entrada multi-view e posicionando uma etapa opcional/plugável de geração local via ComfyUI + Florence antes da ingestão pelo TripoSR.

Nesta fase, o escopo multi-view fica explicitamente restrito a 4 vistas canônicas consistentes — frente, esquerda, costas e direita — sem incluir topo da cabeça ou planta do pé.

Este plano revisa e sucede o plano anterior de `triposr-multiview-plan-2026-05-03.md`, sem substituir a meta principal: melhorar a reconstrução 3D a partir de uma entrada mais informativa do que a imagem processada única.

# Contexto

O pipeline atual do projeto ainda é centrado em uma única imagem processada:
- `app/app.py` faz preprocess de uma imagem e envia uma única entrada ao modelo.
- `app/tsr/system.py` mantém o fluxo semanticamente single-view ao forçar `Nv=1`.
- `app/tsr/models/tokenizers/image.py` indica suporte estrutural a múltiplas vistas no tokenizer, mas esse suporte não está exposto end-to-end.

Novo contexto validado pelo usuário:
- existe um resultado 4-view funcional em `anjinho-all-sides.png`;
- esse artefato foi gerado localmente a partir de `anjinho-lowpoly.png`;
- o caminho validado usa ComfyUI + Florence;
- não há dependência de API key;
- a inspeção do diretório externo `C:\pinokio\api\inteliweb-comfyui.git\app\models\LLM\Florence-2-Flux-Large` mostrou uma estrutura padrão Hugging Face/Transformers, com `configuration_florence2.py`, `processing_florence2.py`, `modeling_florence2.py` e carregamento direto por `AutoModelForCausalLM.from_pretrained(..., trust_remote_code=True)` e `AutoProcessor.from_pretrained(...)` documentado no `README.md`;
- isso indica que a peça Florence pode ser portada para Python puro fora do ComfyUI;
- porém, o próprio pacote inspecionado se apresenta como `image-text-to-text`, isto é, ele comprova portabilidade do componente Florence, mas não comprova isoladamente que ele sozinho sintetiza a imagem final `anjinho-all-sides.png`;
- portanto, deve-se assumir que o resultado 4-view observado pode depender de um pipeline maior no ComfyUI, no qual Florence atua como um componente e não necessariamente como gerador raster final;
- o usuário decidiu restringir explicitamente o escopo da fase atual a 4 vistas canônicas consistentes — frente, esquerda, costas e direita;
- vistas extras como topo da cabeça e planta do pé ficam fora da fase atual;
- a justificativa registrada é priorizar alinhamento consistente, pois o ganho incremental esperado de top/bottom é considerado pequeno frente ao risco de desalinhamento;
- o prompt abaixo foi validado pelo usuário como referência funcional do contrato visual desejado:

> create full body turnaround sheet of this exact character, four poses on pure white background in clean horizontal row: front view, left profile facing left, back view, right profile facing right, evenly spaced, consistent style and proportions, each figure centered, no overlap, use uniform frame size for all poses, define a consistent bounding box based on the widest and tallest pose, scale all characters to fit inside this same box, keep large empty space around each, enforce wide safe margins, nothing touches borders, no cropping ever, full silhouette always visible including wings hair accessories, each pose must show distinct orientation not mirrored or duplicated, prioritize padding over size, equal spacing between frames, no background noise, no shadows

Arquivos críticos observados para futura execução:
- `app/app.py`
- `app/tsr/system.py`
- `app/tsr/utils.py`
- `app/tsr/models/tokenizers/image.py`
- `app/gpu_runtime_check.py`
- potencial novo módulo de orquestração multi-view no diretório `app/`

Estado do contexto em `.vibecoding/`:
- os documentos-base de decisões, invariantes, arquitetura e domínio estão presentes, porém ainda vazios;
- portanto, esta atualização explicita a direção arquitetural e passa a servir como referência principal desta trilha.

# Decisões aplicadas

1. `anjinho-all-sides.png` passa a ser tratado como o artefato canônico validado para a trilha 4-view.
2. A origem das 4 vistas deve ser desacoplada da ingestão pelo TripoSR.
3. A geração local via ComfyUI + Florence passa a ser considerada uma etapa opcional/plugável anterior ao TripoSR, e não mais apenas uma hipótese futura.
4. O sistema deve continuar compatível com fallback single-view durante a transição.
5. O contrato canônico multi-view deve ser estável independentemente da origem das vistas.
6. A trilha diffusion/multiview deixa de ser tratada como puramente especulativa e passa a ser tratada como uma capacidade local já demonstrada, porém ainda opcional em arquitetura.
7. O mosaico/strip 2D continua não recomendado como semântica de entrada do modelo; ele só é aceitável como representação visual canônica ou payload intermediário explicitamente tratado.
8. O plano deve priorizar integração incremental e reversível, sem acoplar o app à implementação específica do workflow do ComfyUI.
9. O pacote `Florence-2-Flux-Large` deve ser tratado como um candidato portável para execução em Python puro fora do ComfyUI.
10. Até inspeção do workflow completo, não se deve assumir que Florence sozinho gera a imagem 4-view final; a arquitetura deve separar explicitamente componentes de compreensão/orquestração de componentes de síntese visual.
11. O escopo multi-view da fase atual fica explicitamente restrito a quatro vistas canônicas: frente, esquerda, costas e direita.
12. Vistas de topo da cabeça e planta do pé ficam deliberadamente fora da fase atual.
13. A exclusão de top/bottom é uma diretriz de redução de escopo para preservar alinhamento consistente; o ganho adicional esperado não justifica, neste momento, o risco extra de desalinhamento.

# Estratégia

A estratégia recomendada passa a ter quatro camadas explícitas:

## 1. Camada de evidência canônica

Formalizar `anjinho-all-sides.png` como prova concreta de que o projeto já dispõe de um insumo multi-view local, reproduzível e sem API key.

Essa camada serve para:
- reduzir incerteza de viabilidade da trilha multi-view local;
- fornecer um artefato real para integração antes de automatizar geração;
- separar o problema de integração no TripoSR do problema de geração das vistas.

## 2. Camada de contrato multi-view

Definir um contrato único para qualquer insumo 4-view validado, seja ele:

Nesta fase, esse contrato cobre exclusivamente quatro vistas canônicas consistentes: `front`, `left`, `back` e `right`.
Não devem ser planejadas, aceitas como padrão nem inferidas automaticamente vistas extras como `top` ou `bottom` na fase atual.
- gerado localmente por ComfyUI + Florence;
- produzido por preprocess interno futuro;
- preparado manualmente para testes;
- derivado de outra engine local compatível.

## 3. Camada de ingestão no TripoSR

Adaptar conceitualmente o pipeline para consumir 4 vistas explícitas como payload estruturado, preservando fallback single-view.

## 4. Camada de geração plugável

Manter a geração local das vistas como módulo anterior ao TripoSR, opcional e substituível. O sistema principal não deve depender da implementação interna do workflow do ComfyUI; deve depender apenas do contrato de saída validado.

Essa camada agora deve prever dois subníveis distintos:
- **subnível A — componente Florence portável em Python**: passível de reutilização direta fora do ComfyUI, conforme evidenciado pelo pacote local baseado em Transformers;
- **subnível B — pipeline gerador 4-view completo**: ainda a ser delimitado, pois o diretório inspecionado não prova sozinho a síntese raster final das quatro vistas.

# Contrato esperado da imagem 4-view validada

## Artefato canônico

Nome de referência:
- `anjinho-all-sides.png`

Origem validada:
- entrada base: `anjinho-lowpoly.png`
- geração local: ComfyUI + Florence
- operação offline/local: sem API key

## Diretriz explícita de escopo desta fase

O contrato multi-view desta fase é intencionalmente limitado a quatro vistas canônicas consistentes:
1. frente
2. esquerda
3. costas
4. direita

Ficam explicitamente fora do escopo atual:
- topo da cabeça;
- planta do pé;
- qualquer variação equivalente de `top view` ou `bottom view`.

Justificativa registrada:
- o usuário prioriza alinhamento consistente entre vistas;
- o ganho adicional esperado de top/bottom é considerado pequeno nesta fase;
- o risco de desalinhamento e aumento de ambiguidade do payload é considerado maior do que o benefício incremental.

## Ordem canônica das vistas

A imagem 4-view validada deve representar, em linha horizontal:
1. front view
2. left profile facing left
3. back view
4. right profile facing right

A ordem deve ser estável e documentada para evitar ambiguidade na interpretação do payload.

## Requisitos visuais obrigatórios

1. Mesmo personagem exato em todas as vistas.
2. Corpo inteiro visível em todas as poses.
3. Fundo branco puro.
4. Linha horizontal limpa, com quatro quadros logicamente consistentes.
5. Espaçamento uniforme entre poses.
6. Estilo, proporções e escala consistentes.
7. Cada figura centralizada em seu frame lógico.
8. Bounding box consistente baseada na pose mais larga e mais alta.
9. Todas as poses escaladas para caber na mesma caixa lógica.
10. Margens amplas e seguras.
11. Nenhuma pose encostando nas bordas.
12. Nenhum crop em hipótese alguma.
13. Silhueta completa sempre visível, incluindo asas, cabelo e acessórios.
14. Orientações realmente distintas, sem espelhamento incorreto ou duplicação semântica.
15. Sem ruído de fundo.
16. Sem sombras.
17. Prioridade para padding, não para maximizar o tamanho do personagem.

## Requisitos funcionais do contrato

Um insumo 4-view só deve ser considerado válido para integração se:
- a ordem das vistas estiver preservada;
- a silhueta completa estiver íntegra nas quatro posições;
- não houver ambiguidades claras de orientação;
- o enquadramento for consistente o suficiente para segmentação/interpretação por frame;
- a imagem puder ser decomposta de forma determinística em quatro vistas lógicas;
- o payload permanecer restrito a `front`, `left`, `back` e `right`, sem depender de `top` ou `bottom`.

## Payload lógico recomendado

Mesmo quando a representação física for uma imagem única horizontal, o contrato interno planejado deve tratar o insumo como:
- `front`
- `left`
- `back`
- `right`
- `composite_preview`
- metadados de resolução, ordem, bbox lógica, padding e origem

Nesta fase, o payload não deve prever campos `top`, `bottom` ou equivalentes.

Isso evita acoplamento com um formato puramente visual e facilita troca futura do gerador.

# Como a nova evidência reduz risco

A existência de `anjinho-all-sides.png` reduz materialmente o risco da trilha diffusion/multiview nos seguintes pontos:

1. **Viabilidade local comprovada**
   - a geração multi-view não depende mais de hipótese abstrata;
   - há um artefato real validado no próprio workspace.

2. **Dependência externa reduzida**
   - a trilha não exige API key;
   - reduz risco de custo, disponibilidade de serviço e bloqueios de integração externa.

3. **Separação de riscos**
   - passa a ser possível validar ingestão multi-view no TripoSR usando um artefato pronto, sem bloquear o avanço pela automação do gerador.

4. **Contrato visual observável**
   - o prompt validado e o artefato gerado definem um alvo concreto de qualidade e estrutura.

5. **Menor incerteza arquitetural**
   - diffusion/multiview local deixa de ser “trilha futura possivelmente útil” e passa a ser “fonte plugável já demonstrada”.

6. **Base melhor para aceite**
   - critérios de entrada podem ser avaliados sobre um caso real e não apenas sobre expectativas teóricas.

Importante: essa evidência reduz risco de geração local multi-view, mas não elimina os riscos de ingestão correta pelo TripoSR, consumo de VRAM, regressão de performance ou real ganho geométrico final.

# Arquitetura recomendada atualizada

## Visão de alto nível

Fluxo planejado:
1. entrada original do usuário
2. preprocess base / normalização mínima
3. etapa opcional de geração 4-view local via módulo plugável
4. validação do contrato da imagem 4-view
5. decomposição lógica em payload multi-view
6. ingestão no TripoSR com `Nv` dinâmico
7. geração de malha e outputs já existentes

## Princípio arquitetural central

O TripoSR não deve depender diretamente de ComfyUI, Florence ou de prompt específico.

O TripoSR deve depender somente de um contrato de entrada multi-view validado.

## Papel da etapa ComfyUI + Florence

A etapa ComfyUI + Florence deve ser tratada como:
- **fonte opcional de vistas**;
- **módulo anterior ao TripoSR**;
- **componente substituível**;
- **capacidade local preferencial quando disponível**.

## Papel de `anjinho-all-sides.png`

`anjinho-all-sides.png` deve ser usado como:
- artefato de referência canônica;
- baseline de integração multi-view;
- evidência de contrato validado pelo usuário;
- insumo inicial para validar parsing, UI e consumo pelo modelo antes de automatizar geração.

# Fases atualizadas

## Fase 0 — Baseline single-view e baseline multi-view evidenciado

### Objetivo
Congelar dois referenciais antes da mudança de integração:
- baseline atual single-view com `anjinho-lowpoly.png`;
- baseline de insumo multi-view validado com `anjinho-all-sides.png`.

### Saídas esperadas
- comparação clara entre entrada original e artefato 4-view canônico;
- checklist de aceitação do contrato da imagem 4-view;
- separação entre baseline de reconstrução atual e baseline de insumo futuro.

## Fase 1 — Formalização do contrato 4-view

### Objetivo
Definir o contrato técnico do insumo multi-view com base no caso validado.

### Escopo
- documentar ordem canônica;
- documentar requisitos visuais obrigatórios;
- documentar critérios de validade;
- definir payload lógico interno multi-view;
- explicitar que a fase atual aceita apenas `front`, `left`, `back` e `right`, excluindo `top` e `bottom`.

### Resultado esperado
O sistema passa a ter um contrato estável para qualquer fonte de 4 vistas.

## Fase 2 — Integração por artefato canônico

### Objetivo
Planejar primeiro a integração usando `anjinho-all-sides.png` diretamente como insumo de teste.

### Escopo
- decompor a imagem 4-view em quatro vistas lógicas canônicas;
- adaptar o fluxo de preprocess/generate para aceitar payload multi-view;
- validar a semântica de `Nv=4` no pipeline;
- manter fora do escopo qualquer ingestão de `top` ou `bottom` nesta fase.

### Resultado esperado
A integração multi-view é provada sobre um artefato real já validado, sem depender ainda da automação do gerador local.

## Fase 3 — Adaptação do TripoSR para multi-view explícito

### Objetivo
Permitir ingestão de múltiplas vistas reais, preservando compatibilidade com single-view.

### Escopo
- revisar o contrato de entrada em `app/app.py`;
- revisar o `forward` em `app/tsr/system.py` para `Nv` dinâmico;
- manter modo legado de fallback.

### Resultado esperado
Dois modos claros:
- `single_view_legacy`
- `multi_view_4_validated`

## Fase 4 — UI orientada a artefato multi-view

### Objetivo
Planejar a UI para refletir o novo artefato consumido pela inferência.

### Escopo
- substituir semanticamente `Processed Image` por `Processed Multi-View` ou equivalente;
- exibir preview composta coerente com o artefato canônico;
- opcionalmente expor miniaturas individuais para debug.

### Resultado esperado
O usuário consegue inspecionar o insumo multi-view antes da geração 3D.

## Fase 5 — Extração do pipeline local para Python

### Objetivo
Planejar a extração progressiva do caminho hoje executado no ComfyUI para componentes utilizáveis diretamente no app, começando pelo que já está comprovadamente portável.

### Escopo
- reutilizar o pacote Florence em Python puro fora do ComfyUI, quando ele fizer sentido como componente;
- identificar se Florence atua como descritor/orquestrador, parser estrutural, condicionador ou outra peça intermediária do fluxo;
- isolar a etapa que realmente sintetiza a imagem 4-view final, caso seja outro modelo/nó;
- encapsular a chamada ao gerador local atrás de interface estável;
- manter o mesmo contrato de saída;
- evitar acoplamento do restante do sistema ao workflow interno da ferramenta.

### Resultado esperado
A geração local se torna uma fonte plugável de 4 vistas, com fronteira clara entre o que já pode sair do ComfyUI imediatamente e o que ainda depende de mapear o restante do workflow.

## Fase 6 — Avaliação comparativa e decisão de produto

### Objetivo
Medir se o caminho multi-view validado melhora a reconstrução em relação ao single-view.

### Escopo
- comparar qualidade geométrica;
- comparar estabilidade visual;
- comparar custo de inferência;
- decidir se o fluxo multi-view deve virar padrão, opção avançada ou recurso experimental.

### Resultado esperado
Decisão de produto baseada em evidência, não em hipótese.

# Etapas

1. Registrar formalmente `anjinho-all-sides.png` como entrada 4-view canônica validada.
2. Formalizar o contrato técnico da imagem 4-view com base no prompt aprovado e na diretriz explícita de escopo restrito.
3. Planejar a decomposição lógica do artefato 4-view em quatro vistas nomeadas canônicas: `front`, `left`, `back` e `right`.
4. Planejar a atualização do preprocess para produzir/aceitar `composite_preview` e payload multi-view.
5. Planejar a adaptação de `generate()` para receber payload multi-view além do legado single-view.
6. Planejar a revisão de `TSR.forward()` para suportar `Nv` dinâmico.
7. Planejar a atualização da UI para refletir o artefato multi-view validado.
8. Planejar a etapa opcional/plugável de geração local via ComfyUI + Florence sem acoplamento duro.
9. Definir estratégia de fallback caso o multi-view não entregue ganho geométrico suficiente.
10. Consolidar critérios de aceite e verificação comparativa entre single-view e multi-view.

# Critérios de aceite atualizados

1. O plano passa a reconhecer `anjinho-all-sides.png` como artefato canônico de entrada 4-view.
2. O escopo da fase atual fica explicitamente restrito a `front`, `left`, `back` e `right`.
3. O plano deixa explícito que `top` e `bottom` ficam fora da fase atual.
4. A arquitetura prevista separa claramente geração das vistas e ingestão no TripoSR.
5. A etapa ComfyUI + Florence aparece como etapa opcional/plugável, local e sem dependência de API key.
6. O contrato da imagem 4-view fica explícito, verificável e independente do gerador.
7. O pipeline planejado preserva fallback single-view.
8. Os riscos da trilha multi-view são reclassificados considerando a evidência concreta já validada.
9. A UI planejada passa a refletir o artefato multi-view como insumo principal.
10. O plano deixa claro que a integração deve ser validada primeiro com artefato real antes de automatizar a geração.

# Riscos atualizados

## Risco 1 — O artefato 4-view validado não se traduzir em ganho 3D real

Mesmo com um insumo visualmente melhor, o modelo pode não aproveitar plenamente as quatro vistas sem ajuste adicional.

### Mitigação
- validar primeiro ingestão real com `Nv=4`;
- manter comparação direta com baseline single-view;
- preservar fallback legado.

## Risco 2 — Ambiguidade ao decompor a imagem horizontal em vistas lógicas

Se a separação por frame não for robusta, o payload multi-view pode entrar desalinhado.

### Mitigação
- documentar ordem canônica fixa;
- exigir espaçamento/margens claras no contrato;
- tratar parsing do artefato como etapa explícita de integração.

## Risco 3 — Acoplamento excessivo ao workflow específico do ComfyUI

Automatizar cedo demais pode prender a arquitetura a um pipeline local específico.

### Mitigação
- integrar primeiro pelo contrato, não pela ferramenta;
- encapsular a geração atrás de interface plugável.

## Risco 4 — Regressão de VRAM e latência

Quatro vistas explícitas podem aumentar custo de memória e tempo.

### Mitigação
- medir baseline;
- comparar single-view e multi-view;
- manter rollout reversível.

## Risco 5 — Qualidade inconsistente em novos personagens fora do caso validado

O sucesso em `anjinho-all-sides.png` não garante generalização imediata.

### Mitigação
- tratar o caso atual como evidência forte, mas ainda limitada;
- expandir validação depois para outros exemplos.

## Risco 6 — Falsa segurança sobre diffusion/multiview

A existência de um caso funcional reduz risco, mas não prova robustez universal do gerador local.

### Mitigação
- distinguir claramente evidência de viabilidade de evidência de generalização;
- manter critérios objetivos de aceite por caso.

## Risco 7 — Ampliação prematura do escopo com vistas extras

Adicionar `top` ou `bottom` nesta fase pode elevar a chance de desalinhamento entre vistas, aumentar ambiguidade no parsing e atrasar a validação do contrato principal de 4 vistas canônicas.

### Mitigação
- manter a fase atual restrita a `front`, `left`, `back` e `right`;
- só reconsiderar `top`/`bottom` após evidência clara de ganho real sem perda de alinhamento;
- tratar qualquer expansão futura como nova decisão de escopo, não como extensão implícita.

# Observações

1. Esta atualização muda o status da trilha ComfyUI + Florence de hipótese para evidência local validada.
2. O principal desbloqueio arquitetural é que agora a integração multi-view pode ser planejada usando um artefato real já aprovado pelo usuário.
3. O foco de implementação futura deve sair de “como gerar qualquer multi-view” para “como consumir corretamente um multi-view validado e tornar a geração uma fonte plugável”.
4. O prompt validado pelo usuário passa a funcionar como referência de contrato visual, não como dependência obrigatória do núcleo do sistema.
5. O plano anterior continua útil como base de integração progressiva, mas sua priorização de diffusion como etapa incerta foi revisada pela nova evidência.
6. A fase atual fica deliberadamente limitada a quatro vistas canônicas consistentes; topo da cabeça e planta do pé não fazem parte do contrato atual.
7. Essa limitação é intencional e orientada por redução de risco: prioriza alinhamento consistente sobre cobertura adicional de vistas com baixo ganho incremental esperado.
8. A inspeção do diretório `Florence-2-Flux-Large` mostra que o componente Florence não está preso ao ComfyUI em termos de carregamento e inferência base; ele pode ser chamado por Python puro com Transformers.
9. A mesma inspeção também indica cautela: o pacote observado é de natureza multimodal texto-imagem estruturada, então a síntese efetiva de `anjinho-all-sides.png` pode depender de outros nós/modelos do workflow ainda não inspecionados.

# Recomendação final

A recomendação atualizada é seguir esta ordem:

1. oficializar `anjinho-all-sides.png` como caso canônico 4-view;
2. formalizar o contrato técnico do insumo multi-view com base no prompt validado e na diretriz explícita de apenas quatro vistas canônicas;
3. planejar a integração do TripoSR usando primeiro esse artefato pronto;
4. adaptar o pipeline para `Nv` dinâmico com fallback single-view;
5. alinhar a UI ao novo artefato de preprocess;
6. não incluir `top` ou `bottom` na fase atual;
7. somente depois automatizar a etapa local ComfyUI + Florence como módulo plugável;
8. decidir adoção padrão do multi-view apenas após comparação objetiva de qualidade, custo e estabilidade.

Essa ordem maximiza previsibilidade, reduz risco de retrabalho e usa a nova evidência validada como acelerador da integração, não como atalho arquitetural perigoso.

# Verificação end-to-end planejada

1. Validar que `anjinho-all-sides.png` atende ao contrato 4-view documentado.
2. Confirmar que o artefato pode ser tratado logicamente como `front`, `left`, `back`, `right`.
3. Confirmar que a fase atual não depende de `top` ou `bottom` em nenhum ponto do contrato planejado.
4. Planejar o fluxo de UI para exibir esse artefato como preview principal.
4. Planejar o consumo desse payload por `/generate` com `Nv=4`.
5. Comparar resultados futuros contra o baseline single-view com `anjinho-lowpoly.png`.
6. Medir impacto em tempo e uso de GPU quando a execução for realizada.
7. Revalidar fallback single-view durante toda a transição.
