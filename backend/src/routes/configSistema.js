// routes/configSistema.js
import express from "express";
import { PrismaClient } from "@prisma/client";
import { authenticateToken, authorizeAdministrative } from "../middleware/auth.js";

const router = express.Router();
const prisma = new PrismaClient();

/**
 * GET /config/latest
 * Retorna a configuração de sistema mais recente (por data_estabelecimento desc, id desc).
 * Atualmente público — se quiser restringir, adicione authenticateToken / authorizeAdministrative.
 */
router.get("/latest", authenticateToken, async (req, res) => {
  try {
    const config = await prisma.config_sistema.findFirst({
      orderBy: [
        { data_estabelecimento: "desc" },
        { id: "desc" },
      ],
    });

    if (!config) {
      return res.status(404).json({ error: "Nenhuma configuração encontrada" });
    }

    // Retornamos o objeto tal como veio do Prisma (inclui agora `validade_em_dias`)
    return res.json(config);
  } catch (err) {
    console.error("Erro GET /config/latest:", err);
    return res.status(500).json({ error: "Erro interno do servidor" });
  }
});

/**
 * POST /config
 * Cria nova configuração. Requer autenticação e tipo Administrativo.
 *
 * Body esperado (opcionais; DB usa defaults quando ausentes) — OBS: preco_da_solicitacao_em_creditos
 * e validade_em_dias NÃO podem ser enviados/alterados via payload: eles serão sempre gravados como:
 *   preco_da_solicitacao_em_creditos = 1
 *   validade_em_dias = 365
 *
 * Exemplo de body:
 * {
 *   "data_estabelecimento": "2025-10-01",
 *   "preco_do_credito": 0.0123,
 *   "descricao": "texto..."
 * }
 */
router.post("/", authenticateToken, authorizeAdministrative, async (req, res) => {
  try {
    const {
      data_estabelecimento,
      preco_do_credito,
      descricao,
      // NOTA: removidos da desestruturação intencionalmente:
      // preco_da_solicitacao_em_creditos,
      // validade_em_dias,
    } = req.body;

    const data = {};

    if (data_estabelecimento !== undefined && data_estabelecimento !== null) {
      const d = new Date(data_estabelecimento);
      if (Number.isNaN(d.getTime())) {
        return res.status(400).json({ error: "data_estabelecimento inválida" });
      }
      data.data_estabelecimento = d;
    }

    if (preco_do_credito !== undefined && preco_do_credito !== null) {
      const parsed = Number(preco_do_credito);
      if (Number.isNaN(parsed)) {
        return res.status(400).json({ error: "preco_do_credito inválido" });
      }
      // enviar como string com 4 casas decimais para Decimal(10,4)
      data.preco_do_credito = parsed.toFixed(4);
    }

    if (descricao !== undefined) {
      data.descricao = descricao;
    }

    // Forçar esses dois campos conforme solicitado:
    data.preco_da_solicitacao_em_creditos = 1; // sempre registrado com 1
    data.validade_em_dias = 365;               // sempre registrado com 365 (365 dias)

    const created = await prisma.config_sistema.create({ data });

    return res.status(201).json(created);
  } catch (err) {
    console.error("Erro POST /config:", err);
    return res.status(500).json({ error: "Erro interno do servidor" });
  }
});

export default router;
