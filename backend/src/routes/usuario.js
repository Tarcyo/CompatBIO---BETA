// routes/usuario.js
import express from "express";
import { PrismaClient } from "@prisma/client";
import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import { authenticateToken, authorizeAdministrative } from "../middleware/auth.js";
// import nodemailer, crypto, uuid já são usados abaixo
import nodemailer from "nodemailer";
import crypto from "crypto";
import { v4 as uuidv4 } from "uuid";
const router = express.Router();
const prisma = new PrismaClient();

// Helper: tenta converter uma string de data em Date válida
function parseDateOrNull(value) {
  if (!value && value !== "") return null;
  if (value instanceof Date) {
    return isNaN(value.getTime()) ? null : value;
  }
  const d = new Date(value);
  return isNaN(d.getTime()) ? null : d;
}

// Helper: calcula saldo atual do usuário somando pacotes não-vencidos
async function computeUserSaldo(prismaOrTx, userId) {
  const config = await prismaOrTx.config_sistema.findFirst({
    orderBy: { atualizado_em: "desc" },
  });
  const validadeDias = config?.validade_em_dias ?? 0;

  const pacotes = await prismaOrTx.pacote_creditos.findMany({
    where: { id_usuario: userId },
    select: { quantidade: true, data_recebimento: true },
  });

  const now = Date.now();
  const msPorDia = 24 * 60 * 60 * 1000;
  let soma = 0;
  for (const p of pacotes) {
    const recebidoTs = new Date(p.data_recebimento).getTime();
    const expiraEm = recebidoTs + validadeDias * msPorDia;
    if (expiraEm >= now) {
      soma += p.quantidade;
    }
  }
  return soma;
}

// Helper: transforma logo Bytes -> base64 (ou null)
function empresaLogoToBase64(empresaObj) {
  if (!empresaObj) return null;
  try {
    const logo = empresaObj.logo;
    if (!logo) return { ...empresaObj, logo_base64: null };
    // logo pode ser Buffer ou Uint8Array
    const base64 = Buffer.from(logo).toString("base64");
    // retornamos uma cópia com campo adicional logo_base64 (sem sobrescrever logo original)
    const { logo: _skip, ...rest } = empresaObj;
    return { ...rest, logo_base64: base64 };
  } catch (err) {
    // fallback: retorna sem logo_base64
    const { logo: _skip, ...rest } = empresaObj || {};
    return { ...rest, logo_base64: null };
  }
}

/**
 * POST /usuarios/administrativo
 * cria usuário do tipo "admin" — exige a senha secreta presente em process.env.ADMIN_CREATION_SECRET
 *
 * Segurança/uso:
 * - A senha secreta de criação deve estar em .env: ADMIN_CREATION_SECRET="valor-muit0-secreto"
 * - A rota aceita o segredo via header "x-admin-secret" (recomendado) ou via body.admin_secret (fallback).
 * - Não logue o segredo em lugar nenhum.
 */
