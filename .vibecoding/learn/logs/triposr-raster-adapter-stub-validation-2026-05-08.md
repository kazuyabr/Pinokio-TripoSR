# TripoSR raster adapter stub validation

## Contexto

Validação do passo incremental de menor risco da trilha `4-view`: congelar contratos e integrar um backend raster `stub` ao runtime serial, sem tocar ainda em [`TSR.forward()`](app/tsr/system.py:87).

## O que foi validado

### 1. Sintaxe dos módulos alterados

Comando executado:

```python
python -m py_compile app\app.py app\model_runtime.py app\multiview_contract.py app\raster_adapter.py
```

Resultado:

- compilação sintática concluída com sucesso.

### 2. Contrato e normalização do adaptador stub

Comando executado no diretório [`app/`](app):

```python
python -c "from PIL import Image; from raster_adapter import RasterMultiViewRequest, StubRasterMultiViewBackend, adapt_backend_result_to_multiview_artifact; image = Image.new('RGB', (64, 64), color=(255, 255, 255)); request = RasterMultiViewRequest(input_image=image, prompt='stub validation').validate(); backend = StubRasterMultiViewBackend(mode='echo_input'); backend_result = backend.generate(request); adapted = adapt_backend_result_to_multiview_artifact(request, backend_result); assert adapted.artifact is not None; assert adapted.artifact.composite_preview.size == (256, 64); assert adapted.artifact.generation_metadata['backend_name'] == 'stub_raster_backend'; print({'status': backend_result.status, 'preview_size': adapted.artifact.composite_preview.size, 'backend': backend_result.backend_name})"
```

Resultado observado:

- `status='success'`;
- `preview_size=(256, 64)`;
- `backend='stub_raster_backend'`.

## Limitação encontrada

A validação direta do runtime completo em [`app/model_runtime.py`](app/model_runtime.py) não pôde rodar no shell atual porque `torch` não está instalado nesse interpretador:

```python
ModuleNotFoundError: No module named 'torch'
```

## Conclusão

- a fronteira do adaptador raster foi validada em nível de contrato e normalização;
- o runtime serial foi atualizado em código para acomodar backend raster plugável;
- o fluxo legado [`single_view_legacy`](app/app.py:90) permaneceu sem mudança de assinatura pública e sem alteração de rota padrão;
- a prova completa do runtime depende de ambiente com `torch` disponível, mas esta etapa não exige ainda a adaptação multi-view profunda do TripoSR.
