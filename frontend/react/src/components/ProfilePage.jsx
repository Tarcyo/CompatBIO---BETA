import React, { useEffect, useMemo, useState } from "react";
import "./Pages.css";

function IconEdit(props) {
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true" {...props}>
      <path
        fill="currentColor"
        d="M3 17.25V21h3.75L17.8 9.95l-3.75-3.75L3 17.25Zm2.92 2.83H5v-.92l8.77-8.77.92.92-8.77 8.77ZM20.71 7.04a1 1 0 0 0 0-1.41L18.37 3.29a1 1 0 0 0-1.41 0l-1.83 1.83 3.75 3.75 1.83-1.83Z"
      />
    </svg>
  );
}

function IconSave(props) {
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true" {...props}>
      <path
        fill="currentColor"
        d="M17 3H5a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V7l-4-4Zm-5 16a3 3 0 1 1 0-6 3 3 0 0 1 0 6ZM6 8V5h9v3H6Z"
      />
    </svg>
  );
}

function IconClose(props) {
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true" {...props}>
      <path
        fill="currentColor"
        d="M18.3 5.71 12 12l6.3 6.29-1.41 1.42L10.59 13.4 4.29 19.71 2.88 18.29 9.17 12 2.88 5.71 4.29 4.29l6.3 6.3 6.29-6.3 1.42 1.42Z"
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

function IconPin(props) {
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true" {...props}>
      <path
        fill="currentColor"
        d="M12 2a7 7 0 0 0-7 7c0 5.2 7 13 7 13s7-7.8 7-13a7 7 0 0 0-7-7Zm0 9.5A2.5 2.5 0 1 1 12 6a2.5 2.5 0 0 1 0 5.5Z"
      />
    </svg>
  );
}

function IconHome(props) {
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true" {...props}>
      <path
        fill="currentColor"
        d="M4 21V7a2 2 0 0 1 2-2h3V3h6v2h3a2 2 0 0 1 2 2v14h-7v-6H11v6H4Zm4-10h2V9H8v2Zm0 4h2v-2H8v2Zm6-4h2V9h-2v2Zm0 4h2v-2h-2v2Z"
      />
    </svg>
  );
}

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

export default function ProfilePage() {
  const STORAGE_KEY = "compatbio_profile";

  const defaultProfile = useMemo(
    () => ({
      name: "Carlos Souza",
      email: "carlos.souza@email.com",
      address: "Rua das Palmeiras, 123, São Paulo, SP",
      company: "AgroTech Solutions",
      avatarUrl: "https://i.pravatar.cc/220?img=12",
    }),
    []
  );

  const [profile, setProfile] = useState(defaultProfile);
  const [draft, setDraft] = useState(defaultProfile);
  const [isEditing, setIsEditing] = useState(false);

  useEffect(() => {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (!raw) return;
      const parsed = JSON.parse(raw);
      const next = { ...defaultProfile, ...parsed };
      setProfile(next);
      setDraft(next);
    } catch {
      // ignore
    }
  }, [defaultProfile]);

  const startEdit = () => {
    setDraft(profile);
    setIsEditing(true);
  };

  const cancelEdit = () => {
    setDraft(profile);
    setIsEditing(false);
  };

  const saveEdit = () => {
    const trimmed = {
      ...draft,
      name: draft.name.trim(),
      email: draft.email.trim(),
      address: draft.address.trim(),
      company: draft.company.trim(),
    };

    setProfile(trimmed);
    setDraft(trimmed);
    setIsEditing(false);

    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(trimmed));
    } catch {
      // ignore
    }
  };

  const onDraft = (key) => (e) => setDraft((p) => ({ ...p, [key]: e.target.value }));

  return (
    <section className="pg-card profileCard">
      <div className="profileTop">
        <img className="profileAvatar" src={profile.avatarUrl} alt="Foto do perfil" />

        <div className="profileInfo">
          <div className="profileTitleRow">
            {!isEditing ? (
              <h2 className="profileName">{profile.name}</h2>
            ) : (
              <input
                className="profileInput profileInputName"
                value={draft.name}
                onChange={onDraft("name")}
                placeholder="Nome"
              />
            )}

            <div className="profileActions">
              {!isEditing ? (
                <button type="button" className="profileActionBtn" onClick={startEdit}>
                  <IconEdit className="profileActionIco" />
                  Editar perfil
                </button>
              ) : (
                <>
                  <button type="button" className="profileActionBtn is-primary" onClick={saveEdit}>
                    <IconSave className="profileActionIco" />
                    Salvar
                  </button>
                  <button type="button" className="profileActionBtn is-ghost" onClick={cancelEdit}>
                    <IconClose className="profileActionIco" />
                    Cancelar
                  </button>
                </>
              )}
            </div>
          </div>

          <div className="profileMeta">
            <div className="profileRow">
              <span className="profileIco" aria-hidden="true">
                <IconMail />
              </span>

              {!isEditing ? (
                <span className="profileText">{profile.email}</span>
              ) : (
                <input
                  className="profileInput"
                  type="email"
                  value={draft.email}
                  onChange={onDraft("email")}
                  placeholder="Email"
                />
              )}
            </div>

            <div className="profileRow">
              <span className="profileIco" aria-hidden="true">
                <IconPin />
              </span>

              {!isEditing ? (
                <span className="profileText">{profile.address}</span>
              ) : (
                <input
                  className="profileInput"
                  value={draft.address}
                  onChange={onDraft("address")}
                  placeholder="Endereço"
                />
              )}
            </div>

            <div className="profileRow">
              <span className="profileIco" aria-hidden="true">
                <IconHome />
              </span>

              {!isEditing ? (
                <span className="profileText">{profile.company}</span>
              ) : (
                <input
                  className="profileInput"
                  value={draft.company}
                  onChange={onDraft("company")}
                  placeholder="Empresa"
                />
              )}
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
              <IconUser />
            </span>
            <span className="profileUserName">{profile.name}</span>
            <span className="profileBadge is-you">você</span>
          </li>

          <li className="profileUser">
            <span className="profileUserIco" aria-hidden="true">
              <IconUser />
            </span>
            <span className="profileUserName">Mariana Lima</span>
            <span className="profileBadge is-admin">admin</span>
          </li>

          <li className="profileUser">
            <span className="profileUserIco" aria-hidden="true">
              <IconUser />
            </span>
            <span className="profileUserName">Lucas Pereira</span>
          </li>

          <li className="profileUser">
            <span className="profileUserIco" aria-hidden="true">
              <IconUser />
            </span>
            <span className="profileUserName">Fernanda Gomes</span>
          </li>
        </ul>
      </div>
    </section>
  );
}
