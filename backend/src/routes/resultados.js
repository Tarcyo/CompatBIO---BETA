// routes/resultados.js
import express from "express";
import { PrismaClient } from "@prisma/client";
import { authenticateToken, authorizeAdministrative } from "../middleware/auth.js";

const prisma = new PrismaClient();
const router = express.Router();

/**
 * Helper: resolve produto por nome+genero OU por id.
 * - Se for passado id (number) busca por id.
 * - Se for passado nome (string) busca por nome e genero (evita ambiguidade).
 * Retorna o objeto produto ou null se não existir.
 *
 * generoEsperado deve ser 'quimico' ou 'biologico'.
 */
async function resolveProduto({ id, nome }, generoEsperado) {
  if (id !== undefined && id !== null) {
    // procura por id
    const byId = await prisma.produto.findUnique({ where: { id } });
    // garante que o produto encontrado tem o gênero esperado (se encontrar)
    if (!byId) return null;
    if (byId.genero !== generoEsperado) return null;
    return byId;
  }

  if (nome) {
    // procura por nome + genero (nome é unico no schema, mas protegemos procurando pelo genero também)
    const byName = await prisma.produto.findFirst({
      where: { nome: nome, genero: generoEsperado },
    });
    return byName;
  }

  return null;
}

/**
 * POST /resultados
 * Protegido por token E apenas para admin.
 * Body esperado (JSON):
 * Pode enviar por NOME (compatibilidade com cliente antigo):
 * {
 *   "nome_produto_quimico": "NomeQuimico",
 *   "nome_produto_biologico": "NomeBio",
 *   "resultado_final": "texto opcional",
 *   "descricao_resultado": "texto opcional"
 * }
 * Ou por ID (também aceito):
 * {
 *   "id_produto_quimico": 123,
 *   "id_produto_biologico": 456,
 *   ...
 * }
 * Mistura também funciona (por exemplo id para um, nome para outro).
 */
router.post("/", authenticateToken, authorizeAdministrative, async (req, res) => {
  try {
    const {
      nome_produto_quimico,
      nome_produto_biologico,
      id_produto_quimico,
      id_produto_biologico,
      resultado_final,
      descricao_resultado,
    } = req.body;

    // valida presença de referência (nome ou id) para ambos os produtos
    if (
      (id_produto_quimico === undefined && !nome_produto_quimico) ||
      (id_produto_biologico === undefined && !nome_produto_biologico)
    ) {
      return res.status(400).json({ error: "Campos obrigatórios ausentes." });
    }

    // resolve os produtos (respeitando genero esperado)
    const quim = await resolveProduto(
      { id: id_produto_quimico, nome: nome_produto_quimico },
      "quimico"
    );
    const bio = await resolveProduto(
      { id: id_produto_biologico, nome: nome_produto_biologico },
      "biologico"
    );

    if (!quim || !bio) {
      return res.status(400).json({
        error:
          "Produto químico ou biológico não encontrado. Crie/forneça os produtos corretamente antes de criar o resultado.",
      });
    }

    const novo = await prisma.catalogo_resultado.create({
      data: {
        id_produto_quimico: quim.id,
        id_produto_biologico: bio.id,
        resultado_final: resultado_final ?? null,
        descricao_resultado: descricao_resultado ?? null,
      },
      include: {
        produto_biologico: true,
        produto_quimico: true,
      },
    });

    return res.status(201).json(novo);
  } catch (err) {
    // trata unique constraint (par único: id_produto_quimico + id_produto_biologico)
    if (err && err.code === "P2002") {
      return res.status(409).json({ error: "Resultado já existe (par único)." });
    }
    console.error("Erro ao criar resultado:", err);
    return res.status(500).json({ error: "Erro interno ao criar resultado" });
  }
});

/**
 * GET /resultados
 * Protegido por token E apenas para admin.
 * Retorna todos os resultados (paginação simples por query ?skip=&take=)
 */
router.get("/", authenticateToken, authorizeAdministrative, async (req, res) => {
  try {
    const skip = parseInt(req.query.skip || "0", 10);
    const take = req.query.take ? parseInt(req.query.take, 10) : undefined;

    const resultados = await prisma.catalogo_resultado.findMany({
      skip: isNaN(skip) ? 0 : skip,
      take: isNaN(take) ? undefined : take,
      orderBy: { criado_em: "desc" },
      include: { produto_biologico: true, produto_quimico: true },
    });

    return res.json(resultados);
  } catch (err) {
    console.error("Erro ao buscar resultados:", err);
    return res.status(500).json({ error: "Erro interno ao buscar resultados" });
  }
});

/**
 * GET /resultados/:id
 * Protegido por token E apenas para admin.
 * Retorna um resultado específico por id.
 */
