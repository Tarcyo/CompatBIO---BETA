import React from "react";
import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";

import CompatBioLogin from "./components/CompatBioLogin";
import DashboardLayout from "./components/DashboardLayout";

import ProfilePage from "./components/ProfilePage";
import RequestAnalysisPage from "./components/RequestAnalyses";
import ResultsPage from "./components/ResultPage";
import PlansCreditsPage from "./components/PlansPage";
import AnalysisDetailsPage from "./components/AnalysesDetails";
import CheckoutConfirmPage from "./components/Checkout";

import RequireAuth from "./auth/RequireAuth";

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        {/* LOGIN */}
        <Route path="/" element={<CompatBioLogin />} />

        {/* ÁREA PROTEGIDA */}
        <Route element={<RequireAuth />}>
          <Route path="/app" element={<DashboardLayout />}>
            {/* ao acessar /app, redireciona para /app/perfil */}
            <Route index element={<Navigate to="perfil" replace />} />

            {/* rotas internas */}
            <Route path="perfil" element={<ProfilePage />} />
            <Route path="solicitar-analise" element={<RequestAnalysisPage />} />
            <Route path="resultados" element={<ResultsPage />} />
            <Route path="detalhes-analise" element={<AnalysisDetailsPage />} />
            <Route path="planos" element={<PlansCreditsPage />} />
            <Route path="confirmar-compra" element={<CheckoutConfirmPage />} />
          </Route>
        </Route>

        {/* fallback */}
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  );
}
