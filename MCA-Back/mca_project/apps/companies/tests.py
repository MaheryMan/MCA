from django.test import TestCase
from django.contrib.auth import get_user_model
from django.utils import timezone
from datetime import timedelta, date
from django.db import IntegrityError

from apps.accounts.models import Role
from apps.companies.models import Company, UserCompany, FiscalYear

User = get_user_model()


class CompaniesModelTest(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            email="manager@company.com",
            first_name="Rivo",
            last_name="Rakoto",
            password="pwd"
        )
        self.role_admin = Role.objects.create(name="admin", description="Admin role")
        self.company = Company.objects.create(
            name="Société Test S.A.",
            nif="1234567890",
            address="Antananarivo, Madagascar",
            currency="MGA"
        )

    def test_company_creation(self):
        self.assertEqual(self.company.name, "Société Test S.A.")
        self.assertEqual(self.company.currency, "MGA")
        self.assertEqual(str(self.company), "Société Test S.A.")

    def test_user_company_association(self):
        uc = UserCompany.objects.create(
            user=self.user,
            company=self.company,
            role=self.role_admin
        )
        self.assertEqual(self.user.user_companies.count(), 1)
        self.assertEqual(self.company.company_users.count(), 1)
        self.assertEqual(uc.role.name, "admin")

        # Test unique constraint (user, company)
        with self.assertRaises(IntegrityError):
            UserCompany.objects.create(
                user=self.user,
                company=self.company,
                role=self.role_admin
            )

    def test_fiscal_year_creation(self):
        fy = FiscalYear.objects.create(
            company=self.company,
            label="Exercice 2026",
            start_date=date(2026, 1, 1),
            end_date=date(2026, 12, 31),
            is_closed=False
        )
        self.assertEqual(self.company.fiscal_years.count(), 1)
        self.assertFalse(fy.is_closed)
        self.assertEqual(str(fy), f"Exercice 2026 — {self.company.name}")
