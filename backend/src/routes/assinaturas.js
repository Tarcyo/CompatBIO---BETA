// routes/assinaturas.js
import express from "express";
import { PrismaClient } from "@prisma/client";
import { authenticateToken } from "../middleware/auth.js";

const router = express.Router();
const prisma = new PrismaClient();

// Helper para checar se o plano contém "Enterprise" (case-insensitive)
function isEnterprisePlanName(name) {
  if (!name) return false;
  return name.toLowerCase().includes("enterprise");
}

// Helper simples para validar e-mail
function isValidEmail(email) {
  if (!email || typeof email !== "string") return false;
  const re = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return re.test(email);
}

/**
 * Calcula saldo atual do usuário somando pacotes não-vencidos.
 * Regra: validade_em_dias <= 0 === sem expiração (conta como válido).
 * Retorna Number (inteiro).
 */
async function computeUserSaldo(prismaOrTx, userId) {
  const config = await prismaOrTx.config_sistema.findFirst({
    orderBy: [{ atualizado_em: "desc" }],
  });
  const validadeDias = Number(config?.validade_em_dias ?? 0);
  const pacotes = await prismaOrTx.pacote_creditos.findMany({
    where: { id_usuario: userId },
    select: { quantidade: true, data_recebimento: true },
  });

  const now = Date.now();
  const msPorDia = 24 * 60 * 60 * 1000;
  let soma = 0;
  for (const p of pacotes) {
    const quantidade = Number(p.quantidade ?? 0);
    if (!Number.isFinite(quantidade) || quantidade === 0) continue;
    if (!p.data_recebimento) continue;

    if (!Number.isFinite(validadeDias) || validadeDias <= 0) {
      soma += quantidade;
      continue;
    }

    const recebidoTs = new Date(p.data_recebimento).getTime();
    const expiraEm = recebidoTs + validadeDias * msPorDia;
    if (expiraEm >= now) soma += quantidade;
  }
  return soma;
}

/**
 * POST /assinaturas/me/assinar
 * Cria uma assinatura local (não-ligada ao Stripe) para o usuário logado.
 * Body: { id_plano: number }
 *
 * Regras adicionadas:
 * - se plano.maximo_colaboradores > 0 -> verificar quantidade de colaboradores da empresa do usuário (excluindo o próprio dono).
 *   Se a quantidade de colaboradores da empresa for maior que maximo_colaboradores, recusar criação.
 * - não cria se o usuário já possui uma assinatura ativa (retorna 400).
 */
router.post("/me/assinar", authenticateToken, async (req, res) => {
  try {
    const userId = req.user && req.user.id;
    if (!userId) return res.status(400).json({ error: "Token não contém id de usuário" });

    const { id_plano } = req.body ?? {};
    const pid = Number(id_plano ?? 0);
    if (!pid || !Number.isFinite(pid)) return res.status(400).json({ error: "id_plano (number) é obrigatório" });

    // buscar plano
    const plano = await prisma.plano.findUnique({ where: { id: pid } });
    if (!plano) return res.status(404).json({ error: "Plano não encontrado" });

    // buscar usuário
    const usuario = await prisma.usuario.findUnique({ where: { id: userId } });
    if (!usuario) return res.status(404).json({ error: "Usuário não encontrado" });

    // verificar se já existe assinatura ativa do usuário
    const existente = await prisma.assinatura.findFirst({ where: { id_dono: userId, ativo: true } });
    if (existente) {
      return res.status(400).json({ error: "Já existe uma assinatura ativa para este usuário" });
    }

    // regra de máximo de colaboradores: se plano.maximo_colaboradores > 0
    if (Number.isFinite(plano.maximo_colaboradores) && plano.maximo_colaboradores > 0) {
      let colaboradoresCount = 0;

      // Se usuário pertence a uma empresa, contamos usuários dessa empresa EXCLUINDO o dono
      if (usuario.id_empresa) {
        colaboradoresCount = await prisma.usuario.count({
          where: {
            id_empresa: usuario.id_empresa,
            // exclui o próprio dono da contagem
            NOT: { id: userId },
          },
        });
      } else {
        // se não pertence a empresa, contamos usuários já vinculados à futura assinatura? (não faz sentido)
        // tratamos como 0 colaboradores então.
        colaboradoresCount = 0;
      }

      // Se colaboradoresCount > maximo => rejeitar
      if (colaboradoresCount > plano.maximo_colaboradores) {
        return res.status(400).json({
          error: "Não é possível criar a assinatura: número de colaboradores da sua empresa excede o limite do plano.",
          detalhe: {
            colaboradores_da_empresa: colaboradoresCount,
            limite_do_plano: plano.maximo_colaboradores,
            observacao: "Remova colaboradores ou escolha um plano com limite maior.",
          },
        });
      }
      // Observação: se colaboradoresCount === maximo_colaboradores, ainda permitimos criar, pois dono não conta.
      // Caso deseje proibir criar quando colaboradores === maximo (pois talvez o fluxo de vinculação imediata ocorra), ajuste para >=.
    }

    // criar assinatura
    const nova = await prisma.assinatura.create({
      data: {
        id_plano: plano.id,
        id_dono: userId,
        ativo: true,
        data_assinatura: new Date(),
      },
      include: { plano: true },
    });

    // opcional: atualizar usuario.id_vinculo_assinatura para apontar para a nova assinatura (se desejar)
    await prisma.usuario.update({
      where: { id: userId },
      data: { id_vinculo_assinatura: nova.id },
    });

    return res.status(201).json({ success: true, assinatura: nova });
  } catch (err) {
    console.error("Erro POST /assinaturas/me/assinar:", err);
    return res.status(500).json({ error: "Erro interno do servidor" });
  }
});


