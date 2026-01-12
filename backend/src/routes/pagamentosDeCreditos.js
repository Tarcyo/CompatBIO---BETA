import dotenv from "dotenv";
dotenv.config();

import express from "express";
import cors from "cors";
import helmet from "helmet";
import rateLimit from "express-rate-limit";
import Stripe from "stripe";
import { PrismaClient } from "@prisma/client";
import jwt from "jsonwebtoken";
import winston from "winston";
import bodyParser from "body-parser";

const prisma = new PrismaClient();
const router = express.Router();

// segurança básica
router.use(helmet());

// CORS restrito (defina FRONTEND_ORIGINS no .env como CSV)
const allowedOrigins = (process.env.FRONTEND_ORIGINS || "")
  .split(",")
  .map((s) => s.trim())
  .filter(Boolean);
router.use(
  cors({
    origin: function (origin, cb) {
      if (!origin) return cb(null, true); // allow server-to-server or curl (ajuste se quiser stricter)
      if (allowedOrigins.length === 0) return cb(null, false);
      if (allowedOrigins.includes(origin)) return cb(null, true);
      return cb(new Error("CORS not allowed"));
    },
    credentials: true,
  })
);

// rate limiting
const limiter = rateLimit({
  windowMs: process.env.RATE_LIMIT_WINDOW_MS
    ? Number(process.env.RATE_LIMIT_WINDOW_MS)
    : 60 * 1000,
  max: process.env.RATE_LIMIT_MAX ? Number(process.env.RATE_LIMIT_MAX) : 30,
});
router.use(limiter);

// Logger (winston)
const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || "info",
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.printf(
      ({ level, message, timestamp }) => `${timestamp} ${level}: ${message}`
    )
  ),
  transports: [new winston.transports.Console()],
});

// Redact profundo e seguro (recursivo, case-insensitive)
const SENSITIVE_KEYS = [
  "senha",
  "password",
  "token",
  "authorization",
  "card",
  "cvc",
  "cvv",
  "number",
  "ssn",
  "cpf",
  "secret",
  "api_key",
];

function redactDeep(obj) {
  if (obj == null) return obj;
  if (Array.isArray(obj)) return obj.map(redactDeep);
  if (typeof obj === "object") {
    const out = {};
    for (const [k, v] of Object.entries(obj)) {
      const lower = k.toLowerCase();
      const shouldRedact = SENSITIVE_KEYS.some((sk) => lower.includes(sk));
      if (shouldRedact) {
        out[k] = "[REDACTED]";
      } else {
        try {
          out[k] = redactDeep(v);
        } catch {
          out[k] = "[UNSAFE_TO_LOG]";
        }
      }
    }
    return out;
  }
  return obj;
}

function safeLog(msg, obj) {
  try {
    if (obj && typeof obj === "object") {
      const copy = redactDeep(obj);
      logger.info(`${msg} ${JSON.stringify(copy)}`);
      return;
    }
  } catch (e) {
    // fallback
  }
  logger.info(msg);
}

// Stripe init
const stripeKey = process.env.STRIPE_SECRET_KEY;
if (!stripeKey || !stripeKey.startsWith("sk_")) {
  logger.error("STRIPE_SECRET_KEY ausente ou inválida. Defina no .env e reinicie.");
}
const stripe = stripeKey ? new Stripe(stripeKey, { apiVersion: "2022-11-15" }) : null;
const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET || null;

// security: require webhook secret in production
if (process.env.NODE_ENV === "production" && !webhookSecret) {
  logger.error("STRIPE_WEBHOOK_SECRET é obrigatório em PRODUCTION. Abortando.");
  throw new Error("Missing STRIPE_WEBHOOK_SECRET in production");
}

// JSON parser para rotas normais (não usar global para webhook)
const jsonParser = bodyParser.json();

// ----------------- middlewares de auth (exemplos seguros) -----------------
export async function authenticateToken(req, res, next) {
  try {
    const auth = req.headers.authorization;
    if (!auth || !auth.startsWith("Bearer "))
      return res.status(401).json({ error: "missing_token" });
    const token = auth.slice(7);
    const secret = process.env.JWT_SECRET;
    if (!secret) return res.status(500).json({ error: "server_misconfigured" });
    let payload;
    try {
      payload = jwt.verify(token, secret);
    } catch (e) {
      return res.status(401).json({ error: "invalid_token" });
    }
    req.user = payload;
    next();
  } catch (err) {
    logger.warn("authenticateToken error: " + String(err));
    return res.status(500).json({ error: "internal_error" });
  }
}

