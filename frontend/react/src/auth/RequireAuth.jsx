import React from "react";
import { Navigate, Outlet, useLocation } from "react-router-dom";
import { useAuth } from "./AuthContext";

export default function RequireAuth() {
  const location = useLocation();
  const { isAuthenticated, authReady } = useAuth();

  // ✅ Enquanto verifica /me, não renderiza rota protegida
  if (!authReady) return null; // ou um spinner/tela de loading

  // ✅ Sem auth: redireciona imediatamente pro login
  if (!isAuthenticated) {
    return <Navigate to="/login" replace state={{ from: location }} />;
  }

  return <Outlet />;
}