// Rota: POST /administrativo
router.post("/administrativo", async (req, res) => {
  try {
    let { nome, cpf, email, senha } = req.body;

    // Ler segredo (prefere header)
    const providedSecret =
      (req.headers["x-admin-secret"] && String(req.headers["x-admin-secret"])) ||
      (req.body && req.body.admin_secret && String(req.body.admin_secret)) ||
      null;

    const envSecret = process.env.ADMIN_CREATION_SECRET;
    if (!envSecret) {
      console.error("ADMIN_CREATION_SECRET não definido em process.env");
      return res.status(500).json({ error: "Configuração do servidor incompleta" });
    }
    if (!providedSecret) {
      return res.status(401).json({ error: "Segredo administrativo não fornecido" });
    }

    // comparação timing-safe: hash both secrets to fixed length then timingSafeEqual
    const providedHash = crypto.createHash("sha256").update(providedSecret, "utf8").digest();
    const envHash = crypto.createHash("sha256").update(envSecret, "utf8").digest();

    let secretMatches = false;
    try {
      secretMatches = crypto.timingSafeEqual(providedHash, envHash);
    } catch (e) {
      secretMatches = false;
    }

    if (!secretMatches) {
      return res.status(401).json({ error: "Segredo administrativo inválido" });
    }

    // Normalizações
    if (typeof email === "string") email = email.trim().toLowerCase();
    if (typeof nome === "string") nome = nome.trim();

    // Validações básicas
    if (!nome || !cpf || !email || !senha) {
      return res.status(400).json({ error: "nome, cpf, email e senha são obrigatórios" });
    }

    // CPF: exatamente 11 dígitos (somente números)
    if (typeof cpf !== "string" || !/^\d{11}$/.test(cpf)) {
      return res.status(400).json({
        error: "cpf deve ser uma string contendo exatamente 11 dígitos (somente números)",
      });
    }

    // Email simples
    if (typeof email !== "string" || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return res.status(400).json({ error: "email inválido" });
    }

    // Senha: mínimo 6 (conforme você pediu)
    if (typeof senha !== "string" || senha.length < 6) {
      return res.status(400).json({
        error: "senha administrativa deve ter no mínimo 6 caracteres",
      });
    }

    // Hash da senha
    const salt = await bcrypt.genSalt(12);
    const passwordHash = await bcrypt.hash(senha, salt);

    // IP do solicitante (tenta x-forwarded-for antes)
    const ip = (req.headers["x-forwarded-for"] || req.ip || "").toString();

    // Cria o admin no DB com tipo_usuario exatamente "administrativo"
    const novoAdmin = await prisma.$transaction(async (tx) => {
      const created = await tx.usuario.create({
        data: {
          nome,
          cpf,
          email,
          senha: passwordHash,
          // **IMPORTANTE**: valor que o middleware procura
          tipo_usuario: "administrativo",
          // garantir que o admin já apareça como tendo feito compra
          ja_fez_compra: true,
        },
        select: {
          id: true,
          nome: true,
          email: true,
          tipo_usuario: true,
          ja_fez_compra: true,
          created_at: true,
        },
      });

      // Opcional: gravar log de auditoria em logs_usuario
      try {
        await tx.logs_usuario.create({
          data: {
            id_do_usuario: created.id,
            acao_no_sistema: `Criação de usuário administrativo via segredo (IP: ${ip})`,
          },
        });
      } catch (logErr) {
        // não interrompe criação se log falhar
        console.warn("Falha ao gravar log de auditoria:", logErr);
      }

      return created;
    });

    // Retorna sem expor senha/hash
    return res.status(201).json({
      id: novoAdmin.id,
      nome: novoAdmin.nome,
      email: novoAdmin.email,
      tipo_usuario: novoAdmin.tipo_usuario, // será "administrativo"
      ja_fez_compra: novoAdmin.ja_fez_compra,
      created_at: novoAdmin.created_at,
    });
  } catch (err) {
    // Unique constraint (P2002)
    if (err && err.code === "P2002") {
      // err.meta.target pode ser um array com nomes de campos
      const target = err.meta && err.meta.target ? err.meta.target : undefined;
      return res.status(409).json({
        error: "Violação de única (campo já existe)",
        field: target,
        meta: err.meta,
      });
    }
    console.error("Erro criando admin:", err);
    return res.status(500).json({ error: "Erro interno do servidor" });
  }
});

/**
 * POST /usuarios
 * criar usuário (agora com id_empresa opcional)
 */
