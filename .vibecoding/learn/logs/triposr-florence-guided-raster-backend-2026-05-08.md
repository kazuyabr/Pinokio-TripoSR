# Florence-guided raster backend incremental step

Data: 2026-05-08

## Contexto

Esta etapa avançou a trilha `multi_view_4_canonical` rumo ao backend raster real baseado em Florence2-Flux-Large, sem quebrar o contrato [`MultiViewArtifact`](../../app/multiview_contract.py), o runtime serial ou o fluxo legado `single_view_legacy`.

## Alterações aplicadas

### [`app/raster_adapter.py`](../../app/raster_adapter.py)
- foi adicionado um backend `FlorenceGuidedRasterMultiViewBackend` com saída normalizada para [`MultiViewArtifact`](../../app/multiview_contract.py);
- o backend usa adaptação raster mínima determinística para produzir as quatro vistas canônicas e o preview horizontal;
- o contrato público do adaptador foi preservado: `RasterMultiViewRequest` -> `RasterMultiViewBackendResult` -> [`MultiViewArtifact`](../../app/multiview_contract.py).

### [`app/model_runtime.py`](../../app/model_runtime.py)
- foi adicionado o backend `florence_guided` ao runtime serial;
- foi adicionada a trilha `generate_florence_guided_multiview_artifact()`;
- Florence é carregado para extrair contexto, descarregado explicitamente, e só então o adaptador raster gera o artefato canônico;
- a política serial `Florence -> unload -> backend raster -> unload -> TripoSR` foi mantida.

### [`app/app.py`](../../app/app.py)
- o checkpoint experimental passou a chamar o caminho Florence-guided de geração canônica;
- o fluxo legado [`single_view_legacy`](../../app/app.py:90) não foi alterado;
- o fallback workspace canonical permanece disponível como rota de segurança.

## Verificações realizadas

### Compilação
Executado com sucesso:

```text
python -m py_compile app\raster_adapter.py app\model_runtime.py app\app.py
```

### Prova mínima em runtime
Executado com sucesso no ambiente local:

```text
app\venv\Scripts\python.exe -c "... generate_florence_guided_multiview_artifact(...) ..."
```

Resultado observado:
- `success True`
- preview canônico com 4 vistas
- backend `florence_guided_raster`

## Limitações reconhecidas

- a adaptação atual ainda é mínima e determinística; ela não comprova ainda geração visual semântica profunda diretamente pelo checkpoint Florence;
- o caminho workspace canonical continua útil como fallback seguro e baseline verificável;
- a trilha Florence agora produz contexto útil e um artefato canônico utilizável, mas o backend raster final ainda pode exigir refinamentos futuros se a qualidade visual precisar subir.

## Status desta etapa

- backend Florence-guided integrado com sucesso;
- runtime serial preservado;
- contrato público preservado;
- fluxo legacy preservado;
- fallback seguro preservado.
