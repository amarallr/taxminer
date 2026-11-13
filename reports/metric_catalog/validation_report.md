# Catálogo de métricas: relatório de validação

Gerado em 2026-11-13 09:22 por `scripts/validate_metric_catalog.R`.

Métricas: 55 (48 declaradas, 7 derivadas); mapeamentos: 50; famílias: fidc, fii, fiagro, fip.

## Verificação estática

Nenhum.

## Consistência com a Ficha atual (fund_metric_sources)

| metric_id | catalog | ficha_atual | resultado |
| --- | --- | --- | --- |
| fii.patrimonio_liquido | inf_mensal_fii_complemento.Patrimonio_Liquido | inf_mensal_fii_complemento.Patrimonio_Liquido | igual |
| fii.cotistas | inf_mensal_fii_complemento.Total_Numero_Cotistas | inf_mensal_fii_complemento.Total_Numero_Cotistas | igual |
| fii.ativo_total | inf_mensal_fii_complemento.Valor_Ativo | inf_mensal_fii_complemento.Valor_Ativo | igual |
| fiagro.patrimonio_liquido | inf_mensal_fiagro.Patrimonio_Liquido | inf_mensal_fiagro.Patrimonio_Liquido | igual |
| fiagro.cotistas | inf_mensal_fiagro.Numero_Cotistas | inf_mensal_fiagro.Numero_Cotistas | igual |
| fiagro.ativo_total | inf_mensal_fiagro.Valor_Ativo | inf_mensal_fiagro.Valor_Ativo | igual |
| fip.patrimonio_liquido | inf_trimestral_fip.VL_PATRIM_LIQ, inf_quadrimestral_fip.VL_PATRIM_LIQ | inf_trimestral_fip.VL_PATRIM_LIQ, inf_quadrimestral_fip.VL_PATRIM_LIQ | igual |
| fip.cotistas | inf_trimestral_fip.NR_COTST, inf_quadrimestral_fip.NR_COTST | inf_trimestral_fip.NR_COTST, inf_quadrimestral_fip.NR_COTST | igual |
| fidc.patrimonio_liquido | inf_mensal_fidc_tab_IV.TAB_IV_A_VL_PL | inf_mensal_fidc_tab_IV.TAB_IV_A_VL_PL | igual |
| fidc.cotistas | inf_mensal_fidc_tab_X_1.TAB_X_NR_COTST | inf_mensal_fidc_tab_X_1.TAB_X_NR_COTST | igual |

## Disponibilidade por métrica

