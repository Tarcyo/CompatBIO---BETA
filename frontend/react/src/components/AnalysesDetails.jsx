// AnalysisDetailsPage.jsx
import React, { useEffect, useRef } from "react";
import { useNavigate } from "react-router-dom";
import "./Pages.css";
import "./AnalysesDetail.css";

function IconCheckCircle(props) {
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true" {...props}>
      <path
        fill="currentColor"
        d="M12 2a10 10 0 1 0 .001 20.001A10 10 0 0 0 12 2Zm-1.1 14.2-3.3-3.3 1.4-1.4 1.9 1.9 4.8-4.8 1.4 1.4-6.2 6.2Z"
      />
    </svg>
  );
}

export default function AnalysisDetailsPage() {
  const cardRef = useRef(null);
  const navigate = useNavigate();

  // ✅ reinicia animação do card no mount
  useEffect(() => {
    const el = cardRef.current;
    if (!el) return;
    el.classList.remove("pg-enter");
    void el.offsetHeight;
    el.classList.add("pg-enter");
  }, []);

  const chemical = "Glifosato";
  const biological = "Bacillus cereus Sp.";
  const status = "Compatível";
  const dateText = "Análise realizada em 18/04/2024 às 11:23";

  const handleDetail = () => {
    console.log("Detalhar análise...");
  };

  // ✅ volta para a rota anterior (histórico)
  const handleBack = () => {
    navigate(-1);
  };

  return (
    <div className="pg-wrap">
      <header className="pg-header">
        <h1 className="pg-title">Detalhes da Análise</h1>
      </header>

      <div className="analysisDetailsPage">
        <div className="detailsMeta">{dateText}</div>

        <section
          ref={cardRef}
          className="pg-card detailsCard"
          aria-label="Detalhes da análise"
        >
          {/* Topo (Produtos + Status) */}
          <div className="detailsTop">
            <div className="detailsBlock">
              <div className="detailsLabel">Produto Químico</div>
              <div className="detailsValue">{chemical}</div>
            </div>

            <div className="detailsArrow" aria-hidden="true">
              →
            </div>

            <div className="detailsMid">
              <span className="detailsBadge detailsBadgeOk">{status}</span>
            </div>

            <div className="detailsBlock">
              <div className="detailsLabel">Produto Biológico</div>
              <div className="detailsValue">{biological}</div>
            </div>

            <button
              type="button"
              className="detailsMiniBtn"
              onClick={handleDetail}
            >
              Detalhar Análise
            </button>
          </div>

          {/* Conteúdo */}
          <div className="detailsBody">
            <div className="detailsStatusRow">
              <span className="detailsStatusIcon" aria-hidden="true">
                <IconCheckCircle />
              </span>

              <h2 className="detailsStatusTitle">{status}</h2>
            </div>

            <p className="detailsText">
              De acordo com a análise realizada, o produto químico{" "}
              <strong>{chemical}</strong> e o produto biológico{" "}
              <strong>{biological}</strong> são considerados compatíveis. Isso
              significa que, sob as condições avaliadas, o uso do bacilo{" "}
              <strong>{biological}</strong> junto ao herbicida{" "}
              <strong>{chemical}</strong> não deve gerar efeitos negativos na
              proteção biológica de seu controle.
            </p>

            <div className="detailsActions">
              <button
                type="button"
                className="detailsBackBtn"
                onClick={handleBack}
              >
                Voltar para Resultados
              </button>
            </div>
          </div>
        </section>
      </div>
    </div>
  );
}