router.post("/cliente", async (req, res) => {
  try {
    const {
      nome,
      cpf,
      email,
      senha,
      data_nascimento,
      id_empresa,
      telefone,
      cidade,
      estado,
      saldo_em_creditos,
      id_vinculo_assinatura,
    } = req.body;

    if (req.body.tipo_usuario && req.body.tipo_usuario !== "Cliente") {
      console.warn(
        `Tentativa de setar tipo_usuario via /cliente: valor recebido="${req.body.tipo_usuario}", ip=${req.ip}`
      );
    }

    // Validações básicas
    if (!nome || !cpf || !email || !senha) {
      return res
        .status(400)
        .json({ error: "nome, cpf, email e senha são obrigatórios" });
    }
    if (typeof cpf !== "string" || cpf.length !== 11) {
      return res.status(400).json({
        error: "cpf deve ser uma string com 11 caracteres (somente números)",
      });
    }
    if (
      id_empresa !== undefined &&
      id_empresa !== null &&
      !Number.isInteger(id_empresa)
    ) {
      return res
        .status(400)
        .json({ error: "id_empresa deve ser um inteiro ou ausente" });
    }

    // se forneceu id_empresa, verificar existência da empresa
    if (id_empresa !== undefined && id_empresa !== null) {
      const existe = await prisma.empresa.findUnique({
        where: { id: Number(id_empresa) },
        select: { id: true },
      });
      if (!existe) {
        return res
          .status(400)
          .json({ error: "Empresa (id_empresa) não encontrada" });
      }
    }

    const parsedDate = parseDateOrNull(data_nascimento);
    if (data_nascimento && !parsedDate) {
      return res
        .status(400)
        .json({ error: "data_nascimento inválida. Use ISO-8601 ou YYYY-MM-DD" });
    }

    // Hash da senha
    const salt = await bcrypt.genSalt(10);
    const passwordHash = await bcrypt.hash(senha, salt);

    // Criar usuário e opcionalmente criar pacote de créditos inicial se saldo_em_creditos fornecido
    const novoUsuario = await prisma.$transaction(async (tx) => {
      const created = await tx.usuario.create({
        data: {
          nome,
          cpf,
          email,
          senha: passwordHash,
          data_nascimento: parsedDate,
          id_empresa: id_empresa ?? null,
          // Forçamos explicitamente o tipo para "cliente" — ignorando o que vier no payload
          tipo_usuario: "Cliente",
          telefone: telefone || null,
          cidade: cidade || null,
          estado: estado || null,
          id_vinculo_assinatura: id_vinculo_assinatura ?? null,
        },
        select: {
          id: true,
          nome: true,
          cpf: true,
          email: true,
          tipo_usuario: true,
          created_at: true,
          id_empresa: true,
          empresa_rel: {
            select: {
              id: true,
              nome: true,
              cnpj: true,
              corTema: true,
              logo: true,
            },
          },
        },
      });

      // garantimos um timestamp único e consistente para os pacotes criados neste fluxo
      const now = new Date();

      // Sempre criar pacote de crédito "amostra grátis" com 1 crédito e descrição/origem indicada
      await tx.pacote_creditos.create({
        data: {
          id_usuario: created.id,
          quantidade: 1,
          origem: "Amostra grátis de criação de conta!",
          data_recebimento: now,
        },
      });

      // Se vier saldo_em_creditos no payload e for > 0, criar pacote de créditos adicional
      if (
        typeof saldo_em_creditos === "number" &&
        Number.isInteger(saldo_em_creditos) &&
        saldo_em_creditos > 0
      ) {
        await tx.pacote_creditos.create({
          data: {
            id_usuario: created.id,
            quantidade: saldo_em_creditos,
            origem: "inicial",
            data_recebimento: now,
          },
        });
      }

      return created;
    });

    // Calcular saldo atual para manter resposta igual
    const saldoAtual = await computeUserSaldo(prisma, novoUsuario.id);

    // transformar empresa_rel.logo (Bytes) em base64 para cliente
    const empresaFormatted = novoUsuario.empresa_rel
      ? empresaLogoToBase64(novoUsuario.empresa_rel)
      : null;

    return res.status(201).json({
      id: novoUsuario.id,
      nome: novoUsuario.nome,
      cpf: novoUsuario.cpf,
      email: novoUsuario.email,
      tipo_usuario: novoUsuario.tipo_usuario, // será "cliente"
      created_at: novoUsuario.created_at,
      saldo_em_creditos: saldoAtual,
      empresa: empresaFormatted ?? null,
    });
  } catch (err) {
    if (err && err.code === "P2002") {
      return res
        .status(409)
        .json({ error: "Violação de única (campo já existe)", meta: err.meta });
    }
    console.error("Erro criando usuário:", err);
    return res.status(500).json({ error: "Erro interno do servidor" });
  }
});


