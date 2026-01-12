// routes/webhookPagamentos.js
import express from "express";
import Stripe from "stripe";
import { PrismaClient } from "@prisma/client";
import dotenv from "dotenv";
import nodemailer from "nodemailer";

dotenv.config();

const router = express.Router();
const prisma = new PrismaClient();

const stripeKey = process.env.STRIPE_SECRET_KEY;
if (!stripeKey) throw new Error("STRIPE_SECRET_KEY não configurada");
const stripe = new Stripe(stripeKey, { apiVersion: "2023-08-16" });

const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET || null;
// exigir webhook secret em produção
if (process.env.NODE_ENV === "production" && !webhookSecret) {
  throw new Error("STRIPE_WEBHOOK_SECRET obrigatório em produção");
}

const HANDLED_EVENTS = new Set([
  "checkout.session.completed",
  "invoice.payment_succeeded",
  "invoice.paid",
  "invoice.payment_failed",
  "customer.subscription.updated",
  "customer.subscription.created",
  "customer.subscription.deleted",
  "payment_intent.succeeded",
  "charge.succeeded",
  "customer.updated",
]);

// --- Email setup (opcional) ---
const emailHost = process.env.EMAIL_HOST;
const emailPort = process.env.EMAIL_PORT ? Number(process.env.EMAIL_PORT) : undefined;
const emailSecure = process.env.EMAIL_SECURE === "true";
const emailUser = process.env.EMAIL_USER;
const emailPass = process.env.EMAIL_PASS;
const emailFrom = process.env.EMAIL_FROM || emailUser;

let transporter = null;
if (emailHost && emailPort && emailUser && emailPass) {
  transporter = nodemailer.createTransport({
    host: emailHost,
    port: emailPort,
    secure: emailSecure,
    auth: { user: emailUser, pass: emailPass },
  });
} else {
  console.warn("Transporter de email incompleto — e-mails não serão enviados.");
}

async function sendEmail({ to, subject, text, html }) {
  if (!transporter || !to) return;
  try {
    await transporter.sendMail({ from: emailFrom, to, subject, text, html });
    console.info("Email enfileirado/enviado:", to, subject);
  } catch (e) {
    console.error("Erro enviando email:", e?.message ?? e);
  }
}

// util
const toInt = (v) => {
  if (v === undefined || v === null) return null;
  const n = Number(v);
  return Number.isInteger(n) ? n : null;
};

// ---------- NOVAS FUNÇÕES AUXILIARES RELACIONADAS A MARCAR ja_fez_compra ----------
// valida se um PaymentIntent indica pagamento definitivo
function paymentIntentIsConfirmed(pi) {
  if (!pi) return false;
  // status 'succeeded' is the canonical check; also check for at least one succeeded charge if present
  if (pi.status === "succeeded") return true;
  if (Array.isArray(pi.charges?.data) && pi.charges.data.length) {
    for (const c of pi.charges.data) {
      if (c && (c.paid === true || c.status === "succeeded")) return true;
    }
  }
  return false;
}

// marca usuario.ja_fez_compra = true de forma idempotente (só atualiza se false)
async function markUserMadePurchase(tx, id_usuario) {
  if (!id_usuario) return;
  try {
    await tx.usuario.updateMany({
      where: { id: id_usuario, ja_fez_compra: false },
      data: { ja_fez_compra: true },
    });
    console.info("Usuario marcado como ja_fez_compra:", id_usuario);
    // opcional: logar a ação
    try {
      await tx.logs_usuario.create({
        data: {
          id_do_usuario: id_usuario,
          acao_no_sistema: "Flag ja_fez_compra marcada automaticamente após confirmação de pagamento via webhook Stripe.",
        },
      });
    } catch (e) {
      console.warn("Falha ao criar log de ja_fez_compra:", e?.message ?? e);
    }
  } catch (e) {
    console.warn("Erro marcando ja_fez_compra:", e?.message ?? e);
  }
}
// ---------------------------------------------------------------------------------

// tenta resolver usuário local por metadata / email / stripe customer
async function findLocalUser(tx, session = {}, metadata = {}) {
  const metaUserId = metadata?.userId || metadata?.user_id || metadata?.usuarioId || metadata?.user;
  if (metaUserId) {
    const idNum = Number(metaUserId);
    if (!Number.isNaN(idNum)) {
      try {
        const u = await tx.usuario.findUnique({ where: { id: idNum } });
        if (u) return u;
      } catch {}
    }
  }

  const metaEmail = metadata?.user_email || metadata?.userEmail || session?.customer_details?.email || null;
  if (metaEmail) {
    try {
      const u = await tx.usuario.findUnique({ where: { email: String(metaEmail) } });
      if (u) return u;
    } catch {}
  }

  const customerId = session?.customer;
  if (customerId) {
    try {
      const cus = await stripe.customers.retrieve(String(customerId));
      if (cus?.email) {
        const u = await tx.usuario.findUnique({ where: { email: String(cus.email) } });
        if (u) return u;
      }
    } catch (e) {
      console.warn("Não foi possível recuperar Stripe Customer:", e?.message ?? e);
    }
  }

  return null;
}