| metric_id | display_name | value_type | status | first | last | discontinuities |
| --- | --- | --- | --- | --- | --- | --- |
| fidc.patrimonio_liquido | Patrimônio líquido | declared | disponível | 2013-01 | 2026-10 |  |
| fidc.pl_medio_3m | PL médio (3 meses) | declared | disponível | 2013-01 | 2026-10 |  |
| fidc.ativo_total | Ativo total | declared | disponível | 2013-01 | 2026-10 |  |
| fidc.disponibilidades | Disponibilidades | declared | disponível | 2013-01 | 2026-10 |  |
| fidc.passivo_total | Passivo total | declared | disponível | 2013-01 | 2026-10 |  |
| fidc.carteira | Carteira | declared | disponível | 2013-01 | 2026-10 |  |
| fidc.dc_com_aquisicao | DC com aquisição substancial | declared | disponível | 2013-01 | 2026-10 |  |
| fidc.dc_sem_aquisicao | DC sem aquisição substancial | declared | disponível | 2013-01 | 2026-10 |  |
| fidc.valores_mobiliarios | Valores mobiliários | declared | disponível | 2013-01 | 2026-10 |  |
| fidc.cotas_fundos_icvm555 | Cotas de fundos da ICVM 555 | declared | disponível | 2013-01 | 2026-10 |  |
| fidc.cotas_classes_fif | Classes de cotas dos FIF | declared | disponível | 2020-11 | 2026-10 |  |
| fidc.titulos_publicos | Títulos públicos federais | declared | disponível | 2013-01 | 2026-10 |  |
| fidc.cdb | CDB | declared | disponível | 2013-01 | 2026-10 |  |
| fidc.compromissadas | Operações compromissadas | declared | disponível | 2013-01 | 2026-10 |  |
| fidc.outros_renda_fixa | Outros ativos de renda fixa | declared | disponível | 2013-01 | 2026-10 |  |
| fidc.cotas_fidc | Cotas de FIDC | declared | disponível | 2013-01 | 2026-10 |  |
| fidc.cotas_fidc_np | Cotas de FIDC-NP | declared | disponível | 2013-01 | 2026-10 |  |
| fidc.derivativos | Posições em derivativos (ativo) | declared | disponível | 2013-01 | 2026-10 |  |
| fidc.outros_ativos | Outros ativos | declared | disponível | 2013-01 | 2026-10 |  |
| fidc.carteira_segmentos | Carteira por segmento (total) | declared | disponível | 2013-01 | 2026-10 |  |
| fidc.precatorios | Precatórios | declared | disponível | 2013-01 | 2026-10 |  |
| fidc.dc_com_aquisicao_inadimplentes | Créditos inadimplentes (com aquisição) | declared | disponível | 2013-01 | 2026-10 |  |
| fidc.dc_sem_aquisicao_inadimplentes | Créditos inadimplentes (sem aquisição) | declared | disponível | 2019-11 | 2026-10 |  |
| fidc.provisao_com_aquisicao | Provisão para redução ao valor de recuperação (com aquisição) | declared | disponível | 2013-01 | 2026-10 |  |
| fidc.provisao_sem_aquisicao | Provisão para redução ao valor de recuperação (sem aquisição) | declared | disponível | 2019-11 | 2026-10 |  |
| fidc.dc_a_vencer_com_aquisicao | DC a vencer por prazo (com aquisição) | declared | disponível | 2013-01 | 2026-10 |  |
| fidc.parcelas_inadimplentes_com_aquisicao | Parcelas inadimplentes (com aquisição) | declared | disponível | 2013-01 | 2026-10 |  |
| fidc.pagos_antecipadamente_com_aquisicao | Pagos antecipadamente (com aquisição) | declared | disponível | 2013-01 | 2026-10 |  |
| fidc.parcelas_inadimplentes_sem_aquisicao | Parcelas inadimplentes (sem aquisição) | declared | disponível | 2013-01 | 2026-10 |  |
| fidc.recompras_valor | Recompras (valor) | declared | disponível | 2013-01 | 2026-10 |  |
| fidc.recompras_quantidade | Recompras (quantidade) | declared | disponível | 2013-01 | 2026-10 |  |
| fidc.substituicoes_valor | Substituições (valor) | declared | disponível | 2013-01 | 2026-10 |  |
| fidc.cotistas | Número de cotistas | declared | disponível | 2013-01 | 2026-10 |  |
| fidc.captacoes | Captações no mês | declared | disponível | 2013-01 | 2026-10 |  |
| fidc.resgates | Resgates no mês | declared | disponível | 2013-01 | 2026-10 |  |
| fidc.resgates_solicitados | Resgates solicitados | declared | disponível | 2013-01 | 2026-10 |  |
| fidc.amortizacoes | Amortizações | declared | disponível | 2013-01 | 2026-10 |  |
| fidc.rentabilidade_mes | Rentabilidade no mês (por classe/série) | declared | disponível | 2013-01 | 2026-10 |  |
| fidc.liquidez_imediata | Ativos com liquidez imediata | declared | disponível | 2013-01 | 2026-10 |  |
| fidc.liquidez_30d | Ativos liquidáveis em até 30 dias | declared | disponível | 2013-01 | 2026-10 |  |
| fidc.dc_total | Direitos creditórios (total) | derived | disponível | 2013-01 | 2026-10 |  |
| fidc.dc_sobre_pl | Direitos creditórios / PL | derived | disponível | 2013-01 | 2026-10 |  |
| fidc.disponibilidades_sobre_pl | Disponibilidades / PL | derived | disponível | 2013-01 | 2026-10 |  |
| fidc.passivo_sobre_ativo | Passivo / Ativo | derived | disponível | 2013-01 | 2026-10 |  |
| fidc.inadimplencia_dc_com_aquisicao | Inadimplência / DC com aquisição | derived | disponível | 2013-01 | 2026-10 |  |
| fidc.precatorios_sobre_carteira_segmentos | Precatórios / Carteira por segmento | derived | disponível | 2013-01 | 2026-10 |  |
| fidc.pl_variacao_mensal | Variação mensal do PL | derived | disponível | 2013-01 | 2026-10 |  |
| fii.patrimonio_liquido | Patrimônio líquido | declared | disponível | 2016-01 | 2026-12 |  |
| fii.ativo_total | Ativo total | declared | disponível | 2016-01 | 2026-12 |  |
| fii.cotistas | Número de cotistas | declared | disponível | 2016-01 | 2026-12 |  |
| fiagro.patrimonio_liquido | Patrimônio líquido | declared | disponível | 2025-05 | 2026-10 |  |
| fiagro.ativo_total | Ativo total | declared | disponível | 2025-05 | 2026-10 |  |
| fiagro.cotistas | Número de cotistas | declared | disponível | 2025-05 | 2026-10 |  |
| fip.patrimonio_liquido | Patrimônio líquido | declared | disponível | 2010-01 | 2026-12 |  |
| fip.cotistas | Número de cotistas | declared | disponível | 2010-01 | 2026-12 |  |

