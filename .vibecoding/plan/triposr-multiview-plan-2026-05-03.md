# Objetivo

Planejar a evolução do TripoSR para substituir a imagem processada única por uma composição multi-view consistente de 4 vistas do personagem — frente, trás, esquerda e direita — com foco em aumentar o detalhamento do modelo 3D sem quebrar o pipeline já funcional de upload, preprocess, geração OBJ/GLB, renderização em Model3D e uso de GPU.

# Contexto

O pipeline atual recebe uma única imagem, aplica remoção de fundo e enquadramento, exibe uma única `Processed Image` na UI e envia esse resultado diretamente ao TripoSR para reconstrução 3D.

Arquivos críticos observados:
- `app/app.py`: concentra preprocess, geração, wiring da UI e contrato entre preprocess e inferência.
- `app/tsr/system.py`: define o forward do TripoSR e atualmente força `Nv=1` na montagem dos tokens.
- `app/tsr/utils.py`: contém `ImagePreprocessor`, `remove_background` e `resize_foreground`.
- `app/tsr/models/tokenizers/image.py`: o tokenizer suporta `n_input_views`, mas o sistema atual não explora isso no `forward`.
- `cache/HF_HOME/hub/models--stabilityai--TripoSR/snapshots/5b521936b01fbe1890f6f9baed0254ab6351c04a/config.yaml`: configura o modelo atualmente carregado.
- `app/gpu_runtime_check.py`: valida hoje o contrato de duas etapas `/preprocess` -> `/generate` com uma única imagem processada.

O contexto em `.vibecoding/` existe, porém os arquivos-base estão praticamente vazios. Portanto, este plano assume como fonte de verdade o que foi solicitado pelo usuário e o estado observado do código, sem contradizer decisões prévias explícitas.

Casos de referência informados:
- `anjinho-lowpoly.png`: caso de teste principal.
- `modelo-postura-em-a.png`: referência visual de enquadramento e postura esperada.

# Decisões aplicadas

1. Não alterar a premissa de que o projeto continua sendo operado a partir de uma única imagem de entrada do usuário.
2. Separar claramente duas responsabilidades:
   - geração/normalização das 4 vistas;
   - ingestão dessas vistas pelo TripoSR.
3. Priorizar arquitetura incremental e reversível.
4. Evitar começar por diffusion como solução obrigatória, devido a custo, latência, dependências adicionais e risco de inconsistência anatômica/identitária.
5. Planejar a UI para expor a composição 4-view como novo artefato principal do preprocess, substituindo a `Processed Image` atual.
6. Considerar diffusion/multiview generativo apenas como fase posterior e opcional de qualidade.

# Estratégia

A estratégia recomendada é dividir a melhoria em três camadas:

1. **Camada de contrato multi-view**
   - alterar conceitualmente o preprocess para produzir um objeto multi-view canônico com 4 vistas nomeadas e uma prévia composta para UI;
   - garantir enquadramento, escala, postura e alinhamento consistentes entre vistas.

2. **Camada de compatibilidade com o TripoSR**
   - primeiro validar formalmente se o modelo atual aceita múltiplas vistas reais via stack/lista de imagens com pequena adaptação em `TSR.forward()`;
   - tratar mosaico/strip apenas como fallback experimental, não como abordagem principal.

3. **Camada de melhoria de qualidade**
   - começar por uma abordagem determinística/controlada para gerar a composição 4-view;
   - manter uma segunda trilha opcional para geração por diffusion/multiview somente após o pipeline multi-view estar estável e mensurável.

# Análise técnica do estado atual

## 1. Pipeline atual

Em `app/app.py`:
- `preprocess(input_image, do_remove_background, foreground_ratio)` retorna apenas uma imagem.
- `generate(image)` chama `model(image, device=device)` com uma única imagem processada.
- a UI exibe `processed_image = gr.Image(...)`.
- o fluxo de eventos é linear: upload -> preprocess -> generate.

## 2. Limitação central do TripoSR atual no projeto

