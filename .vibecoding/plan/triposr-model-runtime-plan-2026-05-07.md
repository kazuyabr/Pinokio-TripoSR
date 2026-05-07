# Objetivo

Planejar a refatoração arquitetural necessária para permitir um ciclo de vida serial de modelos no app do TripoSR, preparando a futura trilha `Florence -> unload -> TripoSR` sem quebrar o fluxo legado `single-view`.

# Contexto

O estado atual do app conflita diretamente com a futura arquitetura multi-view serial:

- [`app/app.py`](app/app.py) carrega o TripoSR no bootstrap global em [`TSR.from_pretrained()`](app/tsr/system.py:52) e o move para GPU logo na inicialização.
- [`generate()`](app/app.py:76) assume que o TripoSR já está residente e pronto para inferência.
- [`preprocess()`](app/app.py:57) não conhece estágio intermediário de geração/canonicalização 4-view.
- [`TSR.forward()`](app/tsr/system.py:87) ainda força `Nv=1`, mas esse não é o primeiro gargalo arquitetural.
- [`ImagePreprocessor.__call__()`](app/tsr/utils.py:95) já aceita lista de imagens, o que ajuda no futuro payload multi-view.
- [`app/gpu_runtime_check.py`](app/gpu_runtime_check.py) já oferece base para futura telemetria de VRAM por etapa.

Portanto, antes de adaptar a inferência para `Nv=4`, o sistema precisa separar o ciclo de vida dos modelos do bootstrap da UI.

# Decisões aplicadas

1. O primeiro pré-requisito arquitetural da trilha multi-view é remover a dependência de TripoSR residente desde o bootstrap.
2. O ciclo de vida dos modelos deve ser tratado como runtime explícito, não como efeito colateral de importação do módulo.
3. O fluxo legado `single-view` deve continuar funcional durante toda a transição.
4. A serialização `Florence -> unload -> TripoSR` deve ser planejada antes de qualquer mudança profunda em `Nv` ou no payload multi-view.
5. O contrato multi-view continua sendo lógico (`front`, `left`, `back`, `right`), mesmo que a representação física da fase use um composto horizontal.

# Estratégia

## Estratégia principal

A recomendação é introduzir uma camada explícita de runtime de modelos, isolando:

- carregamento sob demanda do Florence;
- descarregamento explícito do Florence;
- carregamento sob demanda do TripoSR;
- uso do TripoSR apenas no estágio de reconstrução;
- telemetria mínima por fase para validar a política serial de GPU.

## Princípio de separação

O app deve passar de:

- **estado atual**: UI + bootstrap global + modelo sempre residente;

para:

- **estado-alvo**: UI + orquestração de pipeline + runtime de modelos por fase.

## Consequência prática

A futura mudança para `Nv=4` só deve ocorrer depois que o runtime de modelos estiver desacoplado do bootstrap e o caminho serial puder ser validado sem ambiguidade.

# Etapas

## Etapa 1 — Congelar o problema arquitetural

### Objetivo
Tornar explícito, para a futura implementação, que o carregamento global do TripoSR é incompatível com a trilha serial multi-view.

### Resultado verificável
Existe concordância documental de que o gargalo inicial é o ciclo de vida do modelo, não `Nv=4`.

## Etapa 2 — Planejar uma camada de runtime de modelos

### Objetivo
Definir um módulo conceitual responsável pelo ciclo de vida de Florence e TripoSR.

### Responsabilidades planejadas
- `load_florence()`
- `unload_florence()`
- `load_triposr()`
- `unload_triposr()` ou política equivalente
- consulta de estado atual do runtime
- hooks simples para futura medição de memória/tempo

### Resultado verificável
Existe uma fronteira clara entre UI/pipeline e gestão de modelos.

## Etapa 3 — Separar os caminhos de pipeline

### Objetivo
Planejar dois caminhos internos independentes:

- `single_view_legacy`
- `multi_view_serial_runtime`

### Resultado verificável
O caminho novo nasce paralelo, reversível e sem substituir cedo o fluxo já funcional.

## Etapa 4 — Redefinir semanticamente o papel de `generate()`

### Objetivo
Planejar a evolução de [`generate()`](app/app.py:76) para que deixe de ser apenas uma chamada direta ao TripoSR e passe a ser o orquestrador do estágio final de reconstrução.

### Diretriz
- no legado, mantém comportamento equivalente ao atual;
- no multi-view, só chama o TripoSR após confirmar que o gerador 4-view já concluiu e foi descarregado.

### Resultado verificável
A futura implementação terá ponto único e claro para decidir qual trilha executa.

## Etapa 5 — Planejar telemetria mínima do runtime

### Objetivo
Usar a base de [`app/gpu_runtime_check.py`](app/gpu_runtime_check.py) para definir checkpoints de memória e latência por fase.

### Checkpoints planejados
- memória antes de carregar Florence;
- pico durante Florence;
- memória após unload de Florence;
- memória antes de carregar TripoSR;
- pico durante TripoSR;
- ausência de coexistência indevida entre modelos.

### Resultado verificável
A política serial de GPU passa a ser testável e não apenas presumida.

# Riscos

## 1. Refatorar cedo demais o caminho legado

Se a mudança do runtime contaminar cedo o fluxo já funcional, o baseline pode regredir antes de o multi-view existir.

## 2. Confundir runtime serial com implementação do gerador

O runtime precisa ser planejado de forma independente do mecanismo exato do Florence, pois a viabilidade do gerador ainda é hipótese técnica.

## 3. Declarar progresso pelo `Nv=4` sem resolver o bootstrap

Mesmo que o TripoSR aceite múltiplas vistas depois, a arquitetura continuará frágil se o ciclo de vida dos modelos permanecer acoplado ao import do app.

# Observações

1. [`TSR.forward()`](app/tsr/system.py:87) continua sendo um ponto crítico futuro, mas não é o primeiro passo.
2. [`app/app.py`](app/app.py) é hoje o principal ponto de conflito arquitetural por carregar o TripoSR cedo demais.
3. [`app/tsr/utils.py`](app/tsr/utils.py) já oferece indício útil de preparo parcial para multi-view no preprocess interno.
4. [`app/gpu_runtime_check.py`](app/gpu_runtime_check.py) deve ser tratado como base de observabilidade da transição de runtime.

# Arquivos críticos para futura execução

- [`app/app.py`](app/app.py)
- [`app/tsr/system.py`](app/tsr/system.py)
- [`app/tsr/utils.py`](app/tsr/utils.py)
- [`app/gpu_runtime_check.py`](app/gpu_runtime_check.py)
- potencial novo módulo de runtime em [`app/`](app)
- potencial novo módulo de contrato multi-view em [`app/`](app)

# Verificação planejada

1. Confirmar que o TripoSR deixa de ser carregado no bootstrap global.
2. Confirmar que o fluxo legado continua funcional após a separação do runtime.
3. Confirmar que o runtime consegue suportar a sequência `load Florence -> unload Florence -> load TripoSR`.
4. Confirmar que a política serial de GPU pode ser observada por telemetria simples.
5. Só depois dessa base estar estável, avançar para o payload multi-view e para a adaptação de [`TSR.forward()`](app/tsr/system.py:87).