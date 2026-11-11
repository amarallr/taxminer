# Resolução de entidades e normalização de denominações

Serviço central, determinístico e auditável que separa três conceitos em todo
o TaxMiner:

| Conceito | Chave | Onde vive |
|---|---|---|
| **Identidade cadastral** | `entity_id` = tipo + CNPJ canônico | `entities` |
| **Denominação** | `name_id` = entidade + grupo de nomes equivalentes | `entity_names` |
| **Representação textual** | o nome exatamente como publicado | `name_history` (`original_name`) |

Código: `src/data/entity_resolution.R`. Dicionário de regras:
`config/entity_name_rules.csv`. Testes: `tests/testthat/test_entity_resolution.R`
(work_0028, decision_0036).

## 1. Camadas

| Camada | No TaxMiner | Efeito da resolução |
|---|---|---|
| RAW | ZIPs da CVM em `raw/` | nenhum: nada é alterado |
| CURATED | tabelas consolidadas em `processed/{família}/` com `fund_cnpj_original` e `fund_cnpj_normalized` | nenhum: valores e nomes como publicados |
| MASTER DATA | `processed/master/` (este serviço) | catálogos de entidades, denominações, histórico, revisão e qualidade |
| ANALYTICS | diretório de busca, métricas, Panorama, Administradores | chaves `entity_id`; nomes do catálogo |
| PRESENTATION | app Shiny e exportação estática | filtros e listas consomem o catálogo; CNPJ com máscara |

Os catálogos são construídos a partir do diretório de fundos
(`processed/search/fund_directory.parquet`), que agrega as tabelas
consolidadas e cita o informe mais recente de cada combinação. A construção
fica em cache e só é refeita quando mudam o diretório, o dicionário ou o
código (assinatura em `entity_master_index.rds`): é idempotente.

## 2. CNPJ

- Guardado sempre como texto; zeros à esquerda preservados (valores numéricos
  que os perderam são completados antes da validação).
- `normalize_cnpj` (em `src/data/consolidate_fund_reports.R`, a única
  implementação) valida os dígitos verificadores, inclusive para CNPJ
  alfanumérico (valor de cada caractere = código ASCII − 48).
- `format_cnpj` aplica a máscara `00.000.000/0000-00` a CNPJs válidos; um
  valor inválido aparece como publicado, nunca disfarçado.
- Busca aceita CNPJ com ou sem máscara e prefixos (a partir de 4 caracteres).
- CNPJ inválido no dado publicado vira uma entidade própria
  (`tipo:raw:CARACTERES`, `key_basis = invalid_cnpj`), sinalizada; não se
  tenta adivinhar o CNPJ correto.
- `registration_status` registra só a validade dos dígitos verificadores
  (`valid_check_digits`, `invalid_check_digits`, `missing`). A situação
  cadastral na Receita Federal não é consultada.

## 3. Normalização de denominações

Ordem de aplicação, toda versionada no dicionário:

1. `struct_fold`: caixa alta, sem acentos nem marcas combinantes Unicode,
   pontuação vira espaço, espaços repetidos removidos.
2. `struct_acronym_join`: siglas soletradas (S.A., S/A, C.C.V.M.) unidas
   (SA, CCVM).
3. Regras de expressão (`rule_type` `abbreviation` ou `spelling`), da mais
   longa para a mais curta, só no contexto indicado (`fund`,
   `administrator` ou `all`). Exemplos: Fundo de Investimento em Direitos
   Creditórios → FIDC; Fundo de Investimento Imobiliário → FII; Distribuidora
   de Títulos e Valores Mobiliários → DTVM; Responsabilidade Limitada → RL.
4. Chave de comparação: `struct_redundant_type_acronym` (sigla de tipo
   repetida no mesmo nome) e `struct_token_order` (mesmas palavras em outra
   ordem).

Dois nomes do **mesmo CNPJ** com a mesma chave de comparação formam uma
denominação. Nomes de CNPJs diferentes nunca se unem: coincidências viram
o relatório de homônimos (`name_collisions`).

O nome exibido de cada denominação é a forma publicada mais curta do grupo
(empate: a mais recente). O nome exibido da entidade é o da denominação
observada por último.

### Equivalência versus diferença significativa

- **Equivalente**: só por uma regra ativa do dicionário (caixa, acento,
  pontuação, sigla reconhecida, ordem das palavras).
- **Diferente**: tudo o mais. Palavras que podem distinguir classe, regime
  ou situação (RL, Multiestratégia, IE, Em Liquidação, números) nunca são
  removidas.
- **Ambíguo**: pares de denominações do mesmo CNPJ em que uma contém todas as
  palavras da outra (`token_subset`) ou com grafia muito próxima
  (`near_spelling`, distância de edição ≤ 15%). Ficam separados e vão para
  `name_review` com `status = pending_review`. Nenhuma IA decide equivalências.

## 4. Catálogos (`processed/master/`)

Nomes de colunas em inglês (regra do projeto); a correspondência com os nomes
sugeridos no requisito está entre parênteses.

