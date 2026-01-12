import express from "express";
import { PrismaClient } from "@prisma/client";
import { authenticateToken, authorizeAdministrative } from "../middleware/auth.js";

const router = express.Router();
const prisma = new PrismaClient();

/**
 * Resolve user id from token payload.
 * Retorna Number ou null.
 */
async function resolveUserIdFromPayload(payload) {
  if (!payload) return null;
  if (payload.id) return Number(payload.id);
  if (payload.userId) return Number(payload.userId);
  if (payload.sub) return Number(payload.sub);
  if (payload.email) {
    const u = await prisma.usuario.findUnique({ where: { email: payload.email } });
    return u ? Number(u.id) : null;
  }
  return null;
}

/**
 * Verifica apenas existência de um registro no catálogo para cada par (quimico, biologico).
 * RETORNA MAP onde a chave é "quimico||biologico" (usando nomes dos produtos) => { exists: true/false, id: number|null }
 *
 * Suporta entradas nas quais as solicitações já tragam:
 * - id_produto_quimico / id_produto_biologico (inteiros)  OR
 * - produto_quimico.nome / produto_biologico.nome (relações carregadas) OR
 * - nome_produto_quimico / nome_produto_biologico (strings antigas)
 *
 * A função NUNCA retorna o conteúdo textual do catálogo (resultado_final / descricao_resultado).
 */
