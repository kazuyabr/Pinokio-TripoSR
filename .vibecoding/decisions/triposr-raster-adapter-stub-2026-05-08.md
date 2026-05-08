# TripoSR raster adapter stub boundary

## Decision

A próxima etapa de menor risco da trilha `multi_view_4_canonical` passa a usar uma fronteira explícita de adaptador raster em [`app/raster_adapter.py`](app/raster_adapter.py), integrada ao runtime serial em [`app/model_runtime.py`](app/model_runtime.py), com backend inicial controlado `stub`.

## Aplicação nesta etapa

- o contrato de request canônica foi formalizado em `RasterMultiViewRequest`;
- a saída intermediária interna foi formalizada em `RasterMultiViewBackendResult`;
- a normalização pública continua obrigatoriamente em [`build_multiview_artifact()`](app/multiview_contract.py:118);
- o runtime serial agora conhece `load/reuse/unload` de backend raster, sem carregar semântica profunda de `Nv=4`;
- o fluxo [`single_view_legacy`](app/app.py:90) permanece separado e intacto.

## Regras

- nenhum backend raster pode expor seu formato bruto diretamente ao resto do app;
- toda rota de sucesso deve terminar em `MultiViewArtifact` validado;
- o backend `stub` existe apenas para validar fronteira, observabilidade e integração serial;
- a adaptação profunda de [`TSR.forward()`](app/tsr/system.py:87) continua fora de escopo até existir artefato 4-view real.

## Observações de validação

- a checagem sintática via `python -m py_compile` passou para [`app/app.py`](app/app.py), [`app/model_runtime.py`](app/model_runtime.py), [`app/multiview_contract.py`](app/multiview_contract.py) e [`app/raster_adapter.py`](app/raster_adapter.py);
- a validação funcional controlada do stub passou no nível do adaptador em `python -c`, confirmando preview `(256, 64)` e metadata `backend_name=stub_raster_backend`;
- a validação completa do runtime em [`app/model_runtime.py`](app/model_runtime.py) ficou limitada no shell atual por ausência local de `torch`, sem evidência de regressão do caminho legado em código.
