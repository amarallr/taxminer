# Changelog

## Não incluído em versão — 2026-11-13

- **Hints ao passar o mouse** (aba Fundos e painel publicado): Direitos políticos especiais e Direitos
  econ.-financeiros distintos funcionam como o de Entidade de investimento, em tooltip, sem o botão ⓘ
  (nas características, nos filtros e no cabeçalho da lista). A nota explicativa de Entidade de
  investimento fica só no tooltip, para liberar espaço.
- **Troca de fundo**: ao clicar em outro fundo, o detalhe abre em Perfil e o anterior fica esmaecido até
  os dados novos chegarem.
- **RELATIVO / ABSOLUTO** com fonte 30% menor (abas Fundos e FICHA).
- **FICHA com Perfil e Denominações**: as mesmas subabas da aba Fundos (app e painel publicado).
- **Régua de z robusto nas Distribuições**: eixo secundário no topo de cada gráfico, com 0 na mediana dos
  fundos e marcas a cada 1, 2, 5, 10... z (pelo menos 16 px entre elas). O eixo de baixo continua em valores
  originais. O tooltip explica o cálculo: z = (valor do fundo − mediana) ÷ desvio robusto, na escala do
  gráfico, sem winsorização. O desvio robusto é o MAD escalonado; com MAD zero, usa 1,2533 × desvio
  absoluto médio e, depois, o desvio-padrão. Nas participações, o piso é de 1 p.p. Faixas: 2 a 3,5 é
  atípico; 3,5 ou mais é extremo.
- **Métricas relativas na aba Distribuições** (app e painel publicado): seletor RELATIVO / ABSOLUTO ao
  lado do nome da aba; escolher qualquer um dos dois abre a aba. No modo Relativo, cada item aparece
  dividido pelo total da sua tabela, os totais divididos pelo PL, e há razões analíticas, conforme as
  75 regras de `config/metric_ratio_rules.csv`. Cada fundo tem um valor: a mediana das linhas do
  numerador sobre a mediana das linhas do denominador, na mesma competência. Os fundos com denominador
  ausente, zero ou negativo ficam de fora, e o hint informa quantos. As participações são desenhadas em
  escala linear (0 a 100%).
- **Piso do z robusto**: quando a maioria dos fundos tem o mesmo valor (MAD = 0), usa-se o desvio
  absoluto médio escalonado. Para participações, há um piso de 1 ponto percentual.
- **FIDC X.4 por tipo de operação**: cada campo vira um gráfico por tipo (`TAB_X_TP_OPER`: captações,
  resgates, resgates solicitados, amortizações), em vez de uma mediana que misturava os tipos.
- **FICHA › Distribuições em uma tela**: a grade é dimensionada para até 54 gráficos, todos do mesmo
  tamanho; acima disso, há rolagem vertical.
- **Hints dos direitos especiais** (`.claude/hints.txt`): textos integrais de Descrição, Relevância para
  análise e Atenção, mais a Informação declarada (CVM). Separam o dado declarado (Sim / Não / Não
  informado; o campo vazio nunca vira "não"), a evidência, as hipóteses (marcadas como hipótese) e a
  ausência de conclusão tributária automática (Lei nº 14.754/2023 e Resolução CVM nº 175, sem presumir
  as mesmas regras para todos os fundos). O ⓘ abre por clique e por teclado e tem dica ao passar o
  mouse. Em FIDC, FII e FIAGRO, que não publicam esses campos, o ⓘ aparece na linha "Não constam do
  informe". Nenhum score ou motor tributário usa esses indicadores (há teste para isso).
- **Administradores**: o fundo escolhido na lista é desenhado no gráfico do administrador, na mesma
  escala e na cor do tipo, com o valor e a participação no total na dica de cada mês.
- **Publicação segura** (`prompts/common_p09_safe_publication.txt`, `req_0023`): procedimento obrigatório para
  todo export, commit e push. O carimbo passa a ter fuso horário (`v.X · AAAA-MM-DD HH:MM -03:00 · commit`).
  O manifesto `site/app/version.json` registra versão, geração, ambiente, commit-base e, preenchidos pelo
  workflow do GitHub Pages, o commit publicado, a data/hora e o estado da publicação. O rodapé PRODUÇÃO
  mostra esse estado.
- **Rodapé de versão** em todas as abas: versão, commit, data/hora do build e ambiente
  (DESENVOLVIMENTO no app local, PRODUÇÃO no painel publicado).

- **Características dos fundos** (app e painel publicado): novos campos Público-alvo (FII, FIP,
  FIAGRO), classe de cotas com direitos políticos especiais, com direitos econômico-financeiros
  distintos e percentual total das cotas subscritas (FIP), além de cotistas, condomínio, fundo
  exclusivo, entidade de investimento, interesse único e vínculo familiar. Quando as classes do FIP
  publicam valores diferentes no mesmo informe, todos aparecem ("não / sim"); nenhuma classe é
  escolhida no lugar das outras. No cabeçalho da ficha, as características ficam em etiquetas compactas
  de rótulo e valor, na coluna do nome do fundo. Os
  campos que o informe da família não tem aparecem numa única linha. Ficam destacados em âmbar:
  entidade de investimento = não, direitos políticos especiais = sim e direitos econômico-financeiros
  distintos = sim.
