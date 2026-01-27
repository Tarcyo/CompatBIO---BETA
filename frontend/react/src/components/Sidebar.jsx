
import React, { useLayoutEffect, useMemo, useRef, useState } from "react";
import { NavLink, useLocation, useNavigate } from "react-router-dom";
import "./Sidebar.css";

import logo from "../assets/Logo.png";

/* Ícones (mesmos que você já tinha) */
function IconUser(props) {
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true" {...props}>
      <path
        fill="currentColor"
        d="M12 12a4.6 4.6 0 1 0-4.6-4.6A4.6 4.6 0 0 0 12 12Zm0 2.3c-4.2 0-7.7 2.2-7.7 4.9V21h15.4v-1.8c0-2.7-3.5-4.9-7.7-4.9Z"
      />
    </svg>
  );
}
function IconDoc(props) {
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true" {...props}>
      <path
        fill="currentColor"
        d="M7 2h7l5 5v15a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2Zm7 1.5V8h4.5L14 3.5ZM8 11h8v2H8v-2Zm0 4h8v2H8v-2Z"
      />
    </svg>
  );
}
function IconChart(props) {
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true" {...props}>
      <path
        fill="currentColor"
        d="M4 20V4h2v14h14v2H4Zm4-2V9h2v9H8Zm4 0V6h2v12h-2Zm4 0v-7h2v7h-2Z"
      />
    </svg>
  );
}
function IconCard(props) {
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true" {...props}>
      <path
        fill="currentColor"
        d="M3 6a3 3 0 0 1 3-3h12a3 3 0 0 1 3 3v12a3 3 0 0 1-3 3H6a3 3 0 0 1-3-3V6Zm2 3h14V7a1 1 0 0 0-1-1H6a1 1 0 0 0-1 1v2Zm0 3v6a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-6H5Z"
      />
    </svg>
  );
}
function IconPower(props) {
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true" {...props}>
      <path
        fill="currentColor"
        d="M11 2h2v10h-2V2Zm7.07 3.93 1.41 1.41A9 9 0 1 1 4.52 7.34l1.41-1.41A7 7 0 1 0 18.07 5.93Z"
      />
    </svg>
  );
}

export default function Sidebar() {
  const navigate = useNavigate();
  const location = useLocation();

  const NAV_ITEMS = useMemo(
    () => [
      { to: "/app/perfil", label: "Perfil", icon: IconUser },
      { to: "/app/solicitar-analise", label: "Solicitar análise", icon: IconDoc },
      { to: "/app/resultados", label: "Resultados das análises", icon: IconChart },
      { to: "/app/planos", label: "Planos e créditos", icon: IconCard },
    ],
    []
  );

  const navRef = useRef(null);
  const [pill, setPill] = useState({ y: 0, h: 54, show: false });

  const updatePill = () => {
    const nav = navRef.current;
    if (!nav) return;

    const active = nav.querySelector(".sb-item.is-active");
    if (!active) {
      setPill((p) => ({ ...p, show: false }));
      return;
    }

    const navRect = nav.getBoundingClientRect();
    const actRect = active.getBoundingClientRect();

    const y = actRect.top - navRect.top;
    const h = actRect.height;

    setPill({ y, h, show: true });
  };

  useLayoutEffect(() => {
    // garante que medimos depois do DOM aplicar o active
    const raf = requestAnimationFrame(updatePill);
    return () => cancelAnimationFrame(raf);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [location.pathname]);

  useLayoutEffect(() => {
    const onResize = () => updatePill();
    window.addEventListener("resize", onResize);
    return () => window.removeEventListener("resize", onResize);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const handleLogout = () => {
    sessionStorage.removeItem("auth_token");
    navigate("/", { replace: true });
  };

  return (
    <aside className="sb" aria-label="Menu lateral">
      <div className="sb-top">
        <div className="sb-brand" aria-label="CompatBio">
          <img className="sb-logo" src={logo} alt="CompatBio" />
        </div>

        <nav ref={navRef} className="sb-nav" aria-label="Navegação">
          {/* PILL (highlight) que DESLIZA entre os itens */}
          <span
            className={`sb-activePill ${pill.show ? "is-show" : ""}`}
            style={{
              transform: `translateY(${pill.y}px)`,
              height: `${pill.h}px`,
            }}
            aria-hidden="true"
          />

          {NAV_ITEMS.map((item) => {
            const Icon = item.icon;
            return (
              <NavLink
                key={item.to}
                to={item.to}
                className={({ isActive }) =>
                  `sb-item ${isActive ? "is-active" : ""}`
                }
              >
                <span className="sb-itemIcon" aria-hidden="true">
                  <Icon className="sb-icon" />
                </span>
                <span className="sb-itemLabel">{item.label}</span>
              </NavLink>
            );
          })}
        </nav>
      </div>

      <div className="sb-bottom">
        <button type="button" className="sb-logout" onClick={handleLogout}>
          <span className="sb-logoutIcon" aria-hidden="true">
            <IconPower className="sb-iconPower" />
          </span>
          <span className="sb-logoutLabel">Sair</span>
        </button>
      </div>
    </aside>
  );
}
