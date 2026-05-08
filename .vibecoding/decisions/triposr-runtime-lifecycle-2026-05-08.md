# TripoSR runtime lifecycle

## Decision

O ciclo de vida do TripoSR deixa de depender do bootstrap global de [`app/app.py`](app/app.py) e passa a ser encapsulado por uma camada explícita de runtime em [`app/model_runtime.py`](app/model_runtime.py).

## Scope desta etapa

- preservar o fluxo atual `single_view_legacy`;
- carregar o TripoSR sob demanda no momento de geração;
- manter ponto explícito de `unload` para futura trilha serial `Florence -> unload -> TripoSR`;
- introduzir observabilidade mínima de estado e memória do runtime.

## Regras práticas

- [`app/app.py`](app/app.py) não deve mais instanciar [`TSR.from_pretrained()`](app/tsr/system.py:52) no import do módulo;
- a geração atual deve chamar o runtime, não o modelo diretamente;
- a futura integração com Florence deve reutilizar a mesma fronteira de runtime para coordenar serialização de GPU;
- esta etapa não altera ainda a hipótese de `Nv=1` em [`TSR.forward()`](app/tsr/system.py:87).

## Observabilidade mínima

O runtime deve expor pelo menos:

- estado do modelo ativo;
- indicador de `triposr_loaded`;
- snapshot simples de memória CUDA quando disponível;
- eventos de `load`, `reuse`, `generate` e `unload`.
