// middleware/auth.js
import jwt from "jsonwebtoken";
// middleware/authorizeAdministrative.js
import { PrismaClient } from "@prisma/client";
const prisma = new PrismaClient();

/**
 * Permite acesso somente para usuários com tipo_usuario = "Administrativo".
 * Requer que o middleware de autenticação (authenticateToken) já tenha
 * populado req.user com o payload do JWT.
 */
export async function authorizeAdministrative(req, res, next) {
  try {
    const payload = req.user;
    if (!payload) {
      return res.status(401).json({ error: "Usuário não autenticado" });
    }

    // comparação case-insensitive se o payload já trouxer o tipo
    const payloadTipo = (payload.tipo_usuario || payload.tipo || "").toString().toLowerCase();
    if (payloadTipo === "administrativo") {
      return next();
    }

    // tenta resolver id a partir do payload (id, userId, sub) ou email
    const userId = payload.id ?? payload.userId ?? payload.sub ?? null;
    if (userId) {
      const user = await prisma.usuario.findUnique({ where: { id: Number(userId) } });
      if (!user) return res.status(401).json({ error: "Usuário não encontrado" });
      if ((user.tipo_usuario || "").toString().toLowerCase() === "administrativo") {
        return next();
      }
      return res.status(403).json({ error: "Acesso negado: requer tipo Administrativo" });
    }

    if (payload.email) {
      const user = await prisma.usuario.findUnique({ where: { email: payload.email } });
      if (user && (user.tipo_usuario || "").toString().toLowerCase() === "administrativo") {
        return next();
      }
      return res.status(403).json({ error: "Acesso negado: requer tipo Administrativo" });
    }

    return res.status(403).json({ error: "Acesso negado: credenciais insuficientes" });
  } catch (err) {
    console.error("Erro no middleware de autorização administrativa:", err);
    return res.status(500).json({ error: "Erro interno de autorização" });
  }
}

export default authorizeAdministrative;



export function authenticateToken(req, res, next) {
  try {
    const authHeader = req.headers["authorization"];
    // Espera "Bearer <token>"
    const token = authHeader && authHeader.split(" ")[1];
    if (!token) {
      return res.status(401).json({ error: "Token não fornecido" });
    }

    const secret = process.env.JWT_SECRET;
    if (!secret) {
      console.error("JWT_SECRET não definido em process.env");
      return res.status(500).json({ error: "Configuração de servidor inválida" });
    }

    jwt.verify(token, secret, (err, payload) => {
      if (err) {
        return res.status(403).json({ error: "Token inválido ou expirado" });
      }
      // salva payload no req para uso nas rotas
      req.user = payload;
      next();
    });
  } catch (err) {
    console.error("Erro no middleware de autenticação:", err);
    return res.status(500).json({ error: "Erro interno do servidor" });
  }
}
