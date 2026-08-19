import uuid

from django.db import models
from django.utils import timezone


class BaseModel(models.Model):
    """
    Modèle de base abstrait pour tous les modèles du projet MCA.

    Fournit :
    - id : UUID auto-généré comme clé primaire
    - created_at : horodatage de création
    - updated_at : horodatage de dernière modification
    - deleted_at : horodatage de suppression logique (soft delete)
    """
    id = models.UUIDField(
        primary_key=True,
        default=uuid.uuid4,
        editable=False,
        verbose_name="Identifiant",
    )
    created_at = models.DateTimeField(
        auto_now_add=True,
        verbose_name="Date de création",
    )
    updated_at = models.DateTimeField(
        auto_now=True,
        verbose_name="Dernière modification",
    )
    deleted_at = models.DateTimeField(
        null=True,
        blank=True,
        verbose_name="Date de suppression",
    )

    class Meta:
        abstract = True
        ordering = ['-created_at']

    def soft_delete(self):
        """Marquer l'objet comme supprimé sans le retirer de la base."""
        self.deleted_at = timezone.now()
        self.save(update_fields=['deleted_at'])

    def restore(self):
        """Restaurer un objet supprimé logiquement."""
        self.deleted_at = None
        self.save(update_fields=['deleted_at'])

    @property
    def is_deleted(self):
        """Vérifie si l'objet est supprimé logiquement."""
        return self.deleted_at is not None


class SoftDeleteManager(models.Manager):
    """Manager qui exclut automatiquement les objets soft-deleted."""

    def get_queryset(self):
        return super().get_queryset().filter(deleted_at__isnull=True)


class SoftDeleteModel(BaseModel):
    """
    Modèle de base avec soft delete activé par défaut.
    Utilise SoftDeleteManager comme manager par défaut.
    """
    objects = SoftDeleteManager()
    all_objects = models.Manager()  # Inclut les objets supprimés

    class Meta(BaseModel.Meta):
        abstract = True
