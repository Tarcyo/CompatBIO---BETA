// routes/produtos.js
import express from "express";
import { PrismaClient } from "@prisma/client";
import { authenticateToken, authorizeAdministrative } from "../middleware/auth.js";

const router = express.Router();
const prisma = new PrismaClient();

// aplica o middleware de autenticação a todas as rotas deste router

/**
 * GET /produtos
 * Retorna:
 * {
 *   "produtos_biologicos": { "tipo A": ["nome1","nome2"], "tipo B": [...] },
 *   "produtos_quimicos":   { "tipo X": ["nomeA","nomeB"], ... }
 * }
 *
 * Regras:
 * - Se o usuário autenticado existir e tiver `ja_fez_compra === false`, então
 *   apenas produtos com demo = true são retornados (apenasDemo = true).
 * - Mantém o formato agrupado por tipo (para compatibilidade com fallback do cliente).
 */
router.get("/", authenticateToken, async (req, res) => {
  try {
    // determina se devemos restringir a resposta apenas a produtos com demo = true
    let apenasDemo = false;

    // tenta extrair informação do usuário a partir do payload (se presente)
    if (req.user) {
      const payload = req.user;
      const userId = payload.id ?? payload.userId ?? payload.sub ?? null;

      try {
        let user = null;
        if (userId) {
          user = await prisma.usuario.findUnique({ where: { id: Number(userId) } });
        } else if (payload.email) {
          user = await prisma.usuario.findUnique({ where: { email: payload.email } });
        }

        // se o usuário existir e estiver marcado como ja_fez_compra = false (0), ativamos o filtro
        if (user && user.ja_fez_compra === false) {
          apenasDemo = true;
        }
      } catch (err) {
        // não interrompe a rota principal por falha ao buscar usuário; apenas loga
        console.error("Aviso: falha ao verificar status de compra do usuário:", err);
      }
    }

    // monta cláusulas where respeitando a regra original e o novo filtro de demo quando aplicável
    const biologicosWhere = apenasDemo
      ? { genero: "biologico", demo: true }
      : { genero: "biologico" };

    const quimicosWhere = apenasDemo
      ? { genero: "quimico", demo: true }
      : { genero: "quimico" };

    // mantém a seleção original de campos (nome + tipo), compatível com o cliente que espera mapas
    const biologicos = await prisma.produto.findMany({
      where: biologicosWhere,
      select: { nome: true, tipo: true },
    });

    const quimicos = await prisma.produto.findMany({
      where: quimicosWhere,
      select: { nome: true, tipo: true },
    });

    const agruparPorTipo = (items) =>
      items.reduce((acc, { tipo, nome }) => {
        const chave = tipo ?? "não_informado";
        if (!acc[chave]) acc[chave] = [];
        acc[chave].push(nome);
        return acc;
      }, {});

    const resultado = {
      produtos_biologicos: agruparPorTipo(biologicos),
      produtos_quimicos: agruparPorTipo(quimicos),
    };

    return res.json(resultado);
  } catch (error) {
    console.error("Erro ao buscar produtos:", error);
    return res.status(500).json({ error: "Erro ao buscar produtos" });
  }
});

/**
 * GET /produtos/quimicos
 * Lista todos os produtos quimicos (admin)
 * Retorna objetos completos (inclui campo `demo`).
 */
router.get("/quimicos", authenticateToken, authorizeAdministrative, async (req, res) => {
  try {
    const list = await prisma.produto.findMany({
      where: { genero: "quimico" },
      orderBy: [{ tipo: "asc" }, { nome: "asc" }],
    });
    return res.json(list);
  } catch (err) {
    console.error("Erro ao listar produtos quimicos:", err);
    return res.status(500).json({ error: "Erro interno" });
  }
});

/**
 * GET /produtos/biologicos
 * Lista todos os produtos biologicos (admin)
 * Retorna objetos completos (inclui campo `demo`).
 */
router.get("/biologicos", authenticateToken, authorizeAdministrative, async (req, res) => {
  try {
    const list = await prisma.produto.findMany({
      where: { genero: "biologico" },
      orderBy: [{ tipo: "asc" }, { nome: "asc" }],
    });
    return res.json(list);
  } catch (err) {
    console.error("Erro ao listar produtos biologicos:", err);
    return res.status(500).json({ error: "Erro interno" });
  }
});

/**
 * POST /produtos/quimicos
 * Body:
 * { "nome": "NomeQuimico", "tipo": "Tipo", "demo": true } // demo opcional (boolean)
 * Requer autenticação e autorização administrativa.
 */