async function fetchCatalogExistenceMapForSolicitacoes(solicitacoes) {
  if (!Array.isArray(solicitacoes) || solicitacoes.length === 0) return {};

  // Primeiro: colecionar pares por ids quando possível e nomes quando não
  const pairsById = new Set(); // "qId||bId"
  const namePairs = new Set(); // "qName||bName" (para quando não houver ids)
  const neededProductNames = new Set(); // nomes que precisaremos consultar para virar ids

  for (const s of solicitacoes) {
    // tentar extrair ids (campos possíveis)
    const qId = s.id_produto_quimico ?? (s.produto_quimico && s.produto_quimico.id) ?? null;
    const bId = s.id_produto_biologico ?? (s.produto_biologico && s.produto_biologico.id) ?? null;

    if (qId && bId) {
      pairsById.add(`${Number(qId)}||${Number(bId)}`);
      continue;
    }

    // senão, tentar extrair nomes
    const qName =
      (s.nome_produto_quimico ?? s.nomeProdutoQuimico ?? (s.produto_quimico && s.produto_quimico.nome) ?? "")?.toString();
    const bName =
      (s.nome_produto_biologico ?? s.nomeProdutoBiologico ?? (s.produto_biologico && s.produto_biologico.nome) ?? "")?.toString();

    if (qName && bName) {
      namePairs.add(`${qName}||${bName}`);
      neededProductNames.add(qName);
      neededProductNames.add(bName);
    }
  }

  // Mapeamento final: queremos sempre retornar keys no formato "qName||bName"
  // e o valor com { exists, id (catalogo_resultado.id) }.
  const resultMap = {};
  // Inicializa com false para todas as entradas encontradas (ids e nomes)
  for (const pair of pairsById) {
    // placeholder until resolvemos nomes
    resultMap[pair] = { exists: false, id: null };
  }
  for (const pair of namePairs) {
    resultMap[pair] = { exists: false, id: null };
  }

  // Se temos namePairs, precisamos mapear nomes -> ids primeiro
  const nameToId = {};
  if (neededProductNames.size > 0) {
    const names = Array.from(neededProductNames);
    const prods = await prisma.produto.findMany({
      where: { nome: { in: names } },
      select: { id: true, nome: true },
    });
    for (const p of prods) {
      nameToId[p.nome] = p.id;
    }

    // transformar namePairs em pairsById (adicionando somente quando ambos mapearem para ids)
    for (const np of Array.from(namePairs)) {
      const [qName, bName] = np.split("||");
      const qId = nameToId[qName];
      const bId = nameToId[bName];
      if (qId && bId) {
        pairsById.add(`${qId}||${bId}`);
        // ensure we have a mapping by id pair pointing back to names
        resultMap[`${qId}||${bId}`] = { exists: false, id: null };
      } else {
        // keep the name-pair in resultMap (already initialized as false)
        // nothing else to do for unmapped names
      }
    }
  }

  // Agora consultamos catalogo_resultado por pares de ids (quando tivermos ids)
  const orConditions = [];
  for (const pidPair of Array.from(pairsById)) {
    const [qIdStr, bIdStr] = pidPair.split("||");
    const qId = Number(qIdStr);
    const bId = Number(bIdStr);
    if (Number.isFinite(qId) && Number.isFinite(bId)) {
      orConditions.push({ id_produto_quimico: qId, id_produto_biologico: bId });
    }
  }

  if (orConditions.length > 0) {
    const catalogos = await prisma.catalogo_resultado.findMany({
      where: { OR: orConditions },
      select: { id: true, id_produto_quimico: true, id_produto_biologico: true },
    });

    // para cada catálogo encontrado, precisamos saber os nomes correspondentes para criar a chave "qName||bName"
    const idsNeeded = new Set();
    for (const c of catalogos) {
      idsNeeded.add(c.id_produto_quimico);
      idsNeeded.add(c.id_produto_biologico);
    }

    const idsArr = Array.from(idsNeeded);
    const idToName = {};
    if (idsArr.length > 0) {
      const produtos = await prisma.produto.findMany({
        where: { id: { in: idsArr } },
        select: { id: true, nome: true },
      });
      for (const p of produtos) idToName[p.id] = p.nome;
    }

    for (const c of catalogos) {
      const qName = idToName[c.id_produto_quimico] ?? String(c.id_produto_quimico);
      const bName = idToName[c.id_produto_biologico] ?? String(c.id_produto_biologico);
      const nameKey = `${qName}||${bName}`;

      // preencha tanto o par por nome quanto por id (ambos keys no mapa)
      resultMap[nameKey] = { exists: true, id: c.id };
      resultMap[`${c.id_produto_quimico}||${c.id_produto_biologico}`] = { exists: true, id: c.id };
    }
  }

  // Finalmente: normalizar keys que são id-pairs para também apresentar keys por nome (se possível)
  // (Algumas já foram preenchidas acima.)
  // Para qualquer id-pair restante sem nome equivalente, tentamos mapear ids->nomes:
  for (const key of Object.keys(resultMap)) {
    // se chave já é do tipo "nome||nome" ou já tem exists, continue
    if (resultMap[key].exists) continue;
    const [left, right] = key.split("||");
    const leftIsId = /^\d+$/.test(left);
    const rightIsId = /^\d+$/.test(right);
    if (leftIsId && rightIsId) {
      const qId = Number(left);
      const bId = Number(right);
      // buscar nomes se possível
      const produtos = await prisma.produto.findMany({
        where: { id: { in: [qId, bId] } },
        select: { id: true, nome: true },
      });
      const mapIdToName = {};
      for (const p of produtos) mapIdToName[p.id] = p.nome;
      if (mapIdToName[qId] && mapIdToName[bId]) {
        const nameKey = `${mapIdToName[qId]}||${mapIdToName[bId]}`;
        // garantir que exista uma entrada por nome (se não houver, inicializa)
        if (!resultMap[nameKey]) resultMap[nameKey] = { exists: resultMap[key].exists, id: resultMap[key].id };
      }
    }
  }

  // Garantir que todas as name-pairs (aquelas que vieram originalmente como nomes) existam no retorno:
  // (já inicializamos antes)
  return resultMap;
}

/**
 * Calcula saldo atual do usuário somando pacotes não-vencidos.
 * Aceita tanto prisma client quanto tx.
 *
 * Regra: validade_em_dias <= 0 === sem expiração (conta como válido).
 */
