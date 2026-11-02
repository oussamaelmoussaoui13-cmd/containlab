# Base de données ContainLab

Schéma MySQL / MariaDB à 9 tables : `role`, `user`, `container`, `script`,
`script_type`, `arguments`, `template_model`, `generated_template`, `logs`.

## Installation

Prérequis : MySQL 8.0+ ou MariaDB 10.5+.

```bash
mysql -u root -p --default-character-set=utf8mb4 < database/containlab_schema.sql
```

Sous Windows (PowerShell), si `mysql` n'est pas dans le PATH :

```powershell
Get-Content -Raw -Encoding utf8 database\containlab_schema.sql | & "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" -u root -p --default-character-set=utf8mb4
```

Le script supprime puis recrée la base `containlab` et insère les 3 rôles
(`standard`, `admin`, `super_admin`).

## Vérification

```sql
USE containlab;
SHOW TABLES;        -- 9 tables
SELECT * FROM role; -- 3 rôles
```

## Origine du schéma

Le script SQL et le modèle Workbench d'origine n'ont pas été retrouvés dans
les archives. Ce script est reconstruit à partir de la description des tables
(Synthèse B2, ContainLab_db.md) et intègre les corrections de la feuille de
route B3 : propriétaire du conteneur (`owner_id`), clés étrangères manquantes,
mot de passe de conteneur haché, colonne `key` renommée `arg_key`, 3 rôles du
CdC v1.1. Les tables `container_access` (partage) et `token` (réinitialisation
du mot de passe) viendront en phase 3.
