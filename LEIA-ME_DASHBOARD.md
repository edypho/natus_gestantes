# Patch — Dashboard clínico v1
# (CUMULATIVO: inclui Temas v2 + Obstetra v2 — substitui os zips anteriores)

## O que mudou no DASHBOARD

1. **"Top 5 obstetras" virou "Partos e cesáreas"** — três cards:
   Partos normais / Cesáreas / Partos domiciliares, contados a partir do
   campo "Via de nascimento" (que já era preenchido no diálogo de
   nascimento: Normal, Cesárea, Nascer em casa).

2. **Card "Atendimentos" removido** da linha "Status das gestantes",
   e o item "Atendimentos" saiu do menu lateral (admin e enfermeira).
   A tela em si continua no código — se um dia quiser de volta, é só
   devolver a linha no menu.

3. **Novo bloco "Risco gestacional (pré-natal)"** — três cards:
   Risco habitual (verde) / Risco intermediário (laranja) / Alto risco
   (vermelho). Conta apenas as GESTANTES ATIVAS.

4. **Novo bloco "Diabetes gestacional"** — dois cards:
   Com DG (vermelho) / Sem DG (verde). Também só gestantes ativas.

5. **Amamentação por carteira do obstetra:** já funcionava por
   construção — o gráfico usa a lista de gestantes, que no login do
   obstetra chega FILTRADA pela carteira dele (patch anterior).
   Admin continua vendo o geral. Aliás, TODOS os cards novos seguem a
   mesma regra: no login do obstetra, partos/cesáreas, riscos e DG
   contam só as gestantes dele.

## O que mudou no CADASTRO (pré-natal)

- **Dois campos novos na gestante:**
  - `riscoGestacional`: Não informado / Habitual / Intermediário / Alto Risco
  - `diabetesGestacional`: Não informado / Sim / Não
- Onde aparecem:
  - Diálogo "Editar cadastro da gestante" → dois dropdowns novos
  - Editor por seções (ficha → editar Gestante) → dois campos
  - Ficha de detalhes da gestante → duas linhas novas
- Gestantes antigas ficam como "Não informado" e não entram nas
  contagens até serem classificadas — sem migração necessária.

## Como aplicar
Mesmo processo: copie a pasta `lib` por cima, depois:
1. flutter analyze --no-fatal-infos --no-fatal-warnings
2. flutter test
3. flutter run -d chrome

## Roteiro de teste
1. Dashboard admin: conferir os blocos novos (Risco, Diabetes,
   Partos e cesáreas) e a ausência do card/menu Atendimentos
2. Abrir uma gestante → Editar cadastro → classificar risco e DG →
   voltar ao dashboard e ver os cards contarem
3. Login como obstetra: dashboard deve contar SÓ a carteira dele
   (amamentação, riscos, DG, partos)

---

## v2 — Redesign do pódio "Top 5 maternidades"

- **Corrigido o overflow** ("BOTTOM OVERFLOWED BY 17 PIXELS"): o card de
  conteúdo agora tem altura livre (nome nunca estoura) e quem conta a
  história do ranking é o DEGRAU decorativo embaixo, com alturas
  diferentes (1º mais alto).
- Nome em até 2 linhas com reticências + tooltip com o nome completo
  ao passar o mouse.
- Ouro/prata/bronze traduzidos para a paleta ativa (dourado, neutro,
  rose) — o pódio acompanha os 4 temas.
- Número em destaque grande; "atendimentos" discreto embaixo.
- 4º e 5º lugares ganharam barra de progresso proporcional ao 1º.
- Coroa dourada sobre o campeão; sombras suaves no tom da medalha.
