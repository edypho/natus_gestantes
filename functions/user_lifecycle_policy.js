"use strict";

const PERFIL_PACIENTE = "gestante";
const PERFIL_ADMIN = "admin";
const PERFIS_EQUIPE = new Set([
  "enfermeira",
  "obstetra",
  "profissional",
]);

/**
 * Decide se uma troca textual de perfil preserva o vinculo atual.
 * Fluxos que exigem escolher, remover ou migrar uma entidade devem usar uma
 * callable dedicada e nunca passar por alterarTipoUsuarioClinica.
 * @return {{permitida: boolean, motivo: string}} Resultado da politica.
 */
function avaliarTransicaoPerfil({
  perfilAtual,
  novoPerfil,
  possuiVinculo,
}) {
  if (perfilAtual === novoPerfil) {
    return {permitida: true, motivo: "perfil_inalterado"};
  }

  if (perfilAtual === PERFIL_PACIENTE || novoPerfil === PERFIL_PACIENTE) {
    return {permitida: false, motivo: "vinculo_paciente_exige_fluxo_proprio"};
  }

  const atualEquipe = PERFIS_EQUIPE.has(perfilAtual);
  const novoEquipe = PERFIS_EQUIPE.has(novoPerfil);

  if (perfilAtual === PERFIL_ADMIN && novoEquipe) {
    return {permitida: false, motivo: "novo_perfil_exige_entidade"};
  }

  if (atualEquipe && (novoEquipe || novoPerfil === PERFIL_ADMIN)) {
    return possuiVinculo ?
      {permitida: false, motivo: "entidade_vinculada"} :
      {permitida: true, motivo: "equipe_sem_entidade_vinculada"};
  }

  return {permitida: false, motivo: "transicao_nao_suportada"};
}

module.exports = {
  avaliarTransicaoPerfil,
};