- **Colunas e filtros das características** em Fundos e em todas as subabas. A lista ganha as colunas
  Cotistas e as características das famílias em exibição, ordenáveis e com rolagem horizontal. Um
  painel recolhível, "Características", traz um filtro por característica exibida (Todos, valores
  publicados, Não informado, Não consta do informe) e faixas de cotistas e de cotas subscritas,
  com a contagem de filtros ativos. O Público-alvo une as formas singular e plural (FII
  "INVESTIDOR PROFISSIONAL" e FIP "Investidores profissionais").
- **Rentabilidade em curva normal** (cabeçalho da ficha, ao lado do nome do fundo, app e painel
  publicado): mini gráfico com o histograma da
  rentabilidade mensal publicada, a curva normal com a mesma média e desvio, a média e o último mês.
  Usa FIDC `TAB_X_VL_RENTAB_MES` (a classe/série com mais meses), FII
  `Percentual_Rentabilidade_Efetiva_Mes` (fração, exibida em %) e FIAGRO `Rentabilidade_Efetiva_Mes`.
  A escala vai até 4 desvios da média, e os meses fora dela são contados e informados; nenhum valor
  é descartado. Exige ao menos 6 meses. O FIP não publica rentabilidade, e o gráfico diz isso. No
  app, o gráfico lê só o fundo selecionado; no painel publicado, vem no arquivo da ficha do fundo.
- **Aba Distribuições** ao lado de Série completa (Fundos, subabas e FICHA; app e painel publicado):
  matriz com um pequeno gráfico por campo numérico da tabela escolhida. Ela mostra a **posição do fundo
  entre os fundos da mesma família na mesma competência** (a do seletor de período da Ficha). As
  barras contam fundos por faixa de valor; a curva é a normal com a média e o desvio desses fundos;
  o tracejado é a média e a marca laranja é o fundo. Cada gráfico mostra o percentil do fundo e o
  número de fundos. O hint traz a explicação, P25, mediana e P75, média, desvio, extremos, a escala
  (1º ao 99º percentil, com os fundos fora dela contados) e o histórico do próprio fundo. Há um
  valor por fundo: a mediana das suas linhas na data (classes, séries ou versões). Ficam de fora os
  campos com menos de 6 fundos ou com valor único. No painel publicado, os resumos por tabela e
  competência ficam em `data/peers/` (gzip), lidos só quando escolhidos.
- **Escala logarítmica nos gráficos de distribuição** (Distribuições e rentabilidade mensal ao lado do
  nome do fundo; app e painel publicado): histograma e curva são desenhados em escala log com sinal
  (asinh), que aceita zero e valores negativos. Os valores dos fundos variam por ordens de grandeza, e
  na escala linear o histograma virava uma única barra. A escala é só para exibição: eixo, hint,
  percentis, média, desvio, P25, mediana e P75 continuam em valores originais. O gráfico mostra
  "escala log", e o hint explica que o tracejado marca o centro da curva nessa escala. No mini gráfico
  de rentabilidade, o aviso fica na legenda, sem cobrir as barras.
- **Winsorização a 2,5%** nos gráficos de distribuição: valores abaixo de P2,5 ou acima de P97,5 são
  desenhados nesses limites, e o hint informa os limites e quantos fundos foram afetados. Média, desvio,
  percentis e posição continuam calculados com os valores originais.
- **Análise estatística robusta na aba Distribuições** (app e painel publicado): cada campo mostra o
  **z robusto** do fundo, (valor − mediana) / MAD, na escala de exibição, comparado aos demais fundos da
  mesma família na mesma competência. Classes: típico (|z| < 2), atípico (|z| ≥ 2) e extremo
  (|z| ≥ 3,5, critério de Iglewicz e Hoaglin). O hint informa também se o valor fica fora das cercas de
  Tukey (1,5 × IQR) e quanto o percentil mudou desde a competência anterior (▲▼). Os campos são
  ordenados do mais para o menos atípico, e um painel "Destaques estatísticos" lista os seis campos
  mais fora do típico. A classificação é descritiva: não é conclusão fiscal nem indica irregularidade.
- **Perfil sem barra de rolagem:** o gráfico "Patrimônio líquido e cotistas" ficou mais baixo e cabe no
  painel da ficha, com a legenda visível.
- **Hints de direitos especiais (FIP)**, `req_0022` / `work_0041`: botão ⓘ ao lado de "Direitos
  políticos especiais" e "Direitos econ.-financeiros distintos" nos filtros, nas características da
  ficha e nas colunas da lista (app e painel publicado).
  - O popover tem as seções Fonte (CVM), Descrição, Interpretação (Sim, Não, Não informado; vazio não
    equivale a "não"), Relevância tributária (interpretação analítica), Atenção e Referências
    normativas (Res. CVM 175, Anexo IV; Lei 14.754/2023, art. 23, conferidas nos textos oficiais).
  - Abre com clique, Enter, Espaço ou toque e fecha com Esc, clique fora ou ×.
  - Textos centralizados em `fund_attribute_hints`, de onde vêm `window.TM_INFO` no app e no painel.
  - **Aviso conjunto** (informativo) quando uma mesma linha de classe do último informe FIP tem os dois
    campos = S (`fund_joint_rights`). Ele informa a competência e o número de linhas e não altera
    destaques nem a classificação de entidade de investimento.
- **Decimais da CVM na exibição:** um valor publicado como `12.345` (ponto decimal) aparece como
  `12,345`; antes aparecia `12.345`, que no padrão brasileiro parece doze mil.
- **Sem notação científica:** valores publicados como `1.2345E-5` aparecem como `0,000012345` em
  telas, fichas e séries completas, no app e no painel publicado (`expand_scientific`), e
  `options(scipen = 999)` no app e no exportador.
