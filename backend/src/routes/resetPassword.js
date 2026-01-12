// routes/resetPassword.js
import dotenv from "dotenv";
dotenv.config();

import express from "express";
import { PrismaClient } from "@prisma/client";
import nodemailer from "nodemailer";
import jwt from "jsonwebtoken";
import bcrypt from "bcryptjs";
import crypto from "crypto";
import rateLimit, { ipKeyGenerator } from "express-rate-limit";

const router = express.Router();
const prisma = new PrismaClient();

/**
 * FAIL-FAST: validar variáveis de ambiente obrigatórias.
 * NÃO existe fallback: o sistema exige que estes valores venham do .env.
 */
const requiredEnv = [
  "RESET_SECRET",
  "RESET_JWT_SECRET",
  "JWT_SECRET",
  "RESET_CODE_TTL_MINUTES",
  "RESET_MAX_ATTEMPTS",
  "FORGOT_RATE_WINDOW_MS",
  "FORGOT_RATE_MAX",
  "VERIFY_RATE_WINDOW_MS",
  "VERIFY_RATE_MAX",
  "RESET_RATE_WINDOW_MS",
  "RESET_RATE_MAX",
  "EMAIL_HOST",
  "EMAIL_PORT",
  "EMAIL_SECURE",
  "EMAIL_USER",
  "EMAIL_PASS",
  "EMAIL_FROM",
];

const missing = requiredEnv.filter(k => !(k in process.env) || process.env[k] === "");
if (missing.length > 0) {
  console.error("FATAL: variáveis de ambiente obrigatórias ausentes:", missing.join(", "));
  // fail-fast: não há alternativa, encerra o processo
  process.exit(1);
}

// Parse e validações estritas (sem fallback)
function parseNumberStrict(key) {
  const raw = process.env[key];
  const n = Number(raw);
  if (!Number.isFinite(n) || n < 0) {
    console.error(`FATAL: variável de ambiente ${key} inválida (valor: ${raw}). Deve ser número não-negativo.`);
    process.exit(1);
  }
  return n;
}
function parseBoolStrict(key) {
  const raw = String(process.env[key]).toLowerCase();
  if (raw !== "true" && raw !== "false") {
    console.error(`FATAL: variável de ambiente ${key} inválida (valor: ${process.env[key]}). Deve ser "true" ou "false".`);
    process.exit(1);
  }
  return raw === "true";
}

const RESET_SECRET = process.env.RESET_SECRET;
const RESET_JWT_SECRET = process.env.RESET_JWT_SECRET;
const JWT_SECRET = process.env.JWT_SECRET;
const EMAIL_FROM = process.env.EMAIL_FROM;

const CODE_TTL_MINUTES = parseNumberStrict("RESET_CODE_TTL_MINUTES");
const MAX_CODE_ATTEMPTS = parseNumberStrict("RESET_MAX_ATTEMPTS");
const FORGOT_RATE_WINDOW_MS = parseNumberStrict("FORGOT_RATE_WINDOW_MS");
const FORGOT_RATE_MAX = parseNumberStrict("FORGOT_RATE_MAX");
const VERIFY_RATE_WINDOW_MS = parseNumberStrict("VERIFY_RATE_WINDOW_MS");
const VERIFY_RATE_MAX = parseNumberStrict("VERIFY_RATE_MAX");
const RESET_RATE_WINDOW_MS = parseNumberStrict("RESET_RATE_WINDOW_MS");
const RESET_RATE_MAX = parseNumberStrict("RESET_RATE_MAX");

const EMAIL_HOST = process.env.EMAIL_HOST;
const EMAIL_PORT = parseNumberStrict("EMAIL_PORT");
const EMAIL_SECURE = parseBoolStrict("EMAIL_SECURE");
const EMAIL_USER = process.env.EMAIL_USER;
const EMAIL_PASS = process.env.EMAIL_PASS;

// transporter nodemailer (configurado estritamente com env)
const transporter = nodemailer.createTransport({
  host: EMAIL_HOST,
  port: EMAIL_PORT,
  secure: EMAIL_SECURE,
  auth: {
    user: EMAIL_USER,
    pass: EMAIL_PASS,
  },
});

// verificar transporter no boot. Em ambiente de produção, se falhar, abortar.
// Em qualquer caso, falha aqui só indica problema de envio de email — mas como
// a aplicação exige envs, consideramos falha crítica também.
transporter.verify().then(() => {
  console.info("Email transporter verificado.");
}).catch(err => {
  console.error("FATAL: Falha ao verificar mail transporter (verifique EMAIL_HOST/EMAIL_PORT/EMAIL_USER/EMAIL_PASS).");
  console.error("Mensagem:", err?.message ?? err);
  process.exit(1);
});

