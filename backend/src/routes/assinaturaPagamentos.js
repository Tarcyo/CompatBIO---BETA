// routes/assinaturasPagamentos.js
import express from "express";
import Stripe from "stripe";
import { PrismaClient } from "@prisma/client";
import bodyParser from "body-parser";
import { authenticateToken } from "../middleware/auth.js";
import dotenv from "dotenv";

dotenv.config();

const router = express.Router();
const prisma = new PrismaClient();

const stripeKey = process.env.STRIPE_SECRET_KEY;
if (!stripeKey) throw new Error("STRIPE_SECRET_KEY não configurada");
const stripe = new Stripe(stripeKey, { apiVersion: "2022-11-15" });

const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET || null;

// JSON parser para rotas normais (não usar global para webhook)
const jsonParser = bodyParser.json();

/* ----------------- helpers ----------------- */
function toIntId(v) {
  const n = Number(v);
  return Number.isFinite(n) && n > 0 ? Math.trunc(n) : null;
}

function logInfo(...args) {
  console.info(...args);
}

function isValidEmail(e) {
  if (!e || typeof e !== "string") return false;
  const re = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return re.test(e.trim());
}

/**
 * creditarPacotesParaAssinatura: só cria pacotes se ainda não existir pacote com a mesma origem
 * tx: prisma transaction client
 * assinaturaDb: registro de assinatura (tem id, id_dono, id_plano)
 * origem: string única representando a origem (ex: stripe:subscription:sub_...:invoice:inv_... ou ...:checkout_session:cs_...)
 * quantidadePorUsuario: inteiro
 */
async function creditarPacotesParaAssinatura(tx, assinaturaDb, origem, quantidadePorUsuario) {
  if (!origem) throw new Error("origem obrigatória");
  // checar se já há pacotes com essa origem (idempotência por origem)
  const existente = await tx.pacote_creditos.findFirst({ where: { origem } });
  if (existente) {
    logInfo("Pacote(s) já creditados para origem:", origem);
    return { skipped: true, reason: "already_credited" };
  }

  const agora = new Date();
  const ownerId = assinaturaDb.id_dono;

  const created = [];
  if (quantidadePorUsuario > 0) {
    const p = await tx.pacote_creditos.create({
      data: {
        id_usuario: ownerId,
        quantidade: quantidadePorUsuario,
        origem,
        data_recebimento: agora,
      },
    });
    created.push(p);
  }

  // encontrar vinculados e creditar
  const vinculados = await tx.usuario.findMany({
    where: { id_vinculo_assinatura: assinaturaDb.id },
    select: { id: true },
  });

  for (const v of vinculados) {
    if (quantidadePorUsuario > 0) {
      const p = await tx.pacote_creditos.create({
        data: {
          id_usuario: v.id,
          quantidade: quantidadePorUsuario,
          origem,
          data_recebimento: agora,
        },
      });
      created.push(p);
    }
  }

  // opcional: criar receita (não crítica)
  try {
    await tx.receita.create({
      data: {
        valor: 0.0,
        descricao: `Crédito via assinatura ${assinaturaDb.id} (${origem})`,
        id_usuario: ownerId,
      },
    });
  } catch (e) {
    logInfo("Falha ao criar receita (não crítica):", String(e));
  }

  return { skipped: false, createdCount: created.length, created };
}

/* ----------------- routes ----------------- */

/**
 * POST /create-subscription
 * Body: { planId, metadata?: { linked_emails: string[] | string } }
 * Auth required.
 * Returns: { url, sessionId }
 *
 * Observação:
 *  - Stripe metadata aceita apenas strings, então arrays serão serializados como string (vírgula-separada).
 *  - O webhook já possui lógica para interpretar metadata.linked_emails tanto string quanto array.
 */
