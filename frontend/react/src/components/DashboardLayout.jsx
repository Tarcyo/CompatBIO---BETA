import React from "react";
import { Outlet, useLocation } from "react-router-dom";
import Sidebar from "./Sidebar";
import "./DashboardLayout.css";

import background from "../assets/background.png";

export default function DashboardLayout() {
  const location = useLocation();

  return (
    <div className="ds-page" style={{ backgroundImage: `url(${background})` }}>
      {/* overlay pra dar contraste e ficar mais “cinema” */}
      <div className="ds-overlay" aria-hidden="true" />

      <div className="ds-shell">
        <Sidebar />

        <main className="ds-main">
          {/* key força remount e dispara animação a cada troca de rota */}
          <div key={location.pathname} className="ds-routeAnim">
            <Outlet />
          </div>
        </main>
      </div>
    </div>
  );
}