// GET /assinaturas/me/contas
router.get("/me/contas", authenticateToken, async (req, res) => {
  try {
    const userId = req.user && req.user.id;
    if (!userId) return res.status(400).json({ error: "Token não contém id de usuário" });

    const requester = await prisma.usuario.findUnique({
      where: { id: userId },
      include: {
        vinculoAssinatura: {
          include: { plano: true },
        },
      },
    });

    if (!requester) return res.status(404).json({ error: "Usuário não encontrado" });

    const assinatura = requester.vinculoAssinatura;
    if (!assinatura || !assinatura.plano || !isEnterprisePlanName(assinatura.plano.nome)) {
      return res.status(403).json({ error: "Acesso negado: requer assinatura com plano 'Enterprise'" });
    }

    // Buscar contas vinculadas (sem pedir saldo_em_creditos direto do DB)
    const contas = await prisma.usuario.findMany({
      where: { id_vinculo_assinatura: assinatura.id },
      select: { id: true, nome: true, email: true, tipo_usuario: true, created_at: true }
    });

    // Obter configuração mais recente (validade_em_dias)
    const configMaisRecente = await prisma.config_sistema.findFirst({
      orderBy: { atualizado_em: "desc" }
    });
    const validadeEmDias = Number(configMaisRecente?.validade_em_dias ?? 0);

    // 1) Soma dos pacotes POSITIVOS válidos (aplica expiração se validadeEmDias > 0)
    const userIds = contas.map(c => c.id);
    const msPorDia = 24 * 60 * 60 * 1000;
    const now = new Date();

    const wherePos = {
      id_usuario: { in: userIds },
      quantidade: { gt: 0 },
    };
    if (Number.isFinite(validadeEmDias) && validadeEmDias > 0) {
      const cutoff = new Date(now.getTime() - validadeEmDias * msPorDia);
      wherePos.data_recebimento = { gte: cutoff };
    }
    const positivosGrouped = await prisma.pacote_creditos.groupBy({
      by: ['id_usuario'],
      where: wherePos,
      _sum: { quantidade: true },
    });

    // 2) Soma dos pacotes NEGATIVOS (débitos) — sempre contam, sem expiração
    const negativosGrouped = await prisma.pacote_creditos.groupBy({
      by: ['id_usuario'],
      where: {
        id_usuario: { in: userIds },
        quantidade: { lt: 0 },
      },
      _sum: { quantidade: true },
    });

    // 3) Construir mapa de saldos: positivos válidos + negativos (que são negativos)
    const saldoMap = Object.create(null);
    // inicializa com zero para todos os usuários retornados
    for (const id of userIds) saldoMap[id] = 0;

    for (const p of positivosGrouped) {
      const uid = p.id_usuario;
      const sum = Number(p._sum?.quantidade ?? 0);
      saldoMap[uid] = (saldoMap[uid] ?? 0) + sum;
    }

    for (const n of negativosGrouped) {
      const uid = n.id_usuario;
      const sumNeg = Number(n._sum?.quantidade ?? 0); // será negativo
      saldoMap[uid] = (saldoMap[uid] ?? 0) + sumNeg;
    }

    // Anexar saldo_em_creditos calculado a cada conta (mantendo o mesmo shape esperado)
    const contasComSaldo = contas.map(c => ({
      id: c.id,
      nome: c.nome,
      email: c.email,
      tipo_usuario: c.tipo_usuario,
      saldo_em_creditos: saldoMap[c.id] ?? 0,
      created_at: c.created_at
    }));

    // incluir informação do limite (para UI): maximo_colaboradores (0 = ilimitado) e contagem atual (excluindo dono)
    const colaboradoresAtuais = await prisma.usuario.count({
      where: {
        id_vinculo_assinatura: assinatura.id,
        NOT: { id: assinatura.id_dono },
      },
    });

    return res.json({
      assinaturaId: assinatura.id,
      plano: assinatura.plano.nome,
      donoId: assinatura.id_dono,
      maximo_colaboradores: assinatura.plano.maximo_colaboradores ?? 0,
      colaboradores_atuais: colaboradoresAtuais,
      contas: contasComSaldo,
    });
  } catch (err) {
    console.error("Erro GET /assinaturas/me/contas:", err);
    return res.status(500).json({ error: "Erro interno do servidor" });
  }
});