router.post("/quimicos", authenticateToken, authorizeAdministrative, async (req, res) => {
  try {
    const { nome, tipo, demo } = req.body;
    if (!nome || !tipo) return res.status(400).json({ error: "Campos obrigatórios ausentes" });

    // se forneceu demo, deve ser booleano
    if (demo !== undefined && typeof demo !== "boolean") {
      return res.status(400).json({ error: "Campo 'demo' deve ser booleano quando fornecido." });
    }

    const existe = await prisma.produto.findUnique({ where: { nome } });
    if (existe) return res.status(409).json({ error: "Produto já existe" });

    const dataToCreate = { nome, tipo, genero: "quimico", ...(demo !== undefined ? { demo } : {}) };

    const created = await prisma.produto.create({
      data: dataToCreate,
    });
    return res.status(201).json(created);
  } catch (err) {
    console.error("Erro ao criar produto_quimico:", err);
    return res.status(500).json({ error: "Erro interno ao criar produto químico" });
  }
});

/**
 * POST /produtos/biologicos
 * Body:
 * { "nome": "NomeBio", "tipo": "Tipo", "demo": false } // demo opcional (boolean)
 * Requer autenticação e autorização administrativa.
 */
router.post("/biologicos", authenticateToken, authorizeAdministrative, async (req, res) => {
  try {
    const { nome, tipo, demo } = req.body;
    if (!nome || !tipo) return res.status(400).json({ error: "Campos obrigatórios ausentes" });

    // se forneceu demo, deve ser booleano
    if (demo !== undefined && typeof demo !== "boolean") {
      return res.status(400).json({ error: "Campo 'demo' deve ser booleano quando fornecido." });
    }

    const existe = await prisma.produto.findUnique({ where: { nome } });
    if (existe) return res.status(409).json({ error: "Produto já existe" });

    const dataToCreate = { nome, tipo, genero: "biologico", ...(demo !== undefined ? { demo } : {}) };

    const created = await prisma.produto.create({
      data: dataToCreate,
    });
    return res.status(201).json(created);
  } catch (err) {
    console.error("Erro ao criar produto_biologico:", err);
    return res.status(500).json({ error: "Erro interno ao criar produto biológico" });
  }
});

/**
 * PUT /produtos/quimicos/:nome
 * Atualiza campos permitidos do produto químico.
 * Agora permite atualizar `tipo`, `demo` e também renomear `nome`.
 * Body exemplo: { "tipo": "NovoTipo", "nome": "NovoNome", "demo": true }
 * Requer autorização administrativa.
 */
router.put("/quimicos/:nome", authenticateToken, authorizeAdministrative, async (req, res) => {
  const nomeParam = req.params.nome;
  const { tipo, nome: novoNome, demo } = req.body ?? {};

  if ((tipo === undefined || tipo === null) && (novoNome === undefined || novoNome === null) && (demo === undefined || demo === null)) {
    return res.status(400).json({ error: "Forneça pelo menos um campo para atualização ('tipo' e/ou 'nome' e/ou 'demo')." });
  }

  // se demo for fornecido, validar boolean
  if (demo !== undefined && typeof demo !== "boolean") {
    return res.status(400).json({ error: "Campo 'demo' deve ser booleano quando fornecido." });
  }

  try {
    const existente = await prisma.produto.findUnique({ where: { nome: nomeParam } });
    if (!existente || existente.genero !== "quimico")
      return res.status(404).json({ error: "Produto químico não encontrado." });

    // se pediu renomear e novo nome é igual ao atual, ignorar esse campo
    const dataToUpdate = {};
    if (tipo !== undefined && tipo !== null) dataToUpdate.tipo = tipo;
    if (demo !== undefined) dataToUpdate.demo = demo;
    if (typeof novoNome === "string") {
      const trimmed = novoNome.trim();
      if (trimmed.length === 0) {
        return res.status(400).json({ error: "Novo nome inválido." });
      }
      if (trimmed !== existente.nome) {
        // verificar colisão de nome
        const clash = await prisma.produto.findUnique({ where: { nome: trimmed } });
        if (clash) {
          return res.status(409).json({ error: "Já existe outro produto com esse nome." });
        }
        dataToUpdate.nome = trimmed;
      }
    }

    // se nada para atualizar (ex: só enviou nome igual) retorna objeto atual
    if (Object.keys(dataToUpdate).length === 0) {
      return res.json(existente);
    }

    // atualizar usando where pelo nome antigo
    const atualizado = await prisma.produto.update({
      where: { nome: nomeParam },
      data: dataToUpdate,
    });

    return res.json(atualizado);
  } catch (err) {
    console.error("Erro ao atualizar produto_quimico:", err);
    if (err?.code === "P2002") {
      return res.status(409).json({ error: "Já existe outro produto com esse nome." });
    }
    return res.status(500).json({ error: "Erro interno ao atualizar produto químico" });
  }
});

/**
 * PUT /produtos/biologicos/:nome
 * Atualiza campos permitidos do produto biológico.
 * Agora permite atualizar `tipo`, `demo` e também renomear `nome`.
 * Body exemplo: { "tipo": "NovoTipo", "nome": "NovoNome", "demo": false }
 * Requer autorização administrativa.
 */
