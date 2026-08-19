# 📮 Guide Complet de Test Postman — Authentification MCA (Phase 1)

Ce guide vous explique pas à pas comment tester tous les endpoints d'authentification de l'API MCA avec **Postman**.

---

## 📥 Étape 1 : Importer la Collection dans Postman

1. Ouvrez l'application **Postman**.
2. Cliquez sur le bouton **Import** (en haut à gauche).
3. Choisissez l'option **Files** et sélectionnez le fichier :
   ```
   D:\mahasoa\ASA\MCA\doc\mca-docs\mca_auth_postman_collection.json
   ```
4. Cliquez sur **Import**.
5. Vous verrez apparaître une collection nommée **`MCA — Module Pré-Comptabilité (Auth & Comptes)`**.

> [!TIP]
> **Magie des variables automatiques :** La collection est équipée de scripts de test qui extraient automatiquement les tokens JWT (`accessToken` et `refreshToken`) à chaque fois que vous faites `Register` ou `Login` ! Vous n'avez jamais besoin de copier-coller les tokens manuellement.

---

## 🚀 Étape 2 : Démarrer le Serveur Django

Assurez-vous que le serveur Django tourne en local. Dans votre terminal PowerShell (dans `D:\mahasoa\ASA\MCA\MCA-Back\mca_project`) :

```powershell
python manage.py runserver
```
Le serveur doit écouter sur `http://127.0.0.1:8000/`.

---

## 🧪 Étape 3 : Tester les Endpoints dans l'Ordre Recommandé

### 1️⃣ Requête `1. Inscription (Register)`
- **Méthode / URL :** `POST http://127.0.0.1:8000/api/v1/accounts/register/`
- **Body JSON :**
  ```json
  {
      "email": "comptable@mca.mg",
      "first_name": "Hery",
      "last_name": "Rajaonarison",
      "password": "SecuredPassword2026!",
      "password_confirm": "SecuredPassword2026!"
  }
  ```
- **Code HTTP attendu :** `201 Created`
- **Réponse attendue :**
  ```json
  {
      "message": "Compte créé avec succès.",
      "user": {
          "id": "c1a2...",
          "email": "comptable@mca.mg",
          "first_name": "Hery",
          "last_name": "Rajaonarison",
          "full_name": "Hery Rajaonarison",
          "is_active": true,
          "is_staff": false,
          "companies": []
      },
      "tokens": {
          "access": "eyJhbGciOi...",
          "refresh": "eyJhbGciOi..."
      }
  }
  ```
- **Action automatique :** Postman a sauvegardé le `accessToken` et le `refreshToken` dans les variables de la collection !

---

### 2️⃣ Requête `2. Connexion (Login)`
- **Méthode / URL :** `POST http://127.0.0.1:8000/api/v1/accounts/login/`
- **Body JSON :**
  ```json
  {
      "email": "comptable@mca.mg",
      "password": "SecuredPassword2026!"
  }
  ```
- **Code HTTP attendu :** `200 OK`
- **Réponse attendue :**
  ```json
  {
      "refresh": "eyJhbGciOi...",
      "access": "eyJhbGciOi...",
      "user": {
          "id": "c1a2...",
          "email": "comptable@mca.mg",
          "first_name": "Hery",
          "last_name": "Rajaonarison",
          "full_name": "Hery Rajaonarison",
          "companies": []
      }
  }
  ```

---

### 3️⃣ Requête `3. Mon Profil (Get Me)`
- **Méthode / URL :** `GET http://127.0.0.1:8000/api/v1/accounts/me/`
- **Authorization :** Bearer Token `{{accessToken}}` (déjà configuré automatiquement)
- **Code HTTP attendu :** `200 OK`
- **Réponse attendue :** Retourne le profil complet de l'utilisateur connecté avec ses entreprises affiliées et ses rôles.

---

### 4️⃣ Requête `4. Modifier Profil (Update Me)`
- **Méthode / URL :** `PATCH http://127.0.0.1:8000/api/v1/accounts/me/`
- **Authorization :** Bearer Token `{{accessToken}}`
- **Body JSON :**
  ```json
  {
      "first_name": "Hery Nomena",
      "last_name": "Rajaonarison"
  }
  ```
- **Code HTTP attendu :** `200 OK`
- **Réponse attendue :** Le profil mis à jour avec le nouveau prénom/nom.

---

### 5️⃣ Requête `5. Rafraîchir Token (Refresh)`
- **Méthode / URL :** `POST http://127.0.0.1:8000/api/v1/accounts/token/refresh/`
- **Body JSON :**
  ```json
  {
      "refresh": "{{refreshToken}}"
  }
  ```
- **Code HTTP attendu :** `200 OK`
- **Réponse attendue :** Un nouvel `access` token valide (et mis à jour dans Postman).

---

### 6️⃣ Requête `6. Changer Mot de Passe (Change Password)`
- **Méthode / URL :** `POST http://127.0.0.1:8000/api/v1/accounts/change-password/`
- **Authorization :** Bearer Token `{{accessToken}}`
- **Body JSON :**
  ```json
  {
      "old_password": "SecuredPassword2026!",
      "new_password": "BrandNewPassword2026!",
      "new_password_confirm": "BrandNewPassword2026!"
  }
  ```
- **Code HTTP attendu :** `200 OK`
- **Réponse attendue :**
  ```json
  {
      "message": "Mot de passe mis à jour avec succès."
  }
  ```

---

### 7️⃣ Requête `7. Déconnexion (Logout)`
- **Méthode / URL :** `POST http://127.0.0.1:8000/api/v1/accounts/logout/`
- **Authorization :** Bearer Token `{{accessToken}}`
- **Body JSON :**
  ```json
  {
      "refresh": "{{refreshToken}}"
  }
  ```
- **Code HTTP attendu :** `200 OK`
- **Réponse attendue :**
  ```json
  {
      "message": "Déconnexion réussie. Le token a été révoqué."
  }
  ```
- **Vérification de sécurité :** Si vous tentez de réutiliser ce `refreshToken` dans la requête n°5, vous recevrez une erreur `401 Unauthorized` car il est définitivement blacklisté en base de données.

---

## 🛠️ Dépannage rapide

| Problème | Cause possible | Solution |
|---|---|---|
| `Could not get response` | Django n'est pas lancé | Exécutez `python manage.py runserver` |
| `401 Unauthorized` sur `/me/` | Token expiré ou absent | Ré-exécutez la requête `2. Connexion (Login)` |
| `400 Bad Request` sur Register | Email déjà utilisé | Modifiez l'email dans le JSON de register |
