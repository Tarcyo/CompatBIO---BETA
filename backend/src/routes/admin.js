import express from "express";
import authorizeAdministrative, { authenticateToken } from "../middleware/auth.js";

const router = express.Router();

// Rota para testar autenticação e autorização administrativa
router.get("/", authenticateToken, authorizeAdministrative, (req, res) => {
  // retorna o payload do JWT para verificação
  return res.json({ message: "Acesso administrativo autorizado", user: req.user });
});

export default router;
