-- =====================================================================
--  04 · VALORES DEFAULT — seis usos
--  Fundamentos de Bases de Datos · Universidad Libre · Andrés Castaño
--  MySQL 8.0.13+ / MariaDB 10.4+
--
--  Idea clave: si el INSERT NO menciona la columna, la base pone el DEFAULT.
--  Ejecute sentencia por sentencia y compare lo que envió el INSERT
--  con lo que muestra el SELECT.
-- =====================================================================

DROP DATABASE IF EXISTS demo_default;
CREATE DATABASE demo_default CHARACTER SET utf8mb4;
USE demo_default;


-- ---------------------------------------------------------------------
-- USO 1 · Marca de tiempo automática (auditoría)
-- ---------------------------------------------------------------------
CREATE TABLE logs (
  id             INT AUTO_INCREMENT PRIMARY KEY,
  evento         VARCHAR(80) NOT NULL,
  fecha_creacion DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO logs (evento) VALUES ('Inicio de sesión: ana.ruiz');
INSERT INTO logs (evento) VALUES ('Cambio de contraseña: ana.ruiz');

SELECT * FROM logs;   -- la fecha y hora las puso el servidor


-- ---------------------------------------------------------------------
-- USO 2 · Estado inicial en un flujo de trabajo
-- ---------------------------------------------------------------------
CREATE TABLE usuarios (
  id     INT AUTO_INCREMENT PRIMARY KEY,
  correo VARCHAR(120) NOT NULL UNIQUE,
  activo BOOLEAN      NOT NULL DEFAULT TRUE
);

CREATE TABLE tareas (
  id     INT AUTO_INCREMENT PRIMARY KEY,
  titulo VARCHAR(80) NOT NULL,
  estado VARCHAR(12) NOT NULL DEFAULT 'Pendiente',
  CONSTRAINT chk_tarea_estado CHECK (estado IN ('Pendiente', 'En curso', 'Terminada'))
);

INSERT INTO usuarios (correo) VALUES ('luis.mora@correo.com');
INSERT INTO tareas (titulo)   VALUES ('Revisar taller 14');

SELECT * FROM usuarios;   -- activo = 1 (TRUE)
SELECT * FROM tareas;     -- estado = 'Pendiente'


-- ---------------------------------------------------------------------
-- USO 3 · Contadores y valores financieros en cero
-- ---------------------------------------------------------------------
-- 3A. EL PROBLEMA: sin DEFAULT la columna queda en NULL y las cuentas se dañan
CREATE TABLE cuentas_mal (
  id    INT AUTO_INCREMENT PRIMARY KEY,
  socio VARCHAR(60) NOT NULL,
  saldo DECIMAL(12,2)
);
INSERT INTO cuentas_mal (socio) VALUES ('Camila');

UPDATE cuentas_mal SET saldo = saldo + 50000 WHERE socio = 'Camila';
SELECT * FROM cuentas_mal;   -- saldo sigue en NULL: NULL + 50000 = NULL

-- 3B. LA SOLUCIÓN
CREATE TABLE cuentas (
  id    INT AUTO_INCREMENT PRIMARY KEY,
  socio VARCHAR(60)   NOT NULL,
  saldo DECIMAL(12,2) NOT NULL DEFAULT 0.00
);
INSERT INTO cuentas (socio) VALUES ('Camila');

UPDATE cuentas SET saldo = saldo + 50000 WHERE socio = 'Camila';
SELECT * FROM cuentas;       -- saldo = 50000.00

CREATE TABLE articulos_blog (
  id              INT AUTO_INCREMENT PRIMARY KEY,
  titulo          VARCHAR(120) NOT NULL,
  cantidad_vistas INT          NOT NULL DEFAULT 0
);
INSERT INTO articulos_blog (titulo) VALUES ('Qué es un índice');
UPDATE articulos_blog SET cantidad_vistas = cantidad_vistas + 1 WHERE id = 1;
SELECT * FROM articulos_blog;   -- 1 vista


-- ---------------------------------------------------------------------
-- USO 4 · Identificador único universal (UUID)
-- ---------------------------------------------------------------------
CREATE TABLE envios (
  id             INT AUTO_INCREMENT PRIMARY KEY,
  destino        VARCHAR(40) NOT NULL,
  codigo_rastreo CHAR(36)    NOT NULL DEFAULT (UUID())   -- los paréntesis son obligatorios
);

INSERT INTO envios (destino) VALUES ('Medellín'), ('Cali'), ('Barranquilla');
SELECT * FROM envios;   -- cada envío nació con un código distinto


-- ---------------------------------------------------------------------
-- USO 5 · Configuración regional
-- ---------------------------------------------------------------------
CREATE TABLE clientes (
  id     INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(60) NOT NULL,
  pais   VARCHAR(40) NOT NULL DEFAULT 'Colombia',
  moneda CHAR(3)     NOT NULL DEFAULT 'COP'
);

INSERT INTO clientes (nombre) VALUES ('Ana Ruiz');                          -- cliente local
INSERT INTO clientes (nombre, pais, moneda) VALUES ('John Smith', 'Estados Unidos', 'USD');  -- excepción

SELECT * FROM clientes;


-- ---------------------------------------------------------------------
-- USO 6 · Texto de relleno controlado
-- ---------------------------------------------------------------------
CREATE TABLE contactos (
  id                  INT AUTO_INCREMENT PRIMARY KEY,
  nombre              VARCHAR(60)  NOT NULL,
  telefono_secundario VARCHAR(20)  NOT NULL DEFAULT 'No registrado',
  observaciones       VARCHAR(200) NOT NULL DEFAULT 'Sin comentarios'
);

INSERT INTO contactos (nombre) VALUES ('Diego Rojas');
SELECT * FROM contactos;


-- ---------------------------------------------------------------------
-- DETALLES QUE CONFUNDEN
-- ---------------------------------------------------------------------
-- a) La palabra DEFAULT dentro del VALUES también usa el valor por defecto
INSERT INTO clientes (nombre, pais, moneda) VALUES ('Sara Gil', DEFAULT, DEFAULT);

-- b) Enviar NULL a propósito NO usa el DEFAULT
INSERT INTO clientes (nombre, pais) VALUES ('Pedro Díaz', NULL);   -- DEBE FALLAR
-- ERROR 1048: Column 'pais' cannot be null  (lo frena el NOT NULL)

SELECT * FROM clientes;

-- c) Agregar una columna con DEFAULT llena también las filas que ya existían
ALTER TABLE contactos ADD activo BOOLEAN NOT NULL DEFAULT TRUE;
SELECT * FROM contactos;

-- d) Ver los DEFAULT de una tabla
SHOW CREATE TABLE clientes;