- **Governança em português:** títulos, descrições, critérios, riscos, planos e observações aparecem
  em português por uma camada de exibição (`config/governance_texts_pt.csv`). Os registros continuam
  como gravados (fonte da auditoria), e um teste exige tradução para todo título, descrição, critério
  e risco. Campos, estados e filtros também aparecem em português. A aba cabe na janela, sem barras
  de rolagem na página: cabeçalho e filtros compactos, e só os cartões rolam por dentro. As caixas do
  grafo de rastreabilidade ficaram menores.
- **Aceites** (`decision_0054` a `decision_0056`): work_0019 a work_0024, work_0027 a work_0031
  (`acc_0016` a `acc_0026`). O marco da Fase 1.3 (work_0023) se conclui com o próprio aceite.
- **Governança reorganizada** (app local, somente o proprietário): subabas Visão geral, Pendências,
  Aceites, Requisitos e itens, Dependências, Rastreabilidade, Agentes e tokens e Auditoria. As
  pendências mostram situação, o que falta e de quem depende; os requisitos, o progresso dos itens
  aceitos; as dependências, a situação de cada uma. Selos de status por cor, textos em português,
  tabelas com cabeçalho fixo e números em pt-BR. Um clique em qualquer linha abre a
  rastreabilidade do registro (`src/common/governance_views.R`).
- **Aceites:** Fase 03 da governança (`acc_0014`) e ETAPA 02 do explorador multimétrico
  (`acc_0015`), em `decision_0053`.
- **Fundos com subabas** (app e painel publicado): FIDC, FII, FIP e FIAGRO passam a ser subabas de
  "Fundos" (ao lado de "Todos"), e "Cedentes" fica dentro de FIDC ("Fundos FIDC" e "Cedentes"). Os
  atalhos entre abas (abrir fundo pelo Panorama, duplo clique em Cedentes, fundo atual) abrem a
  cadeia de abas correta.
- **Modo proprietário:** a aba Governança e o script `scripts/governance_registry.R` só funcionam
  com `TAXMINER_OWNER_MODE=1` no perfil do proprietário (`src/common/owner_mode.R`). Fora disso, a
  aba não aparece e o script recusa. Nunca entra no painel publicado nem em instaladores. O código
  é público: isto restringe o uso do app e dos scripts, não a leitura do repositório.
- **Catálogo de métricas** (explorador multimétrico, ETAPA 02; req_0019): 55 métricas (48
  declaradas, 7 derivadas) em `config/metric_catalog.csv` e mapeamentos para tabelas e campos da
  CVM em `config/metric_mappings.csv`, com vigência, filtro, chave de classe e equivalência entre
  leiautes (`same_field`, `proven`, `not_proven`). `src/data/metric_catalog.R` faz a verificação
  estática, a disponibilidade por leiaute, a revisão pelo dicionário da CVM, a matriz métrica ×
  tabela e a série com linhagem por ponto. `scripts/validate_metric_catalog.R` grava
  `reports/metric_catalog/validation_report.md`: as 8 métricas padrão coincidem com a série atual
  da Ficha (0 divergências), e a troca de tabela do FIP em 2024 foi comprovada pelo dicionário.
  ICVM 555 e FIF (I.2.c.5) ficam como métricas separadas: as descrições diferem. Ainda sem
  interface (ETAPA 03).

## Não incluído em versão — 2026-11-12

- **Ficha › Série completa** (app e painel publicado): rolagem horizontal; as colunas não encolhem e a
  coluna "Campo" fica fixa à esquerda.
- **Cobertura e qualidade** (app local): subabas "Tabelas consolidadas" e "Registro de qualidade".
  As tabelas ficam em subabas por família, na ordem das fichas da CVM, com nome e descrição de cada
  uma; no registro de qualidade, as famílias são colunas, com total.
- **Governança — planejamento** (Fase 03): relatório de planejamento com priorização explicada,
  plano por requisito, estimativas só com histórico comparável, deduplicação de pedidos e propostas
  de status dos requisitos para aprovação humana.
- **Governança — Executive Command Center** (aba nova no app local): 17 indicadores com definição
  formal, que mostram "indisponível" quando não há dado; funil de requisitos; linha do tempo e
  desempenho dos agentes; tokens; grafo de rastreabilidade com detalhamento; riscos; roteiro;
  trilha de auditoria; evolução do prompt. Filtros, pesquisa por ID, atualização a cada 150 s e
  exportação em Markdown e CSV. A aba não entra no painel publicado.
- **Carimbo de versão com o commit:** o carimbo em "Sobre" mostra também o hash curto do commit
  (ex.: "v.1.0.3 · 2026-11-12 21:22 · 3cbb696"). No painel publicado, o hash é o do commit
  publicado, gravado na implantação; no app local, é o commit em uso, com "+" se houver alterações
  não salvas em commit.
- **Fontes 20% menores** no app local e no painel publicado (tamanhos do CSS e base do Bootstrap
  multiplicados por 0,8).
- **Fontes 10% maiores** que no ajuste anterior, em todo o app e no painel publicado (fator final de
  0,88 sobre o tamanho original).
- **Nova marca na barra de navegação**, no lugar do nome "TaxMiner": emblema em branco, filete,
  "Analytics" em texto e ícone de barras em SVG, nítidos em qualquer resolução.

## Versão 1.0.3 — 2026-11-12

Registra como `1.0.3` (arquivo `VERSION`, tag `v1.0.3`) as entregas posteriores à 1.0.2:

- **Nota explicativa** da entidade de investimento: quadro com borda, parágrafos justificados com
  hifenização e o período de cada parágrafo ("Até 2023 (ICVM 578/579):") em negrito. Na dica, a
  nota aparece separada da descrição do campo, em caixa mais larga e justificada.
- **TaxMiner Governance** (`req_0021`, `docs/governance_plan.md`):
  - Fases 01 e 02 aceitas: registro de solicitações, trilha de transições e checagem de integridade
    dos registros.
  - Fase 06 aceita: camada imutável com linha de base, revisões do prompt mestre com diff e
    aprovação humana, e histórico de evolução.
  - Fase 04 implementada: registro de execuções de agentes, matriz de capacidades, hook do Claude
    Code e leitor de tokens (ainda não ativados).

## Versão 1.0.2 — 2026-11-12

Registra como `1.0.2` (arquivo `VERSION`, tag `v1.0.2`) as entregas posteriores à 1.0.1, descritas nas
seções abaixo até "Ficha e Série completa no painel publicado": Ficha e Série completa no painel publicado;
Cedentes, aba Ficha, filtro de FIP e negativos em vermelho; áreas protegidas renomeadas; todas as tabelas do
FIDC no painel publicado; nomes dos cedentes (CVM e Receita Federal), características dos fundos, aba
Cedentes com filtro cruzado, fundo corrente compartilhado por todas as abas, nota explicativa da entidade de
investimento e cores das características.

## Nota explicativa da entidade de investimento — 2026-11-12

- Nota explicativa do indicador de entidade de investimento (`ENTID_INVEST`, `decision_0042`): recolhível
  abaixo das características dos FIP e nas dicas da característica, do filtro de FIP e do campo na Ficha e na
  Série completa, no app e no painel publicado.
- Nota com parágrafos justificados. Características dos fundos com cor própria discreta quando
  informadas (azul-acinzentado), cinza quando ausentes e, no FIP, entidade de investimento "não" mantida em
  destaque.

## Nomes dos cedentes, características dos fundos e Ficha que segue a aba — 2026-11-12

- **Nomes dos cedentes PJ** (`decision_0041`): catálogo de entidades, cadastros da CVM (companhias abertas,
  fundos e classes, prestadores de serviço) e base de CNPJ da Receita Federal (dados abertos, razão social da
  raiz do CNPJ), baixados e mantidos localmente. 10.272 de 10.274 cedentes PJ com nome (antes, 986); a fonte
  de cada nome aparece na lista e no detalhe. Novos coletores `scripts/collect_cvm_registries.R` e
  `scripts/collect_rfb_cnpj.R` (`docs/data_sources.md`).
- **Características dos fundos** (Fundos, FIDC, FII, FIP, FIAGRO): cotistas, aberto/fechado, exclusivo,
  entidade de investimento (destacada quando "não") e interesse único e indissociável, pelo último informe
  que publicou cada campo. PL e cotistas num só gráfico, com eixo esquerdo e direito.
- **Fundo corrente em todas as abas:** o último fundo selecionado em qualquer aba é mostrado por todas
  ao serem abertas (Ficha, Fundos e abas de família, Panorama, Administradores e Cedentes), no app e no
  painel publicado.
- **Aba Cedentes:** listas de cedentes e de FIDCs lado a lado, uma filtrando a outra pelo clique; duplo
  clique no FIDC abre o fundo na aba FIDC.
- **Barra de carregamento** no app e no painel publicado.

## Todas as tabelas do FIDC no painel publicado e nomes das tabelas — 2026-11-12

- **Painel publicado:** Ficha e Série completa das 17 demais tabelas do informe mensal do FIDC (II a X.7),
  além da tab_I (`decision_0039`). Um arquivo gzip por fundo em `site/app/data/fichas_x/fidc/`, baixado só
  quando uma dessas tabelas é escolhida, e um índice por fundo; o navegador descomprime. Site com 697 MB
  (limite de 1 GB do GitHub Pages); as tabelas extras ocupam 190 MB comprimidas (cerca de 2,3 GB sem
  compressão).