Em `app/tsr/system.py`:
- `TSR.forward()` aceita tipos que já incluem listas de imagens, porém internamente faz:
  - `self.image_processor(image, size)[:, None]`
  - `rearrange(..., Nv=1)`
- isso força semanticamente uma única vista, mesmo quando o pré-processador poderia montar lote/lista.

## 3. Sinal importante de extensibilidade

Em `app/tsr/models/tokenizers/image.py`:
- o tokenizer lê `batch_size, n_input_views = images.shape[:2]`.
- isso indica que a etapa de tokenização já foi escrita com suporte estrutural a múltiplas vistas.
- portanto, o principal bloqueio aparente está no contrato do `forward`, não necessariamente no tokenizer.

## 4. Conclusão técnica preliminar

O TripoSR do repositório atual não está operando como multi-view end-to-end, mas há indícios concretos de que uma adaptação controlada para `Nv > 1` é viável no pipeline de entrada. Isso torna a abordagem de múltiplas vistas reais mais promissora que empacotar tudo em um mosaico 2D.

# Alternativas viáveis para geração de 4 vistas a partir de uma imagem única

## Alternativa A — Composição determinística / heurística controlada

### Descrição
Gerar quatro vistas consistentes a partir da imagem única usando uma cadeia controlada de transformação visual, podendo combinar:
- segmentação já existente;
- normalização de pose/enquadramento;
- espelhamentos parciais guiados;
- regras anatômicas simples;
- inpainting localizado apenas onde necessário;
- composição final em 4 quadros canônicos.

### Vantagens
- menor custo computacional;
- mais previsível;
- menor dependência externa;
- mais fácil de depurar;
- mais alinhada à necessidade de consistência entre vistas.

### Desvantagens
- trás e laterais tendem a ser estimadas com baixa fidelidade real;
- risco de artefatos semânticos em cabelo, costas, mãos, acessórios e silhueta;
- pode melhorar estabilidade mais do que realismo.

### Melhor uso
- fase 1 e fase 2 do roadmap;
- baseline obrigatória para medir ganho estrutural.

## Alternativa B — Geração por diffusion / image-to-multiview

### Descrição
Usar um gerador externo para produzir frente/trás/esquerda/direita consistentes a partir da imagem inicial, idealmente com controle de pose, identidade e fundo neutro.

### Vantagens
- maior potencial de acrescentar detalhes ausentes da vista frontal;
- melhor cobertura geométrica para regiões ocultas;
- potencial de melhorar malha e textura.

### Desvantagens
- maior latência e consumo de VRAM;
- dependências adicionais e possível complexidade de distribuição;
- risco de inconsistência entre vistas;
- risco de drift de identidade, roupa, proporção e postura;
- exige camada extra de validação antes de alimentar o TripoSR.

### Melhor uso
- fase opcional de qualidade após estabilização do pipeline multi-view.

## Alternativa C — Mosaico/strip 2D enviado como imagem única

### Descrição
Montar as 4 vistas em grade 2x2 ou faixa horizontal/vertical e enviar o mosaico como se fosse uma imagem única para o pipeline atual.

### Vantagens
- mudança aparentemente pequena na interface do app.

### Desvantagens
- semanticamente fraca para o modelo;
- o `ImagePreprocessor` redimensiona para quadrado único, misturando contexto das 4 vistas;
- o backbone DINO e o restante do pipeline não recebem separação explícita por vista;
- alto risco de perda de informação e degradação do resultado.

### Melhor uso
- apenas experimento rápido de descarte, nunca abordagem recomendada.

# Comparação: determinística/composição versus diffusion/multiview

## Critérios

### 1. Consistência entre vistas
- Determinística: alta previsibilidade estrutural, baixa riqueza semântica.
- Diffusion: maior riqueza potencial, menor previsibilidade.

### 2. Custo operacional
- Determinística: baixo a médio.
- Diffusion: médio a alto.

### 3. Risco de regressão no app atual
- Determinística: baixo a médio.
- Diffusion: médio a alto.

### 4. Facilidade de validação
- Determinística: alta.
- Diffusion: média/baixa.