// cria pacote de créditos com idempotência por origem+usuario
async function creditarPacotes(tx, id_usuario, origem, quantidade, opts = {}) {
  if (!origem) throw new Error("origem obrigatória");
  if (!id_usuario) throw new Error("id_usuario obrigatório");
  if (!quantidade || quantidade <= 0) return null;

  const existente = await tx.pacote_creditos.findFirst({ where: { origem, id_usuario } });
  if (existente) {
    console.info("Pacote já existe (idempotência):", { origem, id_usuario });
    return existente;
  }

  const pacote = await tx.pacote_creditos.create({
    data: { id_usuario, quantidade, origem, data_recebimento: new Date() },
  });

  // tentativa não crítica de criar receita vinculada
  try {
    await tx.receita.create({
      data: { valor: 0.0, descricao: `Crédito automático (origem ${origem}, user ${id_usuario})`, id_usuario },
    });
  } catch (e) {
    console.warn("Falha ao criar receita (não crítica):", e?.message ?? e);
  }

  console.info("Pacote criado:", { pacoteId: pacote.id, origem, quantidade, id_usuario, ...opts });
  return pacote;
}

// Parsers mínimos (mantidos para vinculação, mas não usados para crédito)
function parseLinkedFromMetadata(metadata = {}) {
  const rawIds = metadata?.linked_user_ids || metadata?.linkedUserIds || metadata?.linked_user_id || metadata?.linkedUserIdsCSV;
  const rawEmails = metadata?.linked_emails || metadata?.linkedEmails || metadata?.linked_emails_list || metadata?.linkedEmailsCSV;
  const ids = new Set();
  const emails = new Set();

  if (typeof rawIds === "string") {
    for (const s of rawIds.split(",")) {
      const n = Number(s.trim());
      if (Number.isInteger(n)) ids.add(n);
    }
  } else if (Array.isArray(rawIds)) {
    for (const v of rawIds) {
      const n = Number(v);
      if (Number.isInteger(n)) ids.add(n);
    }
  }

  if (typeof rawEmails === "string") {
    for (const s of rawEmails.split(",")) {
      const e = s.trim().toLowerCase();
      if (e) emails.add(e);
    }
  } else if (Array.isArray(rawEmails)) {
    for (const v of rawEmails) {
      if (!v) continue;
      emails.add(String(v).trim().toLowerCase());
    }
  }

  return { ids: Array.from(ids), emails: Array.from(emails) };
}

// Vincula dono e vinculados conforme metadata — NÃO altera lógica de crédito
async function assignAssinaturaToUsers(tx, assinaturaDb, metadata = {}) {
  if (!assinaturaDb?.id) return;
  const assinaturaId = assinaturaDb.id;
  const ownerId = assinaturaDb.id_dono;

  if (ownerId) {
    try {
      const updated = await tx.usuario.updateMany({
        where: { id: ownerId, OR: [{ id_vinculo_assinatura: null }, { id_vinculo_assinatura: assinaturaId }] },
        data: { id_vinculo_assinatura: assinaturaId },
      });
      if (updated.count > 0) {
        await tx.logs_usuario.create({
          data: {
            id_do_usuario: ownerId,
            acao_no_sistema: `Dono vinculado automaticamente à assinatura ${assinaturaId} via webhook.`,
          },
        });
      }
    } catch (e) {
      console.warn("Falha ao vincular dono:", e?.message ?? e);
    }
  }

  const { ids: linkedIds, emails: linkedEmails } = parseLinkedFromMetadata(metadata || {});
  if (linkedIds.length) {
    try {
      const r = await tx.usuario.updateMany({
        where: { id: { in: linkedIds }, OR: [{ id_vinculo_assinatura: null }, { id_vinculo_assinatura: assinaturaId }] },
        data: { id_vinculo_assinatura: assinaturaId },
      });
      if (r.count > 0) {
        const updated = await tx.usuario.findMany({ where: { id: { in: linkedIds }, id_vinculo_assinatura: assinaturaId }, select: { id: true } });
        for (const u of updated) {
          await tx.logs_usuario.create({
            data: { id_do_usuario: u.id, acao_no_sistema: `Vinculado automaticamente à assinatura ${assinaturaId} via metadata.linked_user_ids.` },
          });
        }
      }
    } catch (e) {
      console.warn("Erro vinculando linked_user_ids:", e?.message ?? e);
    }
  }

  if (linkedEmails.length) {
    try {
      const r = await tx.usuario.updateMany({
        where: { email: { in: linkedEmails }, OR: [{ id_vinculo_assinatura: null }, { id_vinculo_assinatura: assinaturaId }] },
        data: { id_vinculo_assinatura: assinaturaId },
      });
      if (r.count > 0) {
        const updated = await tx.usuario.findMany({ where: { email: { in: linkedEmails }, id_vinculo_assinatura: assinaturaId }, select: { id: true } });
        for (const u of updated) {
          await tx.logs_usuario.create({
            data: { id_do_usuario: u.id, acao_no_sistema: `Vinculado automaticamente à assinatura ${assinaturaId} via metadata.linked_emails.` },
          });
        }
      }
      // log emails não encontrados
      const found = await tx.usuario.findMany({ where: { email: { in: linkedEmails } }, select: { email: true } });
      const foundSet = new Set(found.map((x) => x.email));
      const notFound = linkedEmails.filter((e) => !foundSet.has(e));
      if (notFound.length) console.info("linked_emails não encontrados localmente:", notFound);
    } catch (e) {
      console.warn("Erro vinculando linked_emails:", e?.message ?? e);
    }
  }
}