## Disponibilidade por mapeamento (arquivos consolidados com o campo no leiaute)

| metric_id | table_name | field | equivalence | files | files_with_field | first | last | gaps |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| fidc.patrimonio_liquido | inf_mensal_fidc_tab_IV | TAB_IV_A_VL_PL | same_field | 166 | 166 | 2013-01 | 2026-10 |  |
| fidc.pl_medio_3m | inf_mensal_fidc_tab_IV | TAB_IV_B_VL_PL_MEDIO | same_field | 166 | 166 | 2013-01 | 2026-10 |  |
| fidc.ativo_total | inf_mensal_fidc_tab_I | TAB_I_VL_ATIVO | same_field | 166 | 166 | 2013-01 | 2026-10 |  |
| fidc.disponibilidades | inf_mensal_fidc_tab_I | TAB_I1_VL_DISP | same_field | 166 | 166 | 2013-01 | 2026-10 |  |
| fidc.carteira | inf_mensal_fidc_tab_I | TAB_I2_VL_CARTEIRA | same_field | 166 | 166 | 2013-01 | 2026-10 |  |
| fidc.dc_com_aquisicao | inf_mensal_fidc_tab_I | TAB_I2A_VL_DIRCRED_RISCO | same_field | 166 | 166 | 2013-01 | 2026-10 |  |
| fidc.dc_sem_aquisicao | inf_mensal_fidc_tab_I | TAB_I2B_VL_DIRCRED_SEM_RISCO | same_field | 166 | 166 | 2013-01 | 2026-10 |  |
| fidc.valores_mobiliarios | inf_mensal_fidc_tab_I | TAB_I2C_VL_VLMOB | same_field | 166 | 166 | 2013-01 | 2026-10 |  |
| fidc.cotas_fundos_icvm555 | inf_mensal_fidc_tab_I | TAB_I2C5_VL_COTA_FUNDO_ICVM555 | same_field | 166 | 166 | 2013-01 | 2026-10 |  |
| fidc.cotas_classes_fif | inf_mensal_fidc_tab_I | TAB_I2C5_VL_COTA_FIF | same_field | 72 | 72 | 2020-11 | 2026-10 |  |
| fidc.titulos_publicos | inf_mensal_fidc_tab_I | TAB_I2D_VL_TITPUB_FED | same_field | 166 | 166 | 2013-01 | 2026-10 |  |
| fidc.cdb | inf_mensal_fidc_tab_I | TAB_I2E_VL_CDB | same_field | 166 | 166 | 2013-01 | 2026-10 |  |
| fidc.compromissadas | inf_mensal_fidc_tab_I | TAB_I2F_VL_OPER_COMPROM | same_field | 166 | 166 | 2013-01 | 2026-10 |  |
| fidc.outros_renda_fixa | inf_mensal_fidc_tab_I | TAB_I2G_VL_OUTRO_RF | same_field | 166 | 166 | 2013-01 | 2026-10 |  |
| fidc.cotas_fidc | inf_mensal_fidc_tab_I | TAB_I2H_VL_COTA_FIDC | same_field | 166 | 166 | 2013-01 | 2026-10 |  |
| fidc.cotas_fidc_np | inf_mensal_fidc_tab_I | TAB_I2I_VL_COTA_FIDC_NP | same_field | 166 | 166 | 2013-01 | 2026-10 |  |
| fidc.derivativos | inf_mensal_fidc_tab_I | TAB_I3_VL_POSICAO_DERIV | same_field | 166 | 166 | 2013-01 | 2026-10 |  |
| fidc.outros_ativos | inf_mensal_fidc_tab_I | TAB_I4_VL_OUTRO_ATIVO | same_field | 166 | 166 | 2013-01 | 2026-10 |  |
| fidc.passivo_total | inf_mensal_fidc_tab_III | TAB_III_VL_PASSIVO | same_field | 166 | 166 | 2013-01 | 2026-10 |  |
| fidc.carteira_segmentos | inf_mensal_fidc_tab_II | TAB_II_VL_CARTEIRA | same_field | 166 | 166 | 2013-01 | 2026-10 |  |
| fidc.precatorios | inf_mensal_fidc_tab_II | TAB_II_I1_VL_PRECAT | same_field | 166 | 166 | 2013-01 | 2026-10 |  |
| fidc.dc_com_aquisicao_inadimplentes | inf_mensal_fidc_tab_I | TAB_I2A3_VL_CRED_INAD | same_field | 166 | 166 | 2013-01 | 2026-10 |  |
| fidc.dc_sem_aquisicao_inadimplentes | inf_mensal_fidc_tab_I | TAB_I2B3_VL_CRED_INAD | same_field | 84 | 84 | 2019-11 | 2026-10 |  |
| fidc.provisao_com_aquisicao | inf_mensal_fidc_tab_I | TAB_I2A11_VL_REDUCAO_RECUP | same_field | 166 | 166 | 2013-01 | 2026-10 |  |
| fidc.provisao_sem_aquisicao | inf_mensal_fidc_tab_I | TAB_I2B11_VL_REDUCAO_RECUP | same_field | 84 | 84 | 2019-11 | 2026-10 |  |
| fidc.dc_a_vencer_com_aquisicao | inf_mensal_fidc_tab_V | TAB_V_A_VL_DIRCRED_PRAZO | same_field | 166 | 166 | 2013-01 | 2026-10 |  |
| fidc.parcelas_inadimplentes_com_aquisicao | inf_mensal_fidc_tab_V | TAB_V_B_VL_DIRCRED_INAD | same_field | 166 | 166 | 2013-01 | 2026-10 |  |
| fidc.pagos_antecipadamente_com_aquisicao | inf_mensal_fidc_tab_V | TAB_V_C_VL_DIRCRED_ANTECIPADO | same_field | 166 | 166 | 2013-01 | 2026-10 |  |
| fidc.parcelas_inadimplentes_sem_aquisicao | inf_mensal_fidc_tab_VI | TAB_VI_B_VL_DIRCRED_INAD | same_field | 166 | 166 | 2013-01 | 2026-10 |  |
| fidc.recompras_valor | inf_mensal_fidc_tab_VII | TAB_VII_D_2_VL_RECOMPRA | same_field | 166 | 166 | 2013-01 | 2026-10 |  |
| fidc.recompras_quantidade | inf_mensal_fidc_tab_VII | TAB_VII_D_1_QT_RECOMPRA | same_field | 166 | 166 | 2013-01 | 2026-10 |  |
| fidc.substituicoes_valor | inf_mensal_fidc_tab_VII | TAB_VII_C_2_VL_SUBST | same_field | 166 | 166 | 2013-01 | 2026-10 |  |
| fidc.cotistas | inf_mensal_fidc_tab_X_1 | TAB_X_NR_COTST | same_field | 166 | 166 | 2013-01 | 2026-10 |  |
| fidc.captacoes | inf_mensal_fidc_tab_X_4 | TAB_X_VL_TOTAL | same_field | 166 | 166 | 2013-01 | 2026-10 |  |
| fidc.resgates | inf_mensal_fidc_tab_X_4 | TAB_X_VL_TOTAL | same_field | 166 | 166 | 2013-01 | 2026-10 |  |
| fidc.resgates_solicitados | inf_mensal_fidc_tab_X_4 | TAB_X_VL_TOTAL | same_field | 166 | 166 | 2013-01 | 2026-10 |  |
| fidc.amortizacoes | inf_mensal_fidc_tab_X_4 | TAB_X_VL_TOTAL | same_field | 166 | 166 | 2013-01 | 2026-10 |  |
| fidc.rentabilidade_mes | inf_mensal_fidc_tab_X_3 | TAB_X_VL_RENTAB_MES | same_field | 166 | 166 | 2013-01 | 2026-10 |  |
| fidc.liquidez_imediata | inf_mensal_fidc_tab_X_5 | TAB_X_VL_LIQUIDEZ_0 | same_field | 166 | 166 | 2013-01 | 2026-10 |  |
| fidc.liquidez_30d | inf_mensal_fidc_tab_X_5 | TAB_X_VL_LIQUIDEZ_30 | same_field | 166 | 166 | 2013-01 | 2026-10 |  |
| fii.patrimonio_liquido | inf_mensal_fii_complemento | Patrimonio_Liquido | same_field | 11 | 11 | 2016-01 | 2026-12 |  |
| fii.ativo_total | inf_mensal_fii_complemento | Valor_Ativo | same_field | 11 | 11 | 2016-01 | 2026-12 |  |
| fii.cotistas | inf_mensal_fii_complemento | Total_Numero_Cotistas | same_field | 11 | 11 | 2016-01 | 2026-12 |  |
| fiagro.patrimonio_liquido | inf_mensal_fiagro | Patrimonio_Liquido | same_field | 18 | 18 | 2025-05 | 2026-10 |  |
| fiagro.ativo_total | inf_mensal_fiagro | Valor_Ativo | same_field | 18 | 18 | 2025-05 | 2026-10 |  |
| fiagro.cotistas | inf_mensal_fiagro | Numero_Cotistas | same_field | 18 | 18 | 2025-05 | 2026-10 |  |
| fip.patrimonio_liquido | inf_trimestral_fip | VL_PATRIM_LIQ | same_field | 14 | 14 | 2010-01 | 2023-12 |  |
| fip.patrimonio_liquido | inf_quadrimestral_fip | VL_PATRIM_LIQ | proven | 3 | 3 | 2024-01 | 2026-12 |  |
| fip.cotistas | inf_trimestral_fip | NR_COTST | same_field | 14 | 14 | 2010-01 | 2023-12 |  |
| fip.cotistas | inf_quadrimestral_fip | NR_COTST | proven | 3 | 3 | 2024-01 | 2026-12 |  |

