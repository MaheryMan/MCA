from django.contrib import admin
from .models import TestCompany

@admin.register(TestCompany)
class TestCompanyAdmin(admin.ModelAdmin):
    list_display = ('name', 'registration_number', 'email', 'is_active', 'created_at')
    search_fields = ('name', 'registration_number')
    list_filter = ('is_active',)
