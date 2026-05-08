# Florence + contrato 4-view checkpoint

## Data
2026-05-08

## Escopo executado
Etapa incremental focada em:

- preservar o fluxo `single_view_legacy`;
- introduzir contrato explícito do payload lógico 4-view;
- integrar runtime Florence local sob demanda com `unload` explícito;
- validar a viabilidade técnica real do checkpoint local antes de qualquer adaptação profunda de [`TSR.forward()`](app/tsr/system.py:87).

## Artefatos implementados

### Contrato 4-view
Criado [`app/multiview_contract.py`](app/multiview_contract.py) com:

- `CANONICAL_VIEW_ORDER = ["front", "left", "back", "right"]`;
- `CONTRACT_VERSION = "multi_view_4_canonical/v1"`;
- `MultiViewArtifact`;
- `MultiViewContractError`;
- `build_multiview_artifact()`;
- `compose_canonical_preview()`.

O contrato exige os campos lógicos:

- `front`
- `left`
- `back`
- `right`
- `composite_preview`
- `generation_metadata`

### Runtime serial Florence -> unload
Expandido [`app/model_runtime.py`](app/model_runtime.py) para:

- suportar `florence_loaded` no estado do runtime;
- expor `ensure_florence_loaded()`;
- expor `unload_florence()`;
- descarregar Florence antes de eventual carga do TripoSR;
- descarregar TripoSR antes de eventual carga do Florence;
- registrar eventos e snapshot de memória para a trilha experimental.

### Integração controlada no app
Atualizado [`app/app.py`](app/app.py) para:

- manter o fluxo legado `single_view_legacy` intacto em [`generate()`](app/app.py:89);
- adicionar botão experimental `Run Florence 4-view checkpoint`;
- adicionar painel de observabilidade com preview/status do checkpoint multi-view;
- não promover o multi-view como fluxo padrão;
- não chamar ainda ingestão `Nv=4` no TripoSR.

### Dependência registrada
Adicionado `timm` em [`app/requirements.txt`](app/requirements.txt).

## Validação executada

### Compilação local
Executado com sucesso:

- [`python -m py_compile`](app/app.py:1) em [`app/app.py`](app/app.py), [`app/model_runtime.py`](app/model_runtime.py) e [`app/multiview_contract.py`](app/multiview_contract.py)

### Checkpoint Florence local
Teste executado chamando [`run_multiview_florence_checkpoint()`](app/app.py:99) com [`modelo-postura-em-a.png`](modelo-postura-em-a.png).

Resultado observado:

- `viability_status = blocked`
- `preview = None`
- `triposr_loaded = False`
- `florence_loaded = False`
- memória CUDA final voltou para zero no snapshot registrado

### Causa real do bloqueio
A carga do modelo local em [`LLM/Florence-2-Flux-Large`](LLM/Florence-2-Flux-Large) falhou por dependência ausente exigida pelo próprio checkpoint:

- `flash_attn`

Mensagem observada no teste:

- `ImportError: This modeling file requires the following packages that were not found in your environment: flash_attn`

## Conclusão técnica desta fase

A etapa foi materializada com sucesso no nível arquitetural e de contrato, mas a viabilidade do gerador 4-view local permanece **bloqueada no ambiente atual**.

Conclusões confirmadas:

1. o contrato lógico 4-view agora existe de forma explícita;
2. o runtime serial Florence -> unload -> TripoSR foi integrado sem quebrar o legado;
3. o app já possui checkpoint controlado e reversível para a trilha Florence local;
4. a adaptação profunda de [`TSR.forward()`](app/tsr/system.py:87) para `Nv=4` **continua corretamente adiada**;
5. o gargalo imediato não é o TripoSR, e sim a carga/viabilidade do modelo local Florence no ambiente atual.

## Próximo passo recomendado

Antes de qualquer ingestão `Nv=4` no TripoSR, resolver um destes caminhos:

1. habilitar o ambiente para o modelo atual (`flash_attn` compatível);
2. trocar para um checkpoint Florence local equivalente que não exija `flash_attn`;
3. criar uma trilha local alternativa realmente capaz de gerar raster 4-view canônico.
