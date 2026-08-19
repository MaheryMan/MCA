from django.contrib import admin

from .models import Company, UserCompany, FiscalYear


class UserCompanyInline(admin.TabularInline):
    """Affiche les membres d'une entreprise directement dans la fiche entreprise."""
    model = UserCompany
    extra = 1
    autocomplete_fields = ['user', 'role']


class FiscalYearInline(admin.TabularInline):
    """Affiche les exercices comptables directement dans la fiche entreprise."""
    model = FiscalYear
    extra = 0
    fields = ('label', 'start_date', 'end_date', 'is_closed')


@admin.register(Company)
class CompanyAdmin(admin.ModelAdmin):
    """Administration du modèle Company."""
    list_display = ('name', 'nif', 'currency', 'created_at')
    search_fields = ('name', 'nif')
    list_filter = ('currency',)
    inlines = [UserCompanyInline, FiscalYearInline]


@admin.register(UserCompany)
class UserCompanyAdmin(admin.ModelAdmin):
    """Administration de la relation User-Company."""
    list_display = ('user', 'company', 'role')
    list_filter = ('role', 'company')
    search_fields = ('user__email', 'user__first_name', 'user__last_name', 'company__name')
    autocomplete_fields = ['user', 'company', 'role']


@admin.register(FiscalYear)
class FiscalYearAdmin(admin.ModelAdmin):
    """Administration du modèle FiscalYear."""
    list_display = ('label', 'company', 'start_date', 'end_date', 'is_closed')
    list_filter = ('is_closed', 'company')
    search_fields = ('label', 'company__name')
