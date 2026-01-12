// routes/frontServer.js
import express from "express";
import path from "path";
import fs from "fs";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const router = express.Router();

const webDir = path.resolve(__dirname, "../web");
const indexFile = path.join(webDir, "index.html");

// Servir arquivos estáticos (Flutter Web: main.dart.js, assets, favicon etc.)
router.use(express.static(webDir, { index: false }));

// Função para garantir <base href="/app/">
function adjustBaseHref(htmlContent, baseHref = "/app/") {
  const baseRegex = /<base\s+href=["'][^"']*["']\s*\/?>/i;

  if (baseRegex.test(htmlContent)) {
    return htmlContent.replace(baseRegex, `<base href="${baseHref}">`);
  }

  const headRegex = /<head([^>]*)>/i;
  if (headRegex.test(htmlContent)) {
    return htmlContent.replace(headRegex, `<head$1>\n  <base href="${baseHref}">`);
  }

  return htmlContent;
}

// Cache inicial do index.html
let cachedIndexHtml = null;
try {
  cachedIndexHtml = fs.readFileSync(indexFile, "utf8");
} catch {
  cachedIndexHtml = null;
}

// Fallback SPA — somente rotas sem extensão!
const spaRegex = /^\/(?!.*\.\w{2,8}$).*$/;

router.get(spaRegex, (req, res) => {
  let html = cachedIndexHtml;

  if (!html) {
    try {
      html = fs.readFileSync(indexFile, "utf8");
      cachedIndexHtml = html;
    } catch (err) {
      console.error("[frontServer] ERRO ao abrir index.html:", err);
      return res.status(500).send("Erro ao carregar aplicação web.");
    }
  }

  const adjusted = adjustBaseHref(html, "/app/");

  res.setHeader("Content-Type", "text/html; charset=utf-8");
  res.send(adjusted);
});

export default router;
