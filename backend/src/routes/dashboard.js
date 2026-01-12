import express from "express";
import { PrismaClient } from "@prisma/client";
import { authenticateToken, authorizeAdministrative } from "../middleware/auth.js";

const router = express.Router();
const prisma = new PrismaClient();

const MONTH_NAMES_PT = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];

/**
 * GET /dashboard/completo
 * Retorna um JSON completo com os dados agregados para popular o dashboard (admin).
 * Adaptado para o novo schema: agora usamos id_produto_quimico / id_produto_biologico e juntamos nomes em produto.
 */
router.get("/completo", authenticateToken, authorizeAdministrative, async (req, res) => {
  try {
    const now = new Date();

    // --- Construir os últimos 6 meses (ordem: mais antigo -> mais recente)
    const monthsRanges = []; // { start:Date, end:Date, monthIndex:number, label:string }
    for (let i = 5; i >= 0; i--) {
      const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
      const start = new Date(d.getFullYear(), d.getMonth(), 1, 0, 0, 0, 0);
      const end = new Date(d.getFullYear(), d.getMonth() + 1, 1, 0, 0, 0, 0);
      monthsRanges.push({
        start,
        end,
        monthIndex: d.getMonth(),
        label: MONTH_NAMES_PT[d.getMonth()]
      });
    }

    // --- Queries por mês (paralelas) ---
    const analysesCountsPromises = monthsRanges.map(r =>
      prisma.solicitacao_analise.count({
        where: { data_solicitacao: { gte: r.start, lt: r.end } }
      })
    );

    const revenueSumPromises = monthsRanges.map(r =>
      prisma.receita.aggregate({
        _sum: { valor: true },
        where: { data: { gte: r.start, lt: r.end } }
      })
    );

    const newClientsPromises = monthsRanges.map(r =>
      prisma.usuario.count({
        where: { created_at: { gte: r.start, lt: r.end } }
      })
    );

    const [analysesCounts, revenueAggs, newClientsCounts] = await Promise.all([
      Promise.all(analysesCountsPromises),
      Promise.all(revenueSumPromises),
      Promise.all(newClientsPromises)
    ]);

    // normaliza revenue (podem ser null / Decimal string)
    const revenueValues = revenueAggs.map(a => {
      const v = a?._sum?.valor ?? 0;
      return Number(v) || 0;
    });

    // --- Solicitações mais comuns: agrupa por par (químico + biológico) e pega top 10 (Geral) ---
    let groupedRequests = [];
    try {
      // groupBy agora por ids
      const groupedByIds = await prisma.solicitacao_analise.groupBy({
        by: ['id_produto_quimico', 'id_produto_biologico'],
        _count: { _all: true },
        orderBy: { _count: { _all: 'desc' } },
        take: 10,
      });

      // coletar todos os ids únicos para buscar nomes
      const produtoIds = new Set();
      for (const g of groupedByIds) {
        if (g.id_produto_quimico != null) produtoIds.add(g.id_produto_quimico);
        if (g.id_produto_biologico != null) produtoIds.add(g.id_produto_biologico);
      }
      const idsArray = Array.from(produtoIds);

      // buscar nomes dos produtos
      const produtos = idsArray.length > 0
        ? await prisma.produto.findMany({ where: { id: { in: idsArray } }, select: { id: true, nome: true } })
        : [];

      const produtoMap = new Map(produtos.map(p => [p.id, p.nome]));

      groupedRequests = groupedByIds.map(g => ({
        id_produto_quimico: g.id_produto_quimico,
        id_produto_biologico: g.id_produto_biologico,
        nome_produto_quimico: produtoMap.get(g.id_produto_quimico) ?? null,
        nome_produto_biologico: produtoMap.get(g.id_produto_biologico) ?? null,
        _count: { _all: Number(g._count._all ?? 0) }
      }));
    } catch (e) {
      // fallback: raw SQL (MySQL) - agora juntamos produtos para recuperar nomes
      const raw = await prisma.$queryRaw`
        SELECT s.id_produto_quimico, s.id_produto_biologico, COUNT(*) as cnt,
               pq.nome as nome_quimico, pb.nome as nome_biologico
        FROM solicitacao_analise s
        LEFT JOIN produto pq ON pq.id = s.id_produto_quimico
        LEFT JOIN produto pb ON pb.id = s.id_produto_biologico
        GROUP BY s.id_produto_quimico, s.id_produto_biologico
        ORDER BY cnt DESC
        LIMIT 10
      `;
      groupedRequests = raw.map(r => ({
        id_produto_quimico: r.id_produto_quimico,
        id_produto_biologico: r.id_produto_biologico,
        nome_produto_quimico: r.nome_quimico ?? null,
        nome_produto_biologico: r.nome_biologico ?? null,
        _count: { _all: Number(r.cnt) }
      }));
    }

    const totalRequestsAll = groupedRequests.reduce((s, g) => s + (g._count?._all ?? 0), 0) || 0;
    // transforma em formato { label, value, percent } limitado a 6 itens
    const requestsData = groupedRequests.slice(0, 6).map((g) => {
      // mantive o '\n' imediatamente após o '+' conforme solicitado
      const nomeQuim = g.nome_produto_quimico ?? "Desconhecido (quim.)";
      const nomeBio = g.nome_produto_biologico ?? "Desconhecido (bio.)";
      const label = `${nomeQuim} +\n${nomeBio}`;
      const value = Number(g._count?._all ?? 0);
      const percent = totalRequestsAll > 0 ? Number(((value / totalRequestsAll) * 100).toFixed(0)) : 0;
      return { label, value, percent };
    });

    // Top request (se existir)
    const topRequest = requestsData.length > 0 ? requestsData[0] : { label: null, value: 0, percent: 0 };

    // --- Indicadores ---
    const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
    const analysesLastWeek = await prisma.solicitacao_analise.count({
      where: { data_solicitacao: { gte: sevenDaysAgo, lt: now } }
    });

    const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1, 0, 0, 0, 0);
    const startNextMonth = new Date(now.getFullYear(), now.getMonth() + 1, 1, 0, 0, 0, 0);
    const revenueThisMonthAgg = await prisma.receita.aggregate({
      _sum: { valor: true },
      where: { data: { gte: startOfMonth, lt: startNextMonth } }
    });
    const revenueThisMonth = Number(revenueThisMonthAgg?._sum?.valor ?? 0);

    const newClientsThisMonth = await prisma.usuario.count({
      where: { created_at: { gte: startOfMonth, lt: startNextMonth } }
    });

    // totais gerais
    const totalAnalyses = await prisma.solicitacao_analise.count();
    const emAndamento = await prisma.solicitacao_analise.count({ where: { status: "em_andamento" } });

    // último registro de solicitação (mais recente) - incluir nomes via relação
    const ultimo = await prisma.solicitacao_analise.findFirst({
      orderBy: { data_solicitacao: "desc" },
      take: 1,
      include: {
        produto_biologico: { select: { nome: true } },
        produto_quimico: { select: { nome: true } }
      }
    });

    // --- Cálculo de "credits validos" (somente pacotes não vencidos) usando config_sistema.validade_em_dias ---
    const configMaisRecente = await prisma.config_sistema.findFirst({ orderBy: { atualizado_em: "desc" } });
    const validadeEmDias = Number(configMaisRecente?.validade_em_dias ?? 0);
    const pacotesTodos = await prisma.pacote_creditos.findMany({});
    let creditsValidos = 0;
    const agora = new Date();
    for (const p of pacotesTodos) {
      const recebido = p.data_recebimento instanceof Date ? p.data_recebimento : new Date(p.data_recebimento);
      if (!validadeEmDias || validadeEmDias <= 0) {
        creditsValidos += Number(p.quantidade ?? 0);
      } else {
        const expiracao = new Date(recebido.getTime() + validadeEmDias * 24 * 60 * 60 * 1000);
        if (expiracao >= agora) creditsValidos += Number(p.quantidade ?? 0);
      }
    }

    const configForFrontend = {
      preco_do_credito: Number(configMaisRecente?.preco_do_credito ?? 0),
      preco_da_solicitacao_em_creditos: Number(configMaisRecente?.preco_da_solicitacao_em_creditos ?? 0),
      validade_em_dias: Number(configMaisRecente?.validade_em_dias ?? 0)
    };

    // --- Monta labels/arrays finais (ordenados) ---
    const months = monthsRanges.map(r => r.label);
    const analysesValues = analysesCounts.map(n => Number(n ?? 0));
    const newClientsValues = newClientsCounts.map(n => Number(n ?? 0));

    // total revenue over the 6 months
    const totalRevenue6m = revenueValues.reduce((s, v) => s + v, 0);

    // --- NOVA PARTE: Top 10 solicitações no ÚLTIMO MÊS (mês calendário anterior)
    const startPrevMonth = new Date(now.getFullYear(), now.getMonth() - 1, 1, 0, 0, 0, 0);
    const startCurrentMonth = new Date(now.getFullYear(), now.getMonth(), 1, 0, 0, 0, 0);

    let topRequestsLastMonth = [];
    try {
      const groupedLastMonth = await prisma.solicitacao_analise.groupBy({
        by: ['id_produto_quimico', 'id_produto_biologico'],
        _count: { _all: true },
        where: { data_solicitacao: { gte: startPrevMonth, lt: startCurrentMonth } },
        orderBy: { _count: { _all: 'desc' } },
        take: 10,
      });

      // buscar nomes dos produtos usados no agrupamento
      const produtoIdsLM = new Set();
      for (const g of groupedLastMonth) {
        if (g.id_produto_quimico != null) produtoIdsLM.add(g.id_produto_quimico);
        if (g.id_produto_biologico != null) produtoIdsLM.add(g.id_produto_biologico);
      }
      const idsLMArray = Array.from(produtoIdsLM);
      const produtosLM = idsLMArray.length > 0
        ? await prisma.produto.findMany({ where: { id: { in: idsLMArray } }, select: { id: true, nome: true } })
        : [];
      const produtoLMMap = new Map(produtosLM.map(p => [p.id, p.nome]));

      topRequestsLastMonth = groupedLastMonth.map(g => ({
        nome_produto_quimico: produtoLMMap.get(g.id_produto_quimico) ?? null,
        nome_produto_biologico: produtoLMMap.get(g.id_produto_biologico) ?? null,
        quantidade_no_ultimo_mes: Number(g._count?._all ?? 0)
      }));
    } catch (e) {
      // fallback raw SQL com join para pegar nomes (MySQL)
      const raw = await prisma.$queryRaw`
        SELECT s.id_produto_quimico, s.id_produto_biologico, COUNT(*) as cnt,
               pq.nome as nome_quimico, pb.nome as nome_biologico
        FROM solicitacao_analise s
        LEFT JOIN produto pq ON pq.id = s.id_produto_quimico
        LEFT JOIN produto pb ON pb.id = s.id_produto_biologico
        WHERE s.data_solicitacao >= ${startPrevMonth} AND s.data_solicitacao < ${startCurrentMonth}
        GROUP BY s.id_produto_quimico, s.id_produto_biologico
        ORDER BY cnt DESC
        LIMIT 10
      `;
      topRequestsLastMonth = raw.map(r => ({
        nome_produto_quimico: r.nome_quimico ?? null,
        nome_produto_biologico: r.nome_biologico ?? null,
        quantidade_no_ultimo_mes: Number(r.cnt)
      }));
    }

    // --- NOVA PARTE: Empresas e contagens de clientes por empresa + não vinculados ---
    // Lista de empresas (id, nome, cnpj)
    const empresasRaw = await prisma.empresa.findMany({
      select: { id: true, nome: true, cnpj: true }
    });

    // Obter total de clientes
    const totalClientes = await prisma.usuario.count();

    // Agrupar usuários por id_empresa para contar vinculados (com fallback SQL)
    let usuariosPorEmpresaMap = new Map(); // id_empresa (number|null) -> count
    try {
      const groupedUsuarios = await prisma.usuario.groupBy({
        by: ['id_empresa'],
        _count: { _all: true }
      });
      for (const g of groupedUsuarios) {
        // g.id_empresa pode ser null
        usuariosPorEmpresaMap.set(g.id_empresa === undefined ? null : g.id_empresa, Number(g._count._all ?? 0));
      }
    } catch (e) {
      // fallback raw SQL (MySQL)
      const raw = await prisma.$queryRaw`
        SELECT id_empresa, COUNT(*) as cnt
        FROM usuario
        GROUP BY id_empresa
      `;
      for (const r of raw) {
        // r.id_empresa pode ser null
        usuariosPorEmpresaMap.set(r.id_empresa ?? null, Number(r.cnt));
      }
    }

    // Monta array de empresas com contador de clientes vinculados
    const empresasComContagem = empresasRaw.map(e => {
      const count = usuariosPorEmpresaMap.get(e.id) ?? 0;
      return {
        id: e.id,
        nome: e.nome,
        cnpj: e.cnpj,
        clientes_vinculados: Number(count)
      };
    });

    // Quantidade de clientes não vinculados (id_empresa IS NULL)
    const clientesNaoVinculados = Number(usuariosPorEmpresaMap.get(null) ?? 0);

    // --- Resposta JSON final ---
    return res.json({
      months, // ex: ['Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out']
      analysesValues, // counts por mês (todos clientes)
      revenueValues, // soma receita por mês (R$)
      newClientsValues, // novos usuários por mês
      requestsData, // top combos para o pie chart [{label, value, percent}, ...] (top 6 geral)
      top_requests_last_month: topRequestsLastMonth, // NOVO: top 10 combos no mês calendário anterior + quantidade
      indicators: {
        analyses_last_week: Number(analysesLastWeek ?? 0),
        revenue_this_month: Number(revenueThisMonth ?? 0),
        new_clients_current_month: Number(newClientsThisMonth ?? 0),
        top_request_label: topRequest.label,
        top_request_percent: topRequest.percent
      },
      totals: {
        total_analyses: Number(totalAnalyses ?? 0),
        em_andamento: Number(emAndamento ?? 0),
        total_revenue_6m: Number(totalRevenue6m ?? 0),
        credits_validos: Number(creditsValidos ?? 0)
      },
      config: configForFrontend,
      ultimo_analise: ultimo
        ? {
          id: ultimo.id,
          produto_biologico: ultimo.produto_biologico?.nome ?? null,
          produto_quimico: ultimo.produto_quimico?.nome ?? null,
          data_solicitacao: ultimo.data_solicitacao
        }
        : null,

      // NOVOS CAMPOS REQUERIDOS
      empresas: empresasComContagem,               // lista de empresas com clientes vinculados count
      total_clientes: Number(totalClientes ?? 0), // total de usuários cadastrados
      clientes_nao_vinculados: Number(clientesNaoVinculados ?? 0)
    });
  } catch (err) {
    console.error("Erro em GET /dashboard/completo:", err);
    return res.status(500).json({ error: "Erro ao montar dashboard completo" });
  }
});