/**
 * POST /usuarios/login
 */
router.post("/login", async (req, res) => {
  try {
    const { email, senha } = req.body;
    if (!email || !senha) {
      return res.status(400).json({ error: "email e senha são obrigatórios" });
    }

    const usuario = await prisma.usuario.findUnique({
      where: { email },
      select: {
        id: true,
        nome: true,
        email: true,
        senha: true,
        tipo_usuario: true,
        id_empresa: true,
        empresa_rel: {
          select: {
            id: true,
            nome: true,
            cnpj: true,
            corTema: true,
            logo: true,
          },
        },
      },
    });

    if (!usuario) {
      return res.status(401).json({ error: "Credenciais inválidas" });
    }

    const senhaValida = await bcrypt.compare(senha, usuario.senha);
    if (!senhaValida) {
      return res.status(401).json({ error: "Credenciais inválidas" });
    }

    const secret = process.env.JWT_SECRET;
    if (!secret) {
      console.error("JWT_SECRET não definido em process.env");
      return res.status(500).json({ error: "Configuração de servidor inválida" });
    }

    const payload = {
      id: usuario.id,
      email: usuario.email,
      tipo_usuario: usuario.tipo_usuario ?? null,
    };

    const token = jwt.sign(payload, secret, { expiresIn: "8h" });

    const empresaFormatted = usuario.empresa_rel
      ? empresaLogoToBase64(usuario.empresa_rel)
      : null;

    return res.json({
      token,
      user: {
        id: usuario.id,
        nome: usuario.nome,
        email: usuario.email,
        tipo_usuario: usuario.tipo_usuario ?? null,
        empresa: empresaFormatted ?? null,
      },
    });
  } catch (err) {
    console.error("Erro no login:", err);
    return res.status(500).json({ error: "Erro interno do servidor" });
  }
});

/**
 * GET /usuarios/verify-token
 */
router.get("/verify-token", authenticateToken, async (req, res) => {
  try {
    const userId = req.user && req.user.id;
    if (!userId) {
      return res.status(400).json({ error: "Token não contém id de usuário" });
    }

    const usuario = await prisma.usuario.findUnique({
      where: { id: userId },
      select: {
        id: true,
        nome: true,
        email: true,
        tipo_usuario: true,
        id_empresa: true,
        empresa_rel: {
          select: {
            id: true,
            nome: true,
            cnpj: true,
            corTema: true,
            logo: true,
          },
        },
      },
    });

    if (!usuario) {
      return res.status(404).json({ error: "Usuário não encontrado" });
    }

    const saldoAtual = await computeUserSaldo(prisma, userId);

    const empresaFormatted = usuario.empresa_rel
      ? empresaLogoToBase64(usuario.empresa_rel)
      : null;

    return res.json({
      valid: true,
      user: {
        id: usuario.id,
        nome: usuario.nome,
        email: usuario.email,
        tipo_usuario: usuario.tipo_usuario ?? null,
        id_empresa: usuario.id_empresa ?? null,
        empresa: empresaFormatted ?? null,
        saldo_em_creditos: saldoAtual,
      },
    });
  } catch (err) {
    console.error("Erro verificando token:", err);
    return res.status(500).json({ error: "Erro interno do servidor" });
  }
});

/**
 * GET /usuarios/saldo
 */
