import dotenv from "dotenv";
dotenv.config();

import express from "express";
import cors from "cors";

// Rotas da API
import dashboardRoutes from "./routes/dashboard.js";
import solicitacoesRoutes from "./routes/solicitacoes.js";
import produtosRoutes from "./routes/produtos.js";
import usuarioRoutes from "./routes/usuario.js";
import planosRoutes from "./routes/planos.js";
import adminRoutes from "./routes/admin.js";
import resultRoutes from "./routes/resultados.js";
import assinaturasRoutes from "./routes/assinaturas.js";
import configRoutes from "./routes/configSistema.js";
import comprasRoutes from "./routes/compra.js";
import precoCreditoRoutes from "./routes/precoCredito.js";
import empresaRoutes from "./routes/empresa.js";
import passwordResetRoutes from "./routes/resetPassword.js";
import pagamentosRoutes from "./routes/pagamentosDeCreditos.js";
import pagamentosAssinaturas from "./routes/assinaturaPagamentos.js";
import cancelamentoRoutes from "./routes/cancelamentoAssinatura.js";

// FRONTEND
import frontend from "./routes/frontServer.js";

// WEBHOOK
import webhook from "./routes/webhookPagamentos.js";

const app = express();

// 🔥 Permitir Proxies (obrigatório p/ Stripe CLI)
app.set("trust proxy", true);

// CORS
app.use(cors());

// 🔥 WEBHOOK (usa RAW BODY)
app.use("/webhook", webhook);

// 🔥 JSON parser (depois do webhook!)
app.use(express.json());

// FRONTEND (Flutter Web) — tem que vir antes das demais rotas!
app.use("/app", frontend);

// ROTA STATUS
app.get("/status", (req, res) => {
  res.json({ status: "servidor rodando" });
});

// 🔥 ROTA "/" — redireciona sem interferir no restante
app.get("/", (req, res) => {
  return res.redirect("https://www.compatbio.com.br/app/");
});

// ------------------------------------------------------------
// 🔥 Rotas da API (todas preservadas)
// ------------------------------------------------------------

app.use("/pagamentosDeCreditos", pagamentosRoutes);
app.use("/pagamentosDeAssinaturas", pagamentosAssinaturas);
app.use("/cancelamentoAssinatura", cancelamentoRoutes);

app.use("/preco-credito", precoCreditoRoutes);
app.use("/compras", comprasRoutes);
app.use("/empresas", empresaRoutes);
app.use("/config", configRoutes);
app.use("/resetPassword", passwordResetRoutes);

app.use("/admin", adminRoutes);
app.use("/assinaturas", assinaturasRoutes);
app.use("/resultados", resultRoutes);

app.use("/dashboard", dashboardRoutes);
app.use("/solicitacoes", solicitacoesRoutes);
app.use("/produtos", produtosRoutes);
app.use("/usuarios", usuarioRoutes);
app.use("/planos", planosRoutes);

// 404 GLOBAL
app.use((req, res) => {
  res.status(404).json({ error: "not_found" });
});

// START SERVER
const PORT = process.env.PORT || 3000;
app.listen(PORT, () =>
  console.log(`Servidor rodando na porta ${PORT}`)
);