// Credita somente o dono da assinatura (id_dono)
async function creditOnlyOwner(tx, assinaturaDb, origem, quantidade) {
  if (!assinaturaDb?.id) return;
  const ownerId = assinaturaDb.id_dono;
  if (!ownerId) {
    console.info("Assinatura sem dono; nenhum crédito aplicado.", assinaturaDb.id);
    return;
  }
  if (!quantidade || quantidade <= 0) return;
  try {
    await creditarPacotes(tx, ownerId, origem, quantidade, { planoId: assinaturaDb.id_plano, role: "owner_only" });
  } catch (e) {
    console.warn("Erro creditando dono:", e?.message ?? e);
  }
}

// resolve metadata/objetos principais do evento
async function resolveMeta(evt) {
  try {
    if (evt.type === "checkout.session.completed") {
      const session = evt.data.object;
      if (session.subscription) {
        try {
          const sub = await stripe.subscriptions.retrieve(session.subscription);
          return { session, subscription: sub, metadata: sub.metadata || session.metadata || {} };
        } catch {
          return { session, metadata: session.metadata || {} };
        }
      }
      return { session, metadata: session.metadata || {} };
    }

    if (evt.type.startsWith("invoice.")) {
      const invoice = evt.data.object;
      if (invoice.subscription) {
        try {
          const sub = await stripe.subscriptions.retrieve(invoice.subscription);
          return { invoice, subscription: sub, metadata: sub.metadata || invoice.metadata || {} };
        } catch {
          return { invoice, metadata: invoice.metadata || {} };
        }
      }
      return { invoice, metadata: invoice.metadata || {} };
    }

    if (evt.type === "payment_intent.succeeded" || evt.type === "charge.succeeded") {
      return { obj: evt.data.object, metadata: evt.data.object.metadata || {} };
    }

    if (evt.type.startsWith("customer.subscription.")) {
      const sub = evt.data.object;
      return { subscription: sub, metadata: sub.metadata || {} };
    }

    const obj = (evt.data && evt.data.object) || {};
    return { metadata: obj.metadata || {} };
  } catch (e) {
    console.warn("resolveMeta falhou:", e?.message ?? e);
    return { metadata: {} };
  }
}