export function authorizeAdministrative(req, res, next) {
  const payload = req.user || {};
  const role = payload.role || payload.tipo_usuario || "";
  if (role !== "admin" && role !== "super") {
    return res.status(403).json({ error: "forbidden" });
  }
  next();
}
// -------------------------------------------------------------------------

// helpers
const nowIso = () => new Date().toISOString();
function escapeHtml(str) {
  if (str == null) return "";
  return String(str).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

// health
router.get("/health", (_req, res) => res.send("ok"));

/**
 * Success page - redesigned: external script only (no inline script), modern UI.
 */
router.get("/success", (req, res) => {
  const sessionId = req.query.session_id;
  if (!sessionId) return res.status(400).send("<h2>session_id ausente.</h2>");

  const baseUrl = process.env.BASE_URL || `${req.protocol}://${req.get("host")}`;
  const pollBase = baseUrl + "/pagamentos/last-transaction-json";

  const html = `
  <!doctype html>
  <html lang="pt-BR">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width,initial-scale=1">
      <title>Pagamento iniciado — Obrigado</title>
      <link rel="preconnect" href="https://fonts.googleapis.com">
      <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
      <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;600;700;800&display=swap" rel="stylesheet">
      <style>
        :root{
          --bg1: #0f172a; /* deep navy */
          --bg2: #071033; /* darker */
          --card:#0b1220;
          --muted:#9aa4b2;
          --accent:linear-gradient(135deg,#7c3aed 0%,#06b6d4 100%);
        }
        html,body{height:100%;}
        body{
          margin:0; font-family: Inter, system-ui, -apple-system, 'Segoe UI', Roboto, 'Helvetica Neue', Arial; 
          background: radial-gradient(1200px 600px at 10% 10%, rgba(124,58,237,0.12), transparent 8%),
                      radial-gradient(900px 500px at 100% 100%, rgba(6,182,212,0.08), transparent 10%),
                      linear-gradient(180deg,var(--bg1),var(--bg2));
          color:#e6eef8; -webkit-font-smoothing:antialiased; -moz-osx-font-smoothing:grayscale;
          display:flex; align-items:center; justify-content:center; padding:32px;
        }
        .card{
          width:100%; max-width:920px; background: linear-gradient(180deg, rgba(255,255,255,0.02), rgba(255,255,255,0.01));
          border-radius:16px; box-shadow: 0 10px 30px rgba(2,6,23,0.6); padding:28px; border:1px solid rgba(255,255,255,0.03);
          display:grid; grid-template-columns: 1fr 360px; gap:24px; align-items:center;
        }
        @media (max-width:880px){ .card{ grid-template-columns: 1fr; padding:20px;} }

        .left h1{ margin:0; font-size:28px; letter-spacing:-0.02em; }
        .left p.lead{ color:var(--muted); margin:10px 0 18px; font-size:15px }

        .statusBox{ display:flex; gap:16px; align-items:center; }
        .checkWrap{ width:86px; height:86px; border-radius:18px; background:linear-gradient(180deg, rgba(255,255,255,0.02), rgba(255,255,255,0.00)); display:flex; align-items:center; justify-content:center; box-shadow: inset 0 -6px 18px rgba(2,6,23,0.6); }
        .check{ width:56px; height:56px; }
        .statusText{ font-weight:600; font-size:18px; }
        .muted{ color:var(--muted); font-size:14px; }

        .details{ margin-top:10px; background:rgba(255,255,255,0.02); padding:12px 14px; border-radius:12px; color:var(--muted); font-size:14px }

        .right{ text-align:center; }
        .card .right .box{ background: linear-gradient(180deg, rgba(255,255,255,0.015), rgba(255,255,255,0.008)); border-radius:12px; padding:16px; }
        .amount{ font-size:28px; font-weight:700; margin:8px 0; }
        .receivedAt{ font-size:13px; color:var(--muted); }

        .actions{ display:flex; gap:10px; margin-top:18px; justify-content:center; }
        .btn{ padding:10px 14px; border-radius:10px; border:0; background:transparent; color:inherit; cursor:pointer; font-weight:600 }
        .btn.primary{ background: linear-gradient(90deg,#7c3aed,#06b6d4); color:white; box-shadow: 0 6px 20px rgba(12,18,38,0.6); }
        .btn.ghost{ border:1px solid rgba(255,255,255,0.06); }

        .progress{ height:8px; background: rgba(255,255,255,0.04); border-radius:999px; overflow:hidden; margin-top:12px; }
        .progress > i{ display:block; height:100%; width:0%; background: linear-gradient(90deg,#7c3aed,#06b6d4); transition: width 600ms cubic-bezier(.2,.9,.2,1); }

        #debug{ margin-top:10px; font-size:12px; color:#93a1b0; display:none; }

        a.small{ color:inherit; font-size:13px; text-decoration:underline; }

        /* Checkmark animation */
        .svg-check path{ stroke-dasharray: 1000; stroke-dashoffset: 1000; animation: draw 800ms ease forwards; }
        @keyframes draw { to { stroke-dashoffset: 0; } }

      </style>
    </head>
    <body data-session-id="${escapeHtml(String(sessionId))}" data-poll-base="${escapeHtml(pollBase)}">
      <div class="card" role="region" aria-label="Status do pagamento">
        <div class="left">
          <div class="statusBox">
            <div class="checkWrap" aria-hidden="true">
              <svg class="check svg-check" viewBox="0 0 64 64" width="56" height="56" fill="none" xmlns="http://www.w3.org/2000/svg">
                <rect x="1" y="1" width="62" height="62" rx="12" stroke="rgba(255,255,255,0.04)" stroke-width="2"/>
                <path d="M18 34 L28.5 44 L46 22" stroke="url(#g)" stroke-width="4" stroke-linecap="round" stroke-linejoin="round" />
                <defs>
                  <linearGradient id="g" x1="0" x2="1">
                    <stop offset="0" stop-color="#7c3aed"/>
                    <stop offset="1" stop-color="#06b6d4"/>
                  </linearGradient>
                </defs>
              </svg>
            </div>
            <div>
              <div class="statusText" id="status">Aguardando confirmação</div>
              <div class="muted">A confirmação final virá automaticamente pelo webhook.</div>
            </div>
          </div>

          <p class="lead">Obrigado pela sua compra! A confirmação é automática — em alguns segundos o sistema mostrará o status final.</p>

          <div class="details" id="details">Sessão: <strong id="sessionIdShort">${escapeHtml(String(sessionId))}</strong></div>

          <div class="progress" aria-hidden="true">
            <i id="progressBar"></i>
          </div>

          <div style="margin-top:14px; display:flex; gap:8px; align-items:center;">
            <button class="btn primary" id="done">voltar para o inicio</button>
            <a class="small" href="/" style="margin-left:auto">Voltar ao site</a>
          </div>

          <div id="debug"></div>
        </div>

        <div class="right">
          <div class="box">
            <div style="font-size:12px; color:var(--muted);">Resumo</div>
            <div class="amount" id="amount">—</div>
            <div class="receivedAt" id="receivedAt">Nenhuma confirmação ainda</div>
            <div style="margin-top:10px; font-size:13px; color:var(--muted);">Se algo parecer errado, contate o suporte com o ID da sessão acima.</div>
            <div class="actions">
              <button class="btn primary" id="done">voltar para o inicio</button>
            </div>
          </div>
        </div>
      </div>

      <!-- script externo (mesma origin) -->
      <script src="/pagamentos/success.js" defer></script>
    </body>
  </html>
  `;
  res.setHeader("Content-Type", "text/html; charset=utf-8");
  res.send(html);
});

router.get("/success.js", (req, res) => {
  const js = `
  (function(){
    'use strict';

    // Mensagem simples de sucesso
    const messageHTML = '<div style="text-align:center;padding:28px;font-family:system-ui,Arial;color:#e6eef8">' +
                        '<h1 style="margin:0 0 8px;font-size:1.5rem">Assinatura realizada com sucesso!</h1>' +
                        '</div>';

    // Tenta encontrar um card existente
    const card = document.querySelector('.card') || document.getElementById('card');

    if (card) {
      // Substitui conteúdo do card e garante atributos de acessibilidade
      card.innerHTML = messageHTML;
      card.setAttribute('role', 'status');
      card.setAttribute('aria-live', 'polite');
    } else {
      // Caso não exista, cria um card com estilos mínimos e insere no body
      const newCard = document.createElement('div');
      newCard.className = 'card';
      newCard.setAttribute('role', 'status');
      newCard.setAttribute('aria-live', 'polite');
      newCard.innerHTML = messageHTML;

      // Estilos inline para manter aparência consistente mesmo sem CSS
      newCard.style.maxWidth = '880px';
      newCard.style.margin = '40px auto';
      newCard.style.padding = '28px';
      newCard.style.borderRadius = '12px';
      newCard.style.background = 'rgba(255,255,255,0.02)';

      document.body.appendChild(newCard);
    }

    // Remove elementos de interface antigos caso existam (opcional, não lança erro se não existirem)
    ['#status', '#details', '#amount', '#receivedAt', '#progressBar', '#checkNow', '#openReceipt', '#done', '#debug']
      .forEach(sel => {
        try {
          const el = document.querySelector(sel);
          if (el && el.parentNode) el.parentNode.removeChild(el);
        } catch (e) { /* ignore */ }
      });

  })();
  `;
  res.setHeader("Content-Type", "application/javascript; charset=utf-8");
  res.send(js);
});


// notify (UX telemetry)
router.post("/notify", jsonParser, (req, res) => {
  const { session_id } = req.body || {};
  safeLog("[notify] Cliente chegou à /success para session_id", { session_id, at: nowIso() });
  return res.json({ ok: true, message: "Notificação recebida. Confirmação final será pelo webhook." });
});

// admin refund (protegido)
// NOTE: amount (se fornecido) deve ser em CENTAVOS (integer). Se quiser passar reais como decimal,
// passe "amount_major" e converteremos abaixo (nunca confundir).
router.post(
  "/admin/refund",
  jsonParser,
  authenticateToken,
  authorizeAdministrative,
  async (req, res) => {
    try {
      const { localOrderId, sessionId, amount, amount_major } = req.body || {};
      if (!localOrderId && !sessionId)
        return res.status(400).json({ error: "Informe localOrderId ou sessionId" });

      let tx = null;
      if (sessionId) {
        tx = await prisma.compra.findFirst({ where: { stripe_session_id: sessionId } });
      }
      if (!tx && localOrderId) {
        tx = await prisma.compra.findFirst({
          where: { descricao: { contains: String(localOrderId) } },
          orderBy: [{ id: "desc" }],
        });
      }

      if (!tx) return res.status(404).json({ error: "Transação não encontrada." });

      const paymentIntentId = tx.payment_intent_id || null;
      if (!paymentIntentId)
        return res
          .status(400)
          .json({ error: "Nenhum payment_intent associado. Impossível processar refund automaticamente." });

      if (!stripe) return res.status(500).json({ error: "Stripe não configurado" });

      // Determinar amount em centavos se fornecido
      let refundParams = { payment_intent: paymentIntentId, reason: "requested_by_customer" };
      if (typeof amount !== "undefined" && amount !== null) {
        // Preferir amount explicitamente em centavos (integer)
        const amt = Number(amount);
        if (!Number.isInteger(amt) || amt <= 0) {
          return res.status(400).json({ error: "amount deve ser inteiro (centavos) e > 0" });
        }
        refundParams.amount = amt;
      } else if (typeof amount_major !== "undefined" && amount_major !== null) {
        // aceitar amount_major (reais) como número decimal
        const am = Number(amount_major);
        if (Number.isNaN(am) || am <= 0) {
          return res.status(400).json({ error: "amount_major inválido" });
        }
        refundParams.amount = Math.round(am * 100);
      }

      // recuperar payment intent para validar
      const pi = await stripe.paymentIntents.retrieve(paymentIntentId).catch((e) => {
        throw e;
      });

      // se já tem charges, preferimos criar refund para charge (Stripe aceita refund com payment_intent)
      // aqui permitimos refund parcial se refundParams.amount foi setado
      const refund = await stripe.refunds.create(refundParams);
      return res.json({ ok: true, action: "refund.created", refund });
    } catch (err) {
      logger.error("Erro em /admin/refund: " + String(err));
      return res.status(500).json({ error: "internal_error" });
    }
  }
);

// last-transaction (admin)
router.get("/last-transaction", authenticateToken, authorizeAdministrative, async (_req, res) => {
  const t = await prisma.compra.findFirst({ orderBy: [{ id: "desc" }], take: 1 });
  const html = `
    <html><head><meta charset="utf-8"><title>Última transação</title></head>
    <body style="font-family: Arial, sans-serif; max-width:900px; margin:30px auto;">
      <h1>Última transação confirmada</h1>
      ${t ? `<ul>
        <li><strong>localOrderId:</strong> ${escapeHtml(t.descricao || "")}</li>
        <li><strong>checkoutSessionId:</strong> ${escapeHtml(t.stripe_session_id || "")}</li>
        <li><strong>paymentIntentId:</strong> ${escapeHtml(t.payment_intent_id || "")}</li>
        <li><strong>amount:</strong> ${t.valor_pago != null ? Number(t.valor_pago).toFixed(2) : '—'}</li>
      </ul>` : `<p>Nenhuma transação confirmada ainda.</p>`}
      <p><a href="/health">Health</a></p>
    </body></html>
  `;
  res.setHeader("Content-Type", "text/html; charset=utf-8");
  res.send(html);
});

/**
 * last-transaction-json
 */
router.get("/last-transaction-json", async (req, res) => {
  const sessionIdQuery = req.query.sessionId || req.query.session_id;
  try {
    if (sessionIdQuery) {
      const sessionId = String(sessionIdQuery);

      // 1) procura compra no DB
      const t = await prisma.compra.findFirst({ where: { stripe_session_id: sessionId } });
      if (t) {
        return res.json({
          sessionId: t.stripe_session_id,
          amount: t.valor_pago != null ? Number(t.valor_pago) : null,
          receivedAt: t.created_at || null,
        });
      }

      // 2) fallback: procurar em stripe_event (últimos N eventos)
      const recentEvents = await prisma.stripe_event.findMany({
        orderBy: [{ id: "desc" }],
        take: 200,
        select: { id: true, event_id: true, payload: true, received_at: true },
      });

      for (const ev of recentEvents) {
        try {
          const payload = ev.payload || {};
          const type = payload.type || (payload.event && payload.event.type);
          const obj = (payload.data && payload.data.object) || payload.object || null;
          if (obj) {
            const objId = obj.id || obj.session_id || obj.checkout_session_id;
            if (
              String(objId) === String(sessionId) ||
              (objId && String(objId).includes(String(sessionId)))
            ) {
              const amountTotal = (obj.amount_total ?? obj.amount ?? obj.amount_received) || null;
              const amountMajor = amountTotal != null ? Number(amountTotal) / 100.0 : null;
              return res.json({
                sessionId,
                amount:
                  amountMajor != null
                    ? Number(
                        typeof amountMajor.toFixed === "function"
                          ? amountMajor.toFixed(2)
                          : amountMajor
                      )
                    : null,
                receivedAt: ev.received_at || null,
                note: "from_stripe_event_fallback",
              });
            }
          }
        } catch (e) {
          logger.warn("Erro parsing stripe_event payload fallback: " + String(e));
        }
      }

      return res.json(null);
    } else {
      // sem sessionId: retorna última compra persistida
      const t = await prisma.compra.findFirst({ orderBy: [{ id: "desc" }], take: 1 });
      if (!t) return res.json(null);
      return res.json({
        sessionId: t.stripe_session_id,
        amount: t.valor_pago != null ? Number(t.valor_pago) : null,
        receivedAt: t.created_at || null,
      });
    }
  } catch (err) {
    logger.error("Erro em /last-transaction-json: " + String(err));
    return res.status(500).json({ error: "internal_error" });
  }
});

/**
 * create-checkout-session
 */
router.post("/create-checkout-session", jsonParser, authenticateToken, async (req, res) => {
  try {
    const {
      amount,
      currency = "brl",
      name = "Compra",
      payment_methods = [],
      user_email = "",
      user_name = "",
      local_order_id,
    } = req.body || {};

    const amountNum = Number(amount);
    const MIN_AMOUNT = Number(process.env.MIN_AMOUNT_CENTS || 100);
    const MAX_AMOUNT = Number(process.env.MAX_AMOUNT_CENTS || 5000000);

    if (!amountNum || !Number.isInteger(amountNum) || amountNum < MIN_AMOUNT || amountNum > MAX_AMOUNT) {
      return res
        .status(400)
        .json({ error: "amount inválido. Deve ser inteiro em centavos e dentro dos limites permitidos." });
    }

    const localOrderId = String(local_order_id || `local-${Date.now()}`);

    const allowed = ["card", "boleto", "pix"];
    const methods = (payment_methods || []).filter((m) => allowed.includes(m));
    if (methods.length === 0) methods.push("card");

    if (!stripe) return res.status(500).json({ error: "Stripe não configurado no servidor" });

    const baseUrl = process.env.BASE_URL || `http://localhost:${process.env.PORT}`;

    const payload = req.user || {};
    const userId = payload.id ?? payload.userId ?? payload.sub ?? null;
    const payloadEmail = payload.email ?? null;
    const payloadName = payload.nome ?? payload.name ?? null;

    const finalEmail =
      user_email && String(user_email).length > 0 ? String(user_email) : payloadEmail || "";
    const finalName = user_name && String(user_name).length > 0 ? String(user_name) : payloadName || "";

    const metadata = {
      local_order_id: localOrderId,
      user_email: finalEmail || "",
      user_name: finalName || "",
    };
    if (userId) metadata.user_id = String(userId);

    let stripeCustomerId = null;
    try {
      if (finalEmail && stripe) {
        const existing = await stripe.customers.list({ email: finalEmail, limit: 1 });
        let customer = existing && existing.data && existing.data.length ? existing.data[0] : null;
        if (customer) {
          if (finalName && finalName !== (customer.name || "")) {
            try {
              await stripe.customers.update(customer.id, {
                name: finalName,
                metadata: { ...customer.metadata, user_id: userId ? String(userId) : (customer.metadata?.user_id || "") },
              });
            } catch (updErr) {
              logger.warn("Falha ao atualizar Customer: " + String(updErr));
            }
          }
          stripeCustomerId = customer.id;
        } else {
          try {
            const newCustomer = await stripe.customers.create({
              email: finalEmail,
              name: finalName || undefined,
              metadata: userId ? { user_id: String(userId) } : undefined,
            });
            stripeCustomerId = newCustomer.id;
          } catch (createErr) {
            logger.warn("Falha ao criar Stripe Customer: " + String(createErr));
            stripeCustomerId = null;
          }
        }
      }
    } catch (e) {
      logger.warn("Erro ao tentar resolver/atualizar Stripe Customer: " + String(e));
      stripeCustomerId = null;
    }

    const sessionParams = {
      payment_method_types: methods,
      mode: "payment",
      line_items: [
        {
          price_data: {
            currency,
            product_data: { name },
            unit_amount: amountNum,
          },
          quantity: 1,
        },
      ],
      success_url: `${baseUrl}/pagamentosDeCreditos/success?session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: `${baseUrl}/pagamentosDeCreditos/cancel`,
      metadata,
      payment_method_options: { card: { request_three_d_secure: "automatic" } },
      billing_address_collection: "auto",
    };

    if (stripeCustomerId) {
      sessionParams.customer = stripeCustomerId;
    } else if (finalEmail) {
      sessionParams.customer_email = finalEmail;
    }

    let session;
    try {
      session = await stripe.checkout.sessions.create(sessionParams);
    } catch (stripeErr) {
      logger.error("Stripe error creating session: " + String(stripeErr));
      return res.status(500).json({ error: "stripe_error", detail: "Erro ao criar sessão de checkout." });
    }

    safeLog("create-checkout-session created", { sessionId: session.id, localOrderId, userId, stripeCustomerId });
    return res.json({ url: session.url, sessionId: session.id, localOrderId });
  } catch (err) {
    logger.error("Erro create-checkout-session: " + String(err));
    return res.status(500).json({ error: String(err.message || err) });
  }
});

// cancel
router.get("/cancel", (_req, res) => res.send("<h2>Pagamento cancelado.</h2>"));

/**
 * WEBHOOK
 * - usa express.raw para assinatura
 * - fluxo: checar existência do stripe_event; se processed=true => já processado.
 *   se existir processed=false => tentar processar (permitindo reprocess por retries).
 * - somente marcar processed=true APÓS todos os passos críticos terem sido concluídos com sucesso.
 */

export default router;
