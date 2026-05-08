# Objetivo

Definir a interface plugável do adaptador gerador raster `4-view` complementar, separando claramente contratos de entrada, saída, metadados, erros e integração com o runtime serial já existente, antes de qualquer implementação adicional.

# Contexto

A rota de menor retrabalho consolidada em [`.vibecoding/plan/triposr-multiview-route-decision-2026-05-08.md`](.vibecoding/plan/triposr-multiview-route-decision-2026-05-08.md) é a rota **B**:

- manter Florence como componente auxiliar;
- introduzir um backend complementar que realmente produza o raster `4-view`;
- só depois integrar esse artefato ao TripoSR.

O contrato lógico atual já existe em [`app/multiview_contract.py`](app/multiview_contract.py), com [`MultiViewArtifact`](app/multiview_contract.py:16), [`CANONICAL_VIEW_ORDER`](app/multiview_contract.py:8) e [`build_multiview_artifact()`](app/multiview_contract.py:118).

O runtime serial também já existe em [`app/model_runtime.py`](app/model_runtime.py) e deve continuar como base para coordenação `load -> run -> unload`.

Logo, o próximo passo correto não é codar o backend gerador em si, mas congelar a fronteira arquitetural entre:

- entrada do app;
- backend gerador raster;
- contrato lógico `4-view`;
- runtime serial de modelos;
- futura ingestão no TripoSR.

# Decisões aplicadas

1. O adaptador raster deve ser um backend plugável e substituível.
2. O backend raster não deve expor detalhes internos do mecanismo gerador para o resto do app.
3. A saída pública obrigatória do backend deve sempre ser normalizada para [`MultiViewArtifact`](app/multiview_contract.py:16).
4. O runtime serial deve coordenar ciclo de vida dos modelos, mas não deve carregar semântica de contrato visual.
5. Florence permanece opcional como enriquecimento auxiliar ou etapa anterior/adjacente, mas não como saída pública do adaptador raster.
6. O contrato principal de negócio continua lógico: `front`, `left`, `back`, `right`, `composite_preview`, `generation_metadata`.

# Estratégia

## Estratégia principal

Criar uma interface em três camadas:

1. **Request do gerador raster**
2. **Response intermediária do backend**
3. **Artifact normalizado do sistema**

Isso evita acoplamento entre o backend escolhido e o restante do pipeline.

## Princípio de adaptação

O backend pode devolver dados brutos em formato próprio, mas uma camada adaptadora deve convertê-los para [`MultiViewArtifact`](app/multiview_contract.py:16) antes que qualquer outro módulo consuma o resultado.

## Princípio de erro explícito

Falhas devem ser classificadas por tipo:
- erro de configuração;
- erro de carga do backend;
- erro de inferência;
- erro de contrato visual;
- erro de pós-processamento/normalização.

# Interface planejada

## 1. Entrada canônica do backend raster

### Nome conceitual
`RasterMultiViewRequest`

### Campos obrigatórios
- `input_image`: imagem única original do usuário, já aceita pelo app;
- `prompt`: prompt canônico ou derivado da política atual;
- `target_view_order`: ordem esperada, default `front/left/back/right`;
- `target_single_view_size`: tamanho esperado de cada vista individual;
- `target_composite_size`: tamanho físico preferencial do composto, quando aplicável;
- `background_policy`: política de fundo esperada (`pure_white`, por exemplo);
- `padding_policy`: política de margens mínimas;
- `consistency_policy`: regras mínimas de consistência entre vistas;
- `generation_options`: parâmetros específicos do backend encapsulados em mapa flexível.

### Campos opcionais
- `florence_context`: dados auxiliares produzidos por Florence, se existirem;
- `source_metadata`: contexto original da imagem e da chamada;
- `debug`: flags de observabilidade.

## 2. Saída intermediária do backend raster

### Nome conceitual
`RasterMultiViewBackendResult`

### Objetivo
Representar a saída bruta do backend antes da normalização final.

### Campos planejados
- `status`: `success`, `failed`, `blocked`;
- `backend_name`: identificador do gerador usado;
- `backend_version`: versão ou fingerprint do backend;
- `raw_outputs`: mapa com artefatos brutos gerados;
- `named_views_candidate`: vistas detectadas/extraídas pelo backend, se existirem;
- `composite_candidate`: composto gerado, se existir;
- `backend_metadata`: tempos, parâmetros, ids, seeds, resolução, etc.;
- `warnings`: lista de alertas não fatais;
- `error`: erro estruturado, se houver.

### Regra importante
Nenhum módulo downstream deve depender diretamente desta estrutura. Ela é interna à camada de adaptação.

## 3. Saída pública normalizada do sistema

### Nome obrigatório
[`MultiViewArtifact`](app/multiview_contract.py:16)

### Obrigatoriedade
Toda rota de sucesso do backend raster deve terminar em [`build_multiview_artifact()`](app/multiview_contract.py:118).