router.get("/saldo", authenticateToken, async (req, res) => {
  try {
    const userId = req.user && req.user.id;
    if (!userId) return res.status(400).json({ error: "Token não contém id de usuário" });

    const usuario = await prisma.usuario.findUnique({
      where: { id: userId },
      select: {
        id: true,
        nome: true,
      },
    });

    if (!usuario) return res.status(404).json({ error: "Usuário não encontrado" });

    const saldo = await computeUserSaldo(prisma, userId);

    return res.json({ saldo_em_creditos: saldo, user: { id: usuario.id, nome: usuario.nome } });
  } catch (err) {
    console.error("Erro ao buscar saldo:", err);
    return res.status(500).json({ error: "Erro interno do servidor" });
  }
});

/**
 * PATCH /usuarios/saldo
 */
router.patch("/saldo", authenticateToken, async (req, res) => {
  try {
    const requesterId = req.user && req.user.id;
    const requesterTipo = req.user && req.user.tipo_usuario;
    if (!requesterId) return res.status(400).json({ error: "Token não contém id de usuário" });

    const { amount, operation = "add", target_user_id, reason } = req.body;

    if (typeof amount !== "number" || !Number.isInteger(amount) || amount < 0) {
      return res.status(400).json({ error: "amount deve ser um inteiro não-negativo" });
    }
    if (!["add", "subtract", "set"].includes(operation)) {
      return res.status(400).json({ error: "operation inválida. Use 'add', 'subtract' ou 'set'" });
    }

    const targetUserId = target_user_id ?? requesterId;
    if (targetUserId !== requesterId && requesterTipo !== "admin") {
      return res.status(403).json({ error: "Permissão negada para modificar saldo de outro usuário" });
    }

    if (operation === "set" && requesterTipo !== "admin") {
      return res.status(403).json({ error: "Apenas admin pode usar operation 'set'" });
    }

    const result = await prisma.$transaction(async (tx) => {
      // valida usuário alvo
      const user = await tx.usuario.findUnique({
        where: { id: targetUserId },
        select: { id: true, nome: true },
      });
      if (!user) throw { status: 404, message: "Usuário alvo não encontrado" };

      // calcula saldo atual usando pacotes não-vencidos
      const saldoAtual = await computeUserSaldo(tx, targetUserId);

      if (operation === "add") {
        // cria pacote positivo
        await tx.pacote_creditos.create({
          data: {
            id_usuario: targetUserId,
            quantidade: amount,
            origem: `manual_add (operador:${requesterId})`,
            data_recebimento: new Date(),
          },
        });
      } else if (operation === "subtract") {
        if (saldoAtual < amount) throw { status: 400, message: "Saldo insuficiente para subtração" };
        // cria pacote negativo para consumir créditos
        await tx.pacote_creditos.create({
          data: {
            id_usuario: targetUserId,
            quantidade: -amount,
            origem: `manual_subtract (operador:${requesterId})`,
            data_recebimento: new Date(),
          },
        });
      } else if (operation === "set") {
        const diff = amount - saldoAtual;
        if (diff > 0) {
          await tx.pacote_creditos.create({
            data: {
              id_usuario: targetUserId,
              quantidade: diff,
              origem: `manual_set_add (operador:${requesterId})`,
              data_recebimento: new Date(),
            },
          });
        } else if (diff < 0) {
          await tx.pacote_creditos.create({
            data: {
              id_usuario: targetUserId,
              quantidade: diff, // diff é negativo
              origem: `manual_set_subtract (operador:${requesterId})`,
              data_recebimento: new Date(),
            },
          });
        }
      }

      // registra log
      const acao = `Saldo ${operation} ${amount}. Motivo: ${reason ?? ""} (operador: ${requesterId})`;
      await tx.logs_usuario.create({
        data: {
          id_do_usuario: targetUserId,
          acao_no_sistema: acao,
        },
      });

      // recalcular saldo e retornar objeto semelhante ao antigo
      const novoSaldo = await computeUserSaldo(tx, targetUserId);
      return { id: user.id, nome: user.nome, saldo_em_creditos: novoSaldo };
    });

    return res.json({ success: true, user: result });
  } catch (err) {
    if (err && err.status && err.message) {
      return res.status(err.status).json({ error: err.message });
    }
    console.error("Erro ao modificar saldo:", err);
    return res.status(500).json({ error: "Erro interno do servidor" });
  }
});

