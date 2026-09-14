import 'package:flutter/material.dart';

class SuperAdminDestination {
  const SuperAdminDestination({
    required this.id,
    required this.rotulo,
    required this.titulo,
    required this.descricao,
    required this.icone,
    this.aliases = const <String>[],
  });

  final String id;
  final String rotulo;
  final String titulo;
  final String descricao;
  final IconData icone;
  final List<String> aliases;

  bool corresponde(String valor) {
    return id == valor || titulo == valor || aliases.contains(valor);
  }
}

abstract final class SuperAdminNavigation {
  static const destinos = <SuperAdminDestination>[
    SuperAdminDestination(
      id: 'visao-geral',
      rotulo: 'Visão geral',
      titulo: 'Visão geral da plataforma',
      descricao: 'Indicadores comerciais e operacionais da Natus.',
      icone: Icons.dashboard_rounded,
      aliases: ['Dashboard SaaS', 'Dashboard'],
    ),
    SuperAdminDestination(
      id: 'clinicas',
      rotulo: 'Clínicas',
      titulo: 'Clínicas',
      descricao: 'Cadastros, planos e situação de acesso das clínicas.',
      icone: Icons.apartment_rounded,
      aliases: ['Clínicas cadastradas SaaS'],
    ),
    SuperAdminDestination(
      id: 'usuarios',
      rotulo: 'Usuários',
      titulo: 'Usuários da plataforma',
      descricao: 'Contas administrativas e vínculos com clínicas.',
      icone: Icons.people_alt_rounded,
      aliases: ['Usuários/clientes SaaS'],
    ),
    SuperAdminDestination(
      id: 'mensalidades',
      rotulo: 'Mensalidades',
      titulo: 'Mensalidades em atraso',
      descricao: 'Pendências que precisam de acompanhamento.',
      icone: Icons.warning_amber_rounded,
      aliases: ['Mensalidades atrasadas SaaS'],
    ),
    SuperAdminDestination(
      id: 'assinaturas',
      rotulo: 'Assinaturas',
      titulo: 'Financeiro de assinaturas',
      descricao: 'Receita prevista e situação das assinaturas.',
      icone: Icons.payments_rounded,
      aliases: ['Financeiro das assinaturas SaaS'],
    ),
    SuperAdminDestination(
      id: 'nova-clinica',
      rotulo: 'Nova clínica',
      titulo: 'Cadastrar clínica',
      descricao: 'Criação segura da clínica e do administrador responsável.',
      icone: Icons.add_business_rounded,
      aliases: [
        'Criação de clínica/admin/enfermeira SaaS',
        'Criação de clínica/admin SaaS',
      ],
    ),
    SuperAdminDestination(
      id: 'crescimento',
      rotulo: 'Crescimento',
      titulo: 'Crescimento da plataforma',
      descricao: 'Evolução da base de usuários por período.',
      icone: Icons.trending_up_rounded,
      aliases: ['Crescimento de usuários por período SaaS'],
    ),
  ];

  static SuperAdminDestination resolver(String valor) {
    return destinos.firstWhere(
      (destino) => destino.corresponde(valor),
      orElse: () => destinos.first,
    );
  }
}