router.post("/create-subscription", jsonParser, authenticateToken, async (req, res) => {
  try {
    const requesterId = toIntId(req.user && req.user.id);
    if (!requesterId) return res.status(400).json({ error: "Token sem id de usuário válido" });

    const { planId, metadata: incomingMetadata } = req.body || {};
    const planIdInt = toIntId(planId);
    if (!planIdInt) return res.status(400).json({ error: "planId inválido" });

    const plan = await prisma.plano.findUnique({ where: { id: planIdInt } });
    if (!plan) return res.status(404).json({ error: "Plano não encontrado" });

    // precisa ter stripe_price_id no DB
    if (!plan.stripe_price_id) {
      return res.status(400).json({ error: "Plano não possui stripe_price_id. Configure no DB." });
    }

    // resolver email do usuário a partir do token (se presente)
    const payload = req.user || {};
    const userEmail = payload.email || undefined;

    // tentar reusar customer na Stripe por e-mail
    let stripeCustomerId = null;
    if (userEmail) {
      try {
        const existing = await stripe.customers.list({ email: String(userEmail), limit: 1 });
        if (existing && existing.data && existing.data.length > 0) {
          stripeCustomerId = existing.data[0].id;
        }
      } catch (e) {
        logInfo("Stripe customers.list falhou:", e);
      }
    }

    const baseUrl = process.env.BASE_URL || `${req.protocol}://${req.get("host")}`;

    // --- tratar metadata enviada pelo cliente (ex.: linked_emails)
    // Permitimos:
    //  - req.body.metadata.linked_emails (array ou string)
    //  - req.body.linked_emails (array ou string)
    //  - req.body.linkedEmails (camelCase) idem
    let linkedEmailsRaw = undefined;
    if (incomingMetadata && typeof incomingMetadata === "object") {
      if (incomingMetadata.linked_emails) linkedEmailsRaw = incomingMetadata.linked_emails;
      else if (incomingMetadata.linkedEmails) linkedEmailsRaw = incomingMetadata.linkedEmails;
    }
    if (!linkedEmailsRaw) {
      if (req.body.linked_emails) linkedEmailsRaw = req.body.linked_emails;
      else if (req.body.linkedEmails) linkedEmailsRaw = req.body.linkedEmails;
    }

    let linkedEmailsNormalized = [];

    if (linkedEmailsRaw) {
      if (Array.isArray(linkedEmailsRaw)) {
        linkedEmailsNormalized = linkedEmailsRaw.map((v) => String(v).trim()).filter((v) => v.length > 0);
      } else if (typeof linkedEmailsRaw === "string") {
        // aceitar string separada por vírgula/; ou uma única string
        linkedEmailsNormalized = linkedEmailsRaw
          .split(/[,\n;]+/)
          .map((s) => String(s).trim())
          .filter((s) => s.length > 0);
      } else {
        // outros tipos: tentar converter para string
        linkedEmailsNormalized = [String(linkedEmailsRaw).trim()].filter((s) => s.length > 0);
      }

      // normalizar para lowercase e validar
      linkedEmailsNormalized = Array.from(new Set(linkedEmailsNormalized.map((e) => e.toLowerCase())));
      const invalid = linkedEmailsNormalized.filter((e) => !isValidEmail(e));
      if (invalid.length > 0) {
        return res.status(400).json({ error: "Existem emails inválidos em linked_emails", invalid: invalid.slice(0, 10) });
      }
    }

    // montar metadata que será enviada ao Stripe (string-only values)
    const metadataForStripe = {
      planId: String(plan.id),
      userId: String(requesterId),
    };

    if (linkedEmailsNormalized.length > 0) {
      // serializar como CSV simples (webhook já suporta parse de string CSV)
      metadataForStripe.linked_emails = linkedEmailsNormalized.join(",");
      // adicionalmente, para compatibilidade com possíveis parsers, também podemos fornecer variante camelCase
      metadataForStripe.linkedEmails = linkedEmailsNormalized.join(",");
    }

    const sessionParams = {
      mode: "subscription",
      line_items: [
        {
          price: plan.stripe_price_id,
          quantity: 1,
        },
      ],
      // sucesso/cancel devem apontar para o mount /pagamentosDeAssinaturas
      success_url: `${baseUrl}/pagamentosDeAssinaturas/success?session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: `${baseUrl}/pagamentosDeAssinaturas/cancel`,
      subscription_data: {
        metadata: metadataForStripe,
      },
      // também incluir metadata no nível da session (opcional, mas útil)
      metadata: metadataForStripe,
      customer: stripeCustomerId || undefined,
      customer_email: stripeCustomerId ? undefined : (userEmail || undefined),
      payment_method_types: ["card"],
      allow_promotion_codes: true,
    };

    // criar session no Stripe
    const session = await stripe.checkout.sessions.create(sessionParams);

    // retornar url e sessionId para o front
    return res.json({ url: session.url, sessionId: session.id });
  } catch (err) {
    console.error("Erro create-subscription:", err);
    return res.status(500).json({ error: "internal_error" });
  }
});

/**
 * POST /cancel-subscription
 * Body: { subscriptionId || assinaturaId, at_period_end }
 */
router.post("/cancel-subscription", jsonParser, authenticateToken, async (req, res) => {
  try {
    const requesterId = toIntId(req.user && req.user.id);
    if (!requesterId) return res.status(400).json({ error: "Token sem id de usuário válido" });

    const { subscriptionId, assinaturaId, at_period_end = true } = req.body;
    let assinatura = null;

    if (assinaturaId) {
      const aid = toIntId(assinaturaId);
      if (!aid) return res.status(400).json({ error: "assinaturaId inválido" });
      assinatura = await prisma.assinatura.findUnique({ where: { id: aid } });
      if (!assinatura) return res.status(404).json({ error: "Assinatura não encontrada" });
    } else if (subscriptionId) {
      assinatura = await prisma.assinatura.findUnique({ where: { stripe_subscription_id: subscriptionId } });
      if (!assinatura) return res.status(404).json({ error: "Assinatura não encontrada (por subscriptionId)" });
    } else {
      return res.status(400).json({ error: "Forneça assinaturaId ou subscriptionId" });
    }

    // Só dono pode cancelar
    if (assinatura.id_dono !== requesterId) {
      return res.status(403).json({ error: "Apenas o dono pode cancelar a assinatura" });
    }

    if (!assinatura.stripe_subscription_id) {
      const updated = await prisma.assinatura.update({
        where: { id: assinatura.id },
        data: { ativo: false, status: "canceled", canceled_at: new Date() },
      });
      return res.json({ ok: true, local: true, assinatura: updated });
    }

    if (at_period_end) {
      const sub = await stripe.subscriptions.update(assinatura.stripe_subscription_id, { cancel_at_period_end: true });
      const updated = await prisma.assinatura.update({
        where: { id: assinatura.id },
        data: {
          cancel_at_period_end: true,
          status: sub.status ?? "cancel_at_period_end",
          current_period_end: sub.current_period_end ? new Date(sub.current_period_end * 1000) : null,
        },
      });
      return res.json({ ok: true, stripe: sub, assinatura: updated });
    } else {
      const sub = await stripe.subscriptions.del(assinatura.stripe_subscription_id);
      const updated = await prisma.assinatura.update({
        where: { id: assinatura.id },
        data: { ativo: false, status: sub.status ?? "canceled", canceled_at: new Date(), cancel_at_period_end: false },
      });
      return res.json({ ok: true, stripe: sub, assinatura: updated });
    }
  } catch (err) {
    console.error("Erro cancel-subscription:", err);
    return res.status(500).json({ error: "internal_error" });
  }
});

/* ----------------- Success page + client JS ----------------- */

/**
 * GET /success
 * Página estática que o Stripe redireciona após checkout.
 * A página fará polling em /last-transaction-json para detectar conclusão.
 */
router.get("/success", (req, res) => {
  // Mantive a checagem básica do session_id (opcional)
  const sessionId = req.query.session_id;
  if (!sessionId) return res.status(400).send("<h2>session_id ausente.</h2>");

  const html = `
  <!doctype html>
  <html lang="pt-BR">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width,initial-scale=1">
      <title>Assinatura realizada — Obrigado</title>
      <style>
        body{font-family:system-ui,Arial;margin:40px;background:#0b1220;color:#e6eef8}
        .card{max-width:880px;margin:0 auto;padding:28px;border-radius:12px;background:rgba(255,255,255,0.02);text-align:center}
        h1{margin:0;font-size:1.5rem}
        .muted{color:#9aa4b2;margin-top:8px}
      </style>
    </head>
    <body>
      <div class="card" role="region" aria-live="polite">
        <h1>Assinatura realizada com sucesso!</h1>
      </div>
    </body>
  </html>
  `;
  res.setHeader("Content-Type", "text/html; charset=utf-8");
  res.send(html);
});

/**
 * GET /cancel
 */
router.get("/cancel", (_req, res) => res.send("<h2>Assinatura cancelada ou checkout abortado.</h2>"));

/**
 * GET /last-transaction-json
 * - ?sessionId=... (checkout session id) optional
 * Retorna um JSON mínimo para a página de sucesso detectar confirmação.
 */
router.get("/last-transaction-json", async (req, res) => {
  const sessionIdQuery = req.query.sessionId || req.query.session_id;
  try {
    if (sessionIdQuery) {
      const sessionId = String(sessionIdQuery);

      // 1) procurar assinatura conectada a esta session (via stripe_event payload stored)
      // Procurar em stripe_event payloads recentes por ocorrência do sessionId
      const recentEvents = await prisma.stripe_event.findMany({
        orderBy: [{ id: "desc" }],
        take: 300,
        select: { id: true, event_id: true, payload: true, received_at: true },
      });

      for (const ev of recentEvents) {
        try {
          const payload = ev.payload || {};
          const obj = (payload.data && payload.data.object) || payload.object || null;
          if (obj) {
            // checar campos possíveis
            const candidateIds = [
              obj.id,
              obj.session_id,
              obj.checkout_session_id,
              obj.subscription,
              (obj.lines && obj.lines.data && obj.lines.data[0] && obj.lines.data[0].id)
            ].filter(Boolean).map(String);

            // também stringify payload to search for sessionId appearence (fallback)
            const strPayload = JSON.stringify(payload || {});
            if (candidateIds.includes(sessionId) || strPayload.includes(sessionId)) {
              // tentar extrair subscriptionId / amount
              const subscriptionId = obj.subscription || obj.checkout_session || null;
              const amountTotal = (obj.amount_total ?? obj.amount ?? obj.amount_received) || null;
              const amountMajor = amountTotal != null ? Number(amountTotal) / 100.0 : null;
              return res.json({
                sessionId,
                subscriptionId: subscriptionId,
                amount: amountMajor != null ? Number(typeof amountMajor.toFixed === "function" ? amountMajor.toFixed(2) : amountMajor) : null,
                receivedAt: ev.received_at || null,
                note: "from_stripe_event_fallback",
              });
            }
          }
        } catch (e) {
          // ignore parsing error
        }
      }

      // 2) fallback: procurar compra/assinatura local que contenha session id nos logs/descricao
      // procurar em assinatura (descrição não existe) -> procurar em pacotes_creditos com origem contendo sessionId
      const pacote = await prisma.pacote_creditos.findFirst({
        where: { origem: { contains: sessionId } },
        orderBy: [{ id: "desc" }],
      });
      if (pacote) {
        return res.json({
          sessionId,
          amount: null,
          receivedAt: pacote.data_recebimento || null,
          note: "from_local_pacote_creditos",
        });
      }

      return res.json(null);
    } else {
      // sem sessionId -> retornar última assinatura criada (útil para debug)
      const t = await prisma.assinatura.findFirst({ orderBy: [{ id: "desc" }], take: 1 });
      if (!t) return res.json(null);
      return res.json({
        subscriptionId: t.stripe_subscription_id,
        planId: t.id_plano,
        ownerId: t.id_dono,
        status: t.status || null,
        current_period_end: t.current_period_end || null,
      });
    }
  } catch (err) {
    console.error("Erro em /last-transaction-json:", err);
    return res.status(500).json({ error: "internal_error" });
  }
});

export default router;
