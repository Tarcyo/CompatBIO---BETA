import express from "express";
import { PrismaClient } from "@prisma/client";
import { authenticateToken } from "../middleware/auth.js";

const router = express.Router();
const prisma = new PrismaClient();

/**
 * GET /preco-credito
 * Retorna o preço mais recente do crédito.
 * Protegido por autenticação via JWT.
 */
router.get("/", authenticateToken, async (req, res) => {
  try {
    const configAtual = await prisma.config_sistema.findFirst({
      orderBy: { atualizado_em: "desc" },
      select: { preco_do_credito: true, atualizado_em: true },
    });

    if (!configAtual) {
      return res.status(404).json({ error: "Nenhum registro de configuração encontrado" });
    }

    res.json({
      preco_do_credito: configAtual.preco_do_credito,
      atualizado_em: configAtual.atualizado_em,
    });
  } catch (err) {
    console.error("Erro ao buscar preço do crédito:", err);
    res.status(500).json({ error: "Erro interno do servidor" });
  }
});

export default router;