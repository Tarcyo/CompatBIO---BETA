// routes/planos.js
import express from "express";
import { PrismaClient } from "@prisma/client";
import { authenticateToken, authorizeAdministrative } from "../middleware/auth.js";

const router = express.Router();
const prisma = new PrismaClient();

// Aplicar autenticação a todas as rotas deste router
router.use(authenticateToken);

/**
 * Helper: valida e normaliza um valor para inteiro >= 0
 */
function parseNonNegativeInt(value, fallback = 0) {
  if (value === undefined || value === null || value === "") return fallback;
  const n = Number(value);
  if (!Number.isFinite(n) || isNaN(n) || !Number.isInteger(n) || n < 0) {
    return null;
  }
  return n;
}

/**
 * GET /planos
 * Lista todos os planos ordenados por prioridade_de_tempo (asc)
 */
router.get("/", async (req, res) => {
  try {
    const planos = await prisma.plano.findMany({
      orderBy: { prioridade_de_tempo: "asc" },
    });

    const mapped = planos.map((p) => ({
      id: p.id,
      nome: p.nome,
      prioridade_de_tempo: p.prioridade_de_tempo,
      quantidade_credito_mensal: p.quantidade_credito_mensal,
      preco_mensal: p.preco_mensal?.toString?.() ?? String(p.preco_mensal),
      stripe_price_id: p.stripe_price_id ?? null,
      maximo_colaboradores: p.maximo_colaboradores,
      created_at: p.created_at,
    }));

    return res.json(mapped);
  } catch (error) {
    console.error("Erro ao buscar planos:", error);
    return res.status(500).json({ error: "Erro ao buscar planos" });
  }
});

/**
 * GET /planos/me
 * Retorna a assinatura ativa do usuário (usando id do token).
 * Rota estática — deve ficar antes de rotas paramétricas.
 */
router.get("/me", async (req, res) => {
  try {
    const userId = (req.user && (req.user.id || req.user.userId || req.user.sub)) ?? null;
    if (!userId) return res.status(400).json({ error: "User id não encontrado no token" });

    const assinatura = await prisma.assinatura.findFirst({
      where: { id_dono: Number(userId), ativo: true },
      include: { plano: true },
    });

    if (!assinatura) {
      return res.status(404).json({ message: "Nenhuma assinatura ativa encontrada" });
    }

    return res.json({
      assinatura: {
        id: assinatura.id,
        id_plano: assinatura.id_plano,
        id_dono: assinatura.id_dono,
        data_assinatura: assinatura.data_assinatura,
        data_renovacao: assinatura.data_renovacao,
        ativo: assinatura.ativo,
        criado_em: assinatura.criado_em,
        stripe_subscription_id: assinatura.stripe_subscription_id ?? null,
        status: assinatura.status ?? null,
      },
      plano: {
        id: assinatura.plano.id,
        nome: assinatura.plano.nome,
        prioridade_de_tempo: assinatura.plano.prioridade_de_tempo,
        quantidade_credito_mensal: assinatura.plano.quantidade_credito_mensal,
        preco_mensal: assinatura.plano.preco_mensal?.toString?.() ?? String(assinatura.plano.preco_mensal),
        stripe_price_id: assinatura.plano.stripe_price_id ?? null,
        maximo_colaboradores: assinatura.plano.maximo_colaboradores,
      },
    });
  } catch (error) {
    console.error("Erro ao obter plano do usuário:", error);
    return res.status(500).json({ error: "Erro ao obter plano do usuário" });
  }
});

/**
 * POST /planos/change
 * Troca o plano do usuário (desativa antigas, cria nova assinatura, pacote de créditos, compra, receita, atualiza usuario.id_vinculo_assinatura)
 * Body: { id_plano: number }
 * Rota estática — deve ficar antes de rotas paramétricas.
 */