- **Nomes das tabelas nos combos:** a seção do informe ("I – Aplicações", "X.6 – Desempenho esperado
  (benchmark) e realizado") em vez do nome do arquivo da CVM, no app e no painel publicado
  (`fund_table_labels`); o nome da CVM fica na dica e em cada citação.
- **Requisito `req_0020`:** painel de fundos e site publicado formalizados como requisito da Fase 1.3
  (`work_0031`); `docs/requirements.md` passa a listar `req_0015` a `req_0020`.
- **Documentação:** README e `docs/` reformatados (sumário, alertas do GitHub, diagramas Mermaid, cabeçalho
  de metadados, tabelas alinhadas, links validados); panorama do projeto atualizado.

## Áreas protegidas renomeadas — 2026-11-12

- `restricted/` e `tmp/` passam a ser `.restricted/` e `.tmp/` (`decision_0040`): sigilosas, inacessíveis
  aos agentes e nunca compartilhadas nem publicadas. Regras atualizadas em `AGENTS.md`, `CLAUDE.md`,
  `CODEX.md`, `GEMINI.md`, README, prompts e documentos; `.gitignore`, `.renvignore`, `.geminiignore` e
  `.claude/settings.json` protegem os nomes novos e os antigos.

## Cedentes, aba Ficha, filtro de FIP e negativos em vermelho — 2026-11-11

- **Aba Cedentes** (app e painel publicado), logo após FIDC: os cedentes dos FIDC como publicados na
  Tabela I do informe mensal (9 maiores de cada bloco: I.2.a.12 e I.2.b.12 desde nov/2019; I.2.b.1 até
  out/2019), por competência. Ranking por número de FIDCs, filtros por cedente ou FIDC, pessoa física ou
  jurídica e bloco; detalhe com os FIDCs, posição e participação; clique no FIDC abre a ficha na aba FIDC.
  CPF completo, como publicado (`decision_0038`). Participações acima de 100% (cerca de 10% dos valores)
  são inconsistências do próprio informe: aparecem como publicadas, marcadas com ⚠. Mesmo pacote JSON
  nos dois (`src/intelligence/cedente_data.R`, `prototype/www/cedentes.js`).
- **Aba Ficha**, entre FIAGRO e Cobertura e qualidade no app (`prototype/fund_record_module.R`) e entre
  FIAGRO e Sobre no painel publicado: qualquer fundo, com Ficha e Série completa na largura toda. No
  painel publicado, a Ficha abre na tabela com o informe mais recente (FIP: quadrimestral desde 2024).
- **FIP:** filtro "Entidade de investimento" (sim, não, não informado), pelo último informe que publicou
  `ENTID_INVEST`; o detalhe do fundo mostra o valor e o mês do informe.
- **Administradores:** a lista de fundos mostra PL e % do total do administrador.
- **Valores negativos sempre em vermelho**, no app e no painel publicado (células, KPIs, barras, ficha).
- Série completa: valores no tamanho do cabeçalho das competências, CNPJ e números sem quebra.
- `TAXMINER_KEEP_FICHAS=1` na exportação mantém `data/fichas/` quando a consolidação não mudou.

## Ficha e Série completa no painel publicado — 2026-11-11

- As abas de fundos do painel publicado (Fundos, FIDC, FII, FIP, FIAGRO) ganham Ficha e Série completa,
  como no app local, para as tabelas principais de cada tipo: FIDC tab_I; FII geral, complemento e
  ativo/passivo mensais; FIP trimestral e quadrimestral; FIAGRO mensal. As demais tabelas seguem no app local.
- Um arquivo por fundo (`data/fichas/{tipo}/{CNPJ}.json`, mediana 28 KB), baixado só quando o fundo é
  aberto. Valores e rótulos são gerados pelas mesmas funções do app (formato brasileiro, máscara de
  CNPJ/CPF, descrição do dicionário da CVM) e cada coluna cita arquivo, linha e SHA-256 da origem.

## Navegação mais rápida — 2026-11-11

- Administradores (app local): índice administrador × fundo calculado uma vez na carga; trocar de
  administrador caiu de ~3,1 s para ~0,5–0,8 s e o clique num mês de ~1,0 s para ~0,2 s. As listas
  de barras são montadas como texto num só passo (mesma marcação). Resultados idênticos aos anteriores
  (conferido nos dados reais e em teste).
- Fichas (app local): cada tabela é aberta uma vez por sessão e as últimas 40 consultas de fundo ficam
  em memória; reabrir um fundo ou voltar a uma tabela já vista não lê o parquet de novo.
- Painel publicado: nomes normalizados uma vez na carga e lista filtrada/ordenada reaproveitada na troca
  de página; ordenar caiu de ~180 ms para ~40 ms e "próxima página" de ~250 ms para ~30 ms.

## Versão na aba Sobre e Panorama com 30 maiores — 2026-11-11

- Aba Sobre (app e painel publicado): versão e data/hora de geração da página logo abaixo do
  título, no formato `v.1.0.1 · aaaa-mm-dd hh:mm`. A versão vem do arquivo `VERSION` na raiz.
- Panorama: os rankings passam a mostrar os 30 maiores administradores e os 30 maiores fundos;
  a lista de fundos mostra o % de cada fundo no patrimônio filtrado (mesma base dos administradores).
- Ficha e série completa: campos de CNPJ e CPF com máscara (00.000.000/0000-00 e 000.000.000-00)
  quando os dígitos verificadores conferem; nos campos "CPF ou CNPJ" do cedente, o tipo é reconhecido
  pelo valor. Valor inválido aparece como publicado, sem máscara, para não disfarçar erro da fonte.
- Panorama: duplo clique num fundo abre a aba do tipo (FIDC, FII, FIP, FIAGRO) já filtrada pelo CNPJ
  do fundo e com o fundo aberto, no app e no painel publicado; o filtro de administrador é limpo e o
  estado do Panorama não muda.
- Série completa transposta, como um demonstrativo: uma linha por campo com os mesmos rótulos da
  Ficha (descrição do dicionário; itálico sem descrição; código CVM na dica), uma coluna por
  competência do mais recente ao mais antigo, com link e citação da fonte no cabeçalho; rótulos fixos
  à esquerda e cabeçalho fixo no alto; campos vazios em todos os períodos ocultos; colunas estreitas
  (valores em fonte 30% menor, espaçamento reduzido, texto quebrando em 52 px, números completos
  como publicados).
- Rodapé de paginação (Anterior / Página / Próxima) menor, em caixa alta, com filete acima, no app e
  no painel publicado.

## Ajustes após a 1.0 — 2026-11-11

- Série completa do fundo: tabela montada como texto, coluna a coluna, em vez de um objeto por
  célula. Num FIDC com 165 períodos e cerca de 80 campos, a montagem cai de 23,6 s para 0,45 s,
  com a mesma formatação (teste de equivalência e de tempo em `test_fund_reports_search.R`).
- Painel publicado: as abas do topo recebem o mesmo estilo do app (caixa alta pequena, sublinhado
  só na aba ativa); no HTML estático elas não têm a classe `nav-link` que o Shiny adiciona no app.

## Estilo executivo, PL nas listas e ordenação por PL — 2026-11-11

- Listas de fundos (Fundos, FIDC, FII, FIP, FIAGRO) ganham as colunas PL (mês de referência do tipo;
  fora dele, o último informe) e % (participação no PL total do tipo, mesma base do Panorama).
- Toda lista abre ordenada por PL decrescente, também após mudar filtros; sem dados de PL, ordena
  pelo nome.
- Panorama: gráficos por tipo um terço mais baixos; rankings ganham o espaço.
- Estilo executivo em todas as abas: texto sem serifa e títulos/indicadores com serifa, números
  tabulares, filtros e combos menores e sem cantos arredondados, cabeçalhos e rótulos em caixa alta
  pequena, filetes finos no lugar de caixas.
- Ficha do fundo: rótulos e valores menores e uniformes; série completa com citação em uma linha
  (texto completo ao passar o mouse) e ano/versão sem separador de milhar.

## Panorama com filtros cruzados — 2026-11-11

- Estado único de filtros no Panorama: competência (seletor ou clique no gráfico), tipo de fundo,
  administradores e fundos (clique seleciona; Ctrl+clique soma). Filtros combinam por interseção;
  cada filtro ativo aparece com botão de remover; "limpar seleções" e "limpar tudo".
- KPIs, composição, painéis por tipo e os rankings Top 20 são recalculados sobre o mesmo universo
  filtrado; cada gráfico ignora só a própria dimensão e mantém o item selecionado visível.
- Administrador de cada fundo é o informado na competência exibida (vínculo histórico).
- Pacote de dados `processed/metrics/panorama` (`src/intelligence/panorama_data.R`), em cache, usado
  pelo app e pelo painel publicado; motor em `prototype/www/panorama.js`. Página do app passa de
  1,2 MB para 51 KB.
- Testes: dados do Panorama em R e motor de filtros em Node (`tests/testthat/panorama_engine_test.js`).
- Diagnóstico e plano da plataforma de BI em `docs/bi_platform_plan.md`.

## Abas de fundos no painel publicado e Administradores em tela única — 2026-11-11

- Painel publicado (GitHub Pages) ganha as abas Fundos, FIDC, FII, FIP e FIAGRO: lista com busca por
  nome atual ou anterior, CNPJ e administrador, ordenação, paginação, Perfil (indicadores e gráficos) e
  Denominações, lidos no navegador a partir de `site/app/data/` (`prototype/static_funds.R`,
  `prototype/static/taxminer_static.js`). Ficha e série completa seguem no app local.
- Administradores: uma tela, sem rolagem do navegador (só ranking e lista de fundos rolam); fonte e
  gráfico menores; clicar em um mês do gráfico lista os fundos daquela competência.
- Desempenho: o Panorama do app local é montado uma vez na inicialização (carga da página de cerca
  de 6 s para cerca de 1 s).

## Resolução de entidades e abas por tipo de fundo — 2026-11-11

- Serviço central de resolução de entidades (`src/data/entity_resolution.R`): identidade pelo
  CNPJ canônico, denominações agrupadas só por regras do dicionário versionado
  (`config/entity_name_rules.csv`), histórico de nomes com fonte e períodos observados, fila de
  revisão para nomes parecidos mas não equivalentes, relatório de qualidade. Catálogos em
  `processed/master/`; documentação em `docs/entity_resolution.md`.
- Filtros de fundo e administrador consomem o catálogo: `CNPJ formatado — denominação`, várias
  opções por CNPJ, e qualquer uma recupera todo o histórico do CNPJ. Lista com uma linha por
  fundo; nova aba Denominações no detalhe. CNPJ com máscara no app e no painel publicado.
- Abas reordenadas (Panorama, Administradores, Fundos) e uma aba por tipo: FIDC, FII, FIP e
  FIAGRO.
- Texto justificado na página do projeto e na aba Sobre.
- Novo teste `test_entity_resolution.R` (15 casos obrigatórios); o validador roda 11 arquivos.

## Filtros no Panorama, Fundos em uma tela e texto institucional — 2026-11-11

- Panorama: 20 maiores administradores e 20 maiores fundos; clique no gráfico de uma família
  filtra os dois rankings e clique num administrador mostra os maiores fundos dele. Filtros no
  navegador, iguais no app e na versão publicada.
- Fundos: barra de filtros com autocomplete (fundo, administrador com nº de fundos, período,
  famílias), ordenação pelo cabeçalho, sem barras de rolagem da página; ficha com a descrição dos
  campos conforme os metadados da CVM (rótulo derivado em itálico quando não há descrição).
- Valores numéricos exibidos com ponto de milhar e vírgula decimal, alinhados à direita
  (identificadores ficam como publicados).
- Texto institucional (engenharia de dados, IA e engenharia de software) no README e no site.

## Painel publicado e Panorama em uma tela — 2026-11-11

- Painel de fundos publicado em https://amarallr.github.io/taxminer/app/ (versão estática gerada
  por `scripts/export_static_dashboard.R`); links no README e na página do projeto.
