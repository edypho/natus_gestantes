# Patch — Temas dinâmicos v1 (+ Obstetra v2 incluído)

## ⚠️ Este patch é CUMULATIVO
O `lib/main.dart` e o `lib/dados/natus_data_source.dart` daqui JÁ INCLUEM
o patch anterior do Obstetra v2. Aplique este pacote por cima do projeto
e os dois recursos entram juntos. (Se você já tinha copiado o patch do
obstetra, sem problema — os arquivos são os mesmos, evoluídos.)

## O que este patch entrega

**1. Quatro temas, troca em tempo real (sem reiniciar o app):**
- Marsala Natus (oficial — o padrão)
- Verde Oliva (sereno e botânico)
- Azul Petróleo (elegante e clínico)
- Modo Escuro (marsala noturno) — ver nota beta abaixo

**2. Tela de Configurações de verdade** (antes era um placeholder):
seção "Tema do aplicativo" com cartões visuais de cada paleta
(amostras de cor, nome, descrição e check no ativo).

**3. Persistência por usuário:** a escolha é salva no campo `tema` do
documento do usuário (coleção `usuarios`) e recarregada no login.
No logout o app volta ao padrão Marsala.

**4. Arquitetura de paleta dinâmica:** `NatusApp.marsala`, `.vinho`,
`.dourado` etc. continuam com os mesmos nomes — agora apontam para a
paleta ativa (`NatusTema`). As ~390 referências existentes passaram a
ser dinâmicas sem tocar em nenhuma tela. 157 modificadores `const`
foram removidos de expressões que referenciam cores (obrigatório para
o dinamismo) — por isso o patch toca 18 arquivos.

## Arquivos (substituir nos mesmos caminhos)
Todos dentro de `lib/` — veja a estrutura deste zip; é copiar a pasta
`lib` por cima da sua.

## Como aplicar
1. Feche o `flutter run`
2. Copie a pasta `lib` deste patch por cima da `lib` do projeto
3. `flutter analyze --no-fatal-infos --no-fatal-warnings`
4. `flutter test`
5. `flutter run -d chrome`

## Roteiro de teste
1. Login como admin → menu **Configurações**
2. Trocar para **Verde Oliva** → o app inteiro deve mudar na hora
   (menu, cards, botões, títulos)
3. Trocar para **Azul Petróleo** e **Modo Escuro** → idem
4. Recarregar a página (F5) e logar de novo → o tema escolhido volta
5. Logout → tela de login volta ao Marsala padrão
6. Teste rápido do Obstetra v2 (se ainda não fez): cadastrar obstetra
   em "Cadastrar Obstetra", criar login vinculado, validar carteira

## Nota sobre o Modo Escuro (beta)
A arquitetura converte todo o design system, MAS o app tem ~245 usos
hardcoded de `Colors.white`/`Colors.black` espalhados pelas telas que
não acompanham o tema (ex.: alguns cards e faixas brancas vão continuar
claros no escuro). É esperado nesta v1. O plano da Fase 2 é a caça a
esses pontos com QA visual tela a tela — me mande prints do que ficar
estranho no escuro que eu corrijo em lote.

## Commit sugerido
git add lib/
git commit -m "feat(temas): paleta dinamica com 4 temas, tela de configuracoes e persistencia por usuario"
git push
