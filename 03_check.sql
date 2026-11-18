-- =====================================================================
--  03 · RESTRICCIONES CHECK — cinco usos + su límite
--  Fundamentos de Bases de Datos · Universidad Libre · Andrés Castaño
--  MySQL 8.0.16+ / MariaDB 10.4+ (versiones anteriores IGNORAN el CHECK)
--
--  Ejecute sentencia por sentencia. Las marcadas con  -- DEBE FALLAR
--  producen un error a propósito. El mensaje cambia según el motor:
--    MySQL   -> ERROR 3819: Check constraint 'nombre' is violated.
--    MariaDB -> ERROR 4025: CONSTRAINT `nombre` failed for `tabla`
-- =====================================================================

DROP DATABASE IF EXISTS demo_check;
CREATE DATABASE demo_check CHARACTER SET utf8mb4;
USE demo_check;


-- ---------------------------------------------------------------------
-- USO 1 · Rangos numéricos
-- ---------------------------------------------------------------------
CREATE TABLE productos (
  id     INT PRIMARY KEY,
  nombre VARCHAR(60)   NOT NULL,
  precio DECIMAL(12,2) NOT NULL,
  stock  INT           NOT NULL,
  CONSTRAINT chk_prod_precio CHECK (precio > 0),
  CONSTRAINT chk_prod_stock  CHECK (stock >= 0)
);

INSERT INTO productos VALUES (7, 'Taladro percutor', 289900, 3);   -- OK

INSERT INTO productos VALUES (8, 'Pulidora', -5000, 10);           -- DEBE FALLAR (precio)

-- Caso real: hay 3 taladros y una venta intenta descontar 5
UPDATE productos SET stock = stock - 5 WHERE id = 7;               -- DEBE FALLAR (stock)
UPDATE productos SET stock = stock - 2 WHERE id = 7;               -- OK: quedan 1
SELECT * FROM productos;

CREATE TABLE calificaciones (
  id_estudiante INT NOT NULL,
  id_materia    INT NOT NULL,
  nota          DECIMAL(5,2) NOT NULL,
  PRIMARY KEY (id_estudiante, id_materia),
  CONSTRAINT chk_nota CHECK (nota BETWEEN 0 AND 100)
);
INSERT INTO calificaciones VALUES (10, 502, 87.5);                 -- OK
INSERT INTO calificaciones VALUES (10, 503, 120);                  -- DEBE FALLAR


-- ---------------------------------------------------------------------
-- USO 2 · Lista de valores permitidos
-- ---------------------------------------------------------------------
CREATE TABLE pedidos (
  id     INT PRIMARY KEY,
  estado VARCHAR(12) NOT NULL,
  CONSTRAINT chk_ped_estado
    CHECK (estado IN ('Pendiente', 'Pagado', 'Enviado', 'Cancelado'))
);

INSERT INTO pedidos VALUES (1, 'Pendiente');                       -- OK
UPDATE pedidos SET estado = 'Pagado' WHERE id = 1;                 -- OK
UPDATE pedidos SET estado = 'Perdido' WHERE id = 1;                -- DEBE FALLAR
INSERT INTO pedidos VALUES (2, 'pagado');                          -- se acepta
-- Ojo: con la intercalación por defecto MySQL compara sin distinguir
-- mayúsculas, así que 'pagado' en minúscula SÍ pasa el CHECK.
SELECT * FROM pedidos;


-- ---------------------------------------------------------------------
-- USO 3 · Coherencia entre columnas de la misma fila
-- ---------------------------------------------------------------------
CREATE TABLE reservas (
  id           INT PRIMARY KEY,
  habitacion   INT  NOT NULL,
  fecha_inicio DATE NOT NULL,
  fecha_fin    DATE NOT NULL,
  precio_total DECIMAL(12,2) NOT NULL,
  descuento    DECIMAL(12,2) NOT NULL,
  CONSTRAINT chk_res_fechas    CHECK (fecha_fin >= fecha_inicio),
  CONSTRAINT chk_res_descuento CHECK (descuento < precio_total)
);

INSERT INTO reservas VALUES (1, 204, '2026-12-20', '2026-12-24', 1200000, 100000);  -- OK
INSERT INTO reservas VALUES (2, 205, '2026-12-24', '2026-12-20',  900000,      0);  -- DEBE FALLAR (fechas)
INSERT INTO reservas VALUES (3, 206, '2026-12-20', '2026-12-22',  500000, 600000);  -- DEBE FALLAR (descuento)


