from rest_framework import serializers
from django.contrib.auth import get_user_model
from django.contrib.auth.password_validation import validate_password
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from rest_framework_simplejwt.tokens import RefreshToken

from apps.accounts.models import Role

User = get_user_model()


class UserCompanyDetailSerializer(serializers.Serializer):
    """Sérialiseur pour les entreprises associées à l'utilisateur."""
    company_id = serializers.UUIDField(source='company.id')
    company_name = serializers.CharField(source='company.name')
    company_currency = serializers.CharField(source='company.currency')
    role_id = serializers.UUIDField(source='role.id')
    role_name = serializers.CharField(source='role.name')


class UserProfileSerializer(serializers.ModelSerializer):
    """Sérialiseur pour afficher et modifier le profil de l'utilisateur."""
    full_name = serializers.ReadOnlyField()
    companies = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = (
            'id',
            'email',
            'first_name',
            'last_name',
            'full_name',
            'is_active',
            'is_staff',
            'created_at',
            'companies',
        )
        read_only_fields = ('id', 'email', 'is_active', 'is_staff', 'created_at')

    def get_companies(self, obj):
        user_companies = obj.user_companies.select_related('company', 'role').all()
        return UserCompanyDetailSerializer(user_companies, many=True).data


class RegisterSerializer(serializers.ModelSerializer):
    """Sérialiseur pour l'inscription d'un nouvel utilisateur."""
    password = serializers.CharField(
        write_only=True,
        required=True,
        validators=[validate_password],
        style={'input_type': 'password'},
    )
    password_confirm = serializers.CharField(
        write_only=True,
        required=True,
        style={'input_type': 'password'},
    )

    class Meta:
        model = User
        fields = ('id', 'email', 'first_name', 'last_name', 'password', 'password_confirm')
        read_only_fields = ('id',)

    def validate(self, attrs):
        if attrs['password'] != attrs['password_confirm']:
            raise serializers.ValidationError({"password_confirm": "Les deux mots de passe ne correspondent pas."})
        return attrs

    def create(self, validated_data):
        validated_data.pop('password_confirm')
        user = User.objects.create_user(
            email=validated_data['email'],
            first_name=validated_data['first_name'],
            last_name=validated_data['last_name'],
            password=validated_data['password'],
        )
        return user


class CustomTokenObtainPairSerializer(TokenObtainPairSerializer):
    """
    Sérialiseur JWT de connexion personnalisé.

    Enrichit :
    1. Le payload du token d'accès avec des custom claims (email, nom, id).
    2. La réponse JSON avec les données utilisateur et ses entreprises affiliées.
    """

    @classmethod
    def get_token(cls, user):
        token = super().get_token(user)
        # Custom claims injectés directement dans le JWT
        token['email'] = user.email
        token['first_name'] = user.first_name
        token['last_name'] = user.last_name
        token['full_name'] = user.full_name
        return token

    def validate(self, attrs):
        data = super().validate(attrs)

        # Ajouter les détails de l'utilisateur dans la réponse
        user_serializer = UserProfileSerializer(self.user)
        data['user'] = user_serializer.data
        return data


class ChangePasswordSerializer(serializers.Serializer):
    """Sérialiseur pour le changement sécurisé de mot de passe."""
    old_password = serializers.CharField(
        required=True,
        style={'input_type': 'password'},
    )
    new_password = serializers.CharField(
        required=True,
        validators=[validate_password],
        style={'input_type': 'password'},
    )
    new_password_confirm = serializers.CharField(
        required=True,
        style={'input_type': 'password'},
    )

    def validate_old_password(self, value):
        user = self.context['request'].user
        if not user.check_password(value):
            raise serializers.ValidationError("L'ancien mot de passe est incorrect.")
        return value

    def validate(self, attrs):
        if attrs['new_password'] != attrs['new_password_confirm']:
            raise serializers.ValidationError(
                {"new_password_confirm": "Les nouveaux mots de passe ne correspondent pas."}
            )
        return attrs

    def save(self, **kwargs):
        user = self.context['request'].user
        user.set_password(self.validated_data['new_password'])
        user.save()
        return user


class LogoutSerializer(serializers.Serializer):
    """Sérialiseur pour la déconnexion et la révocation du refresh token."""
    refresh = serializers.CharField(required=True)

    def validate(self, attrs):
        self.token = attrs['refresh']
        return attrs

    def save(self, **kwargs):
        try:
            token = RefreshToken(self.token)
            token.blacklist()
        except Exception as e:
            raise serializers.ValidationError({"refresh": "Token invalide ou déjà révoqué."})
