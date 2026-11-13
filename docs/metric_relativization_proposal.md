# Métricas relativizadas na aba Distribuições — proposta

Situação: **proposta**, não implementada. Origem: pedido do usuário de 2026-11-13, executado pelo prompt
`.claude/sugestao_metricas_relativas.txt`. As regras legíveis por máquina estão em
`config/metric_ratio_rules.csv`.

## 1. Por que relativizar

A aba Distribuições compara o valor do fundo com o dos demais fundos da mesma família na mesma
competência. Em valores absolutos (R$), essa comparação mede sobretudo o **porte**: um FIDC de R$ 5 bi
fica no P99 de quase todos os campos, sem dizer nada sobre a composição da carteira. Por isso foi preciso
usar a escala log.

Com razões, a pergunta muda de "quanto o fundo tem" para "como o fundo é feito". Exemplos: "que parte
do ativo está inadimplente", "quanto do PL vem de direitos creditórios", "quanto do capital subscrito
já foi integralizado". Isso é a análise vertical (common-size) da contabilidade. Ela torna comparáveis
fundos de tamanhos diferentes e expõe estruturas atípicas, que são as que interessam à fiscalização.

**Avaliação da proposta do usuário: adequada, com três ajustes.**

1. **Total da tabela sobre o PL e itens sobre o total da tabela** (como nos exemplos). Somar todos os
   itens sobre o mesmo total, e não sobre o "pai" imediato, mantém as razões aditivas e comparáveis
   entre níveis da hierarquia. Nos dados, I.1 + I.2 + I.3 + I.4 = Ativo (razão mediana 1,0000).
2. **Alguns campos pedem um denominador analítico**, porque medem risco e não composição. A
   inadimplência, por exemplo, deve ser medida sobre os direitos creditórios, e não sobre o ativo
   (um fundo com 90% em títulos públicos dilui a inadimplência se o denominador for o ativo).
3. **Manter o valor absoluto acessível**: um seletor "Relativo | Absoluto" na aba Distribuições. O padrão
   é Relativo; o hint mostra também o valor em R$ e os dois termos da razão.

## 2. Regras gerais

| Tipo de campo | Exibição padrão | Observação |
|---|---|---|
| Total de tabela (R$) | total / PL | Ex.: (Tabela I) Ativo / PL = alavancagem bruta |
| Item da hierarquia (R$) | item / total da tabela | Ex.: (I.2.a.1) / (Tabela I) Ativo |
| Provisões (-) | valor absoluto / base que provisionam | Sinal invertido para leitura ("provisão de 3%") |
| Fluxo do mês (R$) | fluxo / PL (ou / estoque correspondente) | Captações, resgates, aquisições, recompras |
| Contagem por categoria | categoria / total de cotistas | Número de cotistas por tipo |
| Percentual ou taxa publicada | mantém | Não relativizar de novo |
| Valor da cota, quantidade de cotas | mantém | Já são unitários; o total de cotas fica em absoluto |
| Identificador ou texto | fora | CNPJ, nomes, datas |

**Bordas** (vale para todas as fichas):

- **Denominador ≤ 0 ou ausente:** razão indefinida. O fundo sai da distribuição daquele campo, e o hint
  diz "PL ≤ 0: razão não calculada" ou "Ativo = 0". No FIDC, cerca de 2,7% das linhas têm PL ≤ 0 e
  2,5% têm Ativo = 0. No FIP, 3,4% das linhas têm PL ≤ 0. São muitos casos para ignorar, então o hint
  da distribuição informa quantos fundos ficaram de fora.
- **Numerador e denominador ambos zero:** fundo sem a rubrica. A razão é 0 e entra na distribuição.
- **Razões acima de 100%:** legítimas (alavancagem, derivativos, capital subscrito maior que o PL) e
  exibidas como são. A escala asinh e a winsorização continuam valendo.
