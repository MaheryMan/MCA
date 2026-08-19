from django.conf import settings
from django.db import models

from apps.core.models import BaseModel
from apps.accounts.models import Role


class Company(BaseModel):
    """
    Entreprise gérée dans le système MCA.

    Chaque entreprise a son propre référentiel comptable,
    ses fournisseurs, ses documents et ses écritures.
    """
    name = models.CharField(
        max_length=255,
        verbose_name="Nom de l'entreprise",
    )
    nif = models.CharField(
        max_length=50,
        blank=True,
        null=True,
        verbose_name="NIF / STAT",
        help_text="Numéro d'Identification Fiscale",
    )
    address = models.TextField(
        blank=True,
        null=True,
        verbose_name="Adresse",
    )
    currency = models.CharField(
        max_length=3,
        default='MGA',
        verbose_name="Devise",
        help_text="Code ISO 4217 de la devise (ex: MGA, EUR, USD)",
    )

    class Meta:
        db_table = 'companies'
        verbose_name = 'Entreprise'
        verbose_name_plural = 'Entreprises'
        ordering = ['name']

    def __str__(self):
        return self.name


class UserCompany(models.Model):
    """
    Table pivot : un utilisateur peut appartenir à plusieurs entreprises,
    avec un rôle spécifique dans chaque entreprise.
    """
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='user_companies',
        verbose_name="Utilisateur",
    )
    company = models.ForeignKey(
        Company,
        on_delete=models.CASCADE,
        related_name='company_users',
        verbose_name="Entreprise",
    )
    role = models.ForeignKey(
        Role,
        on_delete=models.PROTECT,
        related_name='user_companies',
        verbose_name="Rôle",
    )

    class Meta:
        db_table = 'user_companies'
        verbose_name = 'Membre entreprise'
        verbose_name_plural = 'Membres entreprise'
        unique_together = ('user', 'company')

    def __str__(self):
        return f"{self.user.email} — {self.company.name} ({self.role.name})"


class FiscalYear(BaseModel):
    """
    Exercice comptable d'une entreprise.

    Permet de regrouper les écritures comptables par période
    et de gérer la clôture d'exercice.
    """
    company = models.ForeignKey(
        Company,
        on_delete=models.CASCADE,
        related_name='fiscal_years',
        verbose_name="Entreprise",
    )
    label = models.CharField(
        max_length=50,
        verbose_name="Libellé",
        help_text="Ex: Exercice 2026",
    )
    start_date = models.DateField(
        verbose_name="Date de début",
    )
    end_date = models.DateField(
        verbose_name="Date de fin",
    )
    is_closed = models.BooleanField(
        default=False,
        verbose_name="Clôturé",
    )

    class Meta:
        db_table = 'fiscal_years'
        verbose_name = 'Exercice comptable'
        verbose_name_plural = 'Exercices comptables'
        ordering = ['-start_date']

    def __str__(self):
        return f"{self.label} — {self.company.name}"
