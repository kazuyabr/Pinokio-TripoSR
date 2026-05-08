# Florence runtime unblock checkpoint

## Data
2026-05-08

## Objetivo desta etapa
Diagnosticar e destravar a viabilidade local do checkpoint Florence em [`LLM/Florence-2-Flux-Large`](LLM/Florence-2-Flux-Large) sem perder o runtime serial já implementado em [`app/model_runtime.py`](app/model_runtime.py).

## Causa raiz confirmada
O bloqueio original não era uma exigência inevitável de runtime para usar o checkpoint com fallback.

A causa real observada foi composta por duas camadas:

1. o carregamento com `trust_remote_code` em [`AutoModelForCausalLM.from_pretrained()`](app/model_runtime.py:199) passava pelo scanner de imports do Transformers em [`dynamic_module_utils.check_imports()`](app/venv/Lib/site-packages/transformers/dynamic_module_utils.py:159), que tratava `flash_attn` como dependência obrigatória por presença textual no arquivo remoto [`modeling_florence2.py`](LLM/Florence-2-Flux-Large/modeling_florence2.py);
2. após neutralizar esse bloqueio textual, apareceu incompatibilidade real de versão: o checkpoint Florence local foi preparado para uma linha de Transformers compatível com `4.41.x`, enquanto o ambiente estava em [`transformers==4.35.0`](app/requirements.txt:4).

## Evidências coletadas
- checkpoint anterior registrava `ImportError` para `flash_attn` em [`.vibecoding/learn/logs/triposr-florence-contract-checkpoint-2026-05-08.md`](.vibecoding/learn/logs/triposr-florence-contract-checkpoint-2026-05-08.md);
- o próprio arquivo remoto expõe classes de attention `eager`, `sdpa` e `flash_attention_2` em [`FLORENCE2_ATTENTION_CLASSES`](LLM/Florence-2-Flux-Large/modeling_florence2.py:1240);
- a documentação do modelo local cita `flash_attn`, mas a execução local confirmou que o checkpoint consegue carregar sem ele quando o ambiente usa versão compatível de Transformers e o runtime força fallback em [`ensure_florence_loaded()`](app/model_runtime.py:142).

## Correção aplicada
### 1. Fallback explícito de attention no runtime
[`TripoSRModelRuntime.ensure_florence_loaded()`](app/model_runtime.py:142) passou a:

- tentar carregar Florence com `sdpa` primeiro;
- cair para `eager` se necessário;
- registrar tentativas e falhas por implementação de attention;
- manter o fluxo serial `Florence -> unload` intacto.

### 2. Compatibilização mínima do arquivo remoto do modelo
Foram aplicados ajustes conservadores em [`LLM/Florence-2-Flux-Large/modeling_florence2.py`](LLM/Florence-2-Flux-Large/modeling_florence2.py):

- proteção dos imports de `flash_attn` com `try/except ImportError` para não acionar bloqueio rígido quando a biblioteca não existe;
- fallback local para `is_flash_attn_greater_or_equal_2_10()` quando a versão instalada do Transformers não a expõe.

### 3. Alinhamento de dependências do ambiente
[`app/requirements.txt`](app/requirements.txt) foi atualizado para:

- `transformers==4.41.2`;
- `huggingface-hub==0.36.2`.

Esse alinhamento foi o menor ajuste sistêmico necessário para compatibilizar o checkpoint Florence local com o ambiente já existente, evitando tentar instalar `flash_attn` no Windows.

## Validação executada
### Validação direta do runtime Florence
Executado em [`app/`](app):

```python
from PIL import Image
from model_runtime import TripoSRModelRuntime

rt = TripoSRModelRuntime(device='cuda:0')
img = Image.open('../modelo-postura-em-a.png').convert('RGB')
result = rt.validate_florence_multiview_viability(img)
rt.unload_florence()
print(result)
print(rt.get_runtime_state())
```

Resultado:
- Florence carregou com sucesso;
- o checkpoint executou inferência textual normalmente;
- após `unload`, o estado final ficou com `florence_loaded = False` e `triposr_loaded = False`.

### Revalidação do checkpoint do app
Executado [`run_multiview_florence_checkpoint()`](app/app.py:99) via [`app/app.py`](app/app.py):

- `preview = None`;
- `viability_status = "blocked"`;
- `reason` agora indica apenas a limitação funcional real do runtime atual: ainda não existe trilha validada de síntese raster 4-view;
- `runtime_state_after_unload.active_model = None`;
- `runtime_state_after_unload.florence_loaded = False`;
- `runtime_state_after_unload.triposr_loaded = False`.

## Decisão prática desta etapa
Para este projeto e este checkpoint local, `flash_attn` deixa de ser tratado como bloqueio obrigatório imediato.

A decisão operacional passa a ser:

1. usar Transformers compatível com a família Florence local (`4.41.2` aprovado nesta etapa);
2. preferir fallback de attention suportado (`sdpa`, depois `eager`) em vez de instalar `flash_attn` no Windows;
3. manter `flash_attn` como otimização opcional, não como pré-requisito para o checkpoint de viabilidade atual.

## Limitação restante
A trilha multi-view continua **bloqueada apenas no nível funcional**, não mais no nível de carga do modelo.

O checkpoint Florence local atualmente:
- carrega;
- roda descrição/imagem-texto;
- descarrega corretamente;
- mas ainda não entrega artefato raster validado com `front`, `left`, `back`, `right` para o contrato em [`app/multiview_contract.py`](app/multiview_contract.py).

## Próximo bloqueio real
O próximo bloqueio real da trilha não é mais `flash_attn`.

O bloqueio agora é encontrar ou implementar uma rota local verificável de geração de vistas raster canônicas a partir do Florence carregado, antes de qualquer adaptação profunda em [`TSR.forward()`](app/tsr/system.py:87).