### 5. Potencial de ganho visual real
- Determinística: moderado.
- Diffusion: alto, porém incerto.

## Decisão recomendada

Adotar **determinística/composição como baseline oficial** e reservar **diffusion/multiview como trilha opcional posterior**, condicionada a métricas de melhora e orçamento de complexidade.

# Avaliação da UI: substituir a imagem processada atual por composição 4-view

## Objetivo funcional
A UI deve deixar de comunicar um único preprocess e passar a comunicar claramente o artefato multi-view que alimentará a reconstrução.

## Recomendação de apresentação

Substituir o `Processed Image` por um bloco visual com duas saídas derivadas do mesmo preprocess:

1. **Preview composta 4-view**
   - uma imagem 2x2 com rótulos visuais: Front, Back, Left, Right;
   - serve como artefato principal de inspeção humana.

2. **Payload multi-view interno**
   - estrutura não necessariamente exposta diretamente ao usuário como lista crua;
   - usada pelo `generate()`.

## Ajustes de UX planejados
- renomear semanticamente o estágio para algo como “Processed Multi-View”;
- manter feedback visual imediato antes da geração 3D;
- se necessário, expor também miniaturas individuais em galeria para inspeção fina;
- preservar simplicidade do fluxo principal: upload -> preprocess multi-view -> generate.

## Benefício
A UI passa a refletir o artefato real consumido pela inferência, reduzindo opacidade do pipeline e facilitando debug visual.

# Avaliação: o TripoSR atual aceita mosaico/strip ou requer adaptação?

## Conclusão
O TripoSR atual neste projeto **não deve ser tratado como compatível com mosaico/strip de forma nativa** para o objetivo desejado.

## Fundamentação
- `app/app.py` envia apenas uma imagem processada para `generate()`.
- `TSR.forward()` em `app/tsr/system.py` força `Nv=1`.
- o tokenizer aceita dimensão de vistas, mas o pipeline atual não a preserva.
- o `ImagePreprocessor` redimensiona entradas para um único quadrado, o que em mosaico faria cada vista competir pelo mesmo espaço e pela mesma representação global.

## Decisão arquitetural
O caminho correto é **adaptar o contrato para múltiplas vistas explícitas**, não empacotá-las num mosaico como se fossem uma vista só.

# Arquitetura incremental recomendada

## Fase 0 — Baseline e instrumentação de qualidade

### Objetivo
Congelar o baseline atual antes da mudança.

### Escopo
- registrar comportamento atual com `anjinho-lowpoly.png`;
- salvar artefatos de preprocess atual, OBJ, GLB e screenshots do `Model3D`;
- definir checklist de avaliação visual e funcional.

### Saídas esperadas
- baseline reproduzível para comparação;
- critérios mínimos de regressão estabelecidos.

## Fase 1 — Contrato canônico de preprocess multi-view

### Objetivo
Definir um objeto de saída multi-view padronizado sem ainda depender de diffusion.

### Escopo
Planejar um contrato lógico contendo:
- `front`
- `back`
- `left`
- `right`
- `composite_preview`
- metadados de alinhamento (centro, escala, bbox, foreground ratio efetivo)

### Regras do contrato
- todas as vistas no mesmo canvas e mesma resolução;
- personagem centralizado;
- fundo neutro consistente;
- orientação e escala preservadas entre quadros;
- ordem das vistas fixa e documentada.

### Saídas esperadas
- preprocess com semântica multi-view clara;
- UI pronta para trocar a imagem única por preview composta.

## Fase 2 — Integração real multi-view no TripoSR

### Objetivo
Permitir que `generate()` consuma 4 vistas explícitas.

### Escopo de planejamento
- adaptar `TSR.forward()` para inferir `Nv` dinamicamente a partir da entrada;
- evitar inserir `[:, None]` quando a entrada já vier como lista/stack multi-view;
- preservar compatibilidade com caminho single-view legado;
- manter `generate()` capaz de receber o payload multi-view padronizado.

### Resultado esperado
Dois modos compatíveis:
- `single_view_legacy`
- `multi_view_4`

