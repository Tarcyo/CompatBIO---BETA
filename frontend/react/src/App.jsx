import React from "react";
import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";

import CompatBioLogin from "./components/CompatBioLogin";
import DashboardLayout from "./components/DashboardLayout";

// ✅ páginas reais
import ProfilePage from "./components/ProfilePage";
import RequestAnalysisPage from "./components/RequestAnalyses";
import ResultsPage from "./components/ResultPage";
import PlansCreditsPage from "./components/PlansPage";

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        {/* LOGIN */}
        <Route
          path="/"
          element={
            <CompatBioLogin onGoogleClick={() => console.log("Google login")} />
          }
        />

        {/* ÁREA DO APP (com Sidebar) */}
        <Route path="/app" element={<DashboardLayout />}>
          {/* ao acessar /app, redireciona para /app/perfil */}
          <Route index element={<Navigate to="perfil" replace />} />

          {/* rotas do sidebar */}
          <Route path="perfil" element={<ProfilePage />} />
          <Route path="solicitar-analise" element={<RequestAnalysisPage />} />
          <Route path="resultados" element={<ResultsPage />} />
          <Route path="planos" element={<PlansCreditsPage />} />
        </Route>

        {/* fallback */}
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  );
}
