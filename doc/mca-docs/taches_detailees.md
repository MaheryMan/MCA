# 📋 MCA — Module Pré-Comptabilité — Tâches Détaillées (v1)

> Répartition équilibrée entre **Princi** et **Mahery**, sans estimation de durée.
> Basé sur `decoupage_taches.md` et `schema_base_de_donnees.md`, simplifié pour le démarrage du projet.

---

## Phase 0 — Cadrage & Architecture

| Phase | Tâche | Description | Responsable |
|---|---|---|---|
| Cadrage & Architecture | Analyse et conception du projet | Définir le périmètre fonctionnel du MVP et les choix techniques (stack, hébergement). | Princi |
| Cadrage & Architecture | Apprentissage nouvelle technologie | Monter en compétence sur les briques techniques retenues (OCR, framework, etc.). | Mahery |
| Cadrage & Architecture | Installation des environnements | Mettre en place les environnements de dev, base de données et outils de versioning. | Princi |

---

## Phase 1 — Authentification & Multi-entreprise

| Phase | Tâche | Description | Responsable |
|---|---|---|---|
| Authentification | Schéma de base (users, roles, companies) | Créer et migrer les tables `users`, `roles`, `companies`, `user_companies`. | Princi |
| Authentification | API inscription / connexion | Endpoints register, login, logout, gestion des tokens. | Princi |
| Authentification | Gestion des rôles et permissions | Middleware qui limite l'accès aux endpoints selon le rôle de l'utilisateur. | Mahery |
| Authentification | Sélection d'entreprise active | Permettre à un utilisateur multi-entreprise de choisir son contexte de travail. | Mahery |
| Authentification | Page login / register UI | Interface de connexion et d'inscription simple et responsive. | Mahery |
| Authentification | Seed du plan comptable par défaut | Injecter un plan comptable de base à la création d'une entreprise. | Princi |

---

## Phase 2 — Import & Stockage des Documents

| Phase | Tâche | Description | Responsable |
|---|---|---|---|
| Import | API upload multiple | Endpoint d'upload multi-fichiers avec validation du format (jpg, png, pdf). | Mahery |
| Import | Stockage des fichiers | Organisation des fichiers par entreprise, sur disque ou stockage cloud. | Mahery |
| Import | Gestion des lots (batches) | Création automatique d'un lot d'import avec suivi de progression. | Princi |
| Import | Calcul du hash SHA-256 | Calculer un hash unique par fichier pour préparer la détection de doublons. | Princi |
| Import | UI Drag & Drop | Zone de dépôt de fichiers avec barre de progression et miniatures. | Mahery |

---

## Phase 3 — Détection des Doublons

| Phase | Tâche | Description | Responsable |
|---|---|---|---|
| Doublons | Détection par hash exact | Comparer les hash pour repérer les fichiers strictement identiques. | Princi |
| Doublons | Détection par n° facture / montant+date | Repérer les doublons probables après OCR (même fournisseur, montant, date). | Princi |
| Doublons | Groupes de doublons | Créer et gérer les tables `duplicate_groups` / `duplicate_group_items`. | Mahery |
| Doublons | UI de résolution des doublons | Interface de comparaison côte à côte avec actions garder/supprimer. | Mahery |

---

## Phase 4 — OCR & Classification

| Phase | Tâche | Description | Responsable |
|---|---|---|---|
| OCR | Intégration du moteur OCR | Connecter un service OCR pour extraire le texte brut des documents. | Mahery |
| OCR | Extraction des champs structurés | Identifier fournisseur, montant, date, n° facture à partir du texte OCR. | Mahery |
| OCR | Classification du type de document | Détecter automatiquement facture / avoir / reçu. | Princi |
| OCR | Stockage des résultats OCR | Sauvegarder les résultats dans `ocr_results` avec score de confiance. | Princi |

---

## Phase 5 — Scoring des Documents

| Phase | Tâche | Description | Responsable |
|---|---|---|---|
| Scoring | Règles de calcul du score | Définir les critères de qualité (champs présents, confiance OCR, doublons). | Princi |
| Scoring | Application du score au document | Calculer et stocker `processing_score` sur chaque document. | Mahery |
| Scoring | Liste des documents à traiter | Vue filtrée des documents à faible score, à traiter en priorité. | Mahery |

---

## Phase 6 — Référentiel Comptable