router.put("/biologicos/:nome", authenticateToken, authorizeAdministrative, async (req, res) => {
  const nomeParam = req.params.nome;
  const { tipo, nome: novoNome, demo } = req.body ?? {};

  if ((tipo === undefined || tipo === null) && (novoNome === undefined || novoNome === null) && (demo === undefined || demo === null)) {
    return res.status(400).json({ error: "Forneça pelo menos um campo para atualização ('tipo' e/ou 'nome' e/ou 'demo')." });
  }

  // se demo for fornecido, validar boolean
  if (demo !== undefined && typeof demo !== "boolean") {
    return res.status(400).json({ error: "Campo 'demo' deve ser booleano quando fornecido." });
  }

  try {
    const existente = await prisma.produto.findUnique({ where: { nome: nomeParam } });
    if (!existente || existente.genero !== "biologico")
      return res.status(404).json({ error: "Produto biológico não encontrado." });

    const dataToUpdate = {};
    if (tipo !== undefined && tipo !== null) dataToUpdate.tipo = tipo;
    if (demo !== undefined) dataToUpdate.demo = demo;
    if (typeof novoNome === "string") {
      const trimmed = novoNome.trim();
      if (trimmed.length === 0) {
        return res.status(400).json({ error: "Novo nome inválido." });
      }
      if (trimmed !== existente.nome) {
        // verificar colisão de nome
        const clash = await prisma.produto.findUnique({ where: { nome: trimmed } });
        if (clash) {
          return res.status(409).json({ error: "Já existe outro produto com esse nome." });
        }
        dataToUpdate.nome = trimmed;
      }
    }

    if (Object.keys(dataToUpdate).length === 0) {
      return res.json(existente);
    }

    const atualizado = await prisma.produto.update({
      where: { nome: nomeParam },
      data: dataToUpdate,
    });

    return res.json(atualizado);
  } catch (err) {
    console.error("Erro ao atualizar produto_biologico:", err);
    if (err?.code === "P2002") {
      return res.status(409).json({ error: "Já existe outro produto com esse nome." });
    }
    return res.status(500).json({ error: "Erro interno ao atualizar produto biológico" });
  }
});

/**
 * DELETE /produtos/quimicos/:nome
 * Remove um produto químico.
 * Rejeita a exclusão se existirem referências em catalogo_resultado ou solicitacao_analise.
 * Requer autorização administrativa.
 */
router.delete("/quimicos/:nome", authenticateToken, authorizeAdministrative, async (req, res) => {
  const nome = req.params.nome;

  try {
    const existente = await prisma.produto.findUnique({ where: { nome } });
    if (!existente || existente.genero !== "quimico")
      return res.status(404).json({ error: "Produto químico não encontrado." });

    const prodId = existente.id;

    // verifica referências que impediriam exclusão segura (usando os ids)
    const countCatalogo = await prisma.catalogo_resultado.count({ where: { id_produto_quimico: prodId } });
    const countSolic = await prisma.solicitacao_analise.count({ where: { id_produto_quimico: prodId } });

    if (countCatalogo > 0 || countSolic > 0) {
      return res.status(409).json({
        error:
          "Existem registros dependentes. Remova ou atualize referências em 'catalogo_resultado' e 'solicitacao_analise' antes de excluir.",
        dependencias: {
          catalogo_resultado: countCatalogo,
          solicitacao_analise: countSolic,
        },
      });
    }

    await prisma.produto.delete({ where: { id: prodId } });
    return res.status(200).json({ message: "Produto químico removido com sucesso." });
  } catch (err) {
    console.error("Erro ao deletar produto_quimico:", err);
    return res.status(500).json({ error: "Erro interno ao deletar produto químico" });
  }
});

/**
 * DELETE /produtos/biologicos/:nome
 * Remove um produto biológico.
 * Rejeita a exclusão se existirem referências em catalogo_resultado ou solicitacao_analise.
 * Requer autorização administrativa.
 */
router.delete("/biologicos/:nome", authenticateToken, authorizeAdministrative, async (req, res) => {
  const nome = req.params.nome;

  try {
    const existente = await prisma.produto.findUnique({ where: { nome } });
    if (!existente || existente.genero !== "biologico")
      return res.status(404).json({ error: "Produto biológico não encontrado." });

    const prodId = existente.id;

    const countCatalogo = await prisma.catalogo_resultado.count({ where: { id_produto_biologico: prodId } });
    const countSolic = await prisma.solicitacao_analise.count({ where: { id_produto_biologico: prodId } });

    if (countCatalogo > 0 || countSolic > 0) {
      return res.status(409).json({
        error:
          "Existem registros dependentes. Remova ou atualize referências em 'catalogo_resultado' e 'solicitacao_analise' antes de excluir.",
        dependencias: {
          catalogo_resultado: countCatalogo,
          solicitacao_analise: countSolic,
        },
      });
    }

    await prisma.produto.delete({ where: { id: prodId } });
    return res.status(200).json({ message: "Produto biológico removido com sucesso." });
  } catch (err) {
    console.error("Erro ao deletar produto_biologico:", err);
    return res.status(500).json({ error: "Erro interno ao deletar produto biológico" });
  }
});

export default router;
