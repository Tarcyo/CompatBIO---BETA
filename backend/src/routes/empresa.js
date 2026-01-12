import express from "express";
import { PrismaClient } from "@prisma/client";
import authorizeAdministrative, { authenticateToken } from "../middleware/auth.js";
import multer from "multer";
import path from "path";
import fs from "fs";

const router = express.Router();
const prisma = new PrismaClient();

// Upload setup (multer grava temporariamente no disco)
const uploadDir = path.join(process.cwd(), "uploads", "empresas");
fs.mkdirSync(uploadDir, { recursive: true });

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, uploadDir),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase() || ".jpg";
    const name = `${Date.now()}-${Math.random().toString(36).slice(2, 8)}${ext}`;
    cb(null, name);
  },
});

const upload = multer({
  storage,
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB
});

// Valida CNPJ (apenas dígitos, 14 chars)
function isValidCNPJ(cnpj) {
  return typeof cnpj === "string" && /^[0-9]{14}$/.test(cnpj);
}

// Valida cor hexadecimal no formato #RRGGBB
function isValidHexColor(hex) {
  return typeof hex === "string" && /^#([0-9A-Fa-f]{6})$/.test(hex);
}

// Valida URL de imagem básica
function isValidImageUrl(url) {
  if (typeof url !== "string") return false;
  try {
    const u = new URL(url);
    return /\.(jpeg|jpg|png|webp)$/i.test(u.pathname);
  } catch {
    return false;
  }
}