async function computeUserSaldo(prismaOrTx, userId) {
  const config = await prismaOrTx.config_sistema.findFirst({
    orderBy: [{ atualizado_em: "desc" }, { id: "desc" }],
  });
  const validadeDias = Number(config?.validade_em_dias ?? 0);
  const pacotes = await prismaOrTx.pacote_creditos.findMany({
    where: { id_usuario: userId },
    select: { quantidade: true, data_recebimento: true },
  });

  const now = Date.now();
  const msPorDia = 24 * 60 * 60 * 1000;
  let soma = 0;
  for (const p of pacotes) {
    const quantidade = Number(p.quantidade ?? 0);
    if (!Number.isFinite(quantidade) || quantidade === 0) continue;
    if (!p.data_recebimento) {
      // se sem data_recebimento, considerar inválido (defensivo)
      continue;
    }
    const recebidoTs = new Date(p.data_recebimento).getTime();

    // validadeDias <= 0 => sem expiração: conta sempre
    if (!Number.isFinite(validadeDias) || validadeDias <= 0) {
      soma += quantidade;
      continue;
    }

    const expiraEm = recebidoTs + validadeDias * msPorDia;
    if (expiraEm >= now) soma += quantidade;
  }
  return soma;
}

// POST /solicitacoes — cria uma nova solicitação
router.post("/", authenticateToken, async (req, res) => {
  try {
    // aceitar tanto ids quanto nomes no body para compatibilidade
    const {
      nome_produto_quimico,
      nome_produto_biologico,
      id_produto_quimico,
      id_produto_biologico,
    } = req.body;

    if ((!nome_produto_quimico || !nome_produto_biologico) && (!id_produto_quimico || !id_produto_biologico)) {
      return res.status(400).json({
        error: "Forneça id_produto_quimico & id_produto_biologico OU nome_produto_quimico & nome_produto_biologico",
      });
    }

    const userId = await resolveUserIdFromPayload(req.user);
    if (!userId) {
      return res.status(401).json({ error: "Usuário não autenticado corretamente (id não encontrado no token)" });
    }

    // Resolver ids a partir de nomes se necessário
    let finalIdQuim = id_produto_quimico ? Number(id_produto_quimaco ?? id_produto_quimico) : null;
    let finalIdBio = id_produto_biologico ? Number(id_produto_biologico ?? id_produto_biologico) : null;

    // small defensive normalization (avoid undefined variables from typos)
    if (!finalIdQuim && nome_produto_quimico) {
      const pq = await prisma.produto.findUnique({ where: { nome: nome_produto_quimico } });
      if (!pq) return res.status(400).json({ error: `Produto químico '${nome_produto_quimico}' não encontrado` });
      finalIdQuim = pq.id;
    }
    if (!finalIdBio && nome_produto_biologico) {
      const pb = await prisma.produto.findUnique({ where: { nome: nome_produto_biologico } });
      if (!pb) return res.status(400).json({ error: `Produto biológico '${nome_produto_biologico}' não encontrado` });
      finalIdBio = pb.id;
    }

    if (!finalIdQuim || !finalIdBio) {
      return res.status(400).json({ error: "Não foi possível resolver os produtos fornecidos para ids válidos" });
    }

    // validar existência dos produtos por id
    const [produtoQuimico, produtoBiologico] = await Promise.all([
      prisma.produto.findUnique({ where: { id: finalIdQuim } }),
      prisma.produto.findUnique({ where: { id: finalIdBio } }),
    ]);

    if (!produtoQuimico) return res.status(400).json({ error: `Produto químico id '${finalIdQuim}' não encontrado` });
    if (!produtoBiologico) return res.status(400).json({ error: `Produto biológico id '${finalIdBio}' não encontrado` });

    const usuario = await prisma.usuario.findUnique({
      where: { id: Number(userId) },
      include: { vinculoAssinatura: { include: { plano: true } } },
    });
    if (!usuario) return res.status(404).json({ error: "Usuário não encontrado" });

    let assinatura = usuario.vinculoAssinatura;
    if (!assinatura) {
      assinatura = await prisma.assinatura.findFirst({
        where: { id_dono: usuario.id, ativo: true },
        include: { plano: true },
        orderBy: { id: "desc" },
      });
    }

    let prioridade = assinatura?.plano?.prioridade_de_tempo ?? null;
    if (prioridade === null) {
      const globalAssinatura = await prisma.assinatura.findFirst({ include: { plano: true }, orderBy: [{ id: "desc" }] });
      prioridade = globalAssinatura?.plano?.prioridade_de_tempo ?? 0;
    }
    prioridade = Number(prioridade ?? 0);

    // pega a configuração mais recente e usa o campo preco_da_solicitacao_em_creditos
    const configMaisRecente = await prisma.config_sistema.findFirst({
      orderBy: [{ atualizado_em: "desc" }, { id: "desc" }],
    });
    if (!configMaisRecente) return res.status(500).json({ error: "Configuração do sistema ausente. Contate o administrador." });

    const precoEmCreditos = Number(configMaisRecente.preco_da_solicitacao_em_creditos ?? 0);

    // Transação: verifica saldo usando pacotes, cria solicitação e cria pacote negativo (debito)
    try {
      const txResult = await prisma.$transaction(async (tx) => {
        const saldoAntes = await computeUserSaldo(tx, usuario.id);

        if (saldoAntes < precoEmCreditos) {
          const err = new Error("INSUFFICIENT_CREDITS");
          err.code = "INSUFFICIENT_CREDITS";
          throw err;
        }

        // CRIAÇÃO: agora o schema espera ids (id_produto_biologico / id_produto_quimico)
        const created = await tx.solicitacao_analise.create({
          data: {
            id_produto_biologico: finalIdBio,
            id_produto_quimico: finalIdQuim,
            prioridade,
            id_usuario: usuario.id,
            status: "em_andamento",
            resultado_final: null,
            descricao_resultado: null,
            data_resultado: null,
          },
        });

        if (precoEmCreditos > 0) {
          await tx.pacote_creditos.create({
            data: {
              id_usuario: usuario.id,
              quantidade: -Math.abs(precoEmCreditos),
              origem: `consumo_solicitacao:${created.id}`,
              data_recebimento: new Date(),
            },
          });
        }

        const saldoDepois = await computeUserSaldo(tx, usuario.id);

        return { solicitacao: created, saldoAntes, saldoDepois };
      });

      // Para compatibilidade com clientes que esperam nomes no nível superior,
      // buscamos os produtos para anexar nome_produto_* ao objeto retornado.
      const createdWithNames = { ...txResult.solicitacao };
      const [pq, pb] = await Promise.all([
        prisma.produto.findUnique({ where: { id: createdWithNames.id_produto_quimico } }),
        prisma.produto.findUnique({ where: { id: createdWithNames.id_produto_biologico } }),
      ]);
      createdWithNames.nome_produto_quimico = pq?.nome ?? null;
      createdWithNames.nome_produto_biologico = pb?.nome ?? null;

      return res.status(201).json({
        solicitacao: createdWithNames,
        custo_em_creditos: precoEmCreditos,
        saldo_antes: txResult.saldoAntes,
        saldo_depois: txResult.saldoDepois,
      });
    } catch (txErr) {
      if (txErr?.code === "INSUFFICIENT_CREDITS") {
        return res.status(400).json({ error: `Saldo insuficiente: são necessários ${precoEmCreditos} créditos.` });
      }
      console.error("Erro na transação:", txErr);
      return res.status(500).json({ error: "Erro interno ao processar solicitação (transação)" });
    }
  } catch (err) {
    console.error("Erro ao criar solicitação de análise:", err);
    return res.status(500).json({ error: "Erro interno ao criar solicitação de análise" });
  }
});