- **Mesma versão e mesma competência:** numerador e denominador vêm da mesma linha lógica (fundo ou
  classe, competência, versão mais recente). Não se mistura versão retificada com original.
- **Escala:** razões limitadas a [0, 1] ficam em escala linear (já são comparáveis). Razões não
  limitadas, como total/PL e fluxo/PL, mantêm a escala asinh.

## 3. Regras por ficha

### FIDC — informe mensal

PL: `inf_mensal_fidc_tab_IV.TAB_IV_A_VL_PL` (junção por CNPJ do fundo ou classe, competência e versão).

| Tabela | Padrão | Denominador analítico adicional |
|---|---|---|
| I — Ativo | `TAB_I_VL_ATIVO` / PL; itens I.x / `TAB_I_VL_ATIVO` | Inadimplência (I.2.a.2, I.2.a.2.1, I.2.a.3) / `TAB_I2A_VL_DIRCRED_RISCO`; idem para I.2.b / `TAB_I2B_VL_DIRCRED_SEM_RISCO`. Provisões I.2.a.11 e I.2.b.11 sobre o DC correspondente. `TAB_I2A12_PR_CEDENTE_*` já é percentual: mantém |
| II — Carteira por segmento | `TAB_II_VL_CARTEIRA` / PL; segmentos / `TAB_II_VL_CARTEIRA` | Concentração: maior segmento / total (índice de Herfindahl sugerido em §4) |
| III — Passivo | `TAB_III_VL_PASSIVO` / PL; itens / `TAB_III_VL_PASSIVO` | — |
| IV — PL | PL: mantém em absoluto (porte); PL médio 3m / PL | Variação do PL já existe no catálogo |
| V e VI — Prazo, inadimplência e antecipação | Faixas a vencer / `TAB_V_A_VL_DIRCRED_PRAZO`; faixas inadimplentes / `TAB_V_B_VL_DIRCRED_INAD`; faixas antecipadas / `TAB_V_C_VL_DIRCRED_ANTECIPADO` (VI: mesmos campos com `TAB_VI_`) | Inadimplência da carteira = V.b / (V.a + V.b); inadimplência acima de 90 dias = soma de V.b.4 a V.b.10 / (V.a + V.b) |
| VII — Aquisições, alienações, substituições, recompras | Valores / `TAB_I2A_VL_DIRCRED_RISCO` + `TAB_I2B_VL_DIRCRED_SEM_RISCO` (giro da carteira) | Recompras / aquisições; substituições / aquisições; ágio ou deságio = (valor − valor contábil) / valor contábil |
| IX — Taxas | Mantém (já são taxas) | — |
| X — SCR e débitos tributários | Classes AA a H / soma das classes (devedor e operação, separadamente); `TAB_X_DEBITO_TRIBUT` / DC total | Parcela D–H (risco alto) |
| X_1 e X_1_1 — Cotistas | Total mantém; categorias / `TAB_X_NR_COTST` (sênior e subordinada, separadamente) | — |
| X_2 — Cota | `TAB_X_VL_COTA` mantém; `TAB_X_QT_COTA` × `TAB_X_VL_COTA` / PL por classe/série | **Subordinação** = PL das subordinadas / PL total |
| X_3 — Rentabilidade | Mantém | — |
| X_4 — Captações, resgates, amortizações | `TAB_X_VL_TOTAL` / PL, por tipo de operação | — |
| X_5 — Liquidez | Faixas / PL | — |
| X_6 e X_7 | Percentuais mantêm; `TAB_X_VL_GARANTIA_DIRCRED` / DC total | — |

### FII — informe mensal

PL e ativo: `inf_mensal_fii_complemento.Patrimonio_Liquido` e `.Valor_Ativo` (junção por CNPJ,
competência e versão).