| Phase | Tâche | Description | Responsable |
|---|---|---|---|
| Référentiel | Plan comptable | CRUD du plan comptable (`chart_of_accounts`) par entreprise. | Princi |
| Référentiel | Journaux comptables | CRUD des journaux (achats, ventes, banque, caisse, OD). | Princi |
| Référentiel | Taux de TVA | CRUD des taux de TVA applicables par entreprise. | Mahery |

---

## Phase 7 — Fournisseurs

| Phase | Tâche | Description | Responsable |
|---|---|---|---|
| Fournisseurs | CRUD fournisseurs | Création, lecture, modification, suppression des fournisseurs. | Mahery |
| Fournisseurs | Fiche fournisseur | Informations générales, compte comptable et journal par défaut. | Mahery |
| Fournisseurs | Création rapide depuis la saisie | Ajouter un nouveau fournisseur directement depuis le formulaire de facture. | Princi |
| Fournisseurs | Suggestion automatique (matching) | Proposer un fournisseur existant à partir du nom détecté par l'OCR. | Princi |

---

## Phase 8 — Page de Saisie & Validation des Factures

| Phase | Tâche | Description | Responsable |
|---|---|---|---|
| Saisie | Écran liste des factures | Liste des factures avec filtres (statut, fournisseur, recherche). | Mahery |
| Saisie | Fiche détaillée d'une facture | Affichage complet d'une facture avec ses lignes et son document source. | Mahery |
| Saisie | Formulaire de correction | Permettre à l'utilisateur de corriger les champs extraits par l'OCR. | Princi |
| Saisie | Actions Valider / Rejeter | Boutons de validation avec saisie obligatoire d'un motif en cas de refus. | Princi |
| Saisie | Historique des actions | Traçabilité des actions effectuées sur chaque facture (qui, quand, quoi). | Mahery |

---

## Phase 9 — Écritures Comptables

| Phase | Tâche | Description | Responsable |
|---|---|---|---|
| Comptabilité | Règles de génération d'écriture | Définir le mapping facture → écriture (comptes débit/crédit selon le type). | Princi |
| Comptabilité | Génération automatique | Créer `journal_entries` + `journal_entry_lines` depuis une facture validée. | Princi |
| Comptabilité | Numérotation séquentielle | Numéro d'écriture unique et continu par journal et exercice. | Mahery |
| Comptabilité | Contrôle de l'équilibre | Vérifier que débit = crédit avant de comptabiliser. | Mahery |
| Comptabilité | Contre-passation | Génération d'une écriture inverse pour annuler une écriture postée. | Princi |
| Comptabilité | Grand livre & balance | Vues consultables par compte avec soldes. | Mahery |

---

## Phase 10 — Workflow de Validation

| Phase | Tâche | Description | Responsable |
|---|---|---|---|
| Workflow | Statuts de facture | Mettre en place les transitions draft → to_review → validated → accounted / rejected. | Mahery |
| Workflow | Règles par rôle | Restreindre les actions de validation selon le rôle de l'utilisateur. | Princi |
| Workflow | Notifications internes | Alerter les valideurs dès qu'une facture est en attente. | Princi |

---

## Phase 11 — Dashboard & Reporting

| Phase | Tâche | Description | Responsable |
|---|---|---|---|
| Dashboard | KPIs principaux | Nombre de factures à traiter, validées, en erreur, comptabilisées. | Mahery |
| Dashboard | Graphique de scoring | Distribution des scores de traitement des documents. | Mahery |
| Dashboard | Filtres du dashboard | Filtrage par période, fournisseur et statut. | Princi |

---

## Phase 12 — Export FEC & Archivage

| Phase | Tâche | Description | Responsable |
|---|---|---|---|
| Export | Export FEC | Génération du fichier des écritures comptables au format attendu. | Princi |
| Export | Export Excel / PDF | Export du grand livre et de la balance en Excel et PDF. | Mahery |
| Export | Clôture d'exercice | Verrouillage des écritures d'un exercice comptable clôturé. | Princi |

---

## 🎯 Répartition globale

| Responsable | Domaines principaux |
|---|---|
| **Princi** | Auth & rôles, doublons (détection), plan comptable/journaux, écritures comptables, export FEC, clôture |
| **Mahery** | Import & stockage, OCR, scoring, fournisseurs (fiche), saisie (liste/historique), dashboard, workflow (statuts) |

> Répartition volontairement équilibrée en nombre de tâches et en niveau de responsabilité (chacun a des tâches de conception ET d'exécution dans chaque grand bloc fonctionnel).
