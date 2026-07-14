# Patch — Obstetra v2 (coleção própria, CRM e vínculo)

## O que este patch faz

O obstetra agora funciona **exatamente como a enfermeira**:

1. **Nova tela "Cadastrar Obstetra"** (menu do admin, abaixo de "Cadastrar EO")
   com os campos: Nome, Telefone, E-mail, **CRM** e Especialidade.
   Grava na nova coleção `obstetras` do Firestore (criada automaticamente
   no primeiro cadastro — nada a fazer no console).

2. **Criação de login com vínculo**: no diálogo "Criar novo usuário", o tipo
   "obstetra" agora exige selecionar um obstetra cadastrado (dropdown
   "Selecionar obstetra", listando só os sem login). Ao criar, o `uidObstetra`
   é gravado no registro — espelho do fluxo da enfermeira.

3. **Saudação corrigida**: "Olá, {nome}" agora encontra o nome do obstetra
   vinculado (antes caía em "equipe Natus").

4. **Menu do obstetra**: herda o menu operacional da enfermeira via
   `tipoEhProfissionalClinica` (antes o mapa de menus nem tinha a chave
   'obstetra' — o login entrava com menu vazio; corrigido).

5. **Filtro de carteira mais confiável**: a carteira do obstetra agora é
   filtrada pelo nome do REGISTRO VINCULADO na coleção `obstetras` (com
   fallback para o nome do usuário). O matching continua tolerante a
   "Dr./Dra." e maiúsculas.

## Arquivos deste patch (substituir na raiz do projeto)

- `lib/main.dart`
- `lib/dados/natus_data_source.dart`

## Como aplicar

1. Feche o `flutter run` se estiver rodando
2. Copie os dois arquivos por cima dos atuais (mesmos caminhos)
3. `flutter analyze --no-fatal-infos --no-fatal-warnings`
4. `flutter test`  (esperado: os mesmos testes de antes, todos verdes)
5. `flutter run -d chrome`

## Roteiro de teste manual

1. Login como admin → menu deve mostrar "Cadastrar Obstetra"
2. Cadastre um obstetra (ex.: nome "Lucas Almeida", CRM "12345-PR")
3. Usuários → Criar usuário → tipo "obstetra" → o dropdown "Selecionar
   obstetra" deve listar o Lucas → informe o e-mail → Criar
4. Numa gestante de teste, preencha o campo obstetra com "Dr. Lucas Almeida"
5. Logout → login com o e-mail do obstetra + senha `N@tus2026!`
6. Conferir: saudação "Olá, Lucas Almeida", menu igual ao da enfermeira,
   e APENAS a gestante do passo 4 visível (dashboard, lista e mapa)
7. Volte como admin e confira que tudo continua normal

## Observação importante (compatibilidade)

- Obstetras criados antes deste patch (só login, sem registro) continuam
  funcionando: o filtro de carteira cai no nome do usuário, como era.
  Para ganhar a saudação e o vínculo, basta cadastrá-los na nova tela e
  recriar o login (ou apenas cadastrar com o mesmo nome).
- Este `main.dart` JÁ INCLUI a correção do dropdown de criação — se você
  aplicou o replace de uma linha antes, será sobrescrito sem conflito.
