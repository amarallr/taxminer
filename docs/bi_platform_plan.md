# Plataforma de BI dos informes de fundos — diagnóstico e plano

Resposta às instruções `.claude/panorama_melhorias.txt` (foco no Panorama) e
`.claude/especialista_ficha.txt` (foco nas fichas que detalham os fundos), que
têm o mesmo escopo CO-STAR. Conforme a instrução final das duas, este documento
é o **diagnóstico e o plano**; nenhuma alteração estrutural foi feita.
Levantamento de 2026-11-11 sobre os dados consolidados locais
(`processed/` da fonte `investment_fund_reports`) e o código da Fase 1.3.

## 1. Diagnóstico

### 1.1 Arquitetura atual

| Camada | Implementação | Observação |
|---|---|---|
| Coleta | `src/collect/` (ZIPs da CVM, manifesto, SHA-256) | estável |
| Curadoria | `processed/{família}/{tabela}/` em Parquet, uma pasta por tabela do leiaute, com `layout_version`, `reference_period`, `source_file`, `source_line` | rastreabilidade até a linha do arquivo original já existe |
| Dados mestres | `processed/master/` (resolução de entidades, `decision_0036`) | CNPJ como chave, histórico de denominações |
| Métricas | `processed/metrics/fund_period_metrics.parquet`: **só PL, ativo total e cotistas** por fundo e período | é o gargalo para quase todo o escopo pedido |
| Analytics | `src/intelligence/fund_analytics.R` (snapshot, ranking, HHI, séries) | em memória, R base |
| Apresentação | app Shiny local (`prototype/`) + exportação estática (`site/app/`) | sem React; JS próprio no painel publicado |

Stack: R 4.5, Shiny, bslib, arrow; sem DuckDB e sem dplyr no app (o pacote existe
na máquina, mas não é dependência declarada).

### 1.2 Funcionalidades: existentes, parciais e ausentes

| Item do escopo | Situação | Onde |
|---|---|---|
| Filtros com autocomplete, multisseleção, CNPJ com máscara, busca com/sem pontuação, denominações históricas, CNPJ como chave | **existente** | Fundos/abas por tipo, `entity_resolution.R` |
| Panorama: PL por tipo, top 20 administradores e fundos, filtro cruzado por família e administrador | **existente** | `fund_overview_ui` |
| Concentração (HHI, participação dos 5/10 maiores), ranking de administradores, série por administrador, drill por competência | **existente** | Administradores |
| Perfil do fundo: PL, variação 12 meses, cotistas, posição e percentil | **existente** | Perfil |
| Ficha: leitura de cada tabela do informe por competência, com rótulos do dicionário | **parcial**: mostra os valores, sem análise por ficha; aba Ficha própria no app e Ficha/Série completa das tabelas principais no painel publicado (`decision_0037`) | aba Ficha |
| Competência, universo e cobertura nos KPIs | **parcial**: mês de referência e meses completos; sem regra de agregação explícita | Panorama, Cobertura |
| Camada semântica / catálogo de métricas | **ausente** | — |
| Ativo, passivo, carteira, DC, inadimplência, captações, resgates, amortizações, rentabilidade | **ausente** nas métricas (os campos existem nas tabelas) | ver 1.3 |
| Faixas de PL, evolução da quantidade de fundos, comparação entre competências | **ausente** | — |
| Breadcrumbs, estado na URL, filtros salvos | **ausente** | — |
| Painéis analíticos por ficha do FIDC (I a X) | **ausente** | — |
| Explorador universal de fichas, comparador, laboratório de séries, anomalias, relacionamentos, construtor, narrativas | **ausente** | — |
| Gestor | **ausente nos dados**, salvo FIAGRO | ver 1.4 |

### 1.3 Dados disponíveis (verificados)

**FIDC, informe mensal**: 18 tabelas, 2013 a 2026-10. Cada uma tem **três
leiautes** (por exemplo, a Ficha I: 2013–2019, 2019–2020 e 2020 em diante,
5.846 CNPJs no último).

