// routes/cancelarAssinatura.js
import express from "express";
import Stripe from "stripe";
import { PrismaClient } from "@prisma/client";
import bodyParser from "body-parser";
import dotenv from "dotenv";
import { authenticateToken } from "../middleware/auth.js";

dotenv.config();

const router = express.Router();
const prisma = new PrismaClient();

const stripeKey = process.env.STRIPE_SECRET_KEY;
if (!stripeKey) {
  throw new Error("STRIPE_SECRET_KEY não configurada");
}
// Ajuste apiVersion se desejar
const stripe = new Stripe(stripeKey, { apiVersion: "2023-08-16" });

const jsonParser = bodyParser.json();

/**
 * POST /assinaturas/cancelar
 * Body: { assinaturaId?: number, subscriptionId?: string, immediate?: boolean }
 * Auth required (authenticateToken must set req.user.id).
 *
 * Regras:
 *  - Pode fornecer assinaturaId (preferível) ou subscriptionId (stripe_subscription_id).
 *  - Apenas o dono (assinatura.id_dono) pode cancelar.
 *  - Se assinatura tiver stripe_subscription_id, tentamos cancelar no Stripe.
 *    - Se Stripe não reconhecer a subscription (resource_missing), prosseguimos localmente.
 *    - Se Stripe apresentar erro transitório, retornamos 502 e NÃO alteramos o DB.
 *  - Após sucesso (ou ausência de subscription), atualizamos localmente dentro de transação:
 *    - assinatura.ativo = false, status = "cancelado", canceled_at = now(), cancel_at_period_end = false
 *    - para todos usuario com id_vinculo_assinatura = assinatura.id => id_vinculo_assinatura = null
 *    - criar logs_usuario para cada usuário desvinculado (createMany)
 */
