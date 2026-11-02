-- =====================================================================
-- ContainLab : schéma de la base de données (9 tables)
-- Cible : MySQL 8.0+ / MariaDB 10.5+
--
-- Reconstruit à partir du modèle documenté (Synthèse B2, ContainLab_db.md),
-- avec les corrections listées dans la feuille de route B3 :
--   - user        : clé primaire id, statut actif/suspendu, date de création
--   - role        : 3 niveaux du CdC v1.1 (standard, admin, super_admin)
--   - container   : owner_id, image, docker_id, statut texte, mot de passe haché
--   - script      : template_id (FK vers template_model)
--   - arguments   : script_id (FK), colonne `key` renommée arg_key
--   - logs        : user_id, container_id, action
-- Les tables de partage (container_access) et de jetons (token) sont
-- prévues pour la phase 3 (B3-04 / B3-10 / B3-11) et ne sont pas créées ici.
--
-- Usage : mysql -u root -p < database/containlab_schema.sql
-- ATTENTION : le script supprime et recrée la base `containlab`.
-- =====================================================================

DROP DATABASE IF EXISTS containlab;
CREATE DATABASE containlab
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;
USE containlab;

-- ---------------------------------------------------------------------
-- 1. role : niveaux d'habilitation
-- ---------------------------------------------------------------------
CREATE TABLE role (
    id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
    role_name   VARCHAR(50)  NOT NULL,
    description VARCHAR(255) NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_role_name (role_name)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 2. user : comptes utilisateurs
-- ---------------------------------------------------------------------
CREATE TABLE `user` (
    id            INT UNSIGNED NOT NULL AUTO_INCREMENT,
    email         VARCHAR(255) NOT NULL,
    username      VARCHAR(100) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role_id       INT UNSIGNED NOT NULL,
    status        ENUM('active', 'suspended') NOT NULL DEFAULT 'active',
    created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_user_email (email),
    UNIQUE KEY uq_user_username (username),
    CONSTRAINT fk_user_role FOREIGN KEY (role_id)
        REFERENCES role (id) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 3. container : conteneurs Docker gérés par la plateforme
-- ---------------------------------------------------------------------
CREATE TABLE container (
    id            INT UNSIGNED NOT NULL AUTO_INCREMENT,
    name          VARCHAR(100) NOT NULL,
    owner_id      INT UNSIGNED NOT NULL,
    image         VARCHAR(255) NOT NULL,
    docker_id     VARCHAR(64)  NULL,
    status        ENUM('created', 'running', 'stopped', 'error') NOT NULL DEFAULT 'created',
    password_hash VARCHAR(255) NULL,
    created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_container_name (name),
    UNIQUE KEY uq_container_docker_id (docker_id),
    KEY idx_container_owner (owner_id),
    CONSTRAINT fk_container_owner FOREIGN KEY (owner_id)
        REFERENCES `user` (id) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 4. template_model : modèles de scripts réutilisables
-- ---------------------------------------------------------------------
CREATE TABLE template_model (
    id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
    name        VARCHAR(100) NOT NULL,
    path        VARCHAR(500) NOT NULL,
    description TEXT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_template_model_name (name)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 5. generated_template : gabarits générés à partir d'un modèle
-- ---------------------------------------------------------------------
CREATE TABLE generated_template (
    id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
    name        VARCHAR(100) NOT NULL,
    path        VARCHAR(500) NOT NULL,
    template_id INT UNSIGNED NULL,
    created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_generated_template_template (template_id),
    CONSTRAINT fk_generated_template_template FOREIGN KEY (template_id)
        REFERENCES template_model (id) ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 6. script : scripts associés à un conteneur
-- ---------------------------------------------------------------------
CREATE TABLE script (
    id           INT UNSIGNED NOT NULL AUTO_INCREMENT,
    name         VARCHAR(100) NOT NULL,
    path         VARCHAR(500) NOT NULL,
    container_id INT UNSIGNED NOT NULL,
    template_id  INT UNSIGNED NULL,
    PRIMARY KEY (id),
    KEY idx_script_container (container_id),
    KEY idx_script_template (template_id),
    CONSTRAINT fk_script_container FOREIGN KEY (container_id)
        REFERENCES container (id) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_script_template FOREIGN KEY (template_id)
        REFERENCES template_model (id) ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 7. script_type : type d'action d'un script
-- ---------------------------------------------------------------------
CREATE TABLE script_type (
    id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
    script_id   INT UNSIGNED NOT NULL,
    action_type VARCHAR(50)  NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_script_type (script_id, action_type),
    CONSTRAINT fk_script_type_script FOREIGN KEY (script_id)
        REFERENCES script (id) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 8. arguments : paramètres clé/valeur d'un script
-- ---------------------------------------------------------------------
CREATE TABLE arguments (
    id        INT UNSIGNED NOT NULL AUTO_INCREMENT,
    script_id INT UNSIGNED NOT NULL,
    arg_key   VARCHAR(100) NOT NULL,
    arg_value TEXT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_arguments_script_key (script_id, arg_key),
    CONSTRAINT fk_arguments_script FOREIGN KEY (script_id)
        REFERENCES script (id) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 9. logs : journal d'activité et fichiers de logs
-- ---------------------------------------------------------------------
CREATE TABLE logs (
    id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `timestamp`  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    user_id      INT UNSIGNED NULL,
    container_id INT UNSIGNED NULL,
    action       VARCHAR(100) NOT NULL,
    file_path    VARCHAR(500) NULL,
    size         BIGINT UNSIGNED NULL,
    PRIMARY KEY (id),
    KEY idx_logs_user (user_id),
    KEY idx_logs_container (container_id),
    KEY idx_logs_timestamp (`timestamp`),
    CONSTRAINT fk_logs_user FOREIGN KEY (user_id)
        REFERENCES `user` (id) ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT fk_logs_container FOREIGN KEY (container_id)
        REFERENCES container (id) ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Données de référence
-- ---------------------------------------------------------------------
INSERT INTO role (role_name, description) VALUES
    ('standard',    'Utilisateur : gère ses propres conteneurs'),
    ('admin',       'Administrateur : arrête les conteneurs, suspend les comptes'),
    ('super_admin', 'Super-administrateur : promeut ou rétrograde les administrateurs');