// GET /solicitacoes — lista solicitações do usuário logado
router.get("/", authenticateToken, async (req, res) => {
  try {
    const userId = await resolveUserIdFromPayload(req.user);
    if (!userId) return res.status(401).json({ error: "Usuário não autenticado corretamente (id não encontrado no token)" });

    // carregar usuário com vinculoAssinatura (e plano) para verificar se é enterprise
    const usuario = await prisma.usuario.findUnique({
      where: { id: Number(userId) },
      include: { vinculoAssinatura: { include: { plano: true } } },
    });
    if (!usuario) return res.status(404).json({ error: "Usuário não encontrado" });

    // determinar assinatura "atual" do usuário: primeiro vinculoAssinatura, senão assinatura ativa onde é dono
    let assinatura = usuario.vinculoAssinatura ?? null;
    if (!assinatura) {
      assinatura = await prisma.assinatura.findFirst({
        where: { id_dono: usuario.id, ativo: true },
        include: { plano: true },
        orderBy: { id: "desc" },
      });
    }

    // função inline para checar se o plano é do tipo enterprise (mantendo mesma heurística já usada)
    function isEnterprisePlan(plano) {
      if (!plano || !plano.nome) return false;
      return String(plano.nome).toLowerCase().includes("enterprise");
    }

    let solicitacoes = [];

    if (assinatura && isEnterprisePlan(assinatura.plano)) {
      // se for enterprise: buscar solicitações de todos os usuários vinculados a essa assinatura
      // incluir também o dono da assinatura (id_dono) caso não esteja presente entre vinculados
      const vinculados = await prisma.usuario.findMany({
        where: { id_vinculo_assinatura: assinatura.id },
        select: { id: true },
      });
      const vinculadosIds = vinculados.map((u) => u.id);

      // garantir presença do usuário atual e do dono na lista de ids a consultar
      const idsSet = new Set(vinculadosIds.map((id) => Number(id)));
      idsSet.add(Number(usuario.id));
      if (assinatura.id_dono) idsSet.add(Number(assinatura.id_dono));

      const idsArr = Array.from(idsSet).filter((n) => Number.isFinite(n) && n > 0);

      // buscar solicitações para todos esses usuários
      solicitacoes = await prisma.solicitacao_analise.findMany({
        where: { id_usuario: { in: idsArr } },
        orderBy: { data_solicitacao: "desc" },
        include: { produto_biologico: true, produto_quimico: true, usuario: true },
      });
    } else {
      // comportamento padrão: apenas solicitações do usuário logado
      solicitacoes = await prisma.solicitacao_analise.findMany({
        where: { id_usuario: Number(userId) },
        orderBy: { data_solicitacao: "desc" },
        include: { produto_biologico: true, produto_quimico: true },
      });
    }

    // Construir objetos compatíveis com clientes que esperam os nomes no topo
    const solicitacoesWithNames = solicitacoes.map((s) => {
      const plain = JSON.parse(JSON.stringify(s));
      plain.nome_produto_quimico = (plain.produto_quimico && plain.produto_quimico.nome) ?? null;
      plain.nome_produto_biologico = (plain.produto_biologico && plain.produto_biologico.nome) ?? null;
      return plain;
    });

    // BUSCAMOS apenas existência de catálogo -- não expor conteúdos do catálogo como parte da solicitação.
    const catalogExistMap = await fetchCatalogExistenceMapForSolicitacoes(solicitacoesWithNames);

    const out = solicitacoesWithNames.map((plain) => {
      const key = `${plain.nome_produto_quimico || ""}||${plain.nome_produto_biologico || ""}`;
      const cmap = catalogExistMap[key] ?? { exists: false, id: null };

      // Importante: nunca sobrescrever campos reais (resultado_final / descricao_resultado).
      // Incluir apenas um indicador booleano de disponibilidade do catálogo.
      plain._catalogo_disponivel = Boolean(cmap.exists);
      plain._catalogo_id = cmap.id ?? null;

      return plain;
    });

    return res.json(out);
  } catch (err) {
    console.error("Erro ao listar solicitações do usuário:", err);
    return res.status(500).json({ error: "Erro interno ao listar solicitações" });
  }
});