/**
 * PATCH /usuarios/me -> atualizar dados do usuário logado
 */
router.patch("/me", authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;
    const {
      nome,
      id_empresa, // agora atualizamos via FK
      cpf,
      email,
      telefone,
      cidade,
      estado,
      data_nascimento,
    } = req.body;

    if (id_empresa !== undefined && id_empresa !== null && !Number.isInteger(id_empresa)) {
      return res.status(400).json({ error: "id_empresa deve ser um inteiro ou ausente" });
    }

    // se for fornecer id_empresa, validar existência
    if (id_empresa !== undefined && id_empresa !== null) {
      const existe = await prisma.empresa.findUnique({
        where: { id: Number(id_empresa) },
        select: { id: true },
      });
      if (!existe) {
        return res.status(400).json({ error: "Empresa (id_empresa) não encontrada" });
      }
    }

    const parsedDate = data_nascimento ? new Date(data_nascimento) : null;

    const updatedUser = await prisma.usuario.update({
      where: { id: userId },
      data: {
        nome,
        id_empresa: id_empresa ?? undefined,
        cpf,
        email,
        telefone,
        cidade,
        estado,
        data_nascimento: parsedDate,
        updated_at: new Date(),
      },
      select: {
        id: true,
        nome: true,
        cpf: true,
        email: true,
        telefone: true,
        cidade: true,
        estado: true,
        id_empresa: true,
        empresa_rel: {
          select: {
            id: true,
            nome: true,
            cnpj: true,
            corTema: true,
            logo: true,
          },
        },
        data_nascimento: true,
        updated_at: true,
      },
    });

    const empresaFormatted = updatedUser.empresa_rel
      ? empresaLogoToBase64(updatedUser.empresa_rel)
      : null;

    return res.json({
      user: {
        id: updatedUser.id,
        nome: updatedUser.nome,
        cpf: updatedUser.cpf,
        email: updatedUser.email,
        telefone: updatedUser.telefone,
        cidade: updatedUser.cidade,
        estado: updatedUser.estado,
        data_nascimento: updatedUser.data_nascimento,
        updated_at: updatedUser.updated_at,
        id_empresa: updatedUser.id_empresa,
        empresa: empresaFormatted ?? null,
      },
    });
  } catch (err) {
    console.error("Erro no PATCH /usuarios/me:", err);
    return res.status(500).json({ error: "Erro interno do servidor" });
  }
});

/**
 * GET /usuarios/me -> dados completos do usuário + plano
 */
router.get("/me", authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;

    const user = await prisma.usuario.findUnique({
      where: { id: userId },
      include: {
        vinculoAssinatura: {
          include: {
            plano: true,
          },
        },
        empresa_rel: {
          select: {
            id: true,
            nome: true,
            cnpj: true,
            corTema: true,
            logo: true,
          },
        },
      },
    });

    if (!user) {
      return res.status(404).json({ message: "Usuário não encontrado" });
    }

    const plano = user.vinculoAssinatura?.plano || null;
    const saldoAtual = await computeUserSaldo(prisma, userId);

    const empresaFormatted = user.empresa_rel ? empresaLogoToBase64(user.empresa_rel) : null;

    res.json({
      user: {
        id: user.id,
        nome: user.nome,
        cpf: user.cpf,
        email: user.email,
        tipo_usuario: user.tipo_usuario,
        telefone: user.telefone,
        cidade: user.cidade,
        estado: user.estado,
        data_nascimento: user.data_nascimento,
        created_at: user.created_at,
        updated_at: user.updated_at,
        id_empresa: user.id_empresa ?? null,
        empresa: empresaFormatted ?? null,
        saldo_em_creditos: saldoAtual,
        plano: plano
          ? {
            id: plano.id,
            nome: plano.nome,
            preco_mensal: plano.preco_mensal,
            quantidade_credito_mensal: plano.quantidade_credito_mensal,
          }
          : null,
      },
    });
  } catch (error) {
    console.error("Erro ao buscar perfil:", error);
    res.status(500).json({ error: "Erro interno do servidor" });
  }
});

