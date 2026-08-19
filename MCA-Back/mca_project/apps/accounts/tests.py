from django.test import TestCase
from django.urls import reverse
from django.contrib.auth import get_user_model
from rest_framework import status
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken

from apps.accounts.models import Role

User = get_user_model()


class AuthAPITestCase(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.register_url = reverse('accounts:register')
        self.login_url = reverse('accounts:login')
        self.refresh_url = reverse('accounts:token_refresh')
        self.logout_url = reverse('accounts:logout')
        self.profile_url = reverse('accounts:user_profile')
        self.change_password_url = reverse('accounts:change_password')

        # Utilisateur de test
        self.user = User.objects.create_user(
            email="testauth@example.com",
            first_name="Jean",
            last_name="Rakoto",
            password="SecurePassword123!"
        )

    def test_register_success(self):
        payload = {
            "email": "newuser@example.com",
            "first_name": "Soa",
            "last_name": "Rabe",
            "password": "StrongPassword2026!",
            "password_confirm": "StrongPassword2026!"
        }
        response = self.client.post(self.register_url, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertIn('tokens', response.data)
        self.assertIn('access', response.data['tokens'])
        self.assertIn('refresh', response.data['tokens'])
        self.assertEqual(response.data['user']['email'], "newuser@example.com")
        self.assertTrue(User.objects.filter(email="newuser@example.com").exists())

    def test_register_password_mismatch(self):
        payload = {
            "email": "mismatch@example.com",
            "first_name": "Test",
            "last_name": "User",
            "password": "Password123!",
            "password_confirm": "DifferentPassword123!"
        }
        response = self.client.post(self.register_url, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_register_duplicate_email(self):
        payload = {
            "email": "testauth@example.com",
            "first_name": "Jean",
            "last_name": "Rakoto",
            "password": "Password123!",
            "password_confirm": "Password123!"
        }
        response = self.client.post(self.register_url, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_login_success(self):
        payload = {
            "email": "testauth@example.com",
            "password": "SecurePassword123!"
        }
        response = self.client.post(self.login_url, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('access', response.data)
        self.assertIn('refresh', response.data)
        self.assertIn('user', response.data)
        self.assertEqual(response.data['user']['email'], "testauth@example.com")

    def test_login_invalid_credentials(self):
        payload = {
            "email": "testauth@example.com",
            "password": "WrongPassword!"
        }
        response = self.client.post(self.login_url, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_token_refresh(self):
        refresh = RefreshToken.for_user(self.user)
        payload = {"refresh": str(refresh)}
        response = self.client.post(self.refresh_url, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('access', response.data)

    def test_profile_get_authenticated(self):
        self.client.force_authenticate(user=self.user)
        response = self.client.get(self.profile_url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['email'], self.user.email)
        self.assertEqual(response.data['full_name'], "Jean Rakoto")

    def test_profile_get_unauthenticated(self):
        response = self.client.get(self.profile_url)
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_profile_update(self):
        self.client.force_authenticate(user=self.user)
        payload = {"first_name": "Jean-Pierre", "last_name": "Rakotonirina"}
        response = self.client.patch(self.profile_url, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.user.refresh_from_db()
        self.assertEqual(self.user.first_name, "Jean-Pierre")
        self.assertEqual(self.user.last_name, "Rakotonirina")

    def test_change_password_success(self):
        self.client.force_authenticate(user=self.user)
        payload = {
            "old_password": "SecurePassword123!",
            "new_password": "BrandNewPassword456!",
            "new_password_confirm": "BrandNewPassword456!"
        }
        response = self.client.post(self.change_password_url, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.user.refresh_from_db()
        self.assertTrue(self.user.check_password("BrandNewPassword456!"))

    def test_change_password_wrong_old(self):
        self.client.force_authenticate(user=self.user)
        payload = {
            "old_password": "WrongOldPassword!",
            "new_password": "BrandNewPassword456!",
            "new_password_confirm": "BrandNewPassword456!"
        }
        response = self.client.post(self.change_password_url, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_logout_blacklists_token(self):
        self.client.force_authenticate(user=self.user)
        refresh = RefreshToken.for_user(self.user)
        payload = {"refresh": str(refresh)}

        # Logout
        response = self.client.post(self.logout_url, payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)

        # Tentative de refresh avec le token blacklisté -> doit échouer
        refresh_response = self.client.post(self.refresh_url, payload, format='json')
        self.assertEqual(refresh_response.status_code, status.HTTP_401_UNAUTHORIZED)