// GET /solicitacoes/todas — rota administrativa
// Observação: para evitar um panic do Query Engine em consultas com include+orderBy complexas,
// buscamos as solicitações sem includes (orderBy simples) e carregamos relações em lote.
router.get("/todas", authenticateToken, authorizeAdministrative, async (req, res) => {
  try {
    // Buscar todas as solicitações, ordenando apenas por prioridade (evita combinação que causou panic)
    const solicitacoes = await prisma.solicitacao_analise.findMany({
      orderBy: { prioridade: "asc" },
      select: {
        id: true,
        id_produto_biologico: true,
        id_produto_quimico: true,
        prioridade: true,
        data_solicitacao: true,
        data_resultado: true,
        resultado_final: true,
        descricao_resultado: true,
        status: true,
        id_usuario: true,
      },
    });

    // coletar ids de usuários e ids de produtos para buscar relações em lote
    const userIdsSet = new Set();
    const bioIdsSet = new Set();
    const quimIdsSet = new Set();
    for (const s of solicitacoes) {
      if (s.id_usuario) userIdsSet.add(s.id_usuario);
      if (s.id_produto_biologico) bioIdsSet.add(s.id_produto_biologico);
      if (s.id_produto_quimico) quimIdsSet.add(s.id_produto_quimico);
    }
    const userIds = Array.from(userIdsSet);
    const bioIds = Array.from(bioIdsSet);
    const quimIds = Array.from(quimIdsSet);

    // buscar usuarios e produtos em lote
    const [usuarios, bios, quims] = await Promise.all([
      userIds.length > 0 ? prisma.usuario.findMany({ where: { id: { in: userIds } }, select: { id: true, nome: true, email: true } }) : [],
      bioIds.length > 0 ? prisma.produto.findMany({ where: { id: { in: bioIds } }, select: { id: true, nome: true, tipo: true, genero: true } }) : [],
      quimIds.length > 0 ? prisma.produto.findMany({ where: { id: { in: quimIds } }, select: { id: true, nome: true, tipo: true, genero: true } }) : [],
    ]);

    const usuarioMap = {};
    for (const u of usuarios) usuarioMap[String(u.id)] = u;
    const bioMap = {};
    for (const b of bios) bioMap[b.id] = b;
    const quimMap = {};
    for (const q of quims) quimMap[q.id] = q;

    // Para conferência de disponibilidade de catálogo, precisamos fornecer
    // pares por nome para fetchCatalogExistenceMapForSolicitacoes.
    // Primeiro, montamos um array similar ao que a função aceita (com nome_produto_*).
    const solicitacoesForCatalogCheck = solicitacoes.map((s) => {
      const plain = { ...s };
      plain.nome_produto_quimico = quimMap[s.id_produto_quimico]?.nome ?? null;
      plain.nome_produto_biologico = bioMap[s.id_produto_biologico]?.nome ?? null;
      // manter também referências a ids para a função
      plain.id_produto_quimico = s.id_produto_quimico;
      plain.id_produto_biologico = s.id_produto_biologico;
      return plain;
    });

    // buscar apenas existência de catalogos e montar mapa (apenas para referência)
    const catalogExistMap = await fetchCatalogExistenceMapForSolicitacoes(solicitacoesForCatalogCheck);

    // mapear e enriquecer cada solicitação (simulando include)
    const plainSolics = solicitacoes.map((s) => {
      const plain = { ...s };

      plain.usuario = usuarioMap[String(s.id_usuario)] ?? null;
      plain.produto_biologico = bioMap[s.id_produto_biologico] ?? null;
      plain.produto_quimico = quimMap[s.id_produto_quimico] ?? null;

      // Compatibilidade: expor nomes no nível superior (campo antigo)
      plain.nome_produto_quimico = plain.produto_quimico?.nome ?? null;
      plain.nome_produto_biologico = plain.produto_biologico?.nome ?? null;

      const key = `${plain.nome_produto_quimico || ""}||${plain.nome_produto_biologico || ""}`;
      const cmap = catalogExistMap[key] ?? { exists: false, id: null };

      // IMPORTANT: não vincular automaticamente o resultado do catálogo à solicitação.
      // Apenas expor um indicador de disponibilidade do catálogo (sem conteúdo textual).
      plain._catalogo_disponivel = Boolean(cmap.exists);
      plain._catalogo_id = cmap.id ?? null;

      return plain;
    });

    // Agrupar por prioridade (chave string) e ordenar por data_solicitacao desc dentro de cada grupo
    const agrupadas = plainSolics.reduce((acc, s) => {
      const p = Number(s.prioridade ?? 0);
      const key = String(p);
      if (!acc[key]) acc[key] = [];
      acc[key].push(s);
      return acc;
    }, {});

    for (const key of Object.keys(agrupadas)) {
      agrupadas[key].sort((a, b) => {
        const ta = new Date(a.data_solicitacao).getTime();
        const tb = new Date(b.data_solicitacao).getTime();
        return tb - ta; // desc
      });
    }

    return res.json(agrupadas);
  } catch (err) {
    // Se ocorrer um panic no Query Engine, informar claramente (e logar stack)
    console.error("Erro ao listar todas as solicitações (admin):", err);
    return res.status(500).json({ error: "Erro interno ao listar solicitações (admin). Contate o administrador." });
  }
});