function publicLogoPath(filenameOrUrl) {
  if (!filenameOrUrl) return null;
  if (Buffer.isBuffer(filenameOrUrl) || filenameOrUrl instanceof Uint8Array) return null;
  if (/^https?:\/\//i.test(filenameOrUrl)) return filenameOrUrl;
  // legacy local path -> expose under uploads
  return `/uploads/empresas/${path.basename(filenameOrUrl)}`;
}

function isBinaryLogo(logo) {
  return logo && (Buffer.isBuffer(logo) || logo instanceof Uint8Array);
}

function detectImageMime(buffer) {
  if (!buffer || buffer.length < 12) return null;
  const pngSig = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
  if (buffer.slice(0, 8).equals(pngSig)) return "image/png";
  if (buffer[0] === 0xff && buffer[1] === 0xd8 && buffer[2] === 0xff) return "image/jpeg";
  if (buffer.slice(0, 4).toString("ascii") === "RIFF" && buffer.slice(8, 12).toString("ascii") === "WEBP")
    return "image/webp";
  return null;
}

function readAndValidateUploadedFile(filePath, originalName) {
  try {
    if (!fs.existsSync(filePath)) return { error: "Arquivo temporário não encontrado" };
    const buffer = fs.readFileSync(filePath);
    const mime = detectImageMime(buffer);
    const ext = path.extname(originalName || "").toLowerCase();
    const allowedExts = [".jpg", ".jpeg", ".png", ".webp"];
    if (!mime && !allowedExts.includes(ext)) {
      return { error: "Arquivo não é uma imagem válida (png/jpg/webp)" };
    }
    return { buffer, mime };
  } catch (e) {
    return { error: "Falha ao ler arquivo enviado" };
  }
}

// -- helper para versionar logo (cache-busting)
// Se for binário: rota interna /empresas/:id/logo?v=timestamp
// Se for URL externa, retorna a URL tal qual.
// Se for caminho local (uploads), anexa ?v=timestamp
function logoPublicPathWithVersion(logoValue, empresaId) {
  if (!logoValue) return null;
  if (Buffer.isBuffer(logoValue) || logoValue instanceof Uint8Array) {
    return `/empresas/${empresaId}/logo?v=${Date.now()}`;
  }
  if (/^https?:\/\//i.test(logoValue)) return logoValue;
  // local file path
  return `/uploads/empresas/${path.basename(String(logoValue))}?v=${Date.now()}`;
}

// GET /empresas - lista todas as empresas (público)
router.get("/", async (req, res) => {
  try {
    const empresas = await prisma.empresa.findMany({
      orderBy: { id: "asc" },
      select: {
        id: true,
        nome: true,
        cnpj: true,
        corTema: true,
        logo: true,
      },
    });

    const mapped = empresas.map((e) => {
      const isBin = isBinaryLogo(e.logo);
      return {
        id: e.id,
        nome: e.nome,
        cnpj: e.cnpj,
        corTema: e.corTema,
        logo: logoPublicPathWithVersion(e.logo, e.id),
      };
    });

    res.json({ empresas: mapped });
  } catch (err) {
    console.error("Erro ao listar empresas:", err);
    res.status(500).json({ error: "Erro interno do servidor" });
  }
});

// GET /empresas/me - retorna a empresa vinculada ao usuário do token (protegido)
router.get("/me", authenticateToken, async (req, res) => {
  try {
    const payload = req.user;
    if (!payload) return res.status(401).json({ error: "Usuário não autenticado" });

    const rawUserId = payload.id ?? payload.userId ?? payload.sub ?? null;
    let user = null;

    if (rawUserId !== null && rawUserId !== undefined) {
      const uid = Number.isNaN(Number(rawUserId)) ? parseInt(String(rawUserId), 10) : Number(rawUserId);
      if (!Number.isNaN(uid)) {
        user = await prisma.usuario.findUnique({
          where: { id: uid },
          select: { id: true, id_empresa: true },
        });
      }
    }

    if (!user && payload.email) {
      user = await prisma.usuario.findUnique({
        where: { email: payload.email },
        select: { id: true, id_empresa: true },
      });
    }

    if (!user) return res.status(404).json({ error: "Usuário não encontrado" });

    if (!user.id_empresa) {
      return res.status(404).json({ error: "Nenhuma empresa vinculada a este usuário" });
    }

    const empresa = await prisma.empresa.findUnique({
      where: { id: user.id_empresa },
      select: { id: true, nome: true, cnpj: true, corTema: true, logo: true },
    });

    if (!empresa) return res.status(404).json({ error: "Empresa vinculada não encontrada" });

    empresa.logo = logoPublicPathWithVersion(empresa.logo, empresa.id);

    return res.json({ empresa });
  } catch (err) {
    console.error("Erro ao buscar empresa do usuário:", err);
    return res.status(500).json({ error: "Erro interno do servidor" });
  }
});

// GET /empresas/:id - obter empresa por id (público)
router.get("/:id", async (req, res) => {
  try {
    const id = parseInt(req.params.id, 10);
    if (Number.isNaN(id)) return res.status(400).json({ error: "ID inválido" });

    const empresa = await prisma.empresa.findUnique({
      where: { id },
      select: { id: true, nome: true, cnpj: true, corTema: true, logo: true },
    });

    if (!empresa) return res.status(404).json({ error: "Empresa não encontrada" });

    empresa.logo = logoPublicPathWithVersion(empresa.logo, empresa.id);
    res.json({ empresa });
  } catch (err) {
    console.error("Erro ao buscar empresa:", err);
    res.status(500).json({ error: "Erro interno do servidor" });
  }
});

// GET /empresas/:id/logo - serve o conteúdo binário da logo quando armazenada em Bytes
router.get("/:id/logo", async (req, res) => {
  try {
    const id = parseInt(req.params.id, 10);
    if (Number.isNaN(id)) return res.status(400).send("ID inválido");

    const empresa = await prisma.empresa.findUnique({
      where: { id },
      select: { logo: true },
    });

    if (!empresa) return res.status(404).send("Empresa não encontrada");

    const logo = empresa.logo;

    if (!logo) return res.status(404).send("Logo não encontrada");

    if (!isBinaryLogo(logo)) {
      if (/^https?:\/\//i.test(logo)) return res.redirect(logo);
      return res.redirect(publicLogoPath(logo));
    }

    const buffer = Buffer.from(logo);
    const mime = detectImageMime(buffer) || "application/octet-stream";
    // Cache-control para forçar revalidação no cliente
    res.setHeader("Content-Type", mime);
    res.setHeader("Cache-Control", "no-cache, max-age=0, must-revalidate");
    // opcional: ETag poderia ser calculado aqui, mas não é obrigatório para o fix rápido
    return res.send(buffer);
  } catch (err) {
    console.error("Erro ao servir logo:", err);
    return res.status(500).send("Erro ao servir logo");
  }
});

// POST /empresas - criar empresa (protegido)
router.post("/", authenticateToken, authorizeAdministrative, upload.single("logo"), async (req, res) => {
  let keptFilePath = null;
  try {
    const { nome, cnpj, corTema } = req.body;

    if (!nome || typeof nome !== "string" || !nome.trim()) {
      if (req.file && fs.existsSync(req.file.path)) fs.unlinkSync(req.file.path);
      return res.status(400).json({ error: "Campo 'nome' é obrigatório" });
    }
    if (!cnpj || !isValidCNPJ(cnpj)) {
      if (req.file && fs.existsSync(req.file.path)) fs.unlinkSync(req.file.path);
      return res.status(400).json({ error: "Campo 'cnpj' inválido. Deve conter 14 dígitos." });
    }
    if (!corTema || !isValidHexColor(corTema)) {
      if (req.file && fs.existsSync(req.file.path)) fs.unlinkSync(req.file.path);
      return res.status(400).json({ error: "Campo 'corTema' inválido. Use formato '#RRGGBB'." });
    }

    let logoValue = null;

    if (req.file) {
      const validation = readAndValidateUploadedFile(req.file.path, req.file.originalname);
      if (validation.error) {
        if (fs.existsSync(req.file.path)) fs.unlinkSync(req.file.path);
        return res.status(400).json({ error: validation.error });
      }
      logoValue = validation.buffer;
      keptFilePath = req.file.path;
    } else if (req.body.logo) {
      if (!isValidImageUrl(req.body.logo)) {
        return res.status(400).json({ error: "Campo 'logo' inválido. Deve ser URL de imagem (jpg/png/webp) ou enviar arquivo multipart." });
      }
      logoValue = req.body.logo;
    }

    const created = await prisma.empresa.create({
      data: {
        nome: nome.trim(),
        cnpj,
        corTema: corTema.toUpperCase(),
        logo: logoValue,
      },
      select: { id: true, nome: true, cnpj: true, corTema: true, logo: true },
    });

    if (keptFilePath) {
      try {
        if (fs.existsSync(keptFilePath)) fs.unlinkSync(keptFilePath);
      } catch (e) {
        console.warn("Falha ao remover arquivo temporário:", e);
      }
    }

    // version the returned logo URL
    const result = {
      id: created.id,
      nome: created.nome,
      cnpj: created.cnpj,
      corTema: created.corTema,
      logo: logoPublicPathWithVersion(created.logo, created.id),
    };

    res.status(201).json({ empresa: result });
  } catch (err) {
    if (keptFilePath) {
      try {
        if (fs.existsSync(keptFilePath)) fs.unlinkSync(keptFilePath);
      } catch (e) {
        console.warn("Falha ao remover arquivo temporário:", e);
      }
    }
    if (err && err.code === "P2002") {
      return res.status(409).json({ error: "CNPJ já cadastrado", meta: err.meta });
    }
    console.error("Erro criando empresa:", err);
    res.status(500).json({ error: "Erro interno do servidor" });
  }
});

// PATCH /empresas/:id - atualizar empresa (protegido)
router.patch("/:id", authenticateToken, upload.single("logo"), async (req, res) => {
  let keptFilePath = null;
  try {
    const id = parseInt(req.params.id, 10);
    if (Number.isNaN(id)) {
      if (req.file && fs.existsSync(req.file.path)) fs.unlinkSync(req.file.path);
      return res.status(400).json({ error: "ID inválido" });
    }

    const { nome, cnpj, corTema, logo: logoFromBody } = req.body;
    const data = {};

    if (nome !== undefined) {
      if (!nome || typeof nome !== "string" || !nome.trim()) {
        if (req.file && fs.existsSync(req.file.path)) fs.unlinkSync(req.file.path);
        return res.status(400).json({ error: "Campo 'nome' inválido" });
      }
      data.nome = nome.trim();
    }

    if (cnpj !== undefined) {
      if (!isValidCNPJ(cnpj)) {
        if (req.file && fs.existsSync(req.file.path)) fs.unlinkSync(req.file.path);
        return res.status(400).json({ error: "Campo 'cnpj' inválido. Deve conter 14 dígitos." });
      }
      data.cnpj = cnpj;
    }

    if (corTema !== undefined) {
      if (!isValidHexColor(corTema)) {
        if (req.file && fs.existsSync(req.file.path)) fs.unlinkSync(req.file.path);
        return res.status(400).json({ error: "Campo 'corTema' inválido. Use formato '#RRGGBB'." });
      }
      data.corTema = corTema.toUpperCase();
    }

    if (req.file) {
      const validation = readAndValidateUploadedFile(req.file.path, req.file.originalname);
      if (validation.error) {
        if (fs.existsSync(req.file.path)) fs.unlinkSync(req.file.path);
        return res.status(400).json({ error: validation.error });
      }
      data.logo = validation.buffer;
      keptFilePath = req.file.path;
    } else if (logoFromBody !== undefined) {
      if (logoFromBody === "") {
        data.logo = null;
      } else {
        if (!isValidImageUrl(logoFromBody)) {
          return res.status(400).json({ error: "Campo 'logo' inválido. Deve ser URL de imagem (jpg/png/webp) ou enviar arquivo multipart." });
        }
        data.logo = logoFromBody;
      }
    }

    if (Object.keys(data).length === 0) {
      if (req.file && fs.existsSync(req.file.path)) fs.unlinkSync(req.file.path);
      return res.status(400).json({ error: "Nenhum campo para atualizar foi fornecido" });
    }

    const existing = await prisma.empresa.findUnique({ where: { id }, select: { logo: true } });

    const updated = await prisma.empresa.update({
      where: { id },
      data,
      select: { id: true, nome: true, cnpj: true, corTema: true, logo: true },
    });

    // tentar remover arquivo local antigo se aplicável
    try {
      if (existing && existing.logo && !isBinaryLogo(existing.logo) && data.logo) {
        const old = existing.logo;
        if (!/^https?:\/\//i.test(old)) {
          const oldPath = path.join(uploadDir, path.basename(old));
          if (fs.existsSync(oldPath)) {
            try {
              fs.unlinkSync(oldPath);
            } catch (e) {
              console.warn("Falha ao remover old logo:", e);
            }
          }
        }
      }
    } catch (e) {
      console.warn("Erro ao tentar remover logo antiga:", e);
    }

    if (keptFilePath) {
      try {
        if (fs.existsSync(keptFilePath)) fs.unlinkSync(keptFilePath);
      } catch (e) {
        console.warn("Falha ao remover arquivo temporário:", e);
      }
    }

    // version the returned logo URL
    const result = {
      id: updated.id,
      nome: updated.nome,
      cnpj: updated.cnpj,
      corTema: updated.corTema,
      logo: logoPublicPathWithVersion(updated.logo, updated.id),
    };

    res.json({ empresa: result });
  } catch (err) {
    if (keptFilePath) {
      try {
        if (fs.existsSync(keptFilePath)) fs.unlinkSync(keptFilePath);
      } catch (e) {
        console.warn("Falha ao remover arquivo temporário:", e);
      }
    }
    if (err && err.code === "P2025") {
      return res.status(404).json({ error: "Empresa não encontrada" });
    }
    if (err && err.code === "P2002") {
      return res.status(409).json({ error: "CNPJ já cadastrado por outra empresa", meta: err.meta });
    }
    console.error("Erro atualizando empresa:", err);
    res.status(500).json({ error: "Erro interno do servidor" });
  }
});

export default router;
