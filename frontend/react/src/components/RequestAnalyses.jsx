// RequestAnalysisPage.jsx
import React, { useEffect, useRef, useState } from "react";
import "./Pages.css";
import "./RequestAnalysis.css";

function IconSearch(props) {
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true" {...props}>
      <path
        fill="currentColor"
        d="M10 3a7 7 0 1 0 4.3 12.5l4.1 4.1 1.4-1.4-4.1-4.1A7 7 0 0 0 10 3Zm0 2a5 5 0 1 1 0 10 5 5 0 0 1 0-10Z"
      />
    </svg>
  );
}

function IconMail(props) {
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true" {...props}>
      <path
        fill="currentColor"
        d="M20 4H4a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V6a2 2 0 0 0-2-2Zm0 4-8 5L4 8V6l8 5 8-5v2Z"
      />
    </svg>
  );
}

function IconCredits(props) {
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true" {...props}>
      <path
        fill="currentColor"
        d="M12 3c4.97 0 9 1.79 9 4s-4.03 4-9 4-9-1.79-9-4 4.03-4 9-4Zm-9 7v3c0 2.21 4.03 4 9 4s9-1.79 9-4v-3c-1.6 1.66-5.26 2.8-9 2.8S4.6 11.66 3 10Zm0 6v3c0 2.21 4.03 4 9 4s9-1.79 9-4v-3c-1.6 1.66-5.26 2.8-9 2.8S4.6 17.66 3 16Z"
      />
    </svg>
  );
}

export default function RequestAnalysisPage() {
  const [chemical, setChemical] = useState("");
  const [biological, setBiological] = useState("");
  const creditsAvailable = 12;

  const cardRef = useRef(null);

  // ✅ garante o "pulinho" SEMPRE (reinicia a animação no mount)
  useEffect(() => {
    const el = cardRef.current;
    if (!el) return;

    el.classList.remove("pg-enter");
    // força reflow pra reiniciar animation
    void el.offsetHeight;
    el.classList.add("pg-enter");
  }, []);

  const submit = (e) => {
    e.preventDefault();
    console.log({ chemical, biological });
  };

  const requestMissingProduct = () => {
    console.log("Enviar solicitação (produto não encontrado)");
  };

  return (
    <div className="pg-wrap">
      <header className="pg-header">
        <h1 className="pg-title">Solicitar Análise</h1>
      </header>

      <div className="analysisPage">
        {/* ✅ mesmo "tipo" de card das outras telas (sem card externo) */}
        <form ref={cardRef} className="pg-card requestCard" onSubmit={submit}>
          <div className="requestGroup">
            <h2 className="requestTitle">Produto Químico</h2>

            <div className="requestSearch">
              <span className="requestSearchIco" aria-hidden="true">
                <IconSearch />
              </span>

              <input
                className="requestInput"
                value={chemical}
                onChange={(e) => setChemical(e.target.value)}
                placeholder="Buscar produto químico..."
                autoComplete="off"
              />
            </div>
          </div>

          <div className="requestGroup">
            <h2 className="requestTitle">Produto Biológico</h2>

            <div className="requestSearch">
              <span className="requestSearchIco" aria-hidden="true">
                <IconSearch />
              </span>

              <input
                className="requestInput"
                value={biological}
                onChange={(e) => setBiological(e.target.value)}
                placeholder="Buscar produto biológico..."
                autoComplete="off"
              />
            </div>
          </div>

          <div className="requestHelpRow">
            <button type="button" className="requestHelpBtn" onClick={requestMissingProduct}>
              <span className="requestHelpText">Não encontrou o produto? Enviar solicitação!</span>

              <span className="requestHelpIcoWrap" aria-hidden="true">
                <IconMail className="requestHelpIco" />
              </span>
            </button>
          </div>

          <div className="requestActions">
            <button type="submit" className="requestMainBtn">
              Solicitar Análise
            </button>
          </div>

          <div className="requestCredits">
            <span className="requestCreditsLabel">Créditos disponíveis:</span>
            <span className="requestCreditsIco" aria-hidden="true">
              <IconCredits />
            </span>
            <strong className="requestCreditsValue">{creditsAvailable}</strong>
          </div>
        </form>
      </div>
    </div>
  );
}