router.post("/change", async (req, res) => {
  try {
    const userId = (req.user && (req.user.id || req.user.userId || req.user.sub)) ?? null;
    if (!userId) return res.status(400).json({ error: "User id não encontrado no token" });

    const { id_plano } = req.body;
    if (!id_plano || isNaN(Number(id_plano))) {
      return res.status(400).json({ error: "id_plano inválido" });
    }

    const plano = await prisma.plano.findUnique({ where: { id: Number(id_plano) } });
    if (!plano) return res.status(404).json({ error: "Plano não encontrado" });

    // validação de limite de colaboradores:
    // regra: maximo_colaboradores === 0 -> ilimitado; >0 -> aplicar limite
    if (plano.maximo_colaboradores > 0) {
      // buscar informações do usuário para saber se pertence a uma empresa
      const usuarioAtual = await prisma.usuario.findUnique({ where: { id: Number(userId) } });

      if (!usuarioAtual) {
        return res.status(404).json({ error: "Usuário não encontrado" });
      }

      let colaboradoresCount = 1; // usuário solo por padrão
      if (usuarioAtual.id_empresa) {
        colaboradoresCount = await prisma.usuario.count({
          where: { id_empresa: usuarioAtual.id_empresa },
        });
      }

      if (colaboradoresCount > plano.maximo_colaboradores) {
        return res.status(400).json({
          error: "Não é possível trocar para este plano: número de colaboradores da sua empresa excede o limite do plano.",
          detalhe: {
            colaboradores_da_empresa: colaboradoresCount,
            limite_do_plano: plano.maximo_colaboradores,
            observacao: "defina um plano com limite maior ou remova colaboradores para prosseguir",
          },
        });
      }
    }

    const result = await prisma.$transaction(async (tx) => {
      const usuario = await tx.usuario.findUnique({ where: { id: Number(userId) } });

      // desativar assinaturas ativas anteriores
      await tx.assinatura.updateMany({
        where: { id_dono: Number(userId), ativo: true },
        data: { ativo: false },
      });

      // criar nova assinatura
      const novaAssinatura = await tx.assinatura.create({
        data: {
          id_plano: Number(id_plano),
          id_dono: Number(userId),
          ativo: true,
          data_assinatura: new Date(),
        },
        include: { plano: true },
      });

      // criar pacote de créditos correspondente ao plano (se aplicável)
      const quantidadeParaPacote = Number(plano.quantidade_credito_mensal ?? 0);
      if (Number.isFinite(quantidadeParaPacote) && quantidadeParaPacote > 0) {
        await tx.pacote_creditos.create({
          data: {
            id_usuario: Number(userId),
            quantidade: quantidadeParaPacote,
            origem: `assinatura_troca_${novaAssinatura.id}`,
          },
        });
      }

      // registrar compra
      await tx.compra.create({
        data: {
          id_usuario: Number(userId),
          valor_pago: plano.preco_mensal?.toString?.() ?? String(plano.preco_mensal),
          descricao: `( usuário ${usuario?.nome ?? "desconhecido"} assinou o plano ${plano.nome} por 1 mês!`,
        },
      });

      // registrar receita
      await tx.receita.create({
        data: {
          valor: plano.preco_mensal?.toString?.() ?? String(plano.preco_mensal),
          descricao: `Assinatura de plano - usuário ${usuario?.nome ?? "desconhecido"}`,
          id_usuario: Number(userId),
        },
      });

      // atualizar usuario.id_vinculo_assinatura
      await tx.usuario.update({
        where: { id: Number(userId) },
        data: { id_vinculo_assinatura: novaAssinatura.id },
      });

      return novaAssinatura;
    });

    return res.json({
      mensagem: "Plano alterado com sucesso",
      assinatura: {
        id: result.id,
        id_plano: result.id_plano,
        id_dono: result.id_dono,
        data_assinatura: result.data_assinatura,
        ativo: result.ativo,
        criado_em: result.criado_em,
        stripe_price_id: result.plano?.stripe_price_id ?? null,
        maximo_colaboradores: result.plano?.maximo_colaboradores ?? 0,
      },
      plano: {
        id: result.plano.id,
        nome: result.plano.nome,
        preco_mensal: result.plano.preco_mensal?.toString?.() ?? String(result.plano.preco_mensal),
        quantidade_credito_mensal: result.plano.quantidade_credito_mensal,
        prioridade_de_tempo: result.plano.prioridade_de_tempo,
        stripe_price_id: result.plano.stripe_price_id ?? null,
        maximo_colaboradores: result.plano.maximo_colaboradores ?? 0,
      },
    });
  } catch (error) {
    console.error("Erro ao trocar plano:", error);
    return res.status(500).json({ error: "Erro ao trocar plano" });
  }
});

