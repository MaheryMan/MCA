from rest_framework import status, generics
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework_simplejwt.views import TokenObtainPairView
from rest_framework_simplejwt.tokens import RefreshToken

from .serializers import (
    RegisterSerializer,
    CustomTokenObtainPairSerializer,
    UserProfileSerializer,
    ChangePasswordSerializer,
    LogoutSerializer,
)


class RegisterView(APIView):
    """
    Endpoint d'inscription pour créer un nouveau compte utilisateur.

    Retourne les informations du compte créé ainsi que les tokens JWT (access & refresh)
    pour une connexion immédiate.
    """
    permission_classes = [AllowAny]

    def post(self, request, *args, **kwargs):
        serializer = RegisterSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()

        # Générer directement les tokens JWT pour l'utilisateur créé
        refresh = RefreshToken.for_user(user)
        refresh['email'] = user.email
        refresh['first_name'] = user.first_name
        refresh['last_name'] = user.last_name
        refresh['full_name'] = user.full_name

        user_data = UserProfileSerializer(user).data

        return Response(
            {
                'message': 'Compte créé avec succès.',
                'user': user_data,
                'tokens': {
                    'access': str(refresh.access_token),
                    'refresh': str(refresh),
                },
            },
            status=status.HTTP_201_CREATED,
        )


class CustomTokenObtainPairView(TokenObtainPairView):
    """
    Endpoint de connexion (login) par email et mot de passe.

    Retourne :
    - `access` : Token JWT d'accès court terme
    - `refresh` : Token JWT de rafraîchissement long terme
    - `user` : Données du profil et entreprises affiliées
    """
    permission_classes = [AllowAny]
    serializer_class = CustomTokenObtainPairSerializer


class UserProfileView(generics.RetrieveUpdateAPIView):
    """
    Endpoint pour consulter (`GET`) ou mettre à jour (`PATCH`/`PUT`)
    le profil de l'utilisateur actuellement connecté.
    """
    permission_classes = [IsAuthenticated]
    serializer_class = UserProfileSerializer

    def get_object(self):
        return self.request.user


class ChangePasswordView(APIView):
    """
    Endpoint pour changer le mot de passe de l'utilisateur connecté.

    Exige l'ancien mot de passe pour validation préalable.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request, *args, **kwargs):
        serializer = ChangePasswordSerializer(
            data=request.data,
            context={'request': request},
        )
        serializer.is_valid(raise_exception=True)
        serializer.save()

        return Response(
            {'message': 'Mot de passe mis à jour avec succès.'},
            status=status.HTTP_200_OK,
        )


class LogoutView(APIView):
    """
    Endpoint de déconnexion.

    Invalide (blacklist) le refresh token fourni dans le corps de la requête.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request, *args, **kwargs):
        serializer = LogoutSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        serializer.save()

        return Response(
            {'message': 'Déconnexion réussie. Le token a été révoqué.'},
            status=status.HTTP_200_OK,
        )