**entities**: `entity_id` (id_entidade), `entity_type` (tipo_entidade:
`fund` ou `administrator`), `cnpj_canonical` (cnpj_canonico),
`cnpj_formatted` (cnpj_formatado), `cnpj_original`, `registration_status`
(status_cadastral), `key_basis`, `display_name`, `current_name_id`,
`name_count`, `reference_source` (fonte_referencia),
`first_observed_period`, `last_observed_period`, `updated_at`
(dt_atualizacao). Único por `entity_id`.

**entity_names**: `name_id` (id_denominacao), `entity_id`, `entity_type`,
`cnpj_canonical`, `normalized_name` (nome_normalizado), `comparison_key`,
`display_name` (nome_exibicao), `normalization_criteria`
(criterio_normalizacao: regras aplicadas), `rule_version` (versao_regra),
`variant_count`, `first_observed_period`, `last_observed_period`,
`validation_status` (status_validacao: `single_form` ou
`rule_equivalence`), `needs_review`. Único por (`entity_id`,
`comparison_key`).

**name_history**: `entity_id`, `name_id`, `original_name` (nome_original),
`source` (fonte_dados: família), `first_observed_period`
(dt_primeira_observacao), `last_observed_period` (dt_ultima_observacao),
`observed_periods`, `valid_from` / `valid_to` (dt_inicio/fim_vigencia:
**sempre vazios**; a data de observação no informe não é a data jurídica da
denominação), `source_file`, `source_line`.

**name_review**, **name_collisions**, **quality**: fila de revisão,
homônimos e relatório quantitativo.

**Dicionário** (`config/entity_name_rules.csv`): `rule_id`, `pattern`
(expressao_original), `replacement` (expressao_normalizada), `rule_type`
(tipo_regra), `context` (contexto_aplicacao), `rule_version`,
`validation_status` (`active` aplica; qualquer outro valor desativa),
`rationale` (justificativa). A versão do dicionário (`rule_version` nos
catálogos) é o hash das regras ativas: qualquer mudança gera nova versão e
reconstrução. Alterações passam pelo Git.

## 5. Consulta

- Opções de filtro: uma por denominação, `CNPJ formatado — denominação`;
  o mesmo CNPJ aparece em várias opções quando tem denominações diferentes.
- O valor da opção é o `name_id`; a busca o converte no `entity_id` (e daí
  no CNPJ) antes de consultar. **Qualquer denominação recupera todo o
  histórico do CNPJ.** Seleções múltiplas são deduplicadas por entidade.
- Texto livre: CNPJ (com ou sem máscara), nome atual, nome anterior, forma
  normalizada ou abreviada.
- A lista de resultados tem uma linha por fundo e família; o detalhe do
  fundo traz a aba **Denominações** (`entity_name_timeline`): consulta
  temporal separada, que mostra quando e onde cada nome foi observado, sem
  alterar o comportamento dos filtros.
- Administradores: agrupados pelo CNPJ; nomes iguais ao do fundo (erro
  conhecido em informes FIAGRO) são descartados e contados no relatório.

## 6. Integridade

Os catálogos nunca são unidos às tabelas financeiras por denominação. A
ligação é sempre entidade 1:1 (`entity_id`), o que impede multiplicação de
linhas; os testes verificam totais antes e depois da junção.

## 7. Primeira execução (dados reais, 2026-11-11)

Relatório `processed/master/quality.parquet` gerado pela rodada local
(`rule_version` 367725858f55):

| Indicador | Valor |
|---|---|
| Fundos (CNPJ) | 11.650 |
| Fundos com mais de um nome publicado | 1.601 |
| Grafias absorvidas por equivalência (fundos) | 591 |
| Fundos que seguem com denominações diferentes | 1.400 |
| Administradores (CNPJ) | 156 (49 com CNPJ inválido no dado publicado) |
| Grafias absorvidas por equivalência (administradores) | 114 |
| Pares em revisão (contém / grafia próxima) | 1.209 / 114 |
| Grupos de homônimos (CNPJs diferentes, mesmo nome) | 110 |
| CNPJs de fundo em mais de uma família | 227 |
| Duplicidades de chave | 0 |

## 8. Limitações e pendências

- **Granularidade**: nos informes posteriores à Resolução CVM 175, o CNPJ
  informado pode ser o do fundo ou o da classe. A entidade `fund` representa
  o CNPJ como publicado (fundo ou classe); subclasses e gestores não estão
  nas fontes atuais.
- **Fontes cobertas**: informes de fundos (Fase 1.3). As demonstrações
  financeiras (DFP, Fase 1.2, incremento 4) ainda não usam o serviço; devem
  usar `entity_key("company", ...)` quando forem consolidadas.
- **Revisão humana**: a fila `name_review` não tem ainda tela de decisão;
  aprovar um par exige uma regra nova ou uma exceção no dicionário.
- **Situação cadastral**: não há consulta à Receita Federal; só validade dos
  dígitos.
- **Desempenho**: construção completa em poucos segundos sobre o diretório
  (cerca de 30 mil observações); recarga do cache em menos de 1 s.