// POST /assinaturas/me/contas
router.post("/me/contas", authenticateToken, async (req, res) => {
  try {
    const requesterId = req.user && req.user.id;
    const { email } = req.body;

    if (!isValidEmail(email)) {
      return res.status(400).json({ error: "email (string) é obrigatório e deve ser válido" });
    }

    const requester = await prisma.usuario.findUnique({
      where: { id: requesterId },
      include: { vinculoAssinatura: { include: { plano: true } } },
    });
    if (!requester) return res.status(404).json({ error: "Usuário solicitante não encontrado" });

    const assinatura = requester.vinculoAssinatura;
    if (!assinatura || !assinatura.plano || !isEnterprisePlanName(assinatura.plano.nome)) {
      return res.status(403).json({ error: "Acesso negado: requer assinatura com plano 'Enterprise'" });
    }

    // Só dono da assinatura pode adicionar
    if (assinatura.id_dono !== requesterId) {
      return res.status(403).json({ error: "Apenas o dono da assinatura pode adicionar contas vinculadas" });
    }

    // Verificar limite de colaboradores antes de prosseguir
    const maxCol = Number(assinatura.plano.maximo_colaboradores ?? 0);
    if (Number.isFinite(maxCol) && maxCol > 0) {
      const colaboradoresAtuais = await prisma.usuario.count({
        where: {
          id_vinculo_assinatura: assinatura.id,
          NOT: { id: assinatura.id_dono }, // não contar o dono
        },
      });

      if (colaboradoresAtuais >= maxCol) {
        return res.status(400).json({
          error: "Limite de colaboradores atingido para este plano. Remova colaboradores ou atualize o plano.",
          detalhe: { colaboradores_atuais: colaboradoresAtuais, limite_do_plano: maxCol },
        });
      }
    }

    const updated = await prisma.$transaction(async (tx) => {
      const target = await tx.usuario.findUnique({
        where: { email },
        select: { id: true, nome: true, email: true, id_vinculo_assinatura: true },
      });
      if (!target) throw { status: 404, message: "Usuário alvo não encontrado (por email)" };

      if (target.id_vinculo_assinatura === assinatura.id) {
        throw { status: 400, message: "Usuário já vinculado a esta assinatura" };
      }
      if (target.id_vinculo_assinatura !== null) {
        throw { status: 400, message: "Usuário já vinculado a outra assinatura" };
      }

      const userAtualizado = await tx.usuario.update({
        where: { id: target.id },
        data: { id_vinculo_assinatura: assinatura.id },
        select: { id: true, nome: true, email: true, id_vinculo_assinatura: true },
      });

      await tx.logs_usuario.create({
        data: {
          id_do_usuario: target.id,
          acao_no_sistema: `Vinculado à assinatura ${assinatura.id} (plano: ${assinatura.plano.nome}) por dono ${requesterId}`,
        },
      });

      return userAtualizado;
    });

    return res.json({
      success: true,
      donoId: assinatura.id_dono,
      user: updated,
    });
  } catch (err) {
    if (err && err.status && err.message) return res.status(err.status).json({ error: err.message });
    console.error("Erro POST /assinaturas/me/contas:", err);
    return res.status(500).json({ error: "Erro interno do servidor" });
  }
});