router.post("/", express.raw({ type: "application/json" }), async (req, res) => {
  // log mínimo — evitar vazar payloads sensíveis
  console.info("Stripe webhook recebido");

  const sig = req.headers["stripe-signature"];
  if (!sig && webhookSecret) {
    console.warn("stripe-signature ausente");
    return res.status(400).send("Missing stripe-signature header");
  }

  let event;
  try {
    if (webhookSecret) {
      // req.body é Buffer por express.raw
      event = stripe.webhooks.constructEvent(req.body, sig, webhookSecret);
    } else {
      // ambiente dev: aceitar JSON parseável
      const text = Buffer.isBuffer(req.body) ? req.body.toString("utf8") : JSON.stringify(req.body);
      event = JSON.parse(text);
    }
  } catch (err) {
    console.error("Falha verificação webhook:", err?.message ?? err);
    return res.status(400).send(`Webhook signature verification failed: ${err?.message ?? err}`);
  }

  const eventId = event.id;
  if (!eventId) return res.status(400).send("Missing event.id");

  // eventos não tratados -> registrar e responder
  if (!HANDLED_EVENTS.has(event.type)) {
    console.info("Evento ignorado:", event.type);
    try {
      await prisma.stripe_event.upsert({
        where: { event_id: eventId },
        update: { payload: event, processed: true, processed_at: new Date() },
        create: { event_id: eventId, payload: event, processed: true },
      });
    } catch (e) {
      console.warn("Erro registrando evento ignorado:", e?.message ?? e);
    }
    return res.json({ received: true, note: "ignored_event_type" });
  }

  // idempotência: se já processado, sair; caso contrário criar registro (processed=false) se necessário
  try {
    const existing = await prisma.stripe_event.findUnique({ where: { event_id: eventId } });
    if (existing && existing.processed) {
      console.info("Evento já processado:", eventId);
      return res.json({ received: true, note: "already_processed" });
    }
    if (!existing) {
      try {
        await prisma.stripe_event.create({ data: { event_id: eventId, processed: false, payload: event } });
      } catch (e) {
        console.warn("Race condition criando stripe_event:", e?.message ?? e);
      }
    } else {
      try {
        await prisma.stripe_event.update({ where: { event_id: eventId }, data: { payload: event } });
      } catch (e) {
        console.warn("Falha atualizando payload stripe_event:", e?.message ?? e);
      }
    }
  } catch (e) {
    console.error("Erro registrando stripe_event:", e?.message ?? e);
    return res.status(500).send("internal_error");
  }

  // buffer de notificações para envio pós-commit
  const notifications = [];

  try {
    await prisma.$transaction(async (tx) => {
      const { session, subscription, invoice, obj, metadata } = await resolveMeta(event);

      const planId = toInt(metadata?.planId || metadata?.plan_id || metadata?.planoId);
      const userIdMeta = toInt(metadata?.userId || metadata?.user_id || metadata?.usuarioId || metadata?.user);

      // checkout.session.completed
      if (event.type === "checkout.session.completed") {
        const sess = session || event.data.object;
        const stripeSubscriptionId = sess.subscription || (subscription && subscription.id) || null;
        const paymentIntentId = sess.payment_intent || null;

        // prefere PaymentIntent para valores reais
        let amountCents = sess.amount_total ?? null;
        let currency = sess.currency ?? null;
        let piConfirmed = false;
        let pi = null;
        if (paymentIntentId) {
          try {
            pi = await stripe.paymentIntents.retrieve(paymentIntentId, { expand: ["charges.data"] });
            if (pi && typeof pi.amount_received !== "undefined" && pi.amount_received !== null) {
              amountCents = pi.amount_received;
              currency = pi.currency ?? currency;
            }
            piConfirmed = paymentIntentIsConfirmed(pi);
          } catch (e) {
            console.warn("Falha retrieving PaymentIntent:", e?.message ?? e);
          }
        } else {
          // fallback: sessão pode indicar pagamento via payment_status
          if (sess.payment_status === "paid") {
            piConfirmed = true;
          }
        }
        const amountMajor = amountCents != null ? Number(amountCents) / 100.0 : null;

        const resolvedUser = await findLocalUser(tx, sess, metadata);
        const resolvedUserId = resolvedUser ? resolvedUser.id : (userIdMeta || null);

        // persistir compra (criar ou atualizar)
        let compra = await tx.compra.findFirst({ where: { stripe_session_id: String(sess.id) } });
        if (!compra) {
          compra = await tx.compra.create({
            data: {
              valor_pago: amountMajor != null ? Number(amountMajor.toFixed(2)) : null,
              descricao: `Stripe checkout ${sess.id}${sess.metadata?.local_order_id ? ` localOrder:${sess.metadata.local_order_id}` : ""}`,
              stripe_session_id: String(sess.id),
              payment_intent_id: paymentIntentId || undefined,
              id_usuario: resolvedUserId || null,
              created_at: new Date(),
            },
          });
          console.info("Compra criada:", compra.id);
        } else {
          const updates = {};
          if ((compra.valor_pago == null || compra.valor_pago === 0) && amountMajor != null) updates.valor_pago = Number(amountMajor.toFixed(2));
          if (!compra.payment_intent_id && paymentIntentId) updates.payment_intent_id = paymentIntentId;
          if (!compra.id_usuario && resolvedUserId) updates.id_usuario = resolvedUserId;
          if (Object.keys(updates).length) {
            await tx.compra.update({ where: { id: compra.id }, data: updates });
            console.info("Compra atualizada:", compra.id, updates);
          }
          compra = await tx.compra.findUnique({ where: { id: compra.id } });
        }

        // Se a compra estiver confirmada (PaymentIntent confirmado ou session.payment_status === 'paid'),
        // marcar ja_fez_compra = true para o usuário vinculado (se houver).
        // Observação: só marcamos se existe compra.id_usuario (ou se conseguimos resolver o usuário local)
        try {
          const compraUserId = compra?.id_usuario || resolvedUserId || null;
          if (compraUserId && piConfirmed) {
            await markUserMadePurchase(tx, compraUserId);
          } else {
            if (!piConfirmed) {
              console.info("Pagamento da session não está confirmado 100% — não marcar ja_fez_compra ainda.", {
                sessionId: sess.id,
                paymentIntentId,
                sessionPaymentStatus: sess.payment_status,
              });
            }
            if (!compraUserId) {
              console.info("Nenhum usuario vinculado à compra; não será marcada ja_fez_compra.", { compraId: compra?.id });
            }
          }
        } catch (e) {
          console.warn("Erro tentando marcar ja_fez_compra no checkout.session.completed:", e?.message ?? e);
        }

        // se sessão vinculada a subscription -> criar/atualizar assinatura local e creditar só o dono
        if (stripeSubscriptionId) {
          let assinaturaDb = await tx.assinatura.findUnique({ where: { stripe_subscription_id: stripeSubscriptionId } });
          const now = new Date();
          const currentPeriodEnd = subscription && subscription.current_period_end ? new Date(subscription.current_period_end * 1000) : null;
          const status = subscription?.status ?? "active";

          if (!assinaturaDb) {
            if (!planId || !userIdMeta) {
              console.warn("Metadata incompleta para criar assinatura local; ignorando criação automática.", sess.id);
            } else {
              assinaturaDb = await tx.assinatura.create({
                data: {
                  id_plano: planId,
                  id_dono: userIdMeta,
                  data_assinatura: now,
                  criado_em: now,
                  stripe_subscription_id: stripeSubscriptionId,
                  stripe_customer_id: sess.customer || subscription?.customer || null,
                  stripe_price_id: subscription?.items?.data?.[0]?.price?.id || undefined,
                  status,
                  current_period_end: currentPeriodEnd,
                  cancel_at_period_end: subscription?.cancel_at_period_end ?? false,
                  ativo: true,
                },
              });
              console.info("Assinatura criada:", assinaturaDb.id);

              // vincular users (não implica créditos para vinculados)
              try {
                await assignAssinaturaToUsers(tx, assinaturaDb, subscription?.metadata || sess.metadata || {});
              } catch (e) {
                console.warn("Falha ao vincular usuários após criação de assinatura:", e?.message ?? e);
              }

              // notificar dono criação
              try {
                const ownerLocal = await tx.usuario.findUnique({ where: { id: assinaturaDb.id_dono }, select: { email: true, nome: true } });
                const planoDb = await tx.plano.findUnique({ where: { id: assinaturaDb.id_plano }, select: { nome: true, preco_mensal: true, quantidade_credito_mensal: true } });
                if (ownerLocal?.email) {
                  const planName = planoDb?.nome ?? `Plano ${assinaturaDb.id_plano}`;
                  const preco = planoDb?.preco_mensal != null ? Number(planoDb.preco_mensal.toString()).toFixed(2) : "n/a";
                  const qtd = planoDb?.quantidade_credito_mensal ?? 0;
                  notifications.push({
                    to: ownerLocal.email,
                    subject: `Assinatura criada: ${planName}`,
                    html: `<p>Olá ${ownerLocal.nome ?? ""}, sua assinatura foi criada. Plano: ${planName} (R$ ${preco}). Créditos/mês: ${qtd}.</p>`,
                    text: `Olá ${ownerLocal.nome ?? ""}, sua assinatura foi criada. Plano: ${planName}. Créditos/mês: ${qtd}.`,
                  });
                }
              } catch (e) {
                console.warn("Falha preparando notificação de criação de assinatura:", e?.message ?? e);
              }
            }
          } else {
            await tx.assinatura.update({
              where: { id: assinaturaDb.id },
              data: {
                stripe_customer_id: sess.customer || assinaturaDb.stripe_customer_id,
                stripe_price_id: subscription?.items?.data?.[0]?.price?.id || assinaturaDb.stripe_price_id,
                status,
                current_period_end: currentPeriodEnd,
                cancel_at_period_end: subscription?.cancel_at_period_end ?? assinaturaDb.cancel_at_period_end,
                ativo: true,
              },
            });
            console.info("Assinatura atualizada:", assinaturaDb.id);
            try {
              await assignAssinaturaToUsers(tx, assinaturaDb, subscription?.metadata || sess.metadata || {});
            } catch (e) {
              console.warn("Falha ao vincular usuários após atualização de assinatura:", e?.message ?? e);
            }

            // notificar dono sobre update/renew
            try {
              const ownerLocal = await tx.usuario.findUnique({ where: { id: assinaturaDb.id_dono }, select: { email: true, nome: true } });
              if (ownerLocal?.email) {
                notifications.push({
                  to: ownerLocal.email,
                  subject: `Assinatura atualizada — ${stripeSubscriptionId}`,
                  html: `<p>Olá ${ownerLocal.nome ?? ""}, sua assinatura foi atualizada. Subscription: ${stripeSubscriptionId}.</p>`,
                  text: `Olá ${ownerLocal.nome ?? ""}, sua assinatura foi atualizada. Subscription: ${stripeSubscriptionId}.`,
                });
              }
            } catch (e) {
              console.warn("Falha preparando notificação de atualização de assinatura:", e?.message ?? e);
            }
          }

          if (assinaturaDb) {
            const planoDb = await tx.plano.findUnique({ where: { id: assinaturaDb.id_plano } });
            const quantidade = (planoDb && Number(planoDb.quantidade_credito_mensal) > 0) ? Number(planoDb.quantidade_credito_mensal) : 0;
            const origem = `stripe:subscription:${stripeSubscriptionId}:checkout_session:${sess.id}`;
            if (quantidade > 0) {
              try {
                await creditOnlyOwner(tx, assinaturaDb, origem, quantidade);
              } catch (e) {
                console.warn("Falha creditando dono após checkout.session.completed:", e?.message ?? e);
              }
            }
          }
        } else {
          // compra avulsa -> calcular créditos por preço do sistema
          if (resolvedUserId && amountMajor != null) {
            try {
              const cfg = await tx.config_sistema.findFirst({ orderBy: { id: "desc" } });
              const precoDoCredito = cfg && cfg.preco_do_credito != null ? Number(cfg.preco_do_credito.toString()) : null;
              if (precoDoCredito && precoDoCredito > 0) {
                const quantidade = Math.floor(amountMajor / precoDoCredito);
                if (quantidade > 0) {
                  const localOrderId = sess.metadata?.local_order_id ?? null;
                  const origem = `stripe:session:${sess.id}${localOrderId ? `:local:${localOrderId}` : ""}`;
                  await creditarPacotes(tx, resolvedUserId, origem, quantidade, { compraId: compra?.id });
                  try {
                    await tx.receita.create({
                      data: { valor: Number(amountMajor.toFixed(2)), descricao: `Receita via Stripe session ${sess.id}`, id_usuario: resolvedUserId },
                    });
                  } catch (e) {
                    console.warn("Falha ao criar receita (não crítica):", e?.message ?? e);
                  }

                  // notificar usuário
                  try {
                    let userEmail = resolvedUser?.email ?? null;
                    let userNome = resolvedUser?.nome ?? null;
                    if (!userEmail && resolvedUserId) {
                      const u = await tx.usuario.findUnique({ where: { id: resolvedUserId }, select: { email: true, nome: true } });
                      if (u) { userEmail = u.email; userNome = u.nome; }
                    }
                    if (userEmail) {
                      notifications.push({
                        to: userEmail,
                        subject: `Compra confirmada — créditos adicionados (${quantidade})`,
                        html: `<p>Olá ${userNome ?? ""}, recebemos seu pagamento (R$ ${amountMajor.toFixed(2)}). Créditos adicionados: ${quantidade}.</p>`,
                        text: `Olá ${userNome ?? ""}, recebemos seu pagamento (R$ ${amountMajor.toFixed(2)}). Créditos adicionados: ${quantidade}.`,
                      });
                    } else {
                      console.info("Usuário sem email; não será enviada notificação por email (compra avulsa).", { resolvedUserId });
                    }
                  } catch (e) {
                    console.warn("Falha notificando compra avulsa:", e?.message ?? e);
                  }

                  // marcar ja_fez_compra caso o pagamento esteja confirmado
                  try {
                    if ((paymentIntentId && piConfirmed) || (!paymentIntentId && sess.payment_status === "paid")) {
                      await markUserMadePurchase(tx, resolvedUserId);
                    }
                  } catch (e) {
                    console.warn("Erro marcando ja_fez_compra para compra avulsa:", e?.message ?? e);
                  }
                } else {
                  console.info("Valor insuficiente para gerar créditos com preço configurado.", { amountMajor, precoDoCredito });
                }
              } else {
                console.warn("Preco do crédito inválido; não será criado pacote automaticamente.");
              }
            } catch (e) {
              console.warn("Erro criando pacote de créditos para compra avulsa:", e?.message ?? e);
            }
          } else {
            if (!resolvedUserId) console.warn("Usuário não identificado para compra avulsa (metadata/stripe).", { sessionId: sess.id });
            if (amountMajor == null) console.warn("Valor desconhecido para session:", { sessionId: sess.id });
          }
        }
      }

      // invoice.paid / invoice.payment_succeeded
      else if (event.type === "invoice.payment_succeeded" || event.type === "invoice.paid") {
        const inv = invoice || event.data.object;
        const stripeSubscriptionId = inv.subscription || (subscription && subscription.id) || null;
        if (!stripeSubscriptionId) {
          console.info("invoice.paid sem subscription");
        } else {
          const assinaturaDb = await tx.assinatura.findUnique({ where: { stripe_subscription_id: stripeSubscriptionId } });
          if (!assinaturaDb) {
            console.warn("Nenhuma assinatura local para subscription:", stripeSubscriptionId);
          } else {
            const periodEnd = (subscription && subscription.current_period_end) ? new Date(subscription.current_period_end * 1000) :
              (inv.lines?.data?.[0]?.period?.end ? new Date(inv.lines.data[0].period.end * 1000) : null);

            await tx.assinatura.update({
              where: { id: assinaturaDb.id },
              data: { status: subscription?.status ?? "active", current_period_end: periodEnd || undefined, ativo: true },
            });

            try { await assignAssinaturaToUsers(tx, assinaturaDb, subscription?.metadata || inv.metadata || metadata); } catch (e) { console.warn(e); }

            const planoDb = await tx.plano.findUnique({ where: { id: assinaturaDb.id_plano } });
            const quantidade = (planoDb && Number(planoDb.quantidade_credito_mensal) > 0) ? Number(planoDb.quantidade_credito_mensal) : 0;
            const origem = `stripe:subscription:${stripeSubscriptionId}:invoice:${inv.id}`;
            if (quantidade > 0) {
              try {
                await creditOnlyOwner(tx, assinaturaDb, origem, quantidade);
              } catch (e) {
                console.warn("Falha creditando dono após invoice.paid:", e?.message ?? e);
              }
            }

            // notificar dono pagamento
            try {
              const ownerLocal = await tx.usuario.findUnique({ where: { id: assinaturaDb.id_dono }, select: { email: true, nome: true } });
              if (ownerLocal?.email) {
                const amountCents = inv.amount_paid ?? inv.total ?? inv.amount ?? null;
                const amountMajor = amountCents != null ? Number(amountCents) / 100.0 : null;
                notifications.push({
                  to: ownerLocal.email,
                  subject: `Pagamento recebido — assinatura ${stripeSubscriptionId}`,
                  html: `<p>Olá ${ownerLocal.nome ?? ""}, recebemos o pagamento da sua assinatura. Valor: ${amountMajor != null ? `R$ ${amountMajor.toFixed(2)}` : "n/a"}.</p>`,
                  text: `Olá ${ownerLocal.nome ?? ""}, recebemos o pagamento da sua assinatura. Valor: ${amountMajor != null ? `R$ ${amountMajor.toFixed(2)}` : "n/a"}.`,
                });
              }
            } catch (e) {
              console.warn("Falha preparando notificação invoice.paid:", e?.message ?? e);
            }
          }
        }
      }

      // invoice.payment_failed
      else if (event.type === "invoice.payment_failed") {
        const inv = invoice || event.data.object;
        const stripeSubscriptionId = inv.subscription || (subscription && subscription.id) || null;
        if (stripeSubscriptionId) {
          const assinaturaDb = await tx.assinatura.findUnique({ where: { stripe_subscription_id: stripeSubscriptionId } });
          if (assinaturaDb) {
            await tx.assinatura.update({ where: { id: assinaturaDb.id }, data: { status: "past_due" } });
            await tx.logs_usuario.create({
              data: { id_do_usuario: assinaturaDb.id_dono, acao_no_sistema: `Falha de pagamento para assinatura ${assinaturaDb.id} (subscription ${stripeSubscriptionId}, invoice ${inv.id})` },
            });
            try {
              const ownerLocal = await tx.usuario.findUnique({ where: { id: assinaturaDb.id_dono }, select: { email: true, nome: true } });
              if (ownerLocal?.email) {
                notifications.push({
                  to: ownerLocal.email,
                  subject: `Falha no pagamento — assinatura ${stripeSubscriptionId}`,
                  html: `<p>Olá ${ownerLocal.nome ?? ""}, detectamos falha no pagamento da assinatura (invoice ${inv.id}). Por favor, verifique seus dados de pagamento.</p>`,
                  text: `Olá ${ownerLocal.nome ?? ""}, detectamos falha no pagamento da assinatura (invoice ${inv.id}).`,
                });
              }
            } catch (e) { console.warn(e); }
          }
        }
      }

      // subscription.created/updated
      else if (event.type === "customer.subscription.updated" || event.type === "customer.subscription.created") {
        const sub = subscription || event.data.object;
        const assinaturaDb = await tx.assinatura.findUnique({ where: { stripe_subscription_id: sub.id } });
        if (assinaturaDb) {
          await tx.assinatura.update({
            where: { id: assinaturaDb.id },
            data: {
              status: sub.status,
              cancel_at_period_end: sub.cancel_at_period_end ?? assinaturaDb.cancel_at_period_end,
              current_period_end: sub.current_period_end ? new Date(sub.current_period_end * 1000) : assinaturaDb.current_period_end,
            },
          });
          try { await assignAssinaturaToUsers(tx, assinaturaDb, sub.metadata || {}); } catch (e) { console.warn(e); }
        } else {
          const planIdFromMeta = toInt(sub.metadata?.planId || sub.metadata?.plan_id || sub.metadata?.planoId);
          const userIdFromMeta = toInt(sub.metadata?.userId || sub.metadata?.user_id || sub.metadata?.usuarioId || sub.metadata?.user);
          if (planIdFromMeta && userIdFromMeta) {
            try {
              const newAss = await tx.assinatura.create({
                data: {
                  id_plano: planIdFromMeta,
                  id_dono: userIdFromMeta,
                  data_assinatura: new Date(),
                  criado_em: new Date(),
                  stripe_subscription_id: sub.id,
                  stripe_customer_id: sub.customer || null,
                  stripe_price_id: sub.items?.data?.[0]?.price?.id || undefined,
                  status: sub.status ?? "active",
                  current_period_end: sub.current_period_end ? new Date(sub.current_period_end * 1000) : null,
                  cancel_at_period_end: sub.cancel_at_period_end ?? false,
                  ativo: true,
                },
              });
              try { await assignAssinaturaToUsers(tx, newAss, sub.metadata || {}); } catch (e) { console.warn(e); }
              const ownerLocal = await tx.usuario.findUnique({ where: { id: newAss.id_dono }, select: { email: true, nome: true } });
              if (ownerLocal?.email) {
                notifications.push({
                  to: ownerLocal.email,
                  subject: `Assinatura criada (Stripe) — ${sub.id}`,
                  html: `<p>Olá ${ownerLocal.nome ?? ""}, criamos uma assinatura vinculada ao seu pagamento. Subscription: ${sub.id}.</p>`,
                  text: `Olá ${ownerLocal.nome ?? ""}, criamos uma assinatura vinculada ao seu pagamento. Subscription: ${sub.id}.`,
                });
              }
            } catch (e) {
              console.warn("Falha ao criar assinatura local em subscription.created:", e?.message ?? e);
            }
          }
        }
      }

      // subscription.deleted/cancelled
      else if (event.type === "customer.subscription.deleted" || event.type === "customer.subscription.cancelled") {
        const sub = subscription || event.data.object;
        const assinaturaDb = await tx.assinatura.findUnique({ where: { stripe_subscription_id: sub.id } });
        if (assinaturaDb) {
          await tx.assinatura.update({
            where: { id: assinaturaDb.id },
            data: { ativo: false, status: sub.status ?? "canceled", canceled_at: sub.canceled_at ? new Date(sub.canceled_at * 1000) : new Date(), cancel_at_period_end: false },
          });
          await tx.logs_usuario.create({
            data: { id_do_usuario: assinaturaDb.id_dono, acao_no_sistema: `Assinatura ${assinaturaDb.id} marcada inativa por evento Stripe.` },
          });
          try {
            const ownerLocal = await tx.usuario.findUnique({ where: { id: assinaturaDb.id_dono }, select: { email: true, nome: true } });
            if (ownerLocal?.email) {
              notifications.push({
                to: ownerLocal.email,
                subject: `Assinatura cancelada — ${sub.id}`,
                html: `<p>Olá ${ownerLocal.nome ?? ""}, sua assinatura foi marcada como inativa. Subscription: ${sub.id}.</p>`,
                text: `Olá ${ownerLocal.nome ?? ""}, sua assinatura foi marcada como inativa. Subscription: ${sub.id}.`,
              });
            }
          } catch (e) { console.warn(e); }
        }
      }

      // payment_intent.succeeded / charge.succeeded -> reconciliar compra
      else if (event.type === "payment_intent.succeeded" || event.type === "charge.succeeded") {
        const o = obj || event.data.object;
        // tentar normalizar id do payment intent/charge
        const paymentIntentId = o.id || o.payment_intent || null;
        const amountReceived = o.amount_received ?? o.amount ?? null;
        if (paymentIntentId) {
          try {
            const existingCompra = await tx.compra.findFirst({ where: { payment_intent_id: String(paymentIntentId) } });
            if (existingCompra && (existingCompra.valor_pago == null || existingCompra.valor_pago === 0) && typeof amountReceived !== "undefined" && amountReceived !== null) {
              const amountMajor = Number(amountReceived) / 100.0;
              await tx.compra.update({ where: { id: existingCompra.id }, data: { valor_pago: Number(amountMajor.toFixed(2)) } });
              console.info("Compra reconciliada:", existingCompra.id);

              // Se a compra tiver id_usuario, marcar ja_fez_compra = true (evento payment_intent.succeeded é forte)
              if (existingCompra.id_usuario) {
                try {
                  await markUserMadePurchase(tx, existingCompra.id_usuario);
                } catch (e) {
                  console.warn("Falha marcando ja_fez_compra após payment_intent.succeeded:", e?.message ?? e);
                }
              }

              if (existingCompra.id_usuario) {
                const u = await tx.usuario.findUnique({ where: { id: existingCompra.id_usuario }, select: { email: true, nome: true } });
                if (u?.email) {
                  notifications.push({
                    to: u.email,
                    subject: `Pagamento confirmado — compra ${existingCompra.id}`,
                    html: `<p>Olá ${u.nome ?? ""}, recebemos seu pagamento (R$ ${amountMajor.toFixed(2)}).</p>`,
                    text: `Olá ${u.nome ?? ""}, recebemos seu pagamento (R$ ${amountMajor.toFixed(2)}).`,
                  });
                }
              }
            }
          } catch (e) {
            console.warn("Falha reconciliar PaymentIntent -> compra:", e?.message ?? e);
          }
        } else {
          // sem payment_intent_id, tentar casar por outras vias (ex: charge -> payment_intent dentro)
          if (o.charge && typeof o.charge === "object") {
            // nada adicional implementado aqui; idealmentenormalizar payment_intent em payloads futuros
          }
        }
      } else if (event.type === "customer.updated") {
        console.info("customer.updated recebido:", event.data.object.id);
      }

      // marcar evento como processado
      await tx.stripe_event.updateMany({
        where: { event_id: eventId },
        data: { processed: true, processed_at: new Date() },
      });
    }); // end transaction

    // enviar notificações (após commit) — enviamos sequencialmente para evitar burst SMTP
    try {
      for (const n of notifications) {
        if (!n || !n.to) continue;
        await sendEmail({ to: n.to, subject: n.subject || "Notificação", text: n.text || undefined, html: n.html || undefined });
      }
    } catch (e) {
      console.error("Erro enviando notificações por email após transação:", e?.message ?? e);
      // não falhar o webhook por causa de email; já persistimos o evento/estado.
    }

    return res.json({ received: true });
  } catch (err) {
    console.error("Erro processando webhook (transação abortada):", err?.message ?? err);
    return res.status(500).send("internal_error");
  }
});

export default router;
