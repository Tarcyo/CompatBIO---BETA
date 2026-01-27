// PlansCreditsPage.jsx
import React, { useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import "./Pages.css";
import "./PlansPage.css";

function IconCheckCircle(props) {
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true" {...props}>
      <path
        fill="currentColor"
        d="M12 2a10 10 0 1 0 .001 20.001A10 10 0 0 0 12 2Zm-1.15 14.2-3.5-3.5 1.41-1.41 2.09 2.1 5.32-5.32 1.41 1.41-6.73 6.72Z"
      />
    </svg>
  );
}

function PlanCard({
  title,
  price,
  interval = "/mês",
  badge,
  features,
  variant = "blue", // "blue" | "green"
  ctaLabel,
  onCta,
}) {
  return (
    <article className={`planTile ${variant === "green" ? "is-green" : ""}`}>
      {badge ? (
        <div className="planBadgeRow">
          <span className="planBadge">
            <IconCheckCircle className="planBadgeIco" />
            {badge}
          </span>
        </div>
      ) : (
        <div className="planBadgeRow" />
      )}

      <h4 className="planTitle">{title}</h4>

      <div className="planPrice">
        <span className="planPriceMain">{price}</span>
        <span className="planPriceInterval">{interval}</span>
      </div>

      <ul className="planFeatures">
        {features.map((t) => (
          <li key={t} className="planFeature">
            <IconCheckCircle className="planCheck" />
            <span>{t}</span>
          </li>
        ))}
      </ul>

      <button
        type="button"
        className={`planBtn ${variant === "green" ? "is-green" : "is-blue"}`}
        onClick={onCta}
      >
        {ctaLabel}
      </button>
    </article>
  );
}

export default function PlansPage() {
  const navigate = useNavigate();

  const PRICE_PER_CREDIT = 2.0;

  const plans = useMemo(
    () => ({
      current: {
        name: "Plano Premium",
        features: ["Ativo", "Análises ilimitadas", "Suporte Prioritário"],
      },
      pf: [
        {
          id: "pf_basic",
          title: "Plano Básico",
          price: "R$ 19,90",
          features: ["Até 5 análises por mês", "Suporte Prioritário"],
          cta: "Escolher Plano",
          variant: "blue",
        },
        {
          id: "pf_advanced",
          title: "Plano Avançado",
          price: "R$ 49,90",
          features: ["20 análises por mês", "Suporte Prioritário"],
          cta: "Escolher Plano",
          variant: "blue",
        },
      ],
      pj: [
        {
          id: "pj_active",
          title: "Plano",
          price: "R$ 99,90",
          badge: "Seu Plano Ativo",
          features: ["Até 5 análises por mês", "Suporte Prioritário"],
          cta: "Detalhar Plano",
          variant: "green",
        },
        {
          id: "pj_premium",
          title: "Plano Premium",
          price: "R$ 99,90",
          features: ["Até ilimitadas", "Suporte Prioritário"],
          cta: "Escolher Plano",
          variant: "blue",
        },
      ],
    }),
    []
  );

  const [credits, setCredits] = useState(10);

  const handleChoose = (id) => {
    console.log("Escolher plano:", id);
  };

  // ✅ AGORA REDIRECIONA
  const handleBuyCredits = () => {
    navigate("/app/confirmar-compra", {
      state: {
        credits,
        pricePerCredit: PRICE_PER_CREDIT,
      },
    });
  };

  return (
    <div className="pg-wrap">
      <header className="pg-header">
        <h1 className="pg-title">Planos e Créditos</h1>
      </header>

      <section className="pg-card plansCard">
        <h3 className="plansSectionTitle">Seu Plano Atual</h3>

        <div className="currentPlan">
          <div className="currentPlanLeft">
            <h4 className="currentPlanTitle">{plans.current.name}</h4>
            <ul className="currentPlanList">
              {plans.current.features.map((t) => (
                <li key={t} className="currentPlanItem">
                  <IconCheckCircle className="currentPlanCheck" />
                  <span>{t}</span>
                </li>
              ))}
            </ul>
          </div>

          <div className="currentPlanRight">
            <button
              type="button"
              className="chooseBtn is-blue"
              onClick={() => handleChoose("current_change")}
            >
              Escolher Plano
            </button>
          </div>
        </div>

        <div className="plansDivider" />

        <div className="plansCols">
          <div className="plansCol">
            <h3 className="plansGroupTitle">Planos Recomendados para Pessoas Físicas</h3>

            <div className="plansGrid">
              {plans.pf.map((p) => (
                <PlanCard
                  key={p.id}
                  title={p.title}
                  price={p.price}
                  features={p.features}
                  ctaLabel={p.cta}
                  variant={p.variant}
                  onCta={() => handleChoose(p.id)}
                />
              ))}
            </div>
          </div>

          <div className="plansCol is-right">
            <h3 className="plansGroupTitle">Planos Recomendados para Pessoas Jurídicas</h3>

            <div className="plansGrid">
              {plans.pj.map((p) => (
                <PlanCard
                  key={p.id}
                  title={p.title}
                  price={p.price}
                  badge={p.badge}
                  features={p.features}
                  ctaLabel={p.cta}
                  variant={p.variant}
                  onCta={() => handleChoose(p.id)}
                />
              ))}
            </div>
          </div>
        </div>

        <div className="plansDivider" />

        <h3 className="plansSectionTitle">Comprar Créditos Avulsos</h3>

        <p className="creditsLabel">Quantos créditos você deseja comprar?</p>

        <div className="creditsRow">
          <input
            className="creditsInput"
            type="number"
            min={1}
            value={credits}
            onChange={(e) => setCredits(Math.max(1, Number(e.target.value || 1)))}
            aria-label="Quantidade de créditos"
          />

          <button type="button" className="buyBtn is-green" onClick={handleBuyCredits}>
            <IconCheckCircle className="buyBtnIco" />
            Comprar Créditos
          </button>
        </div>

        <small className="creditsHint">R$2,00 por crédito</small>
      </section>
    </div>
  );
}
