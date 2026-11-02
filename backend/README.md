# Backend ContainLab (Django REST)

API REST en Python / Django, connectée à la base MySQL `containlab`.

## Installation

Prérequis : Python 3.12+, la base créée avec `database/containlab_schema.sql`.

```powershell
cd backend
py -m venv .venv
.venv\Scripts\pip install -r requirements.txt
copy .env.example .env    # puis remplir DJANGO_SECRET_KEY et DB_PASSWORD
.venv\Scripts\python manage.py runserver
```

Générer une clé secrète :

```powershell
.venv\Scripts\python -c "from django.core.management.utils import get_random_secret_key as g; print(g())"
```

Ne pas lancer `manage.py migrate` : les tables viennent du script SQL, les
modèles sont en `managed = False`.

## Authentification

Mots de passe hachés en PBKDF2-SHA256 (hasher Django). Jetons JWT
(djangorestframework-simplejwt) : access 30 min, refresh 1 jour (réglables
dans `.env`). Le jeton contient `user_id`, `username` et `role`.

| Méthode | Route | Corps | Réponse |
|---|---|---|---|
| POST | `/api/auth/register` | `email`, `username`, `password` | 201 : `user` + `tokens` |
| POST | `/api/auth/login` | `email`, `password` | 200 : `user` + `tokens` ; 401 identifiants faux ; 403 compte suspendu |
| POST | `/api/auth/refresh` | `refresh` | 200 : nouveau `access` |
| GET | `/api/auth/me` | en-tête `Authorization: Bearer <access>` | 200 : utilisateur courant |

Exemple :

```bash
curl -X POST http://127.0.0.1:8000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test.etudiant@ipi.fr","password":"Docker#Lab2026"}'
```

Toutes les autres routes de l'API exigeront par défaut un jeton valide.
