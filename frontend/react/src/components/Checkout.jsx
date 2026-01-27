// CheckoutConfirmPage.jsx
import React, { useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import "./Pages.css";
import "./Checkout.css";

function IconCheck(props) {
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true" {...props}>
      <path
        fill="currentColor"
        d="M12 2a10 10 0 1 0 .001 20.001A10 10 0 0 0 12 2Zm-1.15 14.2-3.5-3.5 1.41-1.41 2.09 2.1 5.32-5.32 1.41 1.41-6.73 6.72Z"
      />
    </svg>
  );
}

function IconCard(props) {
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true" {...props}>
      <path
        fill="currentColor"
        d="M20 5H4a2 2 0 0 0-2 2v10a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V7a2 2 0 0 0-2-2Zm0 4H4V7h16v2ZM6 16h6v1H6v-1Z"
      />
    </svg>
  );
}

function IconBarcode(props) {
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true" {...props}>
      <path
        fill="currentColor"
        d="M3 5h2v14H3V5Zm4 0h1v14H7V5Zm3 0h2v14h-2V5Zm4 0h1v14h-1V5Zm3 0h2v14h-2V5Zm4 0h1v14h-1V5Z"
      />
    </svg>
  );
}

function formatBRL(value) {
  return new Intl.NumberFormat("pt-BR", {
    style: "currency",
    currency: "BRL",
  }).format(value);
}

export default function CheckoutConfirmPage({
  initialCredits = 37,
  pricePerCredit = 2.0,
  planName = "Compra de Créditos Avulsos",
}) {
  const navigate = useNavigate();

  const [credits, setCredits] = useState(Number(initialCredits) || 1);
  const [method, setMethod] = useState(""); // "card" | "boleto"
  const [isSubmitting, setIsSubmitting] = useState(false);

  const subtotal = useMemo(() => credits * pricePerCredit, [credits, pricePerCredit]);

  const handleConclude = async () => {
    if (!method || credits < 1) return;

    setIsSubmitting(true);
    try {
      console.log("Concluir compra:", { credits, method, total: subtotal });
      alert("Compra concluída (demo).");
    } finally {
      setIsSubmitting(false);
    }
  };

  // ✅ Cancelar e voltar para Planos
  const handleCancel = () => {
    navigate("/app/planos");
  };

  return (
    <div className="pg-wrap">
      <header className="pg-header">
        <h1 className="pg-title">Confirmação de Compra</h1>
      </header>

      <section className="pg-card checkoutCard">
        <div className="checkoutTop">
          <div className="checkoutTopLeft">
            <h2 className="checkoutTitle">{planName}</h2>
            <p className="checkoutSubtitle">Revise os detalhes antes de concluir.</p>
          </div>

          <div className="checkoutTopRight">
            <span className="totalPill">
              <span className="totalPillLabel">Total</span>
              <span className="totalPillValue">{formatBRL(subtotal)}</span>
            </span>
          </div>
        </div>

        <div className="checkoutDivider" />

        <div className="summaryGrid">
          <div className="summaryItem">
            <span className="summaryLabel">Quantidade de créditos</span>
            <div className="summaryValueRow">
              <input
                className="creditsInput"
                type="number"
                min={1}
                value={credits}
                onChange={(e) => setCredits(Math.max(1, Number(e.target.value || 1)))}
                aria-label="Quantidade de créditos"
              />
              <span className="summaryHint">créditos</span>
            </div>
          </div>

          <div className="summaryItem">
            <span className="summaryLabel">Valor por crédito</span>
            <span className="summaryValue">{formatBRL(pricePerCredit)}</span>
          </div>

          <div className="summaryItem is-total">
            <span className="summaryLabel">Valor total a pagar</span>
            <span className="summaryValue is-strong">{formatBRL(subtotal)}</span>
          </div>
        </div>

        <div className="checkoutDivider" />

        <h3 className="sectionTitle">Selecione a forma de pagamento</h3>

        <div className="payOptions" role="radiogroup" aria-label="Forma de pagamento">
          <label className={`payOption ${method === "card" ? "is-selected" : ""}`}>
            <input
              className="payRadio"
              type="radio"
              name="payment"
              value="card"
              checked={method === "card"}
              onChange={() => setMethod("card")}
            />
            <div className="payOptionTop">
              <span className="payIconWrap">
                <IconCard className="payIcon" />
              </span>
              <div className="payTexts">
                <span className="payTitle">Cartão de Crédito</span>
                <span className="payDesc">Aprovação rápida. Pague em 1x.</span>
              </div>
              {method === "card" && <IconCheck className="paySelectedIco" />}
            </div>
            <div className="payFoot">
              <span className="payMini">Você será direcionado para inserir os dados do cartão.</span>
            </div>
          </label>

          <label className={`payOption ${method === "boleto" ? "is-selected" : ""}`}>
            <input
              className="payRadio"
              type="radio"
              name="payment"
              value="boleto"
              checked={method === "boleto"}
              onChange={() => setMethod("boleto")}
            />
            <div className="payOptionTop">
              <span className="payIconWrap">
                <IconBarcode className="payIcon" />
              </span>
              <div className="payTexts">
                <span className="payTitle">Boleto</span>
                <span className="payDesc">Compensação em até 1–2 dias úteis.</span>
              </div>
              {method === "boleto" && <IconCheck className="paySelectedIco" />}
            </div>
            <div className="payFoot">
              <span className="payMini">Geraremos um boleto para pagamento (PDF/código).</span>
            </div>
          </label>
        </div>

        <div className="checkoutDivider" />

        <div className="checkoutActions">
          <div className="confirmNote">
            <IconCheck className="confirmNoteIco" />
            <span>
              Ao concluir, você confirma a compra de <b>{credits}</b> créditos no valor total de{" "}
              <b>{formatBRL(subtotal)}</b>.
            </span>
          </div>

          {/* ✅ Botões lado a lado */}
          <div className="checkoutBtns">
            <button type="button" className="cancelBtn" onClick={handleCancel}>
              Cancelar Compra
            </button>

            <button
              type="button"
              className="concludeBtn"
              disabled={!method || credits < 1 || isSubmitting}
              onClick={handleConclude}
            >
              {isSubmitting ? "Concluindo..." : "Concluir Compra"}
            </button>
          </div>
        </div>
      </section>
    </div>
  );
}
