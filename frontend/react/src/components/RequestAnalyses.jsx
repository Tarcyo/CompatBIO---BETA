import React from "react";
import "./Pages.css";

export default function RequestAnalysisPage() {
  return (
     <section className="pg-card profileCard">
      <div className="profileTop">
        <img
          className="profileAvatar"
          src="https://i.pravatar.cc/140?img=12"
          alt="Foto do perfil"
        />

        <div className="profileInfo">
          <h2 className="profileName">Carlos Souza</h2>

          <div className="profileMeta">
            <div className="profileRow">
              <span className="profileIco" aria-hidden="true">
                <svg viewBox="0 0 24 24">
                  <path
                    fill="currentColor"
                    d="M20 4H4a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V6a2 2 0 0 0-2-2Zm0 4-8 5L4 8V6l8 5 8-5v2Z"
                  />
                </svg>
              </span>
              <span className="profileText">carlos.souza@email.com</span>
            </div>

            <div className="profileRow">
              <span className="profileIco" aria-hidden="true">
                <svg viewBox="0 0 24 24">
                  <path
                    fill="currentColor"
                    d="M12 2a7 7 0 0 0-7 7c0 5.2 7 13 7 13s7-7.8 7-13a7 7 0 0 0-7-7Zm0 9.5A2.5 2.5 0 1 1 12 6a2.5 2.5 0 0 1 0 5.5Z"
                  />
                </svg>
              </span>
              <span className="profileText">Rua das Palmeiras, 123, São Paulo, SP</span>
            </div>

            <div className="profileRow">
              <span className="profileIco" aria-hidden="true">
                <svg viewBox="0 0 24 24">
                  <path
                    fill="currentColor"
                    d="M4 21V7a2 2 0 0 1 2-2h3V3h6v2h3a2 2 0 0 1 2 2v14h-7v-6H11v6H4Zm4-10h2V9H8v2Zm0 4h2v-2H8v2Zm6-4h2V9h-2v2Zm0 4h2v-2h-2v2Z"
                  />
                </svg>
              </span>
              <span className="profileText">AgroTech Solutions</span>
            </div>
          </div>
        </div>
      </div>

      <div className="profileDivider" />

      <div className="profileSection">
        <h3 className="profileSectionTitle">Sua Assinatura Atual</h3>
        <button type="button" className="profilePlanBtn">
          Plano Premium
        </button>
      </div>

      <div className="profileUsers">
        <p className="profileUsersTitle">Usuários na Assinatura:</p>

        <ul className="profileUsersList">
          <li className="profileUser">
            <span className="profileUserIco" aria-hidden="true">
              <svg viewBox="0 0 24 24">
                <path
                  fill="currentColor"
                  d="M12 12a4.6 4.6 0 1 0-4.6-4.6A4.6 4.6 0 0 0 12 12Zm0 2.3c-4.2 0-7.7 2.2-7.7 4.9V21h15.4v-1.8c0-2.7-3.5-4.9-7.7-4.9Z"
                />
              </svg>
            </span>
            <span className="profileUserName">Carlos Souza</span>
            <span className="profileBadge is-you">você</span>
          </li>

          <li className="profileUser">
            <span className="profileUserIco" aria-hidden="true">
              <svg viewBox="0 0 24 24">
                <path
                  fill="currentColor"
                  d="M12 12a4.6 4.6 0 1 0-4.6-4.6A4.6 4.6 0 0 0 12 12Zm0 2.3c-4.2 0-7.7 2.2-7.7 4.9V21h15.4v-1.8c0-2.7-3.5-4.9-7.7-4.9Z"
                />
              </svg>
            </span>
            <span className="profileUserName">Mariana Lima</span>
            <span className="profileBadge is-admin">admin</span>
          </li>

          <li className="profileUser">
            <span className="profileUserIco" aria-hidden="true">
              <svg viewBox="0 0 24 24">
                <path
                  fill="currentColor"
                  d="M12 12a4.6 4.6 0 1 0-4.6-4.6A4.6 4.6 0 0 0 12 12Zm0 2.3c-4.2 0-7.7 2.2-7.7 4.9V21h15.4v-1.8c0-2.7-3.5-4.9-7.7-4.9Z"
                />
              </svg>
            </span>
            <span className="profileUserName">Lucas Pereira</span>
          </li>

          <li className="profileUser">
            <span className="profileUserIco" aria-hidden="true">
              <svg viewBox="0 0 24 24">
                <path
                  fill="currentColor"
                  d="M12 12a4.6 4.6 0 1 0-4.6-4.6A4.6 4.6 0 0 0 12 12Zm0 2.3c-4.2 0-7.7 2.2-7.7 4.9V21h15.4v-1.8c0-2.7-3.5-4.9-7.7-4.9Z"
                />
              </svg>
            </span>
            <span className="profileUserName">Fernanda Gomes</span>
          </li>
        </ul>
      </div>
    </section>
  );
}
