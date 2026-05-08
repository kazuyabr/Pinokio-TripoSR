# TripoSR workspace canonical raster backend

## Decision

A etapa intermediária da trilha `multi_view_4_canonical` passa a usar um backend raster real controlado baseado em artefato canônico já existente no workspace, preservando o runtime serial e sem depender ainda da geração automática final Florence2-Flux.

## Artefato canônico inicial

- fonte escolhida: [`anjinho-all-sides.png`](anjinho-all-sides.png)
- resolução observada: `2048x1024`
- layout assumido nesta etapa: `horizontal_strip`
- extração canônica resultante: `4` tiles de `512x1024` na ordem `front`, `left`, `back`, `right`

## Aplicação nesta etapa

- o backend [`WorkspaceCanonicalRasterBackend`](app/raster_adapter.py) foi adicionado ao adaptador raster;
- o runtime serial em [`app/model_runtime.py`](app/model_runtime.py) agora suporta o backend nomeado `workspace_canonical` com `backend_options` explícitas;
- o fluxo legado [`single_view_legacy`](app/app.py:90) permaneceu intacto;
- a UI experimental em [`app/app.py`](app/app.py) ganhou um checkpoint controlado para gerar um [`MultiViewArtifact`](app/multiview_contract.py:16) validado a partir do raster do workspace;
- o contrato público em [`app/multiview_contract.py`](app/multiview_contract.py:16) foi preservado sem mudança estrutural.

## Regras

- o backend controlado deve continuar reutilizando um artefato estável do workspace e não a imagem enviada pelo usuário;
- a saída pública continua obrigatoriamente normalizada por [`build_multiview_artifact()`](app/multiview_contract.py:118);
- o runtime serial continua responsável apenas por `load/reuse/unload`, sem absorver semântica visual profunda;
- a geração automática final por Florence2-Flux continua fora de escopo desta etapa.

## Observações de validação

- a checagem sintática passou com `python -m py_compile` para [`app/raster_adapter.py`](app/raster_adapter.py), [`app/model_runtime.py`](app/model_runtime.py), [`app/app.py`](app/app.py) e [`app/multiview_contract.py`](app/multiview_contract.py);
- a validação direta do adaptador confirmou `status=success`, `front.size=(512, 1024)` e `composite_preview.size=(2048, 1024)` a partir de [`anjinho-all-sides.png`](anjinho-all-sides.png);
- a validação direta do runtime completo permaneceu limitada no shell atual por ausência local de `torch`, sem evidência em código de regressão do caminho legado.
