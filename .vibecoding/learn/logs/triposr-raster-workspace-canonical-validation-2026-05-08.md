# TripoSR raster workspace canonical validation

## Escopo

Validar a etapa intermediária que conecta um backend raster 4-view real controlado ao adaptador e ao runtime, usando um artefato canônico existente no workspace antes da futura geração automática por Florence2-Flux.

## Resultado

- backend controlado implementado em [`app/raster_adapter.py`](app/raster_adapter.py) como `WorkspaceCanonicalRasterBackend`;
- integração adicionada ao runtime serial em [`app/model_runtime.py`](app/model_runtime.py) como backend `workspace_canonical`;
- checkpoint experimental exposto em [`app/app.py`](app/app.py) para inspeção do preview e do status;
- fluxo legado [`single_view_legacy`](app/app.py:90) preservado sem mudança direta.

## Evidências

### Checagem sintática

Comando executado:

`python -m py_compile app\raster_adapter.py app\model_runtime.py app\app.py app\multiview_contract.py`

Resultado:

- sucesso sem erro de compilação.

### Validação do adaptador

Comando executado:

`python -c "import sys; sys.path.append('app'); from PIL import Image; from raster_adapter import RasterMultiViewRequest, WorkspaceCanonicalRasterBackend, adapt_backend_result_to_multiview_artifact; image=Image.new('RGB',(64,64),'white'); request=RasterMultiViewRequest(input_image=image,prompt='controlled workspace raster').validate(); backend=WorkspaceCanonicalRasterBackend(source_path='../anjinho-all-sides.png', source_layout='horizontal_strip'); backend_result=backend.generate(request); adapter_result=adapt_backend_result_to_multiview_artifact(request, backend_result); artifact=adapter_result.artifact; print(backend_result.status, artifact.front.size, artifact.composite_preview.size, artifact.generation_metadata['backend_name'], artifact.generation_metadata['source_artifact_name'])"`

Saída observada:

- `success (512, 1024) (2048, 1024) workspace_canonical_raster anjinho-all-sides.png`

## Limitações conhecidas

- a validação completa do runtime em [`app/model_runtime.py`](app/model_runtime.py) não foi executável no shell atual porque `torch` não está disponível fora do ambiente da aplicação;
- mesmo assim, a integração sintática passou e o caminho do adaptador com artifact real foi validado isoladamente.

## Próximo passo preparado

A próxima etapa pode consumir o [`MultiViewArtifact`](app/multiview_contract.py:16) real derivado de [`anjinho-all-sides.png`](anjinho-all-sides.png) para iniciar a ingestão multi-view no TripoSR, sem reabrir a discussão sobre a fonte raster canônica controlada.