## Mudanças de tabela ou campo: revisão pelo dicionário da CVM

| metric_id | from | to | since | equivalence | description_before | description_after | verdict |
| --- | --- | --- | --- | --- | --- | --- | --- |
| fip.patrimonio_liquido | inf_trimestral_fip.VL_PATRIM_LIQ | inf_quadrimestral_fip.VL_PATRIM_LIQ | 2024-01 | proven | Valor do patrimônio líquido | Valor do patrimônio líquido | comprovada pelo dicionário |
| fip.cotistas | inf_trimestral_fip.NR_COTST | inf_quadrimestral_fip.NR_COTST | 2024-01 | proven | Número de cotistas | Número de cotistas | comprovada pelo dicionário |

## Valores das métricas padrão contra a série atual da Ficha

| metric_id | pontos_ficha | pontos_catalogo | divergencias | resultado |
| --- | --- | --- | --- | --- |
| fidc.patrimonio_liquido | 242.869 | 242.869 | 0 | igual |
| fidc.cotistas | 242.886 | 242.886 | 0 | igual |
| fii.patrimonio_liquido | 83.632 | 83.632 | 0 | igual |
| fii.cotistas | 83.532 | 83.532 | 0 | igual |
| fiagro.patrimonio_liquido | 3.113 | 3.113 | 0 | igual |
| fiagro.cotistas | 3.113 | 3.113 | 0 | igual |
| fip.patrimonio_liquido | 64.451 | 64.451 | 0 | igual |
| fip.cotistas | 18.227 | 18.227 | 0 | igual |