| Tabela | Padrão | Adicional |
|---|---|---|
| ativo_passivo | Itens de ativo (Imóveis, CRI, LCI, cotas de fundos, títulos etc.) / `Total_Investido`; `Total_Investido` / `Valor_Ativo`; necessidades de liquidez (Disponibilidades, Títulos públicos, Fundos de renda fixa) / `Total_Necessidades_Liquidez`; `Total_Necessidades_Liquidez` / PL; itens de passivo / `Total_Passivo`; `Total_Passivo` / PL | Parcela "papel" = (CRI + CRI_CRA + LCI + LCI_LCA + LIG + Letras_Hipotecarias) / `Total_Investido`; parcela "tijolo" = (Imóveis + Terrenos + Direitos_Bens_Imoveis) / `Total_Investido` |
| complemento | Percentuais mantêm; cotistas por tipo / `Total_Numero_Cotistas`; `Valor_Ativo` / PL; PL mantém (porte) | Parcela de pessoas físicas (relevante para a isenção de rendimentos de FII a PF, como dado descritivo) |
| geral | `Quantidade_Cotas_Emitidas` mantém | — |

### FII — informe trimestral

PL: complemento mensal do último mês do trimestre.

| Tabela | Padrão |
|---|---|
| resultado_contabil_financeiro | Receitas e despesas (contábil e financeiro, separadamente) / `Total_Receitas_Despesas_*` do mesmo regime; `Resultado_Trimestral_Liquido_*` / PL; `Rendimentos_Declarados` / `Resultado_Financeiro_Liquido_Acumulado` (taxa de distribuição; o mínimo legal é 95% do resultado semestral apurado pelo regime de caixa) |
| complemento | Percentuais de vencimento e indexador mantêm; `Ativo_Liquidez_Valor_*` / PL |
| imovel, terreno, alienação, aquisição, inquilino | Percentuais mantêm; `Numero_Unidades` mantém |
| ativo, direito | `Valor` / `Total_Investido` do mês de referência |

### FII — informe anual

| Tabela | Padrão |
|---|---|
| distribuicao_cotistas | Percentuais mantêm; `Numero_Cotistas_Faixa_*` / soma das faixas. **Concentração:** cotas detidas acima de 10% do total |
| ativo_valor_contabil | `Valor_Justo` / `Valor` − 1 (reavaliação); percentual mantém |
| complemento, geral | Percentuais mantêm; valores pagos / PL do fim do exercício |

### FIP — informe trimestral (até 2023) e quadrimestral (desde 2024)

Tudo está na mesma linha por classe, sem junção.

| Campo | Padrão | Observação |
|---|---|---|
| `VL_CAP_COMPROM`, `VL_CAP_SUBSCR`, `VL_CAP_INTEGR` | / `VL_PATRIM_LIQ` (proposta do usuário) | De P10 a P90 nos dados: subscrito/PL de 0,16 a 9,2; integralizado/PL de 0,15 a 3,6. A cauda é longa, então a escala asinh continua |
| Integralização | `VL_CAP_INTEGR` / `VL_CAP_SUBSCR` (limitada a [0, 1]) | Mediana 1,0; o P10 é 0,24, o que mostra capital ainda por chamar |
| Valorização do capital | `VL_PATRIM_LIQ` / `VL_CAP_INTEGR` (múltiplo sobre o capital investido) | Equivale ao RVPI do private equity. Não inclui amortizações já distribuídas, então subestima o retorno de fundos que já devolveram capital |
| `VL_INVEST_FIP_COTA` | / PL | Estrutura em camadas (FIP de FIP) |
| Cotistas por categoria `NR_COTST_SUBSCR_*` | / `NR_TOTAL_COTST_SUBSCR` | `PR_COTA_SUBSCR_*` já é percentual: mantém |
| `QT_COTA_INTEGR` | / `QT_COTA_SUBSCR` | Confere com a razão em valor |
| `VL_PATRIM_COTA`, `VL_QUOTA_CLASSE` | Mantém | Preço unitário |