/**
 * GET /usuarios/empresa/:id
 * lista usuários vinculados a uma empresa
 */
router.get("/empresa/:id", authenticateToken, async (req, res) => {
  try {
    const empresaId = parseInt(req.params.id, 10);
    if (Number.isNaN(empresaId)) return res.status(400).json({ error: "ID da empresa inválido" });

    // opcional: checar existência da empresa
    const existe = await prisma.empresa.findUnique({ where: { id: empresaId }, select: { id: true } });
    if (!existe) return res.status(404).json({ error: "Empresa não encontrada" });

    const users = await prisma.usuario.findMany({
      where: { id_empresa: empresaId },
      select: {
        id: true,
        nome: true,
        email: true,
        tipo_usuario: true,
        telefone: true,
        cidade: true,
        estado: true,
        created_at: true,
      },
    });

    return res.json({ empresaId, usuarios: users });
  } catch (err) {
    console.error("Erro ao listar usuários por empresa:", err);
    return res.status(500).json({ error: "Erro interno do servidor" });
  }
});

/**
 * PATCH /usuarios/:id/empresa
 * atualiza o vínculo de empresa de um usuário (admin ou o próprio usuário)
 * body: { id_empresa: number | null }
 */
router.patch("/:id/empresa", authenticateToken, async (req, res) => {
  try {
    const requesterId = req.user.id;
    const requesterTipo = req.user.tipo_usuario;
    const targetUserId = parseInt(req.params.id, 10);
    if (Number.isNaN(targetUserId)) return res.status(400).json({ error: "ID de usuário inválido" });

    // permissão: admin pode atualizar qualquer usuário; usuário comum só pode atualizar o próprio vínculo
    if (requesterId !== targetUserId && requesterTipo !== "admin") {
      return res.status(403).json({ error: "Permissão negada" });
    }

    const { id_empresa } = req.body;
    if (id_empresa !== undefined && id_empresa !== null && !Number.isInteger(id_empresa)) {
      return res.status(400).json({ error: "id_empresa deve ser um inteiro ou null" });
    }

    if (id_empresa !== undefined && id_empresa !== null) {
      const existe = await prisma.empresa.findUnique({ where: { id: Number(id_empresa) }, select: { id: true } });
      if (!existe) return res.status(404).json({ error: "Empresa não encontrada" });
    }

    const updated = await prisma.usuario.update({
      where: { id: targetUserId },
      data: { id_empresa: id_empresa ?? null, updated_at: new Date() },
      select: {
        id: true,
        nome: true,
        email: true,
        id_empresa: true,
        empresa_rel: {
          select: {
            id: true,
            nome: true,
            cnpj: true,
            corTema: true,
            logo: true,
          },
        },
      },
    });

    const empresaFormatted = updated.empresa_rel ? empresaLogoToBase64(updated.empresa_rel) : null;

    return res.json({
      success: true,
      user: {
        id: updated.id,
        nome: updated.nome,
        email: updated.email,
        id_empresa: updated.id_empresa,
        empresa: empresaFormatted ?? null,
      },
    });
  } catch (err) {
    console.error("Erro ao atualizar vínculo de empresa:", err);
    return res.status(500).json({ error: "Erro interno do servidor" });
  }
});

export default router;