# Design System Natus — Paleta Oficial

Identidade: **off-white, marsala e dourado**, com o logo de coração-árvore.
Tudo centralizado em `lib/shared/natus_app.dart` — para ajustar qualquer cor
do app inteiro, edite apenas as constantes lá.

## Paleta

| Papel | Constante | Hex |
|---|---|---|
| Primária (marca) | `NatusApp.marsala` | `#8A4247` |
| Marsala suave (hover/realce) | `NatusApp.marsalaSuave` | `#A05A5F` |
| Vinho (títulos) | `NatusApp.vinho` | `#6B3136` |
| Vinho profundo (snackbar/tooltip) | `NatusApp.vinhoProfundo` | `#401A1E` |
| Dourado (acento premium) | `NatusApp.dourado` | `#C6A15B` |
| Dourado escuro (ícones em fundo claro) | `NatusApp.douradoEscuro` | `#A17F3C` |
| Dourado claro (bordas de card, chips) | `NatusApp.douradoClaro` | `#EAD9B0` |
| Off-white (superfícies) | `NatusApp.offWhite` | `#FDFBF6` |
| Creme (fundo do app) | `NatusApp.fundo` | `#F8F3EB` |
| Bege / bege escuro | `NatusApp.bege` / `begeEscuro` | `#F0E7D8` / `#DDCEB6` |
| Texto / texto suave | `NatusApp.texto` / `textoSuave` | `#3D2B2D` / `#83706F` |

## Regras de uso

- **Marsala** é ação: botões primários, links, foco de inputs, tabs ativas.
- **Dourado** é destaque, nunca ação: bordas de cards, ícones decorativos,
  indicador de tab, chips selecionados. Isso mantém o dourado especial.
- **Off-white/creme** em superfícies; nunca branco puro em áreas grandes.
- Títulos em `vinho` com peso 700–800; corpo em `texto`.
- Raios: cards 22, botões/inputs 16, dialogs 26.

## O que foi alterado no rebrand

- `lib/shared/natus_app.dart`: reescrito — paleta nova + tema Material 3
  completo (16 componentes tematizados; antes eram 7).
- `lib/shared/natus_premium_visual.dart`: gradiente de fundo e orbes
  retintados (pêssego → dourado; ameixa → marsala).
- Cores antigas hardcoded (`0xFF7A3E57`, `0xFF5C2D3F`, `0xFF3A1725`,
  `0xFFEAB7A9`) substituídas pelos equivalentes novos em todo o `lib/`.
- `assets/logo.png`: substituído pela nova marca (coração-árvore) recolorida
  em marsala — usada no menu lateral e na tela de login automaticamente.
- `assets/logo2.png`: original preservado.
- Ícones de app (iOS: 19 tamanhos, Android: 5 densidades) regenerados com a
  nova marca sobre off-white.

## Nomes preservados

Todas as constantes antigas (`rose`, `olivaSeco`, `douradoSuave`, etc.)
continuam existindo com valores atualizados — nenhuma tela quebrou.


## Referência visual oficial (jul/2026)

O arquivo `design_referencia_visual.png` na raiz do projeto é o guia
aprovado para o redesign das telas no Lote 2f. Elementos-chave a implementar:
saudação com nome no topo; card-herói da gestação com fruta da semana e
progresso; KPIs em cards compactos com ícone; badges arredondados de status
(Ativa/Puérpera) em tons pastel; bottom bar com coração central em marsala;
stepper de cadastro em etapas; agenda com chips de dia e badges de
confirmação; biblioteca com thumbnails. Paleta e tipografia conforme este
documento.
