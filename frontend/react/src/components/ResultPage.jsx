// Result.jsx
import React, { useMemo } from "react";
import { useNavigate } from "react-router-dom";
import "./Pages.css";
import "./Results.css";

function IconArrow(props) {
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true" {...props}>
      <path
        fill="currentColor"
        d="M13 5l7 7-7 7-1.4-1.4L16.2 13H4v-2h12.2l-4.6-4.6L13 5Z"
      />
    </svg>
  );
}

function IconChevronRight(props) {
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true" {...props}>
      <path
        fill="currentColor"
        d="M9 18l6-6-6-6 1.4-1.4L18.8 12l-8.4 8.4L9 18Z"
      />
    </svg>
  );
}

const STATUS_META = {
  compatible: { label: "Compatível", cls: "is-ok" },
  incompatible: { label: "Incompatível", cls: "is-bad" },
  analyzing: { label: "Em Análise", cls: "is-warn" },
};

export default function Result() {
  const navigate = useNavigate();

  const rows = useMemo(
    () => [
      {
        date: "18/04/2024",
        chemical: "Glifosato",
        biological: "Bacillus cereus Sp.",
        status: "compatible",
      },
      {
        date: "16/04/2024",
        chemical: "Metomil",
        biological: "Trichoderma harz.",
        status: "incompatible",
      },
      {
        date: "12/04/2024",
        chemical: "Acefato",
        biological: "Bacillus cereus Sp.",
        status: "compatible",
      },
      {
        date: "07/04/2024",
        chemical: "Glifosato",
        biological: "Trichoderma spp.",
        status: "analyzing",
      },
      {
        date: "02/04/2024",
        chemical: "Glifosato",
        biological: "Trichoderma spp.",
        status: "analyzing",
      },
      {
        date: "22/03/2024",
        chemical: "Clorpirifós",
        biological: "Paecilomyces lilacinus",
        status: "incompatible",
      },
      {
        date: "22/03/2024",
        chemical: "Clorpirifós",
        biological: "Paecilomyces lilacinus",
        status: "incompatible",
      },
    ],
    []
  );

  const onDetail = (item) => {
    console.log("Detalhar:", item);
    navigate("/app/detalhes-analise");
  };

  return (
    <div className="pg-wrap">
      <div className="resultsPage">
        <section className="pg-card resultsCard">
          {/* ✅ TÍTULO DENTRO DO CARD */}
          <header className="resultsCardHeader">
            <h1 className="resultsCardTitle">Resultados das Análises</h1>
          </header>

          <div className="resultsCardBody">
            <ul className="resultsList">
              {rows.map((r, idx) => {
                const meta = STATUS_META[r.status] ?? STATUS_META.analyzing;

                return (
                  <li key={`${r.date}-${r.chemical}-${idx}`} className="resultsRow">
                    <span className="resultsDate">{r.date}</span>

                    <span
                      className="resultsName resultsName--left"
                      title={r.chemical}
                    >
                      {r.chemical}
                    </span>

                    <span className="resultsArrow" aria-hidden="true">
                      <IconArrow />
                    </span>

                    <span
                      className="resultsName resultsName--right"
                      title={r.biological}
                    >
                      {r.biological}
                    </span>

                    <span className={`resultsStatus ${meta.cls}`}>
                      {meta.label}
                    </span>

                    <button
                      type="button"
                      className="resultsDetailBtn"
                      onClick={() => onDetail(r)}
                    >
                      Detalhar Análise
                    </button>
                  </li>
                );
              })}
            </ul>

            {/* “scroll hint” (opcional) */}
            <button
              type="button"
              className="resultsScrollHint"
              aria-label="Mais resultados"
            >
              <IconChevronRight />
            </button>
          </div>
        </section>
      </div>
    </div>
  );
}
