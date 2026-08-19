from django.contrib.auth.models import AbstractBaseUser, PermissionsMixin
from django.db import models

from apps.core.models import BaseModel
from .managers import UserManager


class Role(BaseModel):
    """
    Rôle attribué à un utilisateur dans le contexte d'une entreprise.

    Exemples : admin, comptable, operateur_saisie
    """
    name = models.CharField(
        max_length=50,
        unique=True,
        verbose_name="Nom du rôle",
    )
    description = models.CharField(
        max_length=255,
        blank=True,
        default='',
        verbose_name="Description",
    )

    class Meta:
        db_table = 'roles'
        verbose_name = 'Rôle'
        verbose_name_plural = 'Rôles'
        ordering = ['name']

    def __str__(self):
        return self.name


class User(AbstractBaseUser, PermissionsMixin):
    """
    Modèle utilisateur personnalisé avec email comme identifiant.

    N'hérite pas de BaseModel car AbstractBaseUser a sa propre gestion d'id.
    On ajoute manuellement les champs UUID et timestamps.
    """
    import uuid
    id = models.UUIDField(
        primary_key=True,
        default=uuid.uuid4,
        editable=False,
        verbose_name="Identifiant",
    )
    email = models.EmailField(
        unique=True,
        verbose_name="Adresse email",
    )
    first_name = models.CharField(
        max_length=100,
        verbose_name="Prénom",
    )
    last_name = models.CharField(
        max_length=100,
        verbose_name="Nom",
    )
    is_active = models.BooleanField(
        default=True,
        verbose_name="Actif",
    )
    is_staff = models.BooleanField(
        default=False,
        verbose_name="Membre du staff",
    )
    created_at = models.DateTimeField(
        auto_now_add=True,
        verbose_name="Date de création",
    )
    updated_at = models.DateTimeField(
        auto_now=True,
        verbose_name="Dernière modification",
    )

    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = ['first_name', 'last_name']

    objects = UserManager()

    class Meta:
        db_table = 'users'
        verbose_name = 'Utilisateur'
        verbose_name_plural = 'Utilisateurs'
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.first_name} {self.last_name} ({self.email})"

    @property
    def full_name(self):
        """Retourne le nom complet de l'utilisateur."""
        return f"{self.first_name} {self.last_name}"