### Justificativa
Permite rollout controlado e fallback rápido.

## Fase 3 — UI multi-view operacional

### Objetivo
Substituir a visualização de preprocess atual por composição 4-view e alinhar o fluxo de evento.

### Escopo
- trocar o output principal do preprocess;
- revisar `Examples` para retornar preview multi-view + malhas;
- atualizar contrato esperado por `/preprocess` e `/generate`;
- considerar galeria adicional se a prévia composta não for suficiente.

### Resultado esperado
O usuário entende exatamente quais 4 vistas estão sendo usadas antes de gerar o 3D.

## Fase 4 — Validação com heurística determinística

### Objetivo
Provar que a arquitetura multi-view funciona sem ainda incorporar diffusion.

### Escopo
- usar `anjinho-lowpoly.png` como teste funcional principal;
- usar `modelo-postura-em-a.png` como referência de enquadramento/postura;
- avaliar ganho de volume, laterais e traseira no mesh.

### Resultado esperado
Determinar se somente a reorganização estrutural do input já melhora o resultado.

## Fase 5 — Trilha opcional por diffusion/multiview

### Objetivo
Adicionar uma fonte gerativa de vistas apenas se as fases anteriores mostrarem espaço claro para ganho.

### Escopo
- encapsular o gerador multi-view atrás de interface estável;
- manter mesmo contrato canônico de saída da fase 1;
- comparar latência, VRAM, consistência e qualidade final.

### Resultado esperado
Adoção opcional, não mandatória, com possibilidade de feature flag futura.

# Componentes e responsabilidades propostas

## `app/app.py`
Responsabilidades planejadas:
- deixar de tratar preprocess como retorno de imagem única;
- orquestrar preview composta multi-view;
- encaminhar payload multi-view para geração;
- atualizar bindings da UI e dos exemplos.

## `app/tsr/system.py`
Responsabilidades planejadas:
- aceitar múltiplas vistas reais;
- inferir quantidade de vistas;
- manter compatibilidade com single-view;
- documentar claramente o formato esperado da entrada.

## `app/tsr/utils.py`
Responsabilidades planejadas:
- concentrar utilidades de normalização/alinhamento multi-view;
- separar preprocess geométrico comum das regras de composição das vistas.

## Novo módulo utilitário de multi-view
Responsabilidade planejada:
- isolar a lógica de montagem do objeto 4-view, evitando acoplamento excessivo em `app.py`.

# Etapas

1. Consolidar baseline do pipeline single-view atual com `anjinho-lowpoly.png`.
2. Formalizar o contrato do artefato multi-view e sua ordem canônica.
3. Planejar a troca da UI de `Processed Image` para preview 4-view composta.
4. Planejar a adaptação de `generate()` para consumir payload multi-view.
5. Planejar a adaptação de `TSR.forward()` para `Nv` dinâmico e fallback legado.
6. Validar explicitamente que mosaico/strip é apenas experimento de descarte e não caminho principal.
7. Executar fase de validação com abordagem determinística/controlada.
8. Só após estabilidade, avaliar trilha diffusion/multiview sob contrato idêntico.
9. Comparar qualidade, tempo e consumo de memória entre single-view, multi-view determinístico e multi-view generativo.
10. Consolidar decisão final de produto com base nas métricas.

# Validações planejadas

## Validação funcional
- preprocess continua aceitando upload normal;
- preview 4-view aparece corretamente na UI;
- geração continua produzindo OBJ e GLB válidos;
- `Model3D` continua renderizando os outputs sem regressão.

## Validação técnica
- caminho single-view legado continua funcional;
- caminho multi-view opera com `Nv=4` sem erro de shape;
- consumo de VRAM permanece dentro de faixa aceitável na GPU já validada;
- tempo de inferência não degrada além do limite definido para aceite.

## Validação visual
- silhueta lateral melhora em relação ao baseline;
- traseira deixa de depender apenas de alucinação implícita do modelo;
- proporção global do personagem permanece consistente;
- postura em A fica mais estável e simétrica.