### Campos obrigatórios já consolidados
- `front`
- `left`
- `back`
- `right`
- `composite_preview`
- `generation_metadata`

### Metadados mínimos recomendados
Adicionar ou garantir em `generation_metadata`:
- `contract_version`
- `view_order`
- `backend_name`
- `backend_version`
- `generation_mode`
- `prompt_source`
- `input_image_size`
- `single_view_size`
- `composite_size`
- `background_policy`
- `padding_policy`
- `generation_time_ms`
- `used_florence_context`
- `viability_status`
- `warnings`

# Erros e exceções planejadas

## Classe base
`RasterMultiViewError`

## Especializações planejadas
- `RasterBackendConfigurationError`
- `RasterBackendLoadError`
- `RasterBackendInferenceError`
- `RasterBackendOutputParseError`
- `RasterMultiViewNormalizationError`
- `RasterMultiViewContractError`

## Regra de propagação
- erros do backend não devem vazar crus para a UI;
- a camada de integração deve converter exceções internas em erro estruturado com mensagem técnica + categoria;
- erros de contrato devem permanecer distinguíveis de erros de runtime.

# Integração com o runtime serial

## Papel do runtime
[`app/model_runtime.py`](app/model_runtime.py) continua responsável por:
- carregar backend/modelo sob demanda;
- descarregar backend/modelo ao fim da etapa;
- coordenar ordem serial Florence/backend raster/TripoSR;
- expor estado mínimo e observabilidade.

## Papel do adaptador raster
O adaptador não gerencia o ciclo de vida global do app. Ele apenas:
- recebe uma request canônica;
- invoca o backend sob o runtime existente;
- devolve resultado bruto;
- normaliza para [`MultiViewArtifact`](app/multiview_contract.py:16).

## Ordem planejada
1. runtime prepara backend auxiliar necessário;
2. adaptador raster executa geração;
3. normaliza saída;
4. valida contrato com [`build_multiview_artifact()`](app/multiview_contract.py:118);
5. devolve artifact pronto;
6. runtime descarrega backend raster/Florence;
7. só depois o pipeline pode considerar carregar o TripoSR.

# Regras de fronteira

## O que o backend pode variar
- tecnologia geradora;
- formato bruto dos outputs;
- estratégia interna de composição;
- uso ou não de Florence como auxílio.

## O que o backend não pode variar
- ordem lógica final das vistas;
- contrato público final;
- necessidade de validação do artifact;
- política de isolamento do runtime serial.

# Etapas

1. Formalizar a estrutura conceitual de `RasterMultiViewRequest`.
2. Formalizar a estrutura conceitual de `RasterMultiViewBackendResult`.
3. Definir o conjunto mínimo obrigatório de `generation_metadata` no artifact final.
4. Definir a hierarquia de erros do adaptador raster.
5. Definir a fronteira entre adaptador raster e [`app/model_runtime.py`](app/model_runtime.py).
6. Definir a ordem serial obrigatória antes de qualquer integração com o TripoSR.
7. Só então implementar o backend plugável real.

# Riscos

## 1. Acoplamento do app ao primeiro backend escolhido

Se a interface não for congelada antes, o primeiro backend pode vazar suas particularidades para o restante do sistema.

## 2. Metadados insuficientes para debug

Se a normalização não preservar contexto suficiente, futuras falhas de contrato ficarão difíceis de diagnosticar.

## 3. Confusão entre backend bruto e artifact validado

Se o sistema consumir a saída intermediária diretamente, o contrato lógico perde autoridade.

## 4. Erros mal classificados

Se falhas de backend e falhas de contrato forem misturadas, haverá retrabalho no debug e na UX.

# Observações

1. [`app/multiview_contract.py`](app/multiview_contract.py) já é uma boa base para a saída pública e deve ser preservado como centro do contrato.
2. O adaptador raster deve nascer ao lado do runtime, mas sem absorver a responsabilidade do runtime.
3. A próxima implementação deve começar pela interface e por um backend stub/controlado, não diretamente por um backend real complexo.
4. A futura ingestão multi-view no TripoSR só deve consumir [`MultiViewArtifact`](app/multiview_contract.py:16), nunca o resultado bruto do backend.

# Arquivos críticos para futura execução

- [`app/multiview_contract.py`](app/multiview_contract.py)
- [`app/model_runtime.py`](app/model_runtime.py)
- [`app/app.py`](app/app.py)
- potencial novo módulo do adaptador raster em [`app/`](app)
- potencial novo módulo de tipos/erros do raster em [`app/`](app)

# Verificação planejada

1. Confirmar que qualquer backend futuro consegue receber uma request canônica única.
2. Confirmar que qualquer backend futuro devolve ou é convertido para [`MultiViewArtifact`](app/multiview_contract.py:16).
3. Confirmar que erros de carga, inferência e contrato ficam separados.
4. Confirmar que o runtime serial continua como única autoridade do ciclo de vida dos modelos.
5. Confirmar que nenhuma integração futura com o TripoSR depende do formato bruto do backend raster.