from django.test import TestCase
from .models import TestCompany

class TestCompanyORMTestCase(TestCase):
    """
    Classe de tests unitaires pour valider les opérations ORM (CRUD) avec PostgreSQL.
    """

    def setUp(self):
        # Création d'une instance pour les tests
        self.company = TestCompany.objects.create(
            name="Société Test SAS",
            registration_number="123456789",
            email="contact@societetest.fr",
            is_active=True
        )

    def test_create_and_read(self):
        """Test de création et de lecture (SELECT)"""
        company = TestCompany.objects.get(registration_number="123456789")
        self.assertEqual(company.name, "Société Test SAS")
        self.assertTrue(company.is_active)

    def test_filter_query(self):
        """Test de filtrage (WHERE)"""
        active_companies = TestCompany.objects.filter(is_active=True)
        self.assertEqual(active_companies.count(), 1)

    def test_update(self):
        """Test de mise à jour (UPDATE)"""
        self.company.name = "Société Test SAS - Modifiée"
        self.company.save()

        updated = TestCompany.objects.get(id=self.company.id)
        self.assertEqual(updated.name, "Société Test SAS - Modifiée")

    def test_delete(self):
        """Test de suppression (DELETE)"""
        self.company.delete()
        self.assertEqual(TestCompany.objects.count(), 0)