| Ficha | Tabela | Campos de interesse (exemplos reais) |
|---|---|---|
| I Ativo | `tab_I` (77 col.) | `TAB_I_VL_ATIVO`, `TAB_I1_VL_DISP`, `TAB_I2_VL_CARTEIRA`, `TAB_I2A_VL_DIRCRED_RISCO`, `TAB_I2A2_VL_CRED_VENC_INAD`, `TAB_I2A3_VL_CRED_INAD`, `TAB_I2B_VL_DIRCRED_SEM_RISCO`; também `CONDOM`, `FUNDO_EXCLUSIVO`, `COTST_INTERESSE`, administrador e **CPF/CNPJ dos cedentes** (`TAB_I2B1_CPF_CNPJ_CEDENTE_n`, `TAB_I2B1_PR_CEDENTE_n`) |
| II Carteira por segmento | `tab_II` (46) | `TAB_II_VL_CARTEIRA`, industrial, imobiliário, comercial (varejo, arrendamento), serviços, agronegócio, financeiro (consignado, veículos…), factoring, setor público (precatórios, tributário), judicial, marca |
| III Passivo | `tab_III` (22) | `TAB_III_VL_PASSIVO`, a pagar CP/LP, derivativos |
| IV PL | `tab_IV` (15) | `TAB_IV_A_VL_PL`, `TAB_IV_B_VL_PL_MEDIO` |
| V e VI Prazo e inadimplência (com e sem aquisição de riscos) | `tab_V`, `tab_VI` (46) | a vencer, inadimplentes e antecipados em 10 faixas de prazo (30 a >1080 dias) |
| VII Negócios no mês | `tab_VII` (38) | quantidade e valor adquiridos (com e sem risco), cedentes, prestadores, terceiros, substituições, recompras |
| VIII 25 maiores devedores | `tab_VIII` (2,77 mi linhas) | `SEQUENCIAL`, `VALOR`, `TP_FUNDO_CLASSE`; **sem identificação do devedor** |
| IX Taxas | `tab_IX` (85) | taxas mínima, média e máxima de compra e venda por modalidade |
| X Outras informações | `tab_X` (desde 2023): risco SCR por devedor/operação AA–H, débito tributário; `X_1` cotistas por classe/série; `X_2` cotas; `X_3` rentabilidade no mês por série; `X_4` captações, resgates, resgates solicitados e amortizações; `X_5` liquidez; `X_6` desempenho esperado × real; `X_7` | |

**FII**: mensal (geral, complemento, ativo/passivo), trimestral e anual, de 2016
em diante. O complemento traz cotistas por tipo, ativo, PL, rentabilidade
efetiva e patrimonial, dividend yield e amortização. O ativo/passivo traz a
composição completa e o total do passivo.

**FIP**: trimestral (2010 a 2023) e quadrimestral, com PL, cotistas por tipo,
capital comprometido, subscrito e integralizado, e `ENTID_INVEST`.

**FIAGRO**: mensal desde 2025-05, com 143 colunas, incluindo **gestor**
(`Nome_Gestor`, `CNPJ_Gestor`) e subclasses.

### 1.4 Problemas e restrições identificados

1. **Métricas estreitas.** O modelo derivado tem 3 indicadores. Tudo o que o
   escopo pede além disso depende de ampliar a camada de métricas, e não a
   interface.
2. **Mudança de leiaute.** São 3 versões por ficha do FIDC e 2 a 3 no FII. Um
   campo pode mudar de significado ou de nome; a comparação entre leiautes
   precisa de um mapeamento explícito com período de validade.
3. **Granularidade mista.** `X_1`, `X_2`, `X_3` e `X_6` vêm por classe/série;
   `VIII` vem por fundo ou classe (`TP_FUNDO_CLASSE`). Somar séries ou juntar
   com fichas por fundo duplica valores.
4. **Dados pessoais.** A Ficha I tem CPF de cedentes pessoa física. Isso exige
   decisão própria (LGPD): no mínimo, não publicar no site e mascarar no app.
5. **Gestor e sacados.** O gestor só existe no FIAGRO. Na Ficha VIII os
   devedores não são identificados. Portanto, "relações com sacados" e
   "filtro por gestor" não são possíveis para FIDC, FII e FIP com as fontes
   atuais.
6. **Qualidade de categorias.** Exemplo: `CONDOM` tem `FECHADOO`, `0`, `NA` e
   vazio. Filtros categóricos precisam de normalização documentada, sem
   alterar o valor publicado.
7. **Desempenho e memória.** `VIII` (2,8 mi linhas) e `X_4` (2,5 mi) não cabem
   na estratégia atual de carregar tudo na memória do app. Nesta sessão o
   sistema encerrou processos R por falta de memória. Pré-agregações em
   Parquet são necessárias antes de qualquer tela sobre essas fichas.
8. **Estoque × fluxo.** PL, ativo e carteira são estoques: somam entre fundos
   na mesma competência, nunca entre competências. Captações e resgates são
   fluxos mensais. Taxas, rentabilidade e percentuais não são aditivos. Hoje
   essa regra está implícita no código, sem catálogo.

## 2. Arquitetura proposta

Reaproveitar o stack atual (R, arrow, Shiny, JS próprio no painel publicado),
**sem novas dependências** neste ciclo.

```
processed/{família}/{tabela}  (curadoria, inalterada)
        │  catálogo semântico: config/metric_catalog.csv
        ▼
processed/metrics/fund_indicators.parquet   (fundo × competência × indicador, longo)
processed/metrics/fund_class_indicators.parquet (classe/série, quando houver)
processed/metrics/aggregates/*.parquet      (pré-agregações por família/mês, faixas, top-N)
        ▼
src/intelligence/  (consultas que respeitam a regra de agregação do catálogo)
        ▼
app Shiny (Panorama, Administradores, Fundos, Fichas)  +  site/app (JSON)
```