/**
 * POST /planos
 * Cria um novo plano
 * Requer tipo Administrativo
 *
 * Agora aceita opcionalmente: stripe_price_id (string), maximo_colaboradores (int >=0)
 */
router.post("/", authorizeAdministrative, async (req, res) => {
  try {
    const {
      nome,
      prioridade_de_tempo = 0,
      preco_mensal = "0.00",
      quantidade_credito_mensal = 0,
      stripe_price_id = null,
      maximo_colaboradores = undefined,
    } = req.body ?? {};

    if (!nome || typeof nome !== "string" || nome.trim().length === 0) {
      return res.status(400).json({ error: "Nome do plano é obrigatório" });
    }

    if (stripe_price_id !== null && typeof stripe_price_id !== "string") {
      return res.status(400).json({ error: "stripe_price_id deve ser string quando fornecido" });
    }

    const maxColParsed = parseNonNegativeInt(maximo_colaboradores, 0);
    if (maxColParsed === null) {
      return res.status(400).json({ error: "maximo_colaboradores inválido (deve ser inteiro >= 0)" });
    }

    // criar registro
    const novo = await prisma.plano.create({
      data: {
        nome: nome.trim(),
        prioridade_de_tempo: Number(prioridade_de_tempo) || 0,
        preco_mensal: preco_mensal?.toString?.() ?? String(preco_mensal),
        quantidade_credito_mensal: Number(quantidade_credito_mensal) || 0,
        stripe_price_id: stripe_price_id ?? undefined,
        maximo_colaboradores: maxColParsed,
      },
    });

    return res.status(201).json({
      id: novo.id,
      nome: novo.nome,
      prioridade_de_tempo: novo.prioridade_de_tempo,
      quantidade_credito_mensal: novo.quantidade_credito_mensal,
      preco_mensal: novo.preco_mensal?.toString?.() ?? String(novo.preco_mensal),
      stripe_price_id: novo.stripe_price_id ?? null,
      maximo_colaboradores: novo.maximo_colaboradores,
      created_at: novo.created_at,
    });
  } catch (error) {
    console.error("Erro ao criar plano:", error);
    return res.status(500).json({ error: "Erro ao criar plano" });
  }
});

/**
 * PUT /planos/:id
 * Atualiza um plano existente
 * Requer tipo Administrativo
 *
 * Agora permite atualizar stripe_price_id e maximo_colaboradores
 */