router.post("/cancelar", jsonParser, authenticateToken, async (req, res) => {
  try {
    const requesterIdRaw = req.user && req.user.id;
    const requesterId = Number(requesterIdRaw);
    if (!requesterId || Number.isNaN(requesterId)) {
      return res.status(400).json({ error: "Token sem id de usuário válido" });
    }

    const { assinaturaId, subscriptionId, immediate = true } = req.body || {};

    if (!assinaturaId && !subscriptionId) {
      return res.status(400).json({ error: "Forneça assinaturaId ou subscriptionId" });
    }

    // localizar assinatura localmente
    let assinatura = null;
    if (assinaturaId) {
      const aid = Number(assinaturaId);
      if (!aid || Number.isNaN(aid)) return res.status(400).json({ error: "assinaturaId inválido" });
      assinatura = await prisma.assinatura.findUnique({ where: { id: aid } });
    } else {
      // busca por stripe_subscription_id (único)
      assinatura = await prisma.assinatura.findUnique({ where: { stripe_subscription_id: String(subscriptionId) } });
    }

    if (!assinatura) {
      return res.status(404).json({ error: "Assinatura não encontrada" });
    }

    // autorização: apenas dono pode cancelar
    if (assinatura.id_dono !== requesterId) {
      return res.status(403).json({ error: "Apenas o dono pode cancelar a assinatura" });
    }

    // idempotência: se já cancelado localmente, retorna ok
    const alreadyCancelledLocal =
      !assinatura.ativo || (assinatura.status && String(assinatura.status).toLowerCase() === "cancelado");

    if (alreadyCancelledLocal) {
      return res.json({ ok: true, note: "already_cancelled_local", assinatura });
    }

    // 1) Tentar cancelar no Stripe (se aplicável) ANTES de tocar o DB
    const stripeSubId = assinatura.stripe_subscription_id || null;
    let stripeResponse = null;
    if (stripeSubId) {
      try {
        const subscriptionsApi = stripe.subscriptions;

        if (immediate) {
          // deletar/immediate
          if (subscriptionsApi && typeof subscriptionsApi.del === "function") {
            stripeResponse = await subscriptionsApi.del(String(stripeSubId));
          } else if (subscriptionsApi && typeof subscriptionsApi.cancel === "function") {
            stripeResponse = await subscriptionsApi.cancel(String(stripeSubId));
          } else if (typeof stripe.request === "function") {
            // fallback para SDK que suporta request
            stripeResponse = await stripe.request({
              method: "DELETE",
              path: `/v1/subscriptions/${encodeURIComponent(String(stripeSubId))}`,
            });
          } else {
            throw new Error("Stripe client não possui método conhecido para deletar subscription. Atualize o SDK.");
          }
        } else {
          // marcar para cancelar ao final do período
          if (subscriptionsApi && typeof subscriptionsApi.update === "function") {
            stripeResponse = await subscriptionsApi.update(String(stripeSubId), { cancel_at_period_end: true });
          } else if (typeof stripe.request === "function") {
            stripeResponse = await stripe.request({
              method: "POST",
              path: `/v1/subscriptions/${encodeURIComponent(String(stripeSubId))}`,
              body: new URLSearchParams({ cancel_at_period_end: "true" }).toString(),
            });
          } else {
            throw new Error("Stripe client não possui método conhecido para atualizar subscription. Atualize o SDK.");
          }
        }
      } catch (err) {
        // log detalhado
        console.warn("Stripe cancel error:", err && (err.message || err.type) ? (err.message || err.type) : String(err));

        // detectar subscription inexistente no Stripe
        const isNotFound =
          (err && (err.code === "resource_missing" || err.type === "StripeInvalidRequestError")) ||
          (err && typeof err.message === "string" && /No such subscription/i.test(err.message));

        if (!isNotFound) {
          // erro real (timeout/5xx) => abortar para evitar inconsistência local
          return res.status(502).json({ error: "stripe_error", message: String(err?.message ?? err) });
        } else {
          // se não encontrado, prosseguir com cancelamento local (registro informativo)
          stripeResponse = { note: "stripe_subscription_not_found", subscriptionId: stripeSubId };
          console.info("Stripe subscription not found, proceeding with local cancellation for:", stripeSubId);
        }
      }
    }

    // 2) Atualizar DB localmente dentro de transação (apenas operações locais)
    let updatedAssinatura = null;
    let desvinculados = [];
    try {
      await prisma.$transaction(async (tx) => {
        const now = new Date();

        // atualizar assinatura
        updatedAssinatura = await tx.assinatura.update({
          where: { id: assinatura.id },
          data: {
            ativo: false,
            status: "cancelado",
            canceled_at: now,
            cancel_at_period_end: false,
            // você pode opcionalmente atualizar stripe_customer_id/stripe_price_id se desejar
          },
        });

        // buscar usuários vinculados (inclui dono) antes de update para logs e retorno
        const vinculados = await tx.usuario.findMany({
          where: { id_vinculo_assinatura: assinatura.id },
          select: { id: true, nome: true, email: true },
        });

        if (vinculados && vinculados.length > 0) {
          desvinculados = vinculados;

          // desvincular em lote
          await tx.usuario.updateMany({
            where: { id_vinculo_assinatura: assinatura.id },
            data: { id_vinculo_assinatura: null },
          });

          // criar logs em massa (createMany) -> cuidado com DBs que não suportam createMany com relacionamentos complexos
          const logsData = vinculados.map((u) => ({
            id_do_usuario: u.id,
            acao_no_sistema: `Vinculo removido devido ao cancelamento da assinatura ${assinatura.id} por usuário ${requesterId}`,
            data_acao: new Date(),
          }));

          // createMany pode falhar em alguns dialects se constraints existirem; capturamos erro lá se necessário
          await tx.logs_usuario.createMany({ data: logsData });
        }
      });
    } catch (e) {
      console.error("Erro aplicando alterações no DB após cancelamento Stripe:", e?.message ?? e);
      // Se Stripe já cancelou e DB falhou, precisamos indicar reconciliação manual
      return res.status(500).json({
        error: "db_update_failed",
        message: "Assinatura foi cancelada no Stripe (ou não tinha subscription), mas falha ao atualizar o banco. Requerer reconciliação manual.",
        stripe: stripeResponse,
        dbError: String(e?.message ?? e),
      });
    }

    // 3) Responder com sucesso
    return res.json({
      ok: true,
      note: "cancelled",
      stripe: stripeResponse,
      assinatura: updatedAssinatura,
      desvinculados,
    });
  } catch (err) {
    console.error("Erro na rota /assinaturas/cancelar:", err?.message ?? err);
    return res.status(500).json({ error: "internal_error", message: String(err?.message ?? err) });
  }
});

export default router;