-- ---------------------------------------------------------------------
-- USO 4 · Formato y longitud de texto
-- ---------------------------------------------------------------------
CREATE TABLE clientes (
  id            INT PRIMARY KEY,
  email         VARCHAR(120) NOT NULL,
  codigo_postal CHAR(6)      NOT NULL,
  CONSTRAINT chk_cli_email CHECK (email LIKE '%_@__%.__%'),
  CONSTRAINT chk_cli_cp    CHECK (CHAR_LENGTH(codigo_postal) = 6)
);

INSERT INTO clientes VALUES (1, 'ana.ruiz@correo.com', '110111');  -- OK
INSERT INTO clientes VALUES (2, 'ana.ruizcorreo.com', '110111');   -- DEBE FALLAR (sin @)
INSERT INTO clientes VALUES (3, 'luis@correo', '110111');          -- DEBE FALLAR (sin punto)
INSERT INTO clientes VALUES (4, 'sara@correo.com', '1101');        -- DEBE FALLAR (4 caracteres)


-- ---------------------------------------------------------------------
-- USO 5 · Regla condicional (un campo depende de otro)
-- ---------------------------------------------------------------------
CREATE TABLE empleados (
  id                INT PRIMARY KEY,
  nombre            VARCHAR(60) NOT NULL,
  tipo_contrato     VARCHAR(12) NOT NULL,
  fecha_vencimiento DATE NULL,
  CONSTRAINT chk_emp_tipo CHECK (tipo_contrato IN ('Indefinido', 'Temporal')),
  CONSTRAINT chk_emp_venc CHECK (tipo_contrato <> 'Temporal' OR fecha_vencimiento IS NOT NULL)
);

INSERT INTO empleados VALUES (1, 'Laura', 'Indefinido', NULL);          -- OK
INSERT INTO empleados VALUES (2, 'Diego', 'Temporal', '2027-06-30');    -- OK
INSERT INTO empleados VALUES (3, 'Paula', 'Temporal', NULL);            -- DEBE FALLAR

-- Cambiar a temporal a alguien sin fecha también se bloquea:
UPDATE empleados SET tipo_contrato = 'Temporal' WHERE id = 1;           -- DEBE FALLAR


-- ---------------------------------------------------------------------
-- DETALLE IMPORTANTE · CHECK deja pasar NULL
-- ---------------------------------------------------------------------
CREATE TABLE descuentos (
  id  INT PRIMARY KEY,
  pct DECIMAL(5,2) NULL,
  CONSTRAINT chk_pct CHECK (pct BETWEEN 0 AND 90)
);
INSERT INTO descuentos VALUES (1, NULL);     -- se acepta: NULL no viola el CHECK
-- Si el valor es obligatorio, además del CHECK se necesita NOT NULL.


-- ---------------------------------------------------------------------
-- LÍMITE · CHECK no puede consultar otras tablas
-- ---------------------------------------------------------------------
CREATE TABLE pedidos_mal (
  id         INT PRIMARY KEY,
  cliente_id INT NOT NULL,
  CHECK (cliente_id IN (SELECT id FROM clientes))
);                                            -- DEBE FALLAR: no se permiten subconsultas
-- Para validar contra otra tabla se usa FOREIGN KEY.


-- ---------------------------------------------------------------------
-- BONUS · Agregar un CHECK a una tabla que ya tiene datos malos
-- (caso real de migración)
-- ---------------------------------------------------------------------
CREATE TABLE inventario_viejo (
  id    INT PRIMARY KEY,
  stock INT NOT NULL
);
INSERT INTO inventario_viejo VALUES (1, 10), (2, -2), (3, 5);   -- dato heredado: -2

ALTER TABLE inventario_viejo
  ADD CONSTRAINT chk_inv_stock CHECK (stock >= 0);              -- DEBE FALLAR: ya hay un -2

UPDATE inventario_viejo SET stock = 0 WHERE stock < 0;         -- corregimos el dato
ALTER TABLE inventario_viejo
  ADD CONSTRAINT chk_inv_stock CHECK (stock >= 0);              -- OK

-- Ver los CHECK definidos en esta base:
SELECT TABLE_NAME, CONSTRAINT_NAME
FROM information_schema.TABLE_CONSTRAINTS
WHERE CONSTRAINT_SCHEMA = 'demo_check' AND CONSTRAINT_TYPE = 'CHECK'
ORDER BY TABLE_NAME;
