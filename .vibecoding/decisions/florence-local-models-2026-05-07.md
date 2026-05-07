# Florence local models

## Decision

O repositório passa a tratar modelos Florence em [`LLM/`](LLM/) como referências e downloads locais, sem versionar pesos grandes.

## Default

O modelo default do projeto é [`gokaygokay/Florence-2-Flux-Large`](https://huggingface.co/gokaygokay/Florence-2-Flux-Large).

## Regra prática

- manter documentação e referências em [`LLM/README.md`](LLM/README.md);
- baixar pesos localmente a partir do Hugging Face;
- não commitar [`LLM/Florence-2-Flux-Large/`](LLM/Florence-2-Flux-Large/) nem outros diretórios locais de modelos em [`LLM/`](LLM/).
