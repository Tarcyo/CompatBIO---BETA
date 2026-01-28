
import React, { useCallback, useMemo, useState } from "react";
import "./CompatBioLogin.css";

import background from "../assets/background.png";
import logo from "../assets/Logo.png";
import googleIcon from "../assets/google-icon.png";

export default function CompatBioLogin({ onGoogleClick }) {
  const [isLoading, setIsLoading] = useState(false);

  // backend /login
  const AUTH_URL = useMemo(() => {
    const fromEnv = (import.meta?.env?.VITE_GOOGLE_AUTH_URL ?? "")
      .toString()
      .trim();
    return fromEnv || "http://localhost:3000/login";
  }, []);

  const startGoogleAuth = useCallback(() => {
    if (isLoading) return;
    setIsLoading(true);

    if (typeof onGoogleClick === "function") onGoogleClick();

    // OAuth deve iniciar por navegação
    window.location.assign(AUTH_URL);
  }, [AUTH_URL, isLoading, onGoogleClick]);

  return (
    <main className="cb-page" style={{ backgroundImage: `url(${background})` }}>
      <section className="cb-card" role="dialog" aria-label="Login CompatBio">
        <img className="cb-logo" src={logo} alt="CompatBio" />
        <div className="cb-divider" />
        <h1 className="cb-title">Bem-vindo ao CompatBio!</h1>

        <button
          type="button"
          className="cb-google-btn"
          onClick={startGoogleAuth}
          disabled={isLoading}
        >
          <img className="cb-google-icon" src={googleIcon} alt="" />
          <span className="cb-google-text">
            {isLoading ? "Redirecionando..." : "Continuar com o Google"}
          </span>
        </button>

        <p className="cb-legal">
          Ao continuar, você concorda com nossos{" "}
          <a className="cb-link" href="#" onClick={(e) => e.preventDefault()}>
            Termos de Serviço
          </a>{" "}
          e{" "}
          <a className="cb-link" href="#" onClick={(e) => e.preventDefault()}>
            Política de Privacidade
          </a>
          .
        </p>

        <p className="cb-help">
          Precisa de ajuda? Fale com o{" "}
          <a
            className="cb-link cb-link-strong"
            href="#"
            onClick={(e) => e.preventDefault()}
          >
            Suporte
          </a>
          .
        </p>
      </section>
    </main>
  );
}
