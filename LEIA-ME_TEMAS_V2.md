# Patch — Temas dinâmicos v2 (correção: fundo e menu agora acompanham)

## O que a v2 corrige (o problema que você viu)

O tema só mudava os cards porque três pintores usavam CORES FIXAS
(hex hardcoded), por fora do design system:

1. **PremiumNatusBackground** — o gradiente de fundo do app inteiro
2. **Menu lateral** — o gradiente marsala profundo da sidebar
3. **Header hero + cards premium do dashboard** — gradientes próprios

Além disso, widgets que leem cor direto (fora do Theme) só reavaliam
quando reconstroem — agora a tela principal ESCUTA a troca de tema e
reconstrói o shell inteiro na hora (listener em initState/dispose).

## Decisão de design: o menu tem tokens próprios

O menu lateral é uma superfície escura de marca em TODOS os temas
(não faria sentido ele clarear no modo escuro nem herdar o "vinho",
que no escuro vira cor clara de tinta). A paleta ganhou os tokens
`menuTopo/menuMeio/menuBase`:

- Marsala Natus → o gradiente original EXATO (zero regressão visual)
- Verde Oliva → oliva profundo
- Azul Petróleo → petróleo profundo
- Modo Escuro → marsala quase-preto

O header hero do dashboard usa os mesmos tokens (coeso com o menu).

## Como aplicar

MESMO processo da v1 — este zip substitui a v1 por completo
(cumulativo: inclui temas v1 + obstetra v2):

1. Feche o flutter run
2. Copie a pasta `lib` deste zip por cima da `lib` do projeto
3. flutter analyze --no-fatal-infos --no-fatal-warnings
4. flutter test
5. flutter run -d chrome  (rode do zero, não use hot reload da sessão antiga)

## Teste

Configurações → trocar tema → AGORA devem mudar juntos: fundo,
menu lateral, header do dashboard, cards, botões e títulos.

## Ainda esperado no Modo Escuro (Fase 2)

Manchinhas claras pontuais (washes rosados pequenos e ~245 usos de
Colors.white/black espalhados). Me mande prints do escuro que eu
corrijo em lote.
