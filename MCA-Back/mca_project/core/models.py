import uuid
from django.db import models

class TestCompany(models.Model):
    """
    Exemple de modèle ORM pour tester la connexion PostgreSQL.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=150, verbose_name="Nom de l'entreprise")
    registration_number = models.CharField(max_length=50, unique=True, verbose_name="Numéro SIREN / SIRET")
    email = models.EmailField(blank=True, null=True, verbose_name="Email de contact")
    is_active = models.BooleanField(default=True, verbose_name="Actif")
    created_at = models.DateTimeField(auto_now_add=True, verbose_name="Date de création")
    updated_at = models.DateTimeField(auto_now=True, verbose_name="Dernière modification")

    class Meta:
        db_table = 'test_companies'
        verbose_name = 'Entreprise Test'
        verbose_name_plural = 'Entreprises Test'

    def __str__(self):
        return f"{self.name} ({self.registration_number})"