# Critérios de aceite

1. A UI exibe uma composição 4-view no lugar da `Processed Image` única.
2. O pipeline de geração aceita esse novo artefato sem quebrar OBJ/GLB e `Model3D`.
3. O caminho multi-view apresenta melhora perceptível de detalhamento ou estabilidade geométrica em comparação ao baseline single-view no caso `anjinho-lowpoly.png`.
4. O caminho single-view legado continua disponível como fallback durante a transição.
5. A arquitetura permite trocar a origem das 4 vistas (determinística ou diffusion) sem reescrever a integração com o TripoSR.

# Riscos

## Risco 1 — O backbone não generalizar bem para múltiplas vistas sem ajuste adicional
Mesmo havendo suporte estrutural implícito no tokenizer, o modelo pode ter sido treinado majoritariamente para single-view. Isso pode limitar o ganho sem fine-tuning.

### Mitigação
- manter fallback single-view;
- validar primeiro com pequeno conjunto de casos;
- medir antes de expandir escopo.

## Risco 2 — Vistas sintéticas inconsistentes piorarem o mesh
Se as 4 vistas divergirem em anatomia, roupa ou proporção, o modelo pode reconstruir pior.

### Mitigação
- exigir contrato forte de alinhamento;
- começar por método determinístico/controlado;
- introduzir diffusion só com validação comparativa.

## Risco 3 — A UI esconder demais a estrutura real dos dados
Uma única preview composta pode não bastar para debug.

### Mitigação
- prever galeria auxiliar opcional de vistas individuais.

## Risco 4 — Regressão de performance/VRAM
Quatro vistas explícitas podem aumentar custo de memória e tempo.

### Mitigação
- medir baseline;
- monitorar GPU;
- manter rollout em fases.

## Risco 5 — Mosaico parecer funcionar superficialmente e desviar a arquitetura
Pode gerar falsa sensação de simplicidade, mas sem semântica correta para o modelo.

### Mitigação
- tratar mosaico apenas como experimento de descarte documentado.

# Observações

1. O suporte a múltiplas vistas parece mais próximo do que o pipeline atual deixa transparecer, porque o tokenizer já opera sobre `n_input_views`.
2. O gargalo principal observado está na montagem do tensor em `TSR.forward()` e no contrato simplificado entre UI/preprocess/generate.
3. O repositório atual já possui pontos suficientes para uma evolução incremental sem reescrever o app inteiro.
4. Como os arquivos de contexto em `.vibecoding/` estão vazios, este plano também serve como primeira consolidação arquitetural explícita dessa demanda.

# Recomendação final

Recomenda-se seguir esta ordem:

1. **Oficializar o preprocess multi-view canônico e a preview 4-view na UI**.
2. **Adaptar o TripoSR para consumir 4 vistas explícitas com `Nv` dinâmico e fallback single-view**.
3. **Validar primeiro uma trilha determinística/controlada** com `anjinho-lowpoly.png` e referência de postura em `modelo-postura-em-a.png`.
4. **Descartar mosaico/strip como solução principal**.
5. **Somente depois avaliar diffusion/multiview** como módulo opcional de qualidade, sob o mesmo contrato multi-view.

Essa é a abordagem com melhor equilíbrio entre risco, previsibilidade, custo técnico e potencial de ganho real de detalhamento.

# Arquivos críticos para futura execução

- `app/app.py`
- `app/tsr/system.py`
- `app/tsr/utils.py`
- `app/gpu_runtime_check.py`
- potencial novo módulo de utilidades multi-view sob `app/tsr/` ou `app/`

# Verificação end-to-end planejada

1. Executar preprocess com `anjinho-lowpoly.png`.
2. Confirmar exibição da preview 4-view na UI.
3. Confirmar que `/generate` aceita o novo payload multi-view.
4. Gerar OBJ e GLB.
5. Validar abertura do resultado em `Model3D`.
6. Comparar visualmente com o baseline single-view.
7. Registrar tempo de geração e uso de GPU.
8. Repetir com fallback single-view para confirmar compatibilidade retroativa.
