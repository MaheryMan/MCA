"""
URL configuration for mca_project project.

Routage racine : toutes les APIs sous /api/v1/
"""
from django.contrib import admin
from django.urls import path, include

urlpatterns = [
    path('admin/', admin.site.urls),

    # API v1
    path('api/v1/accounts/', include('apps.accounts.urls')),
    path('api/v1/companies/', include('apps.companies.urls')),
]