/**
 * GET /dashboard/me
 * Dados personalizados do usuário logado (créditos, análises, gráfico dos últimos 4 meses, etc).
 * Mantive a lógica original, adaptando para usar id_produto_* e buscar nomes via relação.
 */
router.get("/me", authenticateToken, async (req, res) => {
  try {
    const userId = (req.user && (req.user.id || req.user.userId || req.user.sub)) ?? null;
    if (!userId) return res.status(400).json({ error: "User id não encontrado no token" });

    // usuário e assinatura/plano ativo (se houver)
    const usuario = await prisma.usuario.findUnique({
      where: { id: Number(userId) },
      include: {
        vinculoAssinatura: { include: { plano: true } }
      }
    });

    if (!usuario) return res.status(404).json({ error: "Usuário não encontrado" });

    // contagens gerais
    const totalAnalises = await prisma.solicitacao_analise.count({
      where: { id_usuario: Number(userId) }
    });

    const emAndamento = await prisma.solicitacao_analise.count({
      where: { id_usuario: Number(userId), status: "em_andamento" }
    });

    // último registro (incluir produtos para obter nomes)
    const ultimo = await prisma.solicitacao_analise.findFirst({
      where: { id_usuario: Number(userId) },
      orderBy: { data_solicitacao: "desc" },
      take: 1,
      include: {
        produto_biologico: { select: { nome: true } },
        produto_quimico: { select: { nome: true } }
      }
    });

    // créditos e saldo mensal (com base na assinatura ativa)
    const planoAtivo = usuario.vinculoAssinatura?.plano ?? null;
    const plano_creditos_mensal = planoAtivo ? Number(planoAtivo.quantidade_credito_mensal) : 0;

    // cálculo de usados no mês atual e saldo restante
    const now = new Date();
    const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
    const startNextMonth = new Date(now.getFullYear(), now.getMonth() + 1, 1);

    const usadosNoMes = await prisma.solicitacao_analise.count({
      where: {
        id_usuario: Number(userId),
        data_solicitacao: { gte: startOfMonth, lt: startNextMonth }
      }
    });

    const saldoARealizar = Math.max(plano_creditos_mensal - usadosNoMes, 0);

    // último 4 meses: labels e valores (contagem de solicitações por mês)
    const chartLabels = [];
    const chartValues = [];
    for (let i = 3; i >= 0; i--) {
      const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
      const year = d.getFullYear();
      const month = d.getMonth();
      const start = new Date(year, month, 1);
      const end = new Date(year, month + 1, 1);

      const cnt = await prisma.solicitacao_analise.count({
        where: {
          id_usuario: Number(userId),
          data_solicitacao: { gte: start, lt: end }
        }
      });

      chartLabels.push(MONTH_NAMES_PT[month]);
      chartValues.push(cnt);
    }

    // === NOVA LÓGICA DE SALDO (sem alterar resposta externa) ===
    const configMaisRecente = await prisma.config_sistema.findFirst({
      orderBy: { atualizado_em: "desc" }
    });
    const validadeEmDias = configMaisRecente?.validade_em_dias ?? 0; // 0 ou negativo => tratar como sem expiração

    const pacotes = await prisma.pacote_creditos.findMany({
      where: { id_usuario: Number(userId) }
    });

    const agora = new Date();
    let somaPacotesValidos = 0;
    for (const p of pacotes) {
      const recebido = p.data_recebimento instanceof Date ? p.data_recebimento : new Date(p.data_recebimento);
      if (!Number.isFinite(p.quantidade)) continue;
      if (!validadeEmDias || validadeEmDias <= 0) {
        somaPacotesValidos += Number(p.quantidade);
      } else {
        const expiracao = new Date(recebido.getTime() + validadeEmDias * 24 * 60 * 60 * 1000);
        if (expiracao >= agora) {
          somaPacotesValidos += Number(p.quantidade);
        }
      }
    }

    return res.json({
      credits: somaPacotesValidos,
      total_analises: totalAnalises,
      em_andamento: emAndamento,
      ultimo_analise: ultimo
        ? {
          id: ultimo.id,
          produto_biologico: ultimo.produto_biologico?.nome ?? null,
          produto_quimico: ultimo.produto_quimico?.nome ?? null,
          data_solicitacao: ultimo.data_solicitacao
        }
        : null,
      mensal: {
        plano_creditos_mensal,
        usados_no_mes: usadosNoMes,
        saldo_a_realizar: saldoARealizar
      },
      chart: {
        labels: chartLabels,
        values: chartValues
      }
    });
  } catch (error) {
    console.error("Erro ao montar dashboard:", error);
    return res.status(500).json({ error: "Erro ao montar dashboard" });
  }
});

export default router;
