import React, { useEffect, useLayoutEffect, useMemo, useRef, useState } from "react";
import { NavLink, useLocation, useNavigate } from "react-router-dom";

import logo from "../assets/Logo.png";
import { useAuth } from "../auth/AuthContext"; // ✅ ajuste o caminho se necessário

/* Ícones */
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

/* Ícone pequeno pro modal */
function IconWarning(props) {
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true" {...props}>
      <path
        fill="currentColor"
        d="M12 2 1 21h22L12 2Zm0 6c.55 0 1 .45 1 1v5a1 1 0 0 1-2 0V9c0-.55.45-1 1-1Zm0 11a1.25 1.25 0 1 1 0-2.5A1.25 1.25 0 0 1 12 19Z"
      />
    </svg>
  );
}

export default function Sidebar() {
  const navigate = useNavigate();
  const location = useLocation();

  const { isAuthenticated, authReady, checkAuth } = useAuth(); // ✅

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

  const [isLogoutOpen, setIsLogoutOpen] = useState(false);
  const [isLoggingOut, setIsLoggingOut] = useState(false);

  // ✅ Se perder autenticação enquanto está no app/Sidebar -> manda pro login
  useEffect(() => {
    if (!authReady) return;
    if (!isAuthenticated) {
      navigate("/login", { replace: true, state: { from: location } });
    }
  }, [authReady, isAuthenticated, navigate, location]);

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

  // fecha modal com ESC
  useLayoutEffect(() => {
    if (!isLogoutOpen) return;

    const onKeyDown = (e) => {
      if (e.key === "Escape") setIsLogoutOpen(false);
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [isLogoutOpen]);

  const openLogout = () => setIsLogoutOpen(true);
  const closeLogout = () => {
    if (isLoggingOut) return;
    setIsLogoutOpen(false);
  };

  // ✅ Intercepta cliques nos itens e valida auth antes de navegar
  const handleProtectedNav = async (e, to) => {
    e.preventDefault();

    // enquanto ainda não validou auth, não navega
    if (!authReady) return;

    // revalida na hora (pega expiração do token)
    const ok = await checkAuth();
    if (!ok) {
      navigate("/login", { replace: true, state: { from: location } });
      return;
    }

    navigate(to);
  };

  const confirmLogout = async () => {
    if (isLoggingOut) return;
    setIsLoggingOut(true);

    try {
      const API_URL = (import.meta?.env?.VITE_API_URL ?? "http://localhost:3000")
        .toString()
        .trim();

      await fetch(`${API_URL}/logout`, {
        method: "POST",
        credentials: "include",
      });
    } catch {
      // mesmo se falhar, seguimos com logout no front
 } finally {
  sessionStorage.removeItem("auth_token");
  setIsLoggingOut(false);
  setIsLogoutOpen(false);

  // ✅ Vai para /login e dá reload (garante reset total do estado)
  navigate("/login", { replace: true });
  window.location.reload();
}

  };

  return (
    <>
      <aside className="sb" aria-label="Menu lateral">
        <div className="sb-top">
          <div className="sb-brand" aria-label="CompatBio">
            <img className="sb-logo" src={logo} alt="CompatBio" />
          </div>

          <nav ref={navRef} className="sb-nav" aria-label="Navegação">
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
                  onClick={(e) => handleProtectedNav(e, item.to)} // ✅
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
          <button type="button" className="sb-logout" onClick={openLogout}>
            <span className="sb-logoutIcon" aria-hidden="true">
              <IconPower className="sb-iconPower" />
            </span>
            <span className="sb-logoutLabel">Sair</span>
          </button>
        </div>
      </aside>

      {/* MODAL LOGOUT */}
      {isLogoutOpen && (
        <div
          className="sb-modalOverlay"
          role="presentation"
          onMouseDown={(e) => {
            if (e.target === e.currentTarget) closeLogout();
          }}
        >
          <div
            className="sb-modal"
            role="dialog"
            aria-modal="true"
            aria-labelledby="sb-logout-title"
            aria-describedby="sb-logout-desc"
          >
            <div className="sb-modalHeader">
              <div className="sb-modalIcon" aria-hidden="true">
                <IconWarning className="sb-modalIconSvg" />
              </div>

              <div className="sb-modalTitles">
                <h2 id="sb-logout-title" className="sb-modalTitle">
                  Deseja realmente sair?
                </h2>
                <p id="sb-logout-desc" className="sb-modalDesc">
                  Você será desconectado e redirecionado para a tela de login.
                </p>
              </div>
            </div>

            <div className="sb-modalActions">
              <button
                type="button"
                className="sb-btn sb-btnGhost"
                onClick={closeLogout}
                disabled={isLoggingOut}
              >
                Cancelar
              </button>

              <button
                type="button"
                className="sb-btn sb-btnDanger"
                onClick={confirmLogout}
                disabled={isLoggingOut}
              >
                {isLoggingOut ? "Saindo..." : "Sim, sair"}
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  );
}