// DELETE /assinaturas/me/contas/:userId
router.delete("/me/contas/:userId", authenticateToken, async (req, res) => {
  try {
    const requesterId = req.user && req.user.id;
    const targetUserId = Number(req.params.userId);
    if (!targetUserId) return res.status(400).json({ error: "userId inválido" });

    const requester = await prisma.usuario.findUnique({
      where: { id: requesterId },
      include: { vinculoAssinatura: { include: { plano: true } } },
    });
    if (!requester) return res.status(404).json({ error: "Usuário solicitante não encontrado" });

    const assinatura = requester.vinculoAssinatura;
    if (!assinatura || !assinatura.plano || !isEnterprisePlanName(assinatura.plano.nome)) {
      return res.status(403).json({ error: "Acesso negado: requer assinatura com plano 'Enterprise'" });
    }

    // Só dono da assinatura pode remover
    if (assinatura.id_dono !== requesterId) {
      return res.status(403).json({ error: "Apenas o dono da assinatura pode remover contas vinculadas" });
    }

    const result = await prisma.$transaction(async (tx) => {
      const target = await tx.usuario.findUnique({
        where: { id: targetUserId },
        select: { id: true, nome: true, id_vinculo_assinatura: true },
      });
      if (!target) throw { status: 404, message: "Usuário alvo não encontrado" };

      if (target.id_vinculo_assinatura !== assinatura.id) {
        throw { status: 400, message: "Usuário alvo não está vinculado à sua assinatura" };
      }

      const updated = await tx.usuario.update({
        where: { id: targetUserId },
        data: { id_vinculo_assinatura: null },
        select: { id: true, nome: true, id_vinculo_assinatura: true },
      });

      await tx.logs_usuario.create({
        data: {
          id_do_usuario: targetUserId,
          acao_no_sistema: `Desvinculado da assinatura ${assinatura.id} (plano: ${assinatura.plano.nome}) por dono ${requesterId}`,
        },
      });

      return updated;
    });

    return res.json({
      success: true,
      donoId: assinatura.id_dono,
      user: result,
    });
  } catch (err) {
    if (err && err.status && err.message) return res.status(err.status).json({ error: err.message });
    console.error("Erro DELETE /assinaturas/me/contas/:userId:", err);
    return res.status(500).json({ error: "Erro interno do servidor" });
  }
});

/**
 * POST /assinaturas/me/contas/transferir
 * Body: { targetUserId: number, quantidade: number }
 *
 * Regras:
 * - Somente o DONO da assinatura (assinatura.id_dono) pode transferir.
 * - Só transfere para usuário que esteja vinculado à mesma assinatura.
 * - Negado se saldo atual (somando pacotes válidos) for menor que quantidade solicitada.
 * - Cria um pacote negativo para o dono e um pacote positivo para o colaborador,
 *   ambos com a MESMA data_recebimento (timestamp gerado na transação).
 * - Registra logs_usuario para ambos.
 */