- Panorama cabe em uma tela, sem barras de rolagem; séries por família com o número de fundos
  (linha tracejada, eixo direito). Fontes menores e página mais larga em todo o app.

## Painel analítico dos fundos — 2026-11-11

- Tabela derivada de métricas por fundo e período (`src/data/build_fund_metrics.R`): patrimônio
  líquido, ativo e cotistas, com citação e reapresentações resolvidas.
- Analítica sem LLM (`src/intelligence/fund_analytics.R`): mês completo, variação em 12 meses,
  totais sem duplicar CNPJ, saldo do FIP entre informes, HHI e ranking de administradores.
- Novas abas Panorama (indicadores, composição por família, séries, maiores administradores e
  fundos, metodologia) e Administradores (ranking, concentração, série e fundos de cada um);
  aba Perfil na ficha do fundo. Gráficos SVG próprios (`prototype/charts.R`), sem pacote novo.
- Novo teste `test_fund_analytics.R` (78). O validador roda 10 arquivos.

## Interface dos fundos e horários corrigidos — 2026-11-11

- Interface em paisagem: filtros com autocomplete (fundo por CNPJ ou nome, administrador,
  períodos), lista paginada e ordenável com seleção por clique, ficha do fundo lado a lado com
  campos na vertical e citação em link, série completa em aba. Estilo próprio sóbrio
  (`prototype/www/taxminer.css`), só com fontes do sistema.
