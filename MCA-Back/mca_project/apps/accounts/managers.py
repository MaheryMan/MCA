from django.contrib.auth.models import BaseUserManager


class UserManager(BaseUserManager):
    """
    Manager personnalisé pour le modèle User.
    Utilise l'email comme identifiant unique au lieu du username.
    """

    def create_user(self, email, first_name, last_name, password=None, **extra_fields):
        """Crée et retourne un utilisateur avec email, prénom, nom et mot de passe."""
        if not email:
            raise ValueError("L'adresse email est obligatoire.")
        if not first_name:
            raise ValueError("Le prénom est obligatoire.")
        if not last_name:
            raise ValueError("Le nom est obligatoire.")

        email = self.normalize_email(email)
        user = self.model(
            email=email,
            first_name=first_name,
            last_name=last_name,
            **extra_fields,
        )
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, email, first_name, last_name, password=None, **extra_fields):
        """Crée et retourne un superutilisateur."""
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('is_superuser', True)

        if extra_fields.get('is_staff') is not True:
            raise ValueError("Le superutilisateur doit avoir is_staff=True.")
        if extra_fields.get('is_superuser') is not True:
            raise ValueError("Le superutilisateur doit avoir is_superuser=True.")

        return self.create_user(email, first_name, last_name, password, **extra_fields)