router.post("/me/contas/transferir", authenticateToken, async (req, res) => {
  try {
    const requesterId = req.user && req.user.id;
    const { targetUserId, quantidade } = req.body;

    const qnt = Number(quantidade ?? 0);
    const targetId = Number(targetUserId ?? 0);

    if (!Number.isFinite(qnt) || qnt <= 0 || !Number.isFinite(targetId) || targetId <= 0) {
      return res.status(400).json({ error: "targetUserId (number) e quantidade (number>0) são obrigatórios" });
    }

    // carregar requester + assinatura
    const requester = await prisma.usuario.findUnique({
      where: { id: requesterId },
      include: { vinculoAssinatura: { include: { plano: true } } },
    });
    if (!requester) return res.status(404).json({ error: "Usuário solicitante não encontrado" });

    const assinatura = requester.vinculoAssinatura;
    if (!assinatura || !assinatura.plano || !isEnterprisePlanName(assinatura.plano.nome)) {
      return res.status(403).json({ error: "Acesso negado: requer assinatura com plano 'Enterprise'" });
    }

    // somente dono pode transferir
    if (assinatura.id_dono !== requesterId) {
      return res.status(403).json({ error: "Apenas o dono da assinatura pode transferir créditos" });
    }

    // target deve existir e estar vinculado à mesma assinatura (não pode transferir para fora)
    const target = await prisma.usuario.findUnique({
      where: { id: targetId },
      select: { id: true, nome: true, id_vinculo_assinatura: true, email: true },
    });
    if (!target) return res.status(404).json({ error: "Usuário alvo não encontrado" });

    if (target.id === requesterId) {
      return res.status(400).json({ error: "Não é permitido transferir para si mesmo" });
    }

    if (target.id_vinculo_assinatura !== assinatura.id) {
      return res.status(403).json({ error: "Usuário alvo não está vinculado à sua assinatura" });
    }

    // Transação: checar saldo, criar pacotes e logs
    try {
      const txResult = await prisma.$transaction(async (tx) => {
        // saldo válido antes
        const saldoAntes = await computeUserSaldo(tx, requesterId);

        if (saldoAntes < qnt) {
          const err = new Error("INSUFFICIENT_CREDITS");
          err.code = "INSUFFICIENT_CREDITS";
          throw err;
        }

        // definir timestamp comum para ambos pacotes (data_recebimento igual)
        const now = new Date();

        // criar pacote negativo no dono
        const pacoteNeg = await tx.pacote_creditos.create({
          data: {
            id_usuario: requesterId,
            quantidade: -Math.abs(qnt),
            origem: `transferencia_para:${targetId}`,
            data_recebimento: now,
          },
        });

        // criar pacote positivo no colaborador com a mesma data_recebimento
        const pacotePos = await tx.pacote_creditos.create({
          data: {
            id_usuario: targetId,
            quantidade: Math.abs(qnt),
            origem: `transferencia_de:${requesterId}`,
            data_recebimento: now,
          },
        });

        // logs para ambos
        await tx.logs_usuario.create({
          data: {
            id_do_usuario: requesterId,
            acao_no_sistema: `Transferiu ${qnt} créditos para usuário ${targetId} (assinatura ${assinatura.id})`,
          },
        });
        await tx.logs_usuario.create({
          data: {
            id_do_usuario: targetId,
            acao_no_sistema: `Recebeu ${qnt} créditos de ${requesterId} (assinatura ${assinatura.id})`,
          },
        });

        // saldo depois (recalcula)
        const saldoDepois = await computeUserSaldo(tx, requesterId);

        return {
          pacoteNeg,
          pacotePos,
          saldoAntes,
          saldoDepois,
        };
      });

      return res.json({
        success: true,
        donoId: assinatura.id_dono,
        transferencia: {
          quantidade: qnt,
          data_recebimento: txResult.pacotePos.data_recebimento,
          pacote_negativo_id: txResult.pacoteNeg.id,
          pacote_positivo_id: txResult.pacotePos.id,
          targetUserId: targetId,
          ownerUserId: requesterId,
        },
        saldo_antes: txResult.saldoAntes,
        saldo_depois: txResult.saldoDepois,
      });
    } catch (txErr) {
      if (txErr?.code === "INSUFFICIENT_CREDITS") {
        return res.status(400).json({ error: `Saldo insuficiente: são necessários ${qnt} créditos.` });
      }
      console.error("Erro na transação de transferência:", txErr);
      return res.status(500).json({ error: "Erro interno ao processar transferência" });
    }
  } catch (err) {
    console.error("Erro POST /assinaturas/me/contas/transferir:", err);
    return res.status(500).json({ error: "Erro interno do servidor" });
  }
});

export default router;