**Catálogo semântico** (`config/metric_catalog.csv`, versionado como o
dicionário de regras de nomes), com uma linha por indicador e versão de leiaute:
`metric_id`, nome, descrição, família, ficha, tabela, campo de origem,
`layout_version` ou período de validade, tipo, unidade, granularidade (fundo ou
classe/série), `aggregation` (`stock_sum_same_period`, `flow_sum`, `none`,
`weighted_mean`), tratamento de ausência (nunca zero implícito), fórmula
(derivados como inadimplência ÷ carteira, com denominador > 0 obrigatório) e
restrições de comparação. A construção recusa uma agregação que o catálogo não
permite. Testes cobrem a regra.

DuckDB só seria avaliado se as pré-agregações em arrow não bastarem; isso
exigiria uma decisão registrada, porque é dependência nova.

## 3. Plano incremental

Cada entrega tem testes (`validate_environment.R`), registro e aceite humano.
Só a primeira entrega começa após autorização.

| # | Entrega | Depende de | Critério de aceite |
|---|---|---|---|
| **P0.1** | Catálogo semântico + `fund_indicators` para FIDC (Fichas I, II, III, IV, V, VI, VII, X_4), FII mensal (complemento, ativo/passivo) e FIAGRO; mapeamento por leiaute | — | totais por competência conferem com as tabelas de origem; nenhuma soma entre competências; ausência ≠ zero; testes de leiaute, competência duplicada, negativo, divisão por zero |
| **P0.2** | Pré-agregações (família × mês; faixas de PL; quantidade de fundos; top-N) e normalização documentada de `CONDOM` e `FUNDO_EXCLUSIVO` | P0.1 | memória do app não cresce; Panorama abre em ≤ 1 s após a carga |
| **P1.1** | **Panorama**: KPIs com competência, universo, cobertura e regra; ativo agregado; fundos por tipo e exclusivos; faixas de PL; evolução da quantidade de fundos; comparação entre duas competências; breadcrumb e estado na URL (app e site) | P0.2 | cada KPI mostra a regra; filtros sobrevivem a recarregar a página; regressão do Panorama atual |
| **P1.2** | **Fichas do FIDC no detalhe do fundo**: uma visão por ficha (I composição do ativo, II segmentos empilhados, III passivo, IV PL × PL médio, V/VI prazo e inadimplência por faixa, VII negócios, VIII concentração dos 25 maiores sobre a carteira, IX taxas mínima/média/máxima, X cotistas, rentabilidade por série, captações/resgates/amortizações, liquidez, desempenho) com tooltip e link à linha de origem | P0.1 | cada valor rastreia `source_file`/`source_line`; séries por classe não somadas; ordenação I, II, …, X_1, X_1_1 |
| P1.3 | Explorador universal de fichas (família → fundo(s) → ficha → indicador → período → gráfico sugerido pelo tipo) | P1.2 | gráfico incompatível não é oferecido |
| P2 | Comparador (base 100, percentis, pares do mesmo tipo e porte), laboratório de séries (médias móveis, quebras de leiaute sinalizadas, sem interpolação), sinais de anomalia (mediana/MAD, IQR, regras) com evidência e limitações | P1.x | todo alerta é "sinal", com método, período, universo e explicações alternativas |
| P3 | Construtor de análises, narrativas determinísticas, exportações | P2 | — |

Fora do alcance com as fontes atuais: gestor (salvo FIAGRO), identificação de
sacados, grupos econômicos e cotistas nominais. Relacionamentos entre fundos
ficam restritos a administrador comum e, sujeito a decisão LGPD, a cedentes
pessoa jurídica.

## 4. Riscos

| Risco | Mitigação |
|---|---|
| Campo muda de sentido entre leiautes | mapeamento por `layout_version` no catálogo; descontinuidade sinalizada no gráfico |
| Duplicação por granularidade classe/série | tabelas separadas por granularidade; teste de totais antes e depois das junções |
| Memória (fichas com milhões de linhas) | pré-agregação em disco; leitura sob demanda com arrow |
| CPF de cedentes | decisão LGPD antes de qualquer uso; nunca no site publicado |
| Peso do site publicado (hoje cerca de 25 MB) | JSON por demanda; fichas detalhadas só no app local |
| Leitura de anomalia como irregularidade | rótulos "sinal" e "hipótese", explicações alternativas e revisão humana (regra do projeto) |

## 5. Decisões pedidas

1. Autorizar **P0.1** (catálogo semântico e indicadores ampliados), base de
   tudo o mais.
2. Ordem depois de P0: **P1.1 Panorama** e **P1.2 fichas FIDC** (as duas
   instruções), em sequência ou em paralelo.
3. ~~Tratamento dos CPFs de cedentes na Ficha I~~ — **decidido (`decision_0038`):** CPF
   completo, como publicado pela CVM, com máscara de formatação, no app e no painel publicado.
