# TripoSR multi-view `Nv` dinâmico e backend raster canônico

Data: 2026-05-08

## Contexto

Esta trilha consolida a validação final do caminho multi-view a partir de um [`MultiViewArtifact`](../../app/multiview_contract.py) válido, mantendo o fluxo legado `single_view_legacy` em [`app/app.py`](../../app/app.py) intacto.

## Objetivo desta etapa

Validar o caminho end-to-end:

`4-view raster canônico -> MultiViewArtifact -> TSR.forward() com Nv dinâmico -> mesh/OBJ/GLB`

sem trocar de branch e sem promover qualquer refatoração adicional além do necessário.

## Evidências verificadas no código

### [`app/tsr/system.py`](../../app/tsr/system.py)
- [`TSR._normalize_input_views()`](../../app/tsr/system.py) aceita [`MultiViewArtifact`](../../app/multiview_contract.py) e valida explicitamente as 4 vistas canônicas;
- [`TSR.forward()`](../../app/tsr/system.py) processa `Nv` dinamicamente a partir do payload normalizado;
- a checagem de contagem de vistas permanece alinhada com o contrato `front`, `left`, `back`, `right`.

### [`app/model_runtime.py`](../../app/model_runtime.py)
- o runtime serial já expõe o backend raster `workspace_canonical`;
- a geração de artefato raster e a ingestão posterior no TripoSR permanecem separadas;
- o fluxo legado `single_view_legacy` continua usando [`generate_mesh()`](../../app/model_runtime.py) sem depender do payload multi-view.

### [`app/app.py`](../../app/app.py)
- o fluxo legacy [`single_view_legacy`](../../app/app.py) permanece isolado em `generate()`;
- o fluxo experimental `run_workspace_canonical_multiview_generate()` monta o [`MultiViewArtifact`](../../app/multiview_contract.py) e então chama o TripoSR;
- não houve necessidade de alterar o caminho legado.

## Execução end-to-end realizada

Foi executado no ambiente do workspace:

```text
venv\Scripts\python.exe -c "from PIL import Image; from model_runtime import TripoSRModelRuntime; rt=TripoSRModelRuntime(device='cpu'); img=Image.open('../anjinho-all-sides.png').convert('RGB'); result=rt.generate_raster_multiview_artifact(img, prompt='Generate canonical front, left, back, right turnaround views for a single subject.', backend_name='workspace_canonical', backend_options={'source_path':'../anjinho-all-sides.png','source_layout':'horizontal_strip'}); print('artifact', result.artifact is not None, result.backend_result.status, result.backend_result.backend_name); mesh=rt.generate_mesh(result.artifact, pipeline_name='multi_view_4_canonical_workspace_generate'); print('mesh', type(mesh).__name__)"
```

### Resultado
- `artifact True success workspace_canonical_raster`
- `mesh Trimesh`

## Conclusão técnica

O caminho multi-view já está funcional sem necessidade de ajuste adicional em [`TSR.forward()`](../../app/tsr/system.py), porque o `Nv` dinâmico já está sendo derivado corretamente do [`MultiViewArtifact`](../../app/multiview_contract.py).

A geração de mesh/OBJ/GLB com o backend raster canônico do workspace foi validada com sucesso.

## Limitações observadas

- a validação foi executada no ambiente do app via `venv\Scripts\python.exe`, não no Python base do terminal;
- a prova executada confirma o fluxo controlado com backend raster canônico do workspace;
- o fluxo `single_view_legacy` não foi alterado e permanece disponível como baseline.

## Status final

- `multi_view_4_canonical`: validado
- `TSR.forward()`: sem ajuste mínimo adicional necessário
- `mesh/OBJ/GLB`: caminho validado com sucesso
- `single_view_legacy`: preservado
