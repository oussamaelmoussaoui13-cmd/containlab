"""
Contrôleur d'authentification : /api/auth/register, /api/auth/login, /api/auth/me.
"""

from django.contrib.auth.hashers import make_password
from django.db import transaction
from rest_framework import status
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken

from .models import User
from .serializers import LoginSerializer, RegisterSerializer, UserSerializer


def issue_tokens(user):
    """Génère la paire de jetons JWT (access + refresh) avec le rôle dans les claims."""
    refresh = RefreshToken.for_user(user)
    refresh["username"] = user.username
    refresh["role"] = user.role.role_name
    return {"access": str(refresh.access_token), "refresh": str(refresh)}


class RegisterView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []

    def post(self, request):
        serializer = RegisterSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        with transaction.atomic():
            user = serializer.save()
        return Response(
            {"user": UserSerializer(user).data, "tokens": issue_tokens(user)},
            status=status.HTTP_201_CREATED,
        )


class LoginView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []

    def post(self, request):
        serializer = LoginSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        email = serializer.validated_data["email"].lower()
        password = serializer.validated_data["password"]

        user = User.objects.select_related("role").filter(email__iexact=email).first()
        if user is None:
            # Hachage factice : même temps de réponse que pour un compte existant
            make_password(password)
            return self._invalid_credentials()
        if not user.check_password(password):
            return self._invalid_credentials()
        if not user.is_active:
            return Response({"detail": "Ce compte est suspendu."}, status=status.HTTP_403_FORBIDDEN)

        return Response({"user": UserSerializer(user).data, "tokens": issue_tokens(user)})

    @staticmethod
    def _invalid_credentials():
        return Response({"detail": "E-mail ou mot de passe incorrect."}, status=status.HTTP_401_UNAUTHORIZED)


class MeView(APIView):
    """Renvoie l'utilisateur correspondant au jeton (sert à tester le JWT)."""

    def get(self, request):
        return Response(UserSerializer(request.user).data)
