import React from "react";
import { Navigate, Outlet } from "react-router-dom";
import { useAuth } from "./AuthContext";

export default function RequireAuth() {
  const { user, loading } = useAuth();

  if (loading) return null; // ou spinner
  if (!user) return <Navigate to="/" replace />;

  return <Outlet />;
}
