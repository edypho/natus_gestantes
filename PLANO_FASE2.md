# Plano Fase 2 — Decomposição do main.dart

## Estado atual (após o lote 2a, incluído neste pacote)

| | Antes | Agora |
|---|---|---|
| main.dart | 14.936 linhas | ~14.750 linhas |
| `print()` em produção | 50 | 0 (todos viraram `debugPrint`) |

**Lote 2a (feito):**
- `lib/core/firebase_globals.dart` — instâncias globais `firestore` e `storage`
- `lib/core/usuario_tipos.dart` — `normalizarTipoUsuarioNatus`
- `lib/auth/tela_login.dart` — `TelaLogin` completa
- `main.dart` re-exporta tudo (nenhum import externo quebra)
- `AuthGate` permaneceu no main de propósito: ela referencia `TelaPrincipal`;
  movê-la agora criaria import circular. Sai no lote final.

## O diagnóstico honesto

O main.dart não tem "muitas classes para separar": tem UMA classe
(`_TelaPrincipalState`) com ~14.500 linhas e ~150 métodos que compartilham
estado mutável (`setState`, listas de gestantes/parcelas/planos carregadas
do Firestore). Extrair métodos daí **exige compilar a cada passo** — por
isso os lotes abaixo foram desenhados para: eu edito → você roda
`flutter analyze && flutter test` → me manda erros se houver → seguimos.

## Lotes (em ordem de risco crescente)

### Lote 2b — Cálculos financeiros puros ✅ FEITO
18 funções extraídas para `lib/financeiro/financeiro_calculos.dart` como
funções puras. No main ficaram wrappers de 1 linha (padrão strangler) — zero
call sites alterados. **Novidade: a lógica financeira agora tem testes
unitários** (`test/financeiro_calculos_test.dart`, 15 casos cobrindo
inadimplência, 5º dia útil, parcelas atrasadas e formatos brasileiros).
main.dart: 14.751 → 14.561 linhas.

### Lote 2c — Regras de gestante e KPIs ✅ FEITO
8 regras puras em `lib/gestantes/gestantes_regras.dart` (status, ativa,
busca, DPP, conversão de datas) e 10 contagens em
`lib/kpis/kpis_calculos.dart`, com wrappers no main (padrão strangler).
Testes em `test/gestantes_kpis_test.dart` (18 casos: normalização de status
com acentos, flag de histórico, busca multi-campo, datas ISO/BR/Timestamp
do Firestore, contagens por período de DPP).
main.dart: 14.561 → 14.325 linhas.

### Lote 2d (mega-lote) — Widgets de card + helpers + higiene ✅ FEITO
10 widgets (`NatusCardKpi`, `NatusCardResumo`, `NatusAlertaDpp`,
`NatusBlocoDashboard`, `NatusCardFinanceiroResumo`, etc.) extraídos para
`lib/dashboard/dashboard_cards_natus.dart` como `StatelessWidget`, visual
preservado. 2 helpers puros (`rotuloParcelaFinanceira` e
`converterValorDinamico`) movidos para o módulo financeiro. **Higiene:
273 usos do deprecado `withOpacity` migrados para `withValues` em 128
arquivos** — deve derrubar a maior parte dos issues do analyze.
main.dart: 14.325 → 13.868 linhas.
Pendência anotada: `cardProgressoGestacional` usa estado — vai no 2f.

### Lote 2e — Cargas do Firestore ✅ FEITO
6 buscas (gestantes, planos, enfermeiras, biblioteca, atendimentos,
contrações) extraídas para `lib/dados/natus_data_source.dart` como funções
que retornam listas — o main só faz o `setState`. Mensagens de erro e
comportamento preservados byte a byte. As gravações (salvar*) e a migração
para os repositórios tipados com models ficam para o 2f, junto das telas.
main.dart: 13.868 → 13.804 linhas.

### Lote 2f — Telas inteiras (~8.000 linhas, risco alto, subdividido)
**Parte 1 ✅ FEITA — redesign dos cards do dashboard**: os 10 widgets de
`lib/dashboard/dashboard_cards_natus.dart` ganharam a linguagem da
referência visual (chips suaves sem borda dura, ícones em containers
arredondados, valores w800 em vinho/cor semântica, alerta de DPP virou
badge-pílula com contagem real de dias, tons semânticos quentes). Criados
2 componentes novos para a fiação das telas: `NatusStatusBadge` (pílula
pastel Ativa/Puérpera/Encerrada) e `NatusSaudacaoDashboard` (Olá, {nome} ♥).
Assinaturas preservadas — zero call sites alterados.

**Parte 2 ✅ FEITA — fiação nas telas**: cabeçalho do dashboard trocado de
"Dashboard" para `NatusSaudacaoDashboard` (Olá, {nome da EO logada} ♥ +
período), com fallback "equipe Natus" para nome vazio. O método
`badgeStatus` (usado na lista, ficha e detalhes da gestante) agora delega
para `NatusStatusBadge` — pílulas pastel alinhadas à referência em todos
os pontos de uma vez.

`telaExamesGestante`, `telaConteudo`, `telaCadastrarEO`, `menuLateral` e as
demais telas viram widgets em seus módulos, um por vez, recebendo callbacks.
Cada tela é um ciclo editar→compilar próprio.

### Lote 2g — Finalização
`AuthGate` sai do main; `TelaPrincipal` vira um shell fino de navegação;
main.dart termina com <300 linhas (bootstrap + rotas).

## Como validar cada lote

```bash
flutter analyze --no-fatal-infos && flutter test && flutter run -d chrome
```
Ou dispare o workflow `ios-check` no Codemagic, que faz tudo num Mac real.
