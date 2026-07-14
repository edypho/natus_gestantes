# AGENTS.md — Projeto Natus

## Visão do produto

Natus é um SaaS escalável de gestão e relacionamento para clínicas em geral.

O produto não deve ser limitado à gestação ou obstetrícia.

Sempre utilizar terminologia genérica e inclusiva para clínicas, como:

- paciente
- profissional
- clínica
- atendimento
- acompanhamento
- prontuário
- procedimento
- especialidade

Evitar termos fixos como:

- gestante
- gravidez
- bebê
- trimestre
- pré-natal

Esses conceitos devem existir somente dentro de módulos específicos de
obstetrícia, quando aplicável.

## Estrutura do projeto

- Priorizar alterações dentro da pasta `lib/`.
- Manter a estrutura existente sempre que ela estiver adequada.
- Criar pastas e arquivos quando isso melhorar a separação de responsabilidades.
- Não concentrar telas, regras de negócio e acesso a dados em um único arquivo.
- Não criar arquivos genéricos excessivamente grandes.
- Evitar duplicação de código.

## Organização

Separar, conforme necessário:

- presentation
- domain
- data
- models
- services
- repositories
- controllers
- providers
- widgets
- pages
- utils
- constants

Funcionalidades específicas devem ser organizadas por módulo ou feature.

Exemplo:

lib/
  core/
  shared/
  features/
    patients/
    appointments/
    medical_records/
    clinic/
    professionals/
    authentication/

## Alterações

Antes de modificar:

1. Inspecionar a estrutura existente.
2. Identificar dependências e usos do código.
3. Planejar os arquivos que serão alterados.
4. Preservar compatibilidade com funcionalidades existentes.

Depois de modificar:

1. Executar `dart format`.
2. Executar `flutter analyze`.
3. Executar testes relacionados, quando existirem.
4. Informar arquivos criados, alterados, movidos ou removidos.
5. Informar erros que não puderam ser resolvidos.

## Limites

- Não alterar `android/`, `ios/`, `web/`, `macos/`, `windows/` ou `linux/`
  sem necessidade explícita.
- Não modificar dependências sem informar.
- Não excluir funcionalidades existentes sem autorização.
- Não expor chaves, tokens ou credenciais.
- Não implementar diretamente em produção.
- Sempre permitir revisão do diff.

## Identidade Natus

A experiência deve transmitir:

- cuidado
- acolhimento
- organização
- confiança
- simplicidade
- tecnologia humana

Manter consistência visual com o ecossistema Natus.