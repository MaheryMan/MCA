# 🧪 Guide de Test : Schéma de Base, Migrations & Authentification (Phase 1)

Ce document fournit un guide pas-à-pas pour tester les migrations PostgreSQL, les modèles `User`, `Role`, `Company`, `UserCompany`, `FiscalYear`, la commande de seed, et l'interface d'administration Django.

---

## 📋 1. Prérequis & Environnement

Assurez-vous que PostgreSQL est actif et que la base de données `mca_db` est accessible.

Dans le terminal PowerShell (dans `MCA-Back/mca_project`) :

```powershell
# 1. Vérifier la variable d'environnement ou le fichier .env
Get-Content .env

# 2. Activer l'environnement virtuel (si pas déjà fait)
..\env\Scripts\Activate.ps1
```

---

## 🗄️ 2. Tests des Migrations PostgreSQL

### A. Vérifier le statut des migrations

```powershell
python manage.py showmigrations
```

> **Résultat attendu :** Toutes les migrations de `accounts`, `companies`, `admin`, `auth`, etc. doivent être cochées `[X]`.

### B. Tester un rollback et ré-application (Rollback test)

Pour vérifier que les migrations sont parfaitement réversibles et non destructives :

```powershell
# 1. Rollback des apps
python manage.py migrate accounts zero
python manage.py migrate companies zero

# 2. Ré-appliquer toutes les migrations
python manage.py migrate
```

### C. Vérifier la structure des tables dans PostgreSQL

Vous pouvez inspecter directement les tables créées :

```powershell
python manage.py dbshell
```

Puis dans le prompt PostgreSQL (`mca_db=>`) :

```sql
-- Lister toutes les tables MCA
\dt

-- Vérifier la structure de la table users (UUID, email unique, timestamps)
\d users;

-- Vérifier la structure de la table companies
\d companies;

-- Vérifier la table pivot user_companies et ses contraintes de clés étrangères
\d user_companies;

-- Quitter dbshell
\q
```

---

## 👥 3. Test du Seed des Rôles

La commande personnalisée `seed_roles` initialise les rôles de base :

- `admin` (Administrateur)
- `comptable` (Comptable)
- `operateur_saisie` (Opérateur de saisie)

### Exécuter la commande :

```powershell
python manage.py seed_roles
```

> **Idempotence :** Exécutez-la une deuxième fois. Elle doit détecter que les rôles existent déjà sans lever d'erreur ni créer de doublons.

---

## 🤖 4. Exécution de la Suite de Tests Automatisés (Unit Tests)

Des tests unitaires sont configurés pour valider le modèle `User` (email unique, managers, création de superuser), `Role`, `Company`, la table pivot `UserCompany`, et `FiscalYear`.

```powershell
# Lancer tous les tests des apps
python manage.py test apps.accounts apps.companies
```

> **Résultat attendu :** `OK` (tous les tests passent avec succès).

---

## 💻 5. Test Interactif via le Shell Django

Vous pouvez tester manuellement les modèles et les relations :

```powershell
python manage.py shell
```

Dans le shell Python :

```python
from django.contrib.auth import get_user_model
from apps.accounts.models import Role
from apps.companies.models import Company, UserCompany, FiscalYear
from datetime import date

User = get_user_model()

# 1. Créer un utilisateur
user = User.objects.create_user(
    email="comptable@societe.mg",
    first_name="Hery",
    last_name="Rajaonarison",
    password="Password123!"
)
print("Utilisateur créé :", user, "| UUID :", user.id)

# 2. Créer une entreprise
company = Company.objects.create(
    name="Société Madagascar SARL",
    nif="NIF-987654321",
    currency="MGA",
    address="Antananarivo"
)
print("Entreprise créée :", company, "| UUID :", company.id)

# 3. Récupérer un rôle
role = Role.objects.get(name="comptable")

# 4. Associer l'utilisateur à l'entreprise
user_company = UserCompany.objects.create(
    user=user,
    company=company,
    role=role
)
print("Association créée :", user_company)

# 5. Créer un exercice comptable
fy = FiscalYear.objects.create(
    company=company,
    label="Exercice 2026",
    start_date=date(2026, 1, 1),
    end_date=date(2026, 12, 31)
)
print("Exercice créé :", fy)

exit()
```

---

## 🛡️ 6. Test de l'Admin Django

### A. Créer un Superutilisateur

```powershell
python manage.py createsuperuser
```

> Renseignez l'email (ex: `admin@mca.mg`), le prénom, le nom, et le mot de passe.

### B. Démarrer le serveur

```powershell
python manage.py runserver
```

### C. Vérifier dans le navigateur

Rendez-vous sur [http://127.0.0.1:8000/admin/](http://127.0.0.1:8000/admin/) et connectez-vous :

1. **Comptes utilisateurs** :
   - `Utilisateurs` : Création/Modification avec gestion des permissions.
   - `Rôles` : Visualisation des rôles (`admin`, `comptable`, `operateur_saisie`).
2. **Entreprises** :
   - `Entreprises` : Formulaire avec inlines pour ajouter des membres (`UserCompany`) et des exercices (`FiscalYear`).
   - `Membres entreprise` : Gestion des rôles par entreprise.
   - `Exercices comptables` : Gestion des périodes et statut clôturé.

---

## 📊 Résumé des Tables Créées

| Table              | Modèle Django            | Clé Primaire                   | Description                              |
| ------------------ | ------------------------- | ------------------------------- | ---------------------------------------- |
| `users`          | `accounts.User`         | UUID                            | Utilisateurs identifiés par email       |
| `roles`          | `accounts.Role`         | UUID                            | Rôles applicatifs                       |
| `companies`      | `companies.Company`     | UUID                            | Entreprises multi-tenant                 |
| `user_companies` | `companies.UserCompany` | Composite (user_id, company_id) | Relation N-N User <-> Entreprise + Rôle |
| `fiscal_years`   | `companies.FiscalYear`  | UUID                            | Exercices comptables par entreprise      |