// POST /solicitacoes/:id/vincular — vincula resultado (admin)
// Observação: Só esta rota pode definir resultado_final/descricao_resultado da solicitação.
// Não alteramos nem criamos automaticamente registros de catalogo_resultado aqui.
router.post("/:id/vincular", authenticateToken, authorizeAdministrative, async (req, res) => {
  try {
    const id = Number(req.params.id);
    if (isNaN(id) || id <= 0) return res.status(400).json({ error: "ID da solicitação inválido" });

    const { resultado_final, descricao_resultado } = req.body;
    if (!resultado_final || typeof resultado_final !== "string" || resultado_final.trim().length === 0) {
      return res.status(400).json({ error: "Campo 'resultado_final' é obrigatório e deve ser uma string não vazia" });
    }

    try {
      // Atualização direta da solicitação: grava apenas os campos que o admin forneceu.
      // NÃO criar nem modificar entradas em catalogo_resultado automaticamente.
      const updated = await prisma.solicitacao_analise.update({
        where: { id },
        data: {
          resultado_final: resultado_final.trim(),
          descricao_resultado: descricao_resultado?.toString() ?? null,
          status: "finalizado",
          data_resultado: new Date(),
        },
        include: { usuario: true, produto_biologico: true, produto_quimico: true },
      });

      // Para compatibilidade com clientes, adicionar os campos nome_produto_* no objeto retornado
      const plain = JSON.parse(JSON.stringify(updated));
      plain.nome_produto_quimico = plain.produto_quimico?.nome ?? null;
      plain.nome_produto_biologico = plain.produto_biologico?.nome ?? null;

      // --- envio de email notificando o usuário que o resultado saiu (SEM o resultado em si) ---
      try {
        const user = updated.usuario;
        const userEmail = user?.email ?? null;
        const userNome = user?.nome ?? null;

        if (userEmail) {
          // dynamic import para compatibilidade com ESM se o arquivo não tiver import nodemailer no topo
          let nodemailerModule;
          try {
            nodemailerModule = (await import("nodemailer")).default ?? (await import("nodemailer"));
          } catch (e) {
            // fallback caso import falhe (não bloqueará a rota)
            console.warn("nodemailer import falhou:", e?.message ?? e);
            nodemailerModule = null;
          }

          if (nodemailerModule) {
            const emailHost = process.env.EMAIL_HOST;
            const emailPort = process.env.EMAIL_PORT ? Number(process.env.EMAIL_PORT) : undefined;
            const emailSecure = process.env.EMAIL_SECURE === "true";
            const emailUser = process.env.EMAIL_USER;
            const emailPass = process.env.EMAIL_PASS;
            const emailFrom = process.env.EMAIL_FROM || emailUser;

            if (emailHost && emailPort && emailUser && emailPass) {
              const transporter = nodemailerModule.createTransport({
                host: emailHost,
                port: emailPort,
                secure: emailSecure,
                auth: {
                  user: emailUser,
                  pass: emailPass,
                },
              });

              // montar conteúdo: somente identificação da solicitação e nomes dos produtos (sem resultado)
              const produtoQuimicoNome = plain.nome_produto_quimico ?? "N/A";
              const produtoBiologicoNome = plain.nome_produto_biologico ?? "N/A";

              const subject = `Resultado disponível — solicitação #${updated.id}`;
              const html = `
                <p>Olá ${userNome ?? ""},</p>
                <p>Informamos que o resultado da sua solicitação foi registrado no sistema.</p>
                <p><strong>Dados da solicitação</strong></p>
                <ul>
                  <li><strong>ID da solicitação:</strong> ${updated.id}</li>
                  <li><strong>Produto químico:</strong> ${produtoQuimicoNome}</li>
                  <li><strong>Produto biológico:</strong> ${produtoBiologicoNome}</li>
                </ul>
                <p>Por motivos de segurança e integridade, o conteúdo do resultado não é enviado por email. Acesse sua conta para visualizar o relatório completo.</p>
                <p>Obrigado.</p>
              `;
              const text = `Olá ${userNome ?? ""},\n\nInformamos que o resultado da sua solicitação foi registrado no sistema.\n\nID da solicitação: ${updated.id}\nProduto químico: ${produtoQuimicoNome}\nProduto biológico: ${produtoBiologicoNome}\n\nPor motivos de segurança e integridade, o conteúdo do resultado não é enviado por email. Acesse sua conta para visualizar o relatório completo.\n\nObrigado.`;

              try {
                await transporter.sendMail({
                  from: emailFrom,
                  to: userEmail,
                  subject,
                  text,
                  html,
                });
                console.info(`Notificação por email enviada para usuário.id=${user.id} (${userEmail}) sobre solicitacao.id=${updated.id}`);
              } catch (sendErr) {
                console.warn("Falha ao enviar email de notificação:", sendErr?.message ?? sendErr);
              }
            } else {
              console.info("Configuração de e-mail incompleta; não foi enviado e-mail de notificação ao usuário.");
            }
          } else {
            console.info("nodemailer não disponível; pulando envio de email.");
          }
        } else {
          console.info("Solicitação atualizada sem email de usuário; não será enviada notificação por email.");
        }
      } catch (mailErr) {
        console.warn("Erro ao tentar notificar por email (não crítico):", mailErr?.message ?? mailErr);
      }

      return res.json({ message: "Resultado vinculado com sucesso", solicitacao: plain });
    } catch (err) {
      if (err?.code === "P2025") return res.status(404).json({ error: "Solicitação não encontrada" });
      console.error("Erro ao atualizar solicitacao:", err);
      return res.status(500).json({ error: "Erro interno ao vincular resultado" });
    }
  } catch (err) {
    console.error("Erro na rota /:id/vincular:", err);
    return res.status(500).json({ error: "Erro interno" });
  }
});


export default router;