- `bslib` declarado no `DESCRIPTION` (já estava no `renv.lock`).
- Nomes publicados sem letras ("NA", ",", "0") aparecem como "(sem nome publicado)" e vão
  para o fim da lista; o dado guardado não muda.
- Testes da busca: 68.
- Horários dos registros de 10 e 11/11 corrigidos (`decision_0032`).

## Busca dos fundos e plano de processamento documental — 2026-11-11

- Busca dos fundos (`work_0022`): `src/intelligence/search_fund_reports.R`, com diretório de
  fundos em cache, filtros e linhas citadas do informe.
- Primeira área do Shiny em `prototype/` (`app.R`, `fund_search_module.R`) e
  `scripts/run_prototype.R`.
- `shiny` declarado no `DESCRIPTION`; `renv.lock` atualizado pelo setup offline. CI pré-instala
  `otel`, `bslib` e `shiny`.
- Novo teste `test_fund_reports_search.R` (49).
- Plano do processamento documental híbrido (MarkItDown, Markdown + Parquet + metadados):
  `docs/integration/hybrid_document_processing_plan.md`.

## Fundos consolidados e inventário de layouts — 2026-11-11

- Rodada completa da consolidação dos fundos: 102 arquivos, 12,16 milhões de linhas.
  Inventário de layouts e resumo de qualidade em `docs/data_dictionary.md`.
- CI: `scripts/ci_preinstall_locked.R` passa a usar o binário quando a versão travada ainda
  está no CRAN e inclui `cpp11` e `arrow`; limite do job em 60 minutos.

## Fase 1.3 iniciada e dados organizados por fonte — 2026-11-11

- Coleta dos fundos (FII, FIDC, FIP, FIAGRO; `decision_0029`):
  `src/collect/discover_fund_reports.R`, `src/collect/download_fund_reports.R` e
  `scripts/collect_fund_reports.R`. Fontes verificadas; 102 arquivos coletados.
- Consolidação dos fundos em Parquet com linhagem, CNPJ validado e registros de qualidade:
  `src/data/consolidate_fund_reports.R` e `scripts/consolidate_fund_reports.R`.
- Dados locais em uma pasta por família (`decision_0028`): `src/common/data_layout.R` e
  `scripts/organize_data_dir.R`.
- `write_parquet_validated` passou para `src/common/parquet_io.R`.
- CI: `scripts/ci_preinstall_locked.R` instala os pacotes travados sem binário de Windows a
  partir dos tarballs.
- Novos testes: `test_fund_reports_collection.R` (34), `test_data_layout.R` (27) e
  `test_fund_reports_consolidation.R` (29).

## Notas consolidadas em Parquet — 2026-11-11

- `src/data/consolidate_financial_notes.R` e `scripts/extract_financial_notes.R` gravam
  `financial_reports` e `financial_notes` em Parquet, uma parte por pacote, de forma
  incremental (`decision_0027`). 28 testes sintéticos
  (`tests/testthat/test_financial_notes_parquet.R`).
- `arrow` declarado no `DESCRIPTION`; `renv.lock` atualizado.
- Nomes de companhias cortados no catálogo da coleta contornados com o índice da CVM em
  Latin-1 (`risk_0016`).
- CI: pré-instalação de `curl`, `qpdf` e `pdftools` antes do `renv::restore`.
- O escritor de ZIP dos testes passou para `tests/testthat/helper_stored_zip.R`.

## Dependências da extração declaradas — 2026-11-11

- `DESCRIPTION` passa a declarar `pdftools`, `xml2` e `base64enc` (`decision_0026`).
- `renv.lock` atualizado por snapshot explícito, sem instalação nova.
- `scripts/setup_environment.R` lê os pacotes do campo `Imports`.

## Extração das notas e rotinas comuns — 2026-11-11

- Extração das notas (Fase 1.2) com seleção de conjuntos corrigida e títulos `(N)` como
  alternativa. Rodada local em 83 pacotes: 66 completos. 22 testes sintéticos
  (`tests/testthat/test_financial_notes.R`).
- Rotinas comuns em `src/common/` (`safe_io.R`, `signatures.R`, `execution_policy.R`), só com
  R base. 55 testes sintéticos (`tests/testthat/test_common_primitives.R`).
- O validador inclui os dois novos arquivos de teste.