Atenção: os campos de capital podem ser declarados para o fundo e repetidos em cada classe. A junção
deve usar a mesma linha (classe) do PL, sem somar classes.

### FIAGRO — informe mensal

Tudo está na mesma tabela.

| Grupo | Padrão |
|---|---|
| `Valor_Ativo`, `Total_Passivo` | / `Patrimonio_Liquido` |
| Ativos (CRA, CPR, CDCA, LCA, direitos creditórios, imóveis rurais, participações etc.) | / `Total_Investido` |
| `A_Vencer_*` | / `A_Vencer`; `Vencidos_*` / `Vencidos` |
| Inadimplência | `Vencidos` / (`A_Vencer` + `Vencidos`) |
| Passivo (taxas a pagar, rendimentos a distribuir, obrigações) | / `Total_Passivo` |
| Cotistas por tipo | / `Numero_Cotistas` |
| Percentuais e rentabilidades | Mantêm |

## 4. Métricas analíticas sugeridas (descritivas, sem conclusão fiscal)

| Família | Métrica | Fórmula | Leitura |
|---|---|---|---|
| FIDC | Subordinação | PL das classes subordinadas / PL | Colchão de proteção da classe sênior |
| FIDC | Inadimplência acima de 90 dias | Soma de V.b.4 a V.b.10 / (V.a + V.b) | Qualidade do crédito |
| FIDC | Cobertura de provisão | (−I.2.a.11) / I.2.a.3 | Provisão sobre o inadimplente |
| FIDC | Recompra pelo cedente | VII.d.2 / VII.a.1.2 | Coobrigação de fato |
| FIDC | Concentração por segmento | Σ (segmento / carteira)² (Herfindahl) | De 1/n a 1 |
| FII | Distribuição sobre o resultado | Rendimentos declarados / resultado financeiro líquido | Comparar com o mínimo de 95% (descritivo) |
| FII | Parcela papel × tijolo | Ver ficha mensal | Perfil do fundo |
| FII | Concentração de cotistas | Cotas detidas acima de 10% / total | Relevante para as condições da isenção a PF (descritivo) |
| FIP | Integralização | Integralizado / subscrito | Ciclo de vida do fundo |
| FIP | Múltiplo sobre o capital | PL / integralizado | Valorização acumulada |
| FIAGRO | Inadimplência | Vencidos / (a vencer + vencidos) | Qualidade do crédito |
| FIAGRO | Lastro em crédito agro | (CRA + CPR + CDCA + LCA + direitos creditórios) / Total_Investido | Perfil |

## 5. Implementação proposta (requer autorização)

1. `config/metric_ratio_rules.csv` passa a ser a fonte única das regras e é validado por teste: todo
   campo citado existe no dicionário META e todo denominador existe na tabela indicada.
2. `fund_peer_summaries` recebe as razões antes do resumo, usando os mesmos 101 quantis, a mesma
   winsorização e o mesmo z robusto. O denominador entre tabelas é lido pelo `fund_peer_cache` com a
   chave fundo, competência e versão.
3. A aba Distribuições ganha o seletor "Relativo | Absoluto"; o rótulo mostra "(I.2.a.1) / Ativo". O hint
   traz o valor da razão, os dois termos em R$ e quantos fundos ficaram de fora por denominador inválido.
4. A exportação estática gera os arquivos de pares das razões (`data/peers/{família}/{tabela}/rel/...`).
   O tamanho estimado fica próximo do atual, pois o número de campos é o mesmo.
5. Testes: razões com denominador zero, negativo e ausente; aditividade (soma dos itens = 1 ± arredondamento);
   junção entre tabelas sem mistura de versões; equivalência entre app e site.

**Critérios de aceite:** toda razão tem regra no CSV; nenhum campo inventado; bordas tratadas e
informadas no hint; os valores absolutos continuam acessíveis; app e site iguais; a suíte de testes passa.
