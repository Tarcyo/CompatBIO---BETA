import express from "express";
import { PrismaClient } from "@prisma/client";
import { authenticateToken } from "../middleware/auth.js";

const router = express.Router();
const prisma = new PrismaClient();

// todas as rotas aqui exigem autenticação
router.use(authenticateToken);

/**
 * POST /creditos
 * Body: { quantidade: number }
 * Permite que o usuário autenticado compre créditos.
 * - lê o preço por crédito no registro de config_sistema com MAIOR id
 * - calcula preço total = preco_do_credito * quantidade
 * - registra uma compra na tabela `compra` com a descrição:
 *   ( usuário <nome> comprou <quantidade> por <preco_do_credito> a unidade )
 * - cria também um pacote_creditos para creditar o usuário (origem: compra)
 * - cria um registro em `receita` com o valor total e descrição com o nome do usuário
 */
router.post("/creditos", async (req, res) => {
  try {
    const userId = (req.user && (req.user.id || req.user.userId || req.user.sub)) ?? null;
    if (!userId) return res.status(400).json({ error: "User id não encontrado no token" });

    const { quantidade } = req.body;
    const quantidadeNum = Number(quantidade);
    if (!quantidade || !Number.isFinite(quantidadeNum) || quantidadeNum <= 0) {
      return res.status(400).json({ error: "quantidade inválida" });
    }

    const compraResult = await prisma.$transaction(async (tx) => {
      // buscar configuração com MAIOR id (registro mais recente)
      const config = await tx.config_sistema.findFirst({
        orderBy: { id: "desc" }
      });

      if (!config) throw new Error("Configuração do sistema não encontrada (preço do crédito)");

      // obter preço unitário como string (preserva precisão do Decimal)
      const precoUnitStr = config.preco_do_credito?.toString?.() ?? String(config.preco_do_credito);
      const precoUnitNum = parseFloat(precoUnitStr);
      const total = precoUnitNum * quantidadeNum;
      // ajustar para 2 casas decimais (campo compra.valor_pago é Decimal(10,2))
      const totalStr = total.toFixed(2);

      const usuario = await tx.usuario.findUnique({ where: { id: Number(userId) } });
      if (!usuario) throw new Error("Usuário não encontrado");

      // criar registro de compra
      const compra = await tx.compra.create({
        data: {
          id_usuario: Number(userId),
          valor_pago: totalStr,
          descricao: `( usuário ${usuario.nome} comprou ${quantidadeNum} por ${precoUnitStr} a unidade )`
        }
      });

      // creditar os créditos ao usuário (pacote_creditos)
      await tx.pacote_creditos.create({
        data: {
          id_usuario: Number(userId),
          quantidade: quantidadeNum,
          origem: `compra_creditos_${compra.id}`
        }
      });

      // registrar receita com o valor total e descrição com o nome do usuário
      await tx.receita.create({
        data: {
          valor: totalStr,
          descricao: `Compra de créditos - usuário ${usuario.nome}`,
          id_usuario: Number(userId)
        }
      });

      return { compra, preco_unitario: precoUnitStr, quantidade: quantidadeNum, total: totalStr };
    });

    return res.json({
      mensagem: "Compra realizada com sucesso",
      compra: {
        id: compraResult.compra.id,
        id_usuario: compraResult.compra.id_usuario,
        valor_pago: compraResult.total,
        descricao: compraResult.compra.descricao
      },
      detalhes: {
        quantidade: compraResult.quantidade,
        preco_unitario: compraResult.preco_unitario,
        total: compraResult.total
      }
    });
  } catch (error) {
    console.error("Erro ao processar compra de créditos:", error);
    return res.status(500).json({ error: "Erro ao processar compra de créditos" });
  }
});

export default router;
