import React from "react";
import { BrowserRouter, Routes, Route, Navigate, useLocation } from "react-router-dom";

import CompatBioLogin from "./components/CompatBioLogin";
import DashboardLayout from "./components/DashboardLayout";

import ProfilePage from "./components/ProfilePage";
import RequestAnalysisPage from "./components/RequestAnalyses";
import ResultsPage from "./components/ResultPage";
import PlansCreditsPage from "./components/PlansPage";
import AnalysisDetailsPage from "./components/AnalysesDetails";
import CheckoutConfirmPage from "./components/Checkout";

import RequireAuth from "./auth/RequireAuth";
import { useAuth } from "./auth/AuthContext";

function LoginRoute() {
  const { isAuthenticated, authReady } = useAuth();
  const location = useLocation();

  const from = location.state?.from?.pathname || "/app";

  // enquanto valida sessão, evita piscar/trocar rota
  if (!authReady) return null;

  // se já autenticado, não deixa ficar no /login
  if (isAuthenticated) return <Navigate to={from} replace />;

  return <CompatBioLogin />;
}

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        {/* ÚNICA rota pública */}
        <Route path="/login" element={<LoginRoute />} />

        {/* TUDO o resto protegido */}
        <Route element={<RequireAuth />}>
          <Route path="/" element={<Navigate to="/app" replace />} />

          <Route path="/app" element={<DashboardLayout />}>
            <Route index element={<Navigate to="perfil" replace />} />
            <Route path="perfil" element={<ProfilePage />} />
            <Route path="solicitar-analise" element={<RequestAnalysisPage />} />
            <Route path="resultados" element={<ResultsPage />} />
            <Route path="detalhes-analise" element={<AnalysisDetailsPage />} />
            <Route path="planos" element={<PlansCreditsPage />} />
            <Route path="confirmar-compra" element={<CheckoutConfirmPage />} />
          </Route>

          {/* qualquer rota errada protegida cai no app */}
          <Route path="*" element={<Navigate to="/app" replace />} />
        </Route>
      </Routes>
    </BrowserRouter>
  );
}