// helpers
function genCode() {
  const n = crypto.randomInt(0, 1000000);
  return String(n).padStart(6, "0");
}
function hmacForCode(emailLower, code) {
  // usar RESET_SECRET *obrigatório*
  if (!RESET_SECRET) {
    // já garantido pelo fail-fast anterior, mas checamos por segurança
    throw new Error("RESET_SECRET não definido.");
  }
  return crypto.createHmac("sha256", RESET_SECRET).update(`${emailLower}|${code}`).digest("hex");
}
function timingSafeCompareHex(aHex, bHex) {
  try {
    const a = Buffer.from(aHex, "hex");
    const b = Buffer.from(bHex, "hex");
    if (a.length !== b.length) return false;
    return crypto.timingSafeEqual(a, b);
  } catch (e) {
    return false;
  }
}

// rate limiters: keyGenerator combina IP + e-mail para reduzir bypass.
// obs: ttl e limites vêm estritamente do .env (nenhuma opção alternativa)
const forgotLimiter = rateLimit({
  windowMs: FORGOT_RATE_WINDOW_MS,
  max: FORGOT_RATE_MAX,
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req) => {
    const ip = ipKeyGenerator(req);
    const email = (req.body && req.body.email) ? String(req.body.email).trim().toLowerCase() : "";
    return email ? `${ip}:${email}` : ip;
  }
});

const verifyLimiter = rateLimit({
  windowMs: VERIFY_RATE_WINDOW_MS,
  max: VERIFY_RATE_MAX,
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req) => {
    const ip = ipKeyGenerator(req);
    const email = (req.body && req.body.email) ? String(req.body.email).trim().toLowerCase() : "";
    return email ? `${ip}:${email}` : ip;
  }
});

const resetLimiter = rateLimit({
  windowMs: RESET_RATE_WINDOW_MS,
  max: RESET_RATE_MAX,
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req) => ipKeyGenerator(req),
});

// rota: esqueci a senha -> gera código e persiste HMAC
router.post("/forgot-password", forgotLimiter, async (req, res) => {
  try {
    const { email } = req.body;
    if (!email) return res.status(400).json({ error: "email obrigatório" });

    const emailLower = String(email).trim().toLowerCase();

    // TTL em minutos — fonte de verdade: .env
    const ttlMinutes = CODE_TTL_MINUTES;
    const expiresAt = new Date(Date.now() + ttlMinutes * 60 * 1000);

    const code = genCode();
    let hmac;
    try {
      hmac = hmacForCode(emailLower, code);
    } catch (err) {
      console.error("Erro ao gerar HMAC para código de reset (verifique RESET_SECRET).");
      return res.status(500).json({ error: "Configuração do servidor inválida" });
    }

    // invalidar tokens anteriores não consumidos e criar novo token de forma atômica
    try {
      await prisma.$transaction(async (tx) => {
        await tx.password_reset_token.updateMany({
          where: { email: emailLower, consumed: false },
          data: { consumed: true }
        });

        await tx.password_reset_token.create({
          data: {
            email: emailLower,
            hmac,
            expires_at: expiresAt,
            attempts: 0,
            used: false,
            consumed: false,
          },
        });
      });
    } catch (e) {
      // não expor detalhes sensíveis
      console.warn("warning: falha ao invalidar tokens anteriores ou criar novo token (DB).");
    }

    const mail = {
      from: EMAIL_FROM,
      to: emailLower,
      subject: "Código de redefinição de senha",
      text: `Seu código: ${code}. Válido por ${ttlMinutes} minutos.`,
      html: `<p>Seu código: <b>${code}</b>. Válido por ${ttlMinutes} minutos.</p>`,
    };

    try {
      await transporter.sendMail(mail);
    } catch (err) {
      // não vaza existência do e-mail — só logar mensagem genérica
      console.error("Falha ao enviar email de reset (verifique credenciais/servidor SMTP).");
    }

    return res.json({ success: true, message: "Se o e-mail existir, um código foi enviado." });
  } catch (err) {
    console.error("forgot-password error:", err?.message ?? err);
    return res.status(500).json({ error: "Erro interno" });
  }
});

