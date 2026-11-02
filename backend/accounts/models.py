"""
Modèles branchés sur les tables existantes `role` et `user`
(créées par database/containlab_schema.sql, donc managed = False).
"""

from django.contrib.auth.base_user import AbstractBaseUser, BaseUserManager
from django.db import models


class Role(models.Model):
    STANDARD = "standard"
    ADMIN = "admin"
    SUPER_ADMIN = "super_admin"

    id = models.AutoField(primary_key=True)
    role_name = models.CharField(max_length=50, unique=True)
    description = models.CharField(max_length=255, null=True, blank=True)

    class Meta:
        managed = False
        db_table = "role"

    def __str__(self):
        return self.role_name


class UserManager(BaseUserManager):
    def create_user(self, email, username, password, role_name=Role.STANDARD):
        if not email:
            raise ValueError("L'adresse e-mail est obligatoire.")
        user = self.model(
            email=self.normalize_email(email).lower(),
            username=username,
            role=Role.objects.get(role_name=role_name),
        )
        user.set_password(password)  # hachage PBKDF2, jamais de mot de passe en clair
        user.save(using=self._db)
        return user


class User(AbstractBaseUser):
    STATUS_ACTIVE = "active"
    STATUS_SUSPENDED = "suspended"
    STATUS_CHOICES = [(STATUS_ACTIVE, "Actif"), (STATUS_SUSPENDED, "Suspendu")]

    id = models.AutoField(primary_key=True)
    email = models.EmailField(max_length=255, unique=True)
    username = models.CharField(max_length=100, unique=True)
    password = models.CharField(max_length=255, db_column="password_hash")
    role = models.ForeignKey(Role, on_delete=models.PROTECT, db_column="role_id")
    status = models.CharField(max_length=10, choices=STATUS_CHOICES, default=STATUS_ACTIVE)
    created_at = models.DateTimeField(auto_now_add=True)

    # La table `user` n'a pas de colonne last_login
    last_login = None

    objects = UserManager()

    USERNAME_FIELD = "email"
    EMAIL_FIELD = "email"
    REQUIRED_FIELDS = ["username"]

    class Meta:
        managed = False
        db_table = "user"

    @property
    def is_active(self):
        return self.status == self.STATUS_ACTIVE

    def __str__(self):
        return self.email