## Matriz métrica × tabela da CVM (campo físico)

| metric_id | inf_mensal_fiagro | inf_mensal_fidc_tab_I | inf_mensal_fidc_tab_II | inf_mensal_fidc_tab_III | inf_mensal_fidc_tab_IV | inf_mensal_fidc_tab_V | inf_mensal_fidc_tab_VI | inf_mensal_fidc_tab_VII | inf_mensal_fidc_tab_X_1 | inf_mensal_fidc_tab_X_3 | inf_mensal_fidc_tab_X_4 | inf_mensal_fidc_tab_X_5 | inf_mensal_fii_complemento | inf_quadrimestral_fip | inf_trimestral_fip |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| fidc.patrimonio_liquido |  |  |  |  | TAB_IV_A_VL_PL |  |  |  |  |  |  |  |  |  |  |
| fidc.pl_medio_3m |  |  |  |  | TAB_IV_B_VL_PL_MEDIO |  |  |  |  |  |  |  |  |  |  |
| fidc.ativo_total |  | TAB_I_VL_ATIVO |  |  |  |  |  |  |  |  |  |  |  |  |  |
| fidc.disponibilidades |  | TAB_I1_VL_DISP |  |  |  |  |  |  |  |  |  |  |  |  |  |
| fidc.passivo_total |  |  |  | TAB_III_VL_PASSIVO |  |  |  |  |  |  |  |  |  |  |  |
| fidc.carteira |  | TAB_I2_VL_CARTEIRA |  |  |  |  |  |  |  |  |  |  |  |  |  |
| fidc.dc_com_aquisicao |  | TAB_I2A_VL_DIRCRED_RISCO |  |  |  |  |  |  |  |  |  |  |  |  |  |
| fidc.dc_sem_aquisicao |  | TAB_I2B_VL_DIRCRED_SEM_RISCO |  |  |  |  |  |  |  |  |  |  |  |  |  |
| fidc.valores_mobiliarios |  | TAB_I2C_VL_VLMOB |  |  |  |  |  |  |  |  |  |  |  |  |  |
| fidc.cotas_fundos_icvm555 |  | TAB_I2C5_VL_COTA_FUNDO_ICVM555 |  |  |  |  |  |  |  |  |  |  |  |  |  |
| fidc.cotas_classes_fif |  | TAB_I2C5_VL_COTA_FIF |  |  |  |  |  |  |  |  |  |  |  |  |  |
| fidc.titulos_publicos |  | TAB_I2D_VL_TITPUB_FED |  |  |  |  |  |  |  |  |  |  |  |  |  |
| fidc.cdb |  | TAB_I2E_VL_CDB |  |  |  |  |  |  |  |  |  |  |  |  |  |
| fidc.compromissadas |  | TAB_I2F_VL_OPER_COMPROM |  |  |  |  |  |  |  |  |  |  |  |  |  |
| fidc.outros_renda_fixa |  | TAB_I2G_VL_OUTRO_RF |  |  |  |  |  |  |  |  |  |  |  |  |  |
| fidc.cotas_fidc |  | TAB_I2H_VL_COTA_FIDC |  |  |  |  |  |  |  |  |  |  |  |  |  |
| fidc.cotas_fidc_np |  | TAB_I2I_VL_COTA_FIDC_NP |  |  |  |  |  |  |  |  |  |  |  |  |  |
| fidc.derivativos |  | TAB_I3_VL_POSICAO_DERIV |  |  |  |  |  |  |  |  |  |  |  |  |  |
| fidc.outros_ativos |  | TAB_I4_VL_OUTRO_ATIVO |  |  |  |  |  |  |  |  |  |  |  |  |  |
| fidc.carteira_segmentos |  |  | TAB_II_VL_CARTEIRA |  |  |  |  |  |  |  |  |  |  |  |  |
| fidc.precatorios |  |  | TAB_II_I1_VL_PRECAT |  |  |  |  |  |  |  |  |  |  |  |  |
| fidc.dc_com_aquisicao_inadimplentes |  | TAB_I2A3_VL_CRED_INAD |  |  |  |  |  |  |  |  |  |  |  |  |  |
| fidc.dc_sem_aquisicao_inadimplentes |  | TAB_I2B3_VL_CRED_INAD |  |  |  |  |  |  |  |  |  |  |  |  |  |
| fidc.provisao_com_aquisicao |  | TAB_I2A11_VL_REDUCAO_RECUP |  |  |  |  |  |  |  |  |  |  |  |  |  |
| fidc.provisao_sem_aquisicao |  | TAB_I2B11_VL_REDUCAO_RECUP |  |  |  |  |  |  |  |  |  |  |  |  |  |
| fidc.dc_a_vencer_com_aquisicao |  |  |  |  |  | TAB_V_A_VL_DIRCRED_PRAZO |  |  |  |  |  |  |  |  |  |
| fidc.parcelas_inadimplentes_com_aquisicao |  |  |  |  |  | TAB_V_B_VL_DIRCRED_INAD |  |  |  |  |  |  |  |  |  |
| fidc.pagos_antecipadamente_com_aquisicao |  |  |  |  |  | TAB_V_C_VL_DIRCRED_ANTECIPADO |  |  |  |  |  |  |  |  |  |
| fidc.parcelas_inadimplentes_sem_aquisicao |  |  |  |  |  |  | TAB_VI_B_VL_DIRCRED_INAD |  |  |  |  |  |  |  |  |
| fidc.recompras_valor |  |  |  |  |  |  |  | TAB_VII_D_2_VL_RECOMPRA |  |  |  |  |  |  |  |
| fidc.recompras_quantidade |  |  |  |  |  |  |  | TAB_VII_D_1_QT_RECOMPRA |  |  |  |  |  |  |  |
| fidc.substituicoes_valor |  |  |  |  |  |  |  | TAB_VII_C_2_VL_SUBST |  |  |  |  |  |  |  |
| fidc.cotistas |  |  |  |  |  |  |  |  | TAB_X_NR_COTST |  |  |  |  |  |  |
| fidc.captacoes |  |  |  |  |  |  |  |  |  |  | TAB_X_VL_TOTAL |  |  |  |  |
| fidc.resgates |  |  |  |  |  |  |  |  |  |  | TAB_X_VL_TOTAL |  |  |  |  |
| fidc.resgates_solicitados |  |  |  |  |  |  |  |  |  |  | TAB_X_VL_TOTAL |  |  |  |  |
| fidc.amortizacoes |  |  |  |  |  |  |  |  |  |  | TAB_X_VL_TOTAL |  |  |  |  |
| fidc.rentabilidade_mes |  |  |  |  |  |  |  |  |  | TAB_X_VL_RENTAB_MES |  |  |  |  |  |
| fidc.liquidez_imediata |  |  |  |  |  |  |  |  |  |  |  | TAB_X_VL_LIQUIDEZ_0 |  |  |  |
| fidc.liquidez_30d |  |  |  |  |  |  |  |  |  |  |  | TAB_X_VL_LIQUIDEZ_30 |  |  |  |
| fii.patrimonio_liquido |  |  |  |  |  |  |  |  |  |  |  |  | Patrimonio_Liquido |  |  |
| fii.ativo_total |  |  |  |  |  |  |  |  |  |  |  |  | Valor_Ativo |  |  |
| fii.cotistas |  |  |  |  |  |  |  |  |  |  |  |  | Total_Numero_Cotistas |  |  |
| fiagro.patrimonio_liquido | Patrimonio_Liquido |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| fiagro.ativo_total | Valor_Ativo |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| fiagro.cotistas | Numero_Cotistas |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| fip.patrimonio_liquido |  |  |  |  |  |  |  |  |  |  |  |  |  | VL_PATRIM_LIQ | VL_PATRIM_LIQ |
| fip.cotistas |  |  |  |  |  |  |  |  |  |  |  |  |  | NR_COTST | NR_COTST |