// rota: verifica o código -> emite JWT curto com jti
router.post("/verify-reset-code", verifyLimiter, async (req, res) => {
  try {
    const { email, code } = req.body;
    if (!email || !code) return res.status(400).json({ error: "email e code obrigatórios" });

    const emailLower = String(email).trim().toLowerCase();

    const tokenRecord = await prisma.password_reset_token.findFirst({
      where: { email: emailLower, consumed: false },
      orderBy: { created_at: "desc" },
    });

    if (!tokenRecord) return res.status(400).json({ error: "Código inválido ou expirado" });

    if (new Date() > tokenRecord.expires_at) {
      // marca consumido para evitar reuso posterior
      await prisma.password_reset_token.update({ where: { id: tokenRecord.id }, data: { consumed: true } });
      return res.status(400).json({ error: "Código inválido ou expirado" });
    }

    const updated = await prisma.password_reset_token.updateMany({
      where: { id: tokenRecord.id, consumed: false, attempts: { lt: MAX_CODE_ATTEMPTS } },
      data: { attempts: { increment: 1 } }
    });
    if (updated.count === 0) {
      await prisma.password_reset_token.update({ where: { id: tokenRecord.id }, data: { consumed: true } });
      return res.status(429).json({ error: "Muitas tentativas" });
    }

    let providedHmac;
    try {
      providedHmac = hmacForCode(emailLower, String(code));
    } catch (err) {
      console.error("Erro ao gerar HMAC para verificação (verifique RESET_SECRET).");
      return res.status(500).json({ error: "Configuração do servidor inválida" });
    }

    if (!timingSafeCompareHex(providedHmac, tokenRecord.hmac)) {
      return res.status(401).json({ error: "Código inválido" });
    }

    const jti = crypto.randomBytes(16).toString("hex");
    const jwtPayload = { email: emailLower, purpose: "reset_password", jti };

    if (!RESET_JWT_SECRET) {
      console.error("FATAL: RESET_JWT_SECRET ausente (checado no boot).");
      return res.status(500).json({ error: "Configuração do servidor inválida: RESET_JWT_SECRET" });
    }

    // O JWT usa EXATAMENTE o TTL definido em .env (CODE_TTL_MINUTES)
    const token = jwt.sign(jwtPayload, RESET_JWT_SECRET, { expiresIn: `${CODE_TTL_MINUTES}m` });

    await prisma.password_reset_token.update({
      where: { id: tokenRecord.id },
      data: { used: true, jti, used_at: new Date() },
    });

    const user = await prisma.usuario.findUnique({ where: { email: emailLower } });
    if (user) {
      await prisma.logs_usuario.create({
        data: {
          id_do_usuario: user.id,
          acao_no_sistema: "Código de reset verificado, token JWT emitido",
        },
      });
    }

    return res.json({ token });
  } catch (err) {
    console.error("verify-reset-code error:", err?.message ?? err);
    return res.status(500).json({ error: "Erro interno ao verificar código" });
  }
});

// rota: reset final usando JWT de permissão
router.post("/reset-password", resetLimiter, async (req, res) => {
  try {
    const { token, newPassword } = req.body;
    if (!token || !newPassword) return res.status(400).json({ error: "token e newPassword obrigatórios" });

    if (!RESET_JWT_SECRET) {
      console.error("FATAL: RESET_JWT_SECRET ausente (checado no boot).");
      return res.status(500).json({ error: "Configuração do servidor inválida: RESET_JWT_SECRET" });
    }

    let payload;
    try {
      payload = jwt.verify(token, RESET_JWT_SECRET);
    } catch (err) {
      return res.status(401).json({ error: "Token inválido ou expirado" });
    }

    if (!payload || payload.purpose !== "reset_password" || !payload.email || !payload.jti) {
      return res.status(400).json({ error: "Token de permissão inválido" });
    }

    const emailLower = payload.email;
    const jti = payload.jti;

    const tokenRecord = await prisma.password_reset_token.findFirst({
      where: { email: emailLower, jti, used: true, consumed: false },
      orderBy: { created_at: "desc" },
    });
    if (!tokenRecord) return res.status(401).json({ error: "Token inválido ou já utilizado" });

    if (new Date() > tokenRecord.expires_at) {
      await prisma.password_reset_token.update({ where: { id: tokenRecord.id }, data: { consumed: true } });
      return res.status(400).json({ error: "Token expirado" });
    }

    if (typeof newPassword !== "string" || newPassword.length < 8) {
      return res.status(400).json({ error: "Senha fraca: mínimo 8 caracteres" });
    }

    const user = await prisma.usuario.findUnique({ where: { email: emailLower } });
    if (!user) return res.status(404).json({ error: "Usuário não encontrado" });

    const sameAsOld = await bcrypt.compare(newPassword, user.senha);
    if (sameAsOld) return res.status(400).json({ error: "Nova senha deve ser diferente da atual" });

    const salt = await bcrypt.genSalt(12);
    const hash = await bcrypt.hash(newPassword, salt);

    await prisma.usuario.update({ where: { id: user.id }, data: { senha: hash, updated_at: new Date() } });

    // marca token atual como consumido e revoga quaisquer tokens restantes (por email)
    await prisma.password_reset_token.update({ where: { id: tokenRecord.id }, data: { consumed: true, used_at: new Date() } });

    // revoga quaisquer outros tokens não consumidos para o mesmo email (boa prática)
    try {
      await prisma.password_reset_token.updateMany({
        where: { email: emailLower, consumed: false },
        data: { consumed: true, used_at: new Date() }
      });
    } catch (e) {
      console.warn("warning: não foi possível revogar todos os tokens pós-reset");
    }

    await prisma.logs_usuario.create({
      data: {
        id_do_usuario: user.id,
        acao_no_sistema: "Senha redefinida via fluxo de reset",
      },
    });

    return res.json({ success: true, message: "Senha atualizada com sucesso" });
  } catch (err) {
    console.error("reset-password error:", err?.message ?? err);
    return res.status(500).json({ error: "Erro interno ao resetar senha" });
  }
});

export default router;