router.put("/:id", authorizeAdministrative, async (req, res) => {
  try {
    const { id } = req.params;
    if (!id || isNaN(Number(id))) return res.status(400).json({ error: "ID inválido" });

    const { nome, prioridade_de_tempo, preco_mensal, quantidade_credito_mensal, stripe_price_id, maximo_colaboradores } = req.body ?? {};

    // verificar existência
    const planoExistente = await prisma.plano.findUnique({ where: { id: Number(id) } });
    if (!planoExistente) return res.status(404).json({ error: "Plano não encontrado" });

    // montar data de update apenas com campos presentes
    const dataToUpdate = {};
    if (nome !== undefined) {
      if (typeof nome !== "string" || nome.trim().length === 0) {
        return res.status(400).json({ error: "Nome inválido" });
      }
      dataToUpdate.nome = nome.trim();
    }
    if (prioridade_de_tempo !== undefined) {
      if (isNaN(Number(prioridade_de_tempo))) {
        return res.status(400).json({ error: "prioridade_de_tempo inválido" });
      }
      dataToUpdate.prioridade_de_tempo = Number(prioridade_de_tempo);
    }
    if (quantidade_credito_mensal !== undefined) {
      if (isNaN(Number(quantidade_credito_mensal))) {
        return res.status(400).json({ error: "quantidade_credito_mensal inválido" });
      }
      dataToUpdate.quantidade_credito_mensal = Number(quantidade_credito_mensal);
    }
    if (preco_mensal !== undefined) {
      // aceitar string/number/Decimal-like; armazenar como string para Prisma Decimal
      dataToUpdate.preco_mensal = preco_mensal?.toString?.() ?? String(preco_mensal);
    }
    if (stripe_price_id !== undefined) {
      if (stripe_price_id !== null && typeof stripe_price_id !== "string") {
        return res.status(400).json({ error: "stripe_price_id deve ser string ou null" });
      }
      // permitir set null para remover vinculo
      dataToUpdate.stripe_price_id = stripe_price_id ?? null;
    }
    if (maximo_colaboradores !== undefined) {
      const parsed = parseNonNegativeInt(maximo_colaboradores);
      if (parsed === null) {
        return res.status(400).json({ error: "maximo_colaboradores inválido (deve ser inteiro >= 0)" });
      }
      dataToUpdate.maximo_colaboradores = parsed;
    }

    if (Object.keys(dataToUpdate).length === 0) {
      return res.status(400).json({ error: "Nenhum campo fornecido para atualização" });
    }

    const atualizado = await prisma.plano.update({
      where: { id: Number(id) },
      data: dataToUpdate,
    });

    return res.json({
      id: atualizado.id,
      nome: atualizado.nome,
      prioridade_de_tempo: atualizado.prioridade_de_tempo,
      quantidade_credito_mensal: atualizado.quantidade_credito_mensal,
      preco_mensal: atualizado.preco_mensal?.toString?.() ?? String(atualizado.preco_mensal),
      stripe_price_id: atualizado.stripe_price_id ?? null,
      maximo_colaboradores: atualizado.maximo_colaboradores,
      created_at: atualizado.created_at,
    });
  } catch (error) {
    console.error("Erro ao atualizar plano:", error);
    return res.status(500).json({ error: "Erro ao atualizar plano" });
  }
});

/**
 * DELETE /planos/:id
 * Deleta um plano
 * Requer tipo Administrativo
 */
router.delete("/:id", authorizeAdministrative, async (req, res) => {
  try {
    const { id } = req.params;
    if (!id || isNaN(Number(id))) return res.status(400).json({ error: "ID inválido" });

    try {
      await prisma.plano.delete({ where: { id: Number(id) } });
      return res.json({ mensagem: "Plano deletado com sucesso" });
    } catch (e) {
      // geralmente ocorre por integridade referencial (assinaturas vinculadas)
      console.error("Erro ao deletar plano (possível FK):", e);
      return res.status(400).json({
        error:
          "Não foi possível deletar o plano — verifique se há assinaturas/relacionamentos vinculados. Remova vínculos antes de deletar.",
      });
    }
  } catch (error) {
    console.error("Erro ao deletar plano:", error);
    return res.status(500).json({ error: "Erro ao deletar plano" });
  }
});

/**
 * GET /planos/:id
 * Retorna um plano pelo id
 * NOTA: rota paramétrica colocada depois de rotas estáticas (/me, /change) para evitar conflitos.
 */
router.get("/:id", async (req, res) => {
  try {
    const { id } = req.params;
    if (!id || isNaN(Number(id))) return res.status(400).json({ error: "ID inválido" });

    const plano = await prisma.plano.findUnique({ where: { id: Number(id) } });
    if (!plano) return res.status(404).json({ error: "Plano não encontrado" });

    return res.json({
      id: plano.id,
      nome: plano.nome,
      prioridade_de_tempo: plano.prioridade_de_tempo,
      quantidade_credito_mensal: plano.quantidade_credito_mensal,
      preco_mensal: plano.preco_mensal?.toString?.() ?? String(plano.preco_mensal),
      stripe_price_id: plano.stripe_price_id ?? null,
      maximo_colaboradores: plano.maximo_colaboradores,
      created_at: plano.created_at,
    });
  } catch (error) {
    console.error("Erro ao obter plano:", error);
    return res.status(500).json({ error: "Erro ao obter plano" });
  }
});

export default router;