## Fases reorganizadas — 2026-11-10

- O MVP passa a ter duas fases (`decision_0025`):
  - **Fase 1 — Coleta, estruturação e pesquisa de dados**, com as subfases 1.1 (Soluções de
    Consulta), 1.2 (notas explicativas) e 1.3 (fundos de investimento);
  - **Fase 2 — Inteligência cruzada** sobre as bases aceitas.
- Prompts, arquitetura, requisitos, registros, `AGENTS.md`, README, panorama e site atualizados.

## Fundos de investimento como nova fonte (Fase 4) — 2026-11-10

- Nova família `investment_fund_reports` (FII, FIDC, FIP e FIAGRO) com aceite próprio
  (`decision_0024`). Requisitos `req_0012`–`req_0014`; work items `work_0020`–`work_0023`.
- Listagens da CVM verificadas: `docs/data_sources.md`, `docs/source_inventory.md` e
  `config/investment_fund_report_sources.yml`.
- Novos prompts `collect_p05_investment_fund_report_acquisition.txt` e
  `data_p04_investment_fund_report_consolidation.txt`. O roteiro de todos os prompts passa a ter
  quatro fases.
- Arquitetura, requisitos, dicionário de dados, `AGENTS.md`, README, panorama e site
  atualizados.
- Análise de novas fontes de dados (`docs/integration/new_data_sources_gap_analysis.md`,
  `decision_0023`).

## Collect P01 e GitHub Pages — 2026-11-10

- Fontes verificadas: `docs/source_inventory.md`, `docs/feasibility.md`,
  `scripts/probe_sources.R` e fixture pública `tests/fixtures/normas_search_sample.json`.
- Aceites `acc_0004`–`acc_0008` registrados.
- Panorama publicado no GitHub Pages e linkado no README.

## Assistentes no RStudio — 2026-11-10

- Smoke test sintético corrigido e ampliado ao Claude Code; Codex, Claude Code e
  Gemini aprovados no terminal integrado do RStudio.
- Copilot com login ativo e sugestão aceita, confirmados pelo desenvolvedor.
- `work_0004`–`work_0007` implementados; aceite humano pendente.

## Recomendações da revisão aplicadas — 2026-11-10

- Aceitos `req_0003`, limiares e arquitetura (`acc_0003`).
- Licença MIT; CI mínimo de validação no Windows.
- `doit` passa a usar `.claude/doit.txt`; bloqueio de leitura de `tmp/` restaurado.
- Diretório renv por usuário criado; e-mail noreply para commits futuros.

## Revisão geral do projeto — 2026-11-10

- Prompts alinhados (títulos, fonte dupla, nomes en-US, fases e pós-MVP);
  detalhes em `prompts/CHANGELOG.md`.
- Registros: vocabulário `approved`, `acceptance_register.csv`, handoff enxuto
  com `handoff_history.md`, `risk_0010`, `decision_0013`, `work_0018`, `test_0020`.
- Arquitetura: propostas para fallback de IDs, identificadores de empresa,
  nível de evidência das relações, armazenamento e local do Shiny.
- Setup: `.gitattributes`; diagnóstico restrito às dependências declaradas.
- Exceção `doit` documentada em `AGENTS.md`/`CLAUDE.md`.

## Repositório público — 2026-11-10

- Tornada pública, por solicitação do usuário, a visibilidade de
  `amarallr/taxminer`; GitHub confirmou `private=false` e branch `main`.
- Registrado que metadados de autoria do histórico ficaram públicos e que a
  licença de distribuição continua indefinida.

## Correção do validador Windows — 2026-11-10

- O validador ajusta `LC_CTYPE` para UTF-8 dentro do processo R quando o locale
  herdado não é aceito pelo R do Windows; o comando direto passou com 5 checks.
- O helper do terminal RStudio deixou de limpar variáveis de ambiente externas.
- Permanecem visíveis avisos de inicialização de outras categorias de locale e
  do `testthat` compilado em uma versão mais nova de R.

## Revisão do ambiente — 2026-11-10

- Conferidos os caminhos por usuário de R, Git, GitHub CLI, Codex, Gemini CLI,
  Node.js e npm; corrigidas instruções vigentes que ainda apontavam para `.local/`.
- Registrada a falha do comando R com o locale herdado e a aprovação das cinco
  verificações após limpar variáveis regionais somente no processo filho.
- Registrada a ausência atual do destino de estado global renv configurado e a
  necessidade de o desenvolvedor verificar a sincronização da pasta OneDrive.
- Atualizados guias de ambiente, GitHub, retomada e painel. Nenhuma instalação,
  configuração persistente, autenticação, commit ou publicação ocorreu nesta revisão.

## Histórico — baseline do setup local (2026-11-10)

Os itens a seguir registram o estado inicial do setup e foram superados pelos
registros posteriores de aceite P02 e visibilidade pública.

- Criados os registros mínimos de governança e alinhados os prompts às três fases.
- Preparada a fundação local RStudio com dependências explícitas, bootstrap
  offline, teste sintético e regras de exclusão das áreas protegidas.
- Nenhum MVP, aceite humano do MVP ou release realizado naquele momento.
- Validado o ambiente R no terminal integrado do RStudio; registrada a limpeza
  regional apenas no processo de validação e preservadas as falhas anteriores.
- Preparado GitHub CLI portátil local com digest verificado e autenticação
  existente validada; revisada lista explícita para o primeiro commit.
  Naquele momento, identidade Git, commit e destino remoto permaneciam pendentes.
