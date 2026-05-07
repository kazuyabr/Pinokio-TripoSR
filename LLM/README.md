# Modelos Florence locais

Este diretório é reservado para referências e downloads locais de modelos Florence usados pelo projeto.

## Modelo default do projeto

O modelo default adotado neste projeto é [`gokaygokay/Florence-2-Flux-Large`](https://huggingface.co/gokaygokay/Florence-2-Flux-Large).

A pasta local esperada para esse modelo é [`LLM/Florence-2-Flux-Large`](LLM/Florence-2-Flux-Large).

## Abordagem adotada neste repositório

Este repositório **não versiona pesos grandes** dentro de [`LLM/`](LLM/).

A abordagem padrão é:

1. manter neste repositório apenas a referência/documentação;
2. baixar o modelo localmente a partir do repositório oficial no Hugging Face;
3. usar a pasta local [`LLM/Florence-2-Flux-Large`](LLM/Florence-2-Flux-Large) apenas como cache/modelo local.

A pasta [`LLM/Florence-2-Flux-Large`](LLM/Florence-2-Flux-Large) **não deve ser commitada**.

Submódulo do Hugging Face **não é a solução principal adotada aqui**. O padrão deste projeto é **referência + download local**.

## Download local recomendado

Exemplo com `huggingface-cli`:

```bash
huggingface-cli download gokaygokay/Florence-2-Flux-Large --local-dir LLM/Florence-2-Flux-Large
```

Exemplo com Python e `huggingface_hub`:

```python
from huggingface_hub import snapshot_download

snapshot_download(
    repo_id="gokaygokay/Florence-2-Flux-Large",
    local_dir="LLM/Florence-2-Flux-Large",
    local_dir_use_symlinks=False,
)
```

## Modelos oficiais Florence

- [`microsoft/Florence-2-base`](https://huggingface.co/microsoft/Florence-2-base)
- [`microsoft/Florence-2-base-ft`](https://huggingface.co/microsoft/Florence-2-base-ft)
- [`microsoft/Florence-2-large`](https://huggingface.co/microsoft/Florence-2-large)
- [`microsoft/Florence-2-large-ft`](https://huggingface.co/microsoft/Florence-2-large-ft)
- [`HuggingFaceM4/Florence-2-DocVQA`](https://huggingface.co/HuggingFaceM4/Florence-2-DocVQA)

## Ajustes finos testados

- [`MiaoshouAI/Florence-2-base-PromptGen-v1.5`](https://huggingface.co/MiaoshouAI/Florence-2-base-PromptGen-v1.5)
- [`MiaoshouAI/Florence-2-large-PromptGen-v1.5`](https://huggingface.co/MiaoshouAI/Florence-2-large-PromptGen-v1.5)
- [`thwri/CogFlorence-2.2-Large`](https://huggingface.co/thwri/CogFlorence-2.2-Large)
- [`HuggingFaceM4/Florence-2-DocVQA`](https://huggingface.co/HuggingFaceM4/Florence-2-DocVQA)
- [`gokaygokay/Florence-2-SD3-Captioner`](https://huggingface.co/gokaygokay/Florence-2-SD3-Captioner)
- [`gokaygokay/Florence-2-Flux-Large`](https://huggingface.co/gokaygokay/Florence-2-Flux-Large)
- [`NikshepShetty/Florence-2-pixelpros`](https://huggingface.co/NikshepShetty/Florence-2-pixelpros)