router.get("/:id", authenticateToken, authorizeAdministrative, async (req, res) => {
  try {
    const id = parseInt(req.params.id, 10);
    if (isNaN(id)) {
      return res.status(400).json({ error: "ID inválido." });
    }

    const resultado = await prisma.catalogo_resultado.findUnique({
      where: { id },
      include: { produto_biologico: true, produto_quimico: true },
    });

    if (!resultado) {
      return res.status(404).json({ error: "Resultado não encontrado." });
    }

    return res.json(resultado);
  } catch (err) {
    console.error("Erro ao buscar resultado:", err);
    return res.status(500).json({ error: "Erro interno ao buscar resultado" });
  }
});

/**
 * PUT /resultados/:id
 * Atualiza um resultado existente.
 * Protegido por token E apenas para admin.
 * Body aceito (parcial ou completo):
 * - pode enviar nome_produto_quimico / nome_produto_biologico (string) para compatibilidade
 * - ou id_produto_quimico / id_produto_biologico (int)
 * {
 *   "nome_produto_quimico": "NovoNomeQuimico",   // opcional
 *   "nome_produto_biologico": "NovoNomeBio",     // opcional
 *   "id_produto_quimico": 123,                   // opcional
 *   "id_produto_biologico": 456,                 // opcional
 *   "resultado_final": "texto opcional",         // opcional
 *   "descricao_resultado": "texto opcional"      // opcional
 * }
 */
router.put("/:id", authenticateToken, authorizeAdministrative, async (req, res) => {
  try {
    const id = parseInt(req.params.id, 10);
    if (isNaN(id)) {
      return res.status(400).json({ error: "ID inválido." });
    }

    const {
      nome_produto_quimico,
      nome_produto_biologico,
      id_produto_quimico,
      id_produto_biologico,
      resultado_final,
      descricao_resultado,
    } = req.body;

    // Verifica existência do registro alvo
    const existente = await prisma.catalogo_resultado.findUnique({ where: { id } });
    if (!existente) {
      return res.status(404).json({ error: "Resultado não encontrado." });
    }

    // Se cliente informou novos produtos (por id ou nome), validamos e resolvemos os ids
    let novoIdQuim = undefined;
    let novoIdBio = undefined;

    if (id_produto_quimico !== undefined || nome_produto_quimico !== undefined) {
      const quim = await resolveProduto(
        { id: id_produto_quimico, nome: nome_produto_quimico },
        "quimico"
      );
      if (!quim) {
        return res.status(400).json({
          error: "Produto químico informado não existe. Crie/forneça-o antes de vincular.",
        });
      }
      novoIdQuim = quim.id;
    }

    if (id_produto_biologico !== undefined || nome_produto_biologico !== undefined) {
      const bio = await resolveProduto(
        { id: id_produto_biologico, nome: nome_produto_biologico },
        "biologico"
      );
      if (!bio) {
        return res.status(400).json({
          error: "Produto biológico informado não existe. Crie/forneça-o antes de vincular.",
        });
      }
      novoIdBio = bio.id;
    }

    // Monta objeto de update apenas com campos fornecidos
    const dataToUpdate = {};
    if (novoIdQuim !== undefined) dataToUpdate.id_produto_quimico = novoIdQuim;
    if (novoIdBio !== undefined) dataToUpdate.id_produto_biologico = novoIdBio;
    if (resultado_final !== undefined) dataToUpdate.resultado_final = resultado_final;
    if (descricao_resultado !== undefined) dataToUpdate.descricao_resultado = descricao_resultado;

    if (Object.keys(dataToUpdate).length === 0) {
      return res.status(400).json({ error: "Nenhum campo para atualizar fornecido." });
    }

    const atualizado = await prisma.catalogo_resultado.update({
      where: { id },
      data: dataToUpdate,
      include: { produto_biologico: true, produto_quimico: true },
    });

    return res.json(atualizado);
  } catch (err) {
    // unique constraint: par único (id_produto_quimico, id_produto_biologico)
    if (err && err.code === "P2002") {
      return res.status(409).json({ error: "Atualização violaria par único existente." });
    }
    console.error("Erro ao atualizar resultado:", err);
    return res.status(500).json({ error: "Erro interno ao atualizar resultado" });
  }
});

/**
 * DELETE /resultados/:id
 * Remove um resultado por id.
 * Protegido por token E apenas para admin.
 */
router.delete("/:id", authenticateToken, authorizeAdministrative, async (req, res) => {
  try {
    const id = parseInt(req.params.id, 10);
    if (isNaN(id)) {
      return res.status(400).json({ error: "ID inválido." });
    }

    const existente = await prisma.catalogo_resultado.findUnique({ where: { id } });
    if (!existente) {
      return res.status(404).json({ error: "Resultado não encontrado." });
    }

    await prisma.catalogo_resultado.delete({ where: { id } });

    // 200 com mensagem para clareza no cliente.
    return res.status(200).json({ message: "Resultado removido com sucesso." });
  } catch (err) {
    console.error("Erro ao deletar resultado:", err);
    return res.status(500).json({ error: "Erro interno ao deletar resultado" });
  }
});

export default router;
