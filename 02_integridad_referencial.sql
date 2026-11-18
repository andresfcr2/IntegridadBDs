-- =====================================================================
--  02 · INTEGRIDAD REFERENCIAL — cinco fallos + acciones ON DELETE
--  Fundamentos de Bases de Datos · Universidad Libre · Andrés Castaño
--  MySQL 8.0.16+ / MariaDB 10.4+
--
--  Ejecute sentencia por sentencia. Las marcadas con  -- DEBE FALLAR
--  producen un error a propósito: ese error es la demostración.
--  Cada escenario muestra primero el PROBLEMA (tabla sin FOREIGN KEY)
--  y luego la SOLUCIÓN (con FOREIGN KEY).
-- =====================================================================

DROP DATABASE IF EXISTS demo_referencial;
CREATE DATABASE demo_referencial CHARACTER SET utf8mb4;
USE demo_referencial;


-- ---------------------------------------------------------------------
-- ESCENARIO 1 · Inserción huérfana (clave inexistente)
-- ---------------------------------------------------------------------
CREATE TABLE clientes (
  id_cliente INT PRIMARY KEY,
  nombre     VARCHAR(60) NOT NULL
);
INSERT INTO clientes VALUES (1, 'Juan'), (2, 'María');

-- 1A. EL PROBLEMA: pedidos sin FOREIGN KEY
CREATE TABLE pedidos_sin_fk (
  id_pedido  INT PRIMARY KEY,
  id_cliente INT NOT NULL
);

INSERT INTO pedidos_sin_fk VALUES (500, 99);   -- se acepta: el cliente 99 NO existe

-- ¿Qué pedidos apuntan a clientes que no existen?
SELECT * FROM pedidos_sin_fk
WHERE id_cliente NOT IN (SELECT id_cliente FROM clientes);

-- 1B. LA SOLUCIÓN: con FOREIGN KEY
CREATE TABLE pedidos (
  id_pedido  INT PRIMARY KEY,
  id_cliente INT NOT NULL,
  CONSTRAINT fk_pedidos_clientes
    FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente)
);

INSERT INTO pedidos VALUES (501, 1);           -- OK: Juan existe
INSERT INTO pedidos VALUES (500, 99);          -- DEBE FALLAR
-- ERROR 1452: Cannot add or update a child row: a foreign key constraint fails


-- ---------------------------------------------------------------------
-- ESCENARIO 2 · Borrado del registro padre
-- ---------------------------------------------------------------------
-- 2A. EL PROBLEMA: sin FOREIGN KEY
CREATE TABLE categorias (
  id_categoria INT PRIMARY KEY,
  nombre       VARCHAR(40) NOT NULL
);
INSERT INTO categorias VALUES (10, 'Electrónica'), (20, 'Hogar');

CREATE TABLE productos_sin_fk (
  id_producto  INT PRIMARY KEY,
  nombre       VARCHAR(60) NOT NULL,
  id_categoria INT
);
INSERT INTO productos_sin_fk VALUES
  (1, 'Audífonos', 10), (2, 'Parlante', 10), (3, 'Lámpara', 20);

DELETE FROM categorias WHERE id_categoria = 10;   -- se acepta

-- Productos que quedaron apuntando a una categoría fantasma:
SELECT * FROM productos_sin_fk
WHERE id_categoria NOT IN (SELECT id_categoria FROM categorias);

-- 2B. LA SOLUCIÓN: con FOREIGN KEY (por defecto RESTRICT)
INSERT INTO categorias VALUES (10, 'Electrónica');   -- devolvemos la categoría

CREATE TABLE productos (
  id_producto  INT PRIMARY KEY,
  nombre       VARCHAR(60) NOT NULL,
  id_categoria INT,
  CONSTRAINT fk_productos_categorias
    FOREIGN KEY (id_categoria) REFERENCES categorias(id_categoria)
);
INSERT INTO productos VALUES
  (1, 'Audífonos', 10), (2, 'Parlante', 10), (3, 'Lámpara', 20);

DELETE FROM categorias WHERE id_categoria = 10;   -- DEBE FALLAR
-- ERROR 1451: Cannot delete or update a parent row: a foreign key constraint fails


-- ---------------------------------------------------------------------
-- ACCIONES AL BORRAR EL PADRE: RESTRICT, CASCADE y SET NULL
-- (caso real de una tienda en línea)
-- ---------------------------------------------------------------------
CREATE TABLE tienda_categoria (
  id     INT PRIMARY KEY,
  nombre VARCHAR(40) NOT NULL
);
CREATE TABLE tienda_producto (
  id           INT PRIMARY KEY,
  nombre       VARCHAR(60) NOT NULL,
  categoria_id INT NULL,                       -- debe aceptar NULL para SET NULL
  CONSTRAINT fk_tp_categoria FOREIGN KEY (categoria_id)
    REFERENCES tienda_categoria(id) ON DELETE SET NULL
);
CREATE TABLE tienda_cliente (
  id     INT PRIMARY KEY,
  nombre VARCHAR(60) NOT NULL
);
CREATE TABLE tienda_pedido (
  id         INT PRIMARY KEY,
  cliente_id INT NOT NULL,
  CONSTRAINT fk_tpe_cliente FOREIGN KEY (cliente_id)
    REFERENCES tienda_cliente(id) ON DELETE RESTRICT  -- la factura es historia
);
CREATE TABLE tienda_detalle (
  pedido_id   INT NOT NULL,
  producto_id INT NOT NULL,
  cantidad    INT NOT NULL,
  PRIMARY KEY (pedido_id, producto_id),
  CONSTRAINT fk_td_pedido FOREIGN KEY (pedido_id)
    REFERENCES tienda_pedido(id) ON DELETE CASCADE,   -- la línea es parte del pedido
  CONSTRAINT fk_td_producto FOREIGN KEY (producto_id)
    REFERENCES tienda_producto(id)
);

INSERT INTO tienda_categoria VALUES (1, 'Temporada navideña'), (2, 'Herramientas');
INSERT INTO tienda_producto  VALUES (100, 'Luces LED', 1), (200, 'Taladro', 2);
INSERT INTO tienda_cliente   VALUES (1, 'Ana Ruiz'), (2, 'Luis Mora');
INSERT INTO tienda_pedido    VALUES (9001, 1), (9002, 2);
INSERT INTO tienda_detalle   VALUES (9001, 100, 3), (9001, 200, 1), (9002, 200, 2);

-- RESTRICT: Ana tiene un pedido, no se puede borrar
DELETE FROM tienda_cliente WHERE id = 1;          -- DEBE FALLAR
-- ERROR 1451

-- CASCADE: el pedido 9001 se creó por error; al borrarlo se van sus líneas
SELECT * FROM tienda_detalle;                     -- 3 líneas
DELETE FROM tienda_pedido WHERE id = 9001;        -- OK
SELECT * FROM tienda_detalle;                     -- quedó solo la línea del pedido 9002

-- SET NULL: termina la temporada y se elimina la categoría
DELETE FROM tienda_categoria WHERE id = 1;        -- OK
SELECT * FROM tienda_producto;                    -- Luces LED quedó con categoria_id = NULL


-- ---------------------------------------------------------------------
-- ESCENARIO 3 · Cambio de la llave del registro padre
-- ---------------------------------------------------------------------
-- 3A. EL PROBLEMA: sin FOREIGN KEY
CREATE TABLE departamentos_sin_fk (
  codigo VARCHAR(10) PRIMARY KEY,
  nombre VARCHAR(40) NOT NULL
);
CREATE TABLE empleados_sin_fk (
  id           INT PRIMARY KEY,
  nombre       VARCHAR(60) NOT NULL,
  departamento VARCHAR(10) NOT NULL
);
INSERT INTO departamentos_sin_fk VALUES ('DEP-01', 'Ventas');
INSERT INTO empleados_sin_fk VALUES (1, 'Laura', 'DEP-01'), (2, 'Diego', 'DEP-01');

UPDATE departamentos_sin_fk SET codigo = 'VENT-2026' WHERE codigo = 'DEP-01';

SELECT * FROM empleados_sin_fk
WHERE departamento NOT IN (SELECT codigo FROM departamentos_sin_fk);
-- Laura y Diego quedaron en 'DEP-01', un departamento que ya no existe

-- 3B. Con FOREIGN KEY y sin acción: el cambio se bloquea
CREATE TABLE departamentos (
  codigo VARCHAR(10) PRIMARY KEY,
  nombre VARCHAR(40) NOT NULL
);
CREATE TABLE empleados (
  id           INT PRIMARY KEY,
  nombre       VARCHAR(60) NOT NULL,
  departamento VARCHAR(10) NOT NULL,
  CONSTRAINT fk_emp_dep FOREIGN KEY (departamento) REFERENCES departamentos(codigo)
);
INSERT INTO departamentos VALUES ('DEP-01', 'Ventas');
INSERT INTO empleados VALUES (1, 'Laura', 'DEP-01'), (2, 'Diego', 'DEP-01');

UPDATE departamentos SET codigo = 'VENT-2026' WHERE codigo = 'DEP-01';   -- DEBE FALLAR
-- ERROR 1451

-- 3C. Con ON UPDATE CASCADE: el cambio se propaga a los empleados
ALTER TABLE empleados DROP FOREIGN KEY fk_emp_dep;
ALTER TABLE empleados
  ADD CONSTRAINT fk_emp_dep FOREIGN KEY (departamento)
  REFERENCES departamentos(codigo) ON UPDATE CASCADE;

UPDATE departamentos SET codigo = 'VENT-2026' WHERE codigo = 'DEP-01';   -- OK
SELECT * FROM empleados;                       -- ambos quedaron en 'VENT-2026'


-- ---------------------------------------------------------------------
-- ESCENARIO 4 · NULL mal usado en la llave foránea
-- ---------------------------------------------------------------------
CREATE TABLE vendedores (
  id     INT PRIMARY KEY,
  nombre VARCHAR(60) NOT NULL
);
INSERT INTO vendedores VALUES (1, 'Camila Torres');

-- 4A. EL PROBLEMA: la FK acepta NULL
CREATE TABLE facturas_mal (
  id          INT PRIMARY KEY,
  total       DECIMAL(12,2) NOT NULL,
  id_vendedor INT NULL,
  FOREIGN KEY (id_vendedor) REFERENCES vendedores(id)
);
INSERT INTO facturas_mal VALUES (1, 150000, 1);
INSERT INTO facturas_mal VALUES (2, 980000, NULL);   -- se acepta: venta hecha por "nadie"

SELECT * FROM facturas_mal WHERE id_vendedor IS NULL;

-- 4B. LA SOLUCIÓN: FK NOT NULL porque toda venta tiene vendedor
CREATE TABLE facturas (
  id          INT PRIMARY KEY,
  total       DECIMAL(12,2) NOT NULL,
  id_vendedor INT NOT NULL,
  FOREIGN KEY (id_vendedor) REFERENCES vendedores(id)
);
INSERT INTO facturas VALUES (1, 150000, 1);          -- OK
INSERT INTO facturas VALUES (2, 980000, NULL);       -- DEBE FALLAR
-- ERROR 1048: Column 'id_vendedor' cannot be null


-- ---------------------------------------------------------------------
-- ESCENARIO 5 · Importación masiva sin validar las llaves foráneas
-- ---------------------------------------------------------------------
CREATE TABLE cursos (
  id_curso VARCHAR(10) PRIMARY KEY,
  nombre   VARCHAR(60) NOT NULL
);
INSERT INTO cursos VALUES ('BD-101', 'Fundamentos de BD'), ('POO-101', 'Programación I');

CREATE TABLE inscripciones_curso (
  id         INT PRIMARY KEY,
  estudiante VARCHAR(60) NOT NULL,
  id_curso   VARCHAR(10) NOT NULL,
  FOREIGN KEY (id_curso) REFERENCES cursos(id_curso)
);

-- 5A. EL PROBLEMA: alguien desactiva las FK "para que cargue rápido"
SET FOREIGN_KEY_CHECKS = 0;
INSERT INTO inscripciones_curso VALUES
  (1, 'Ana',   'BD-101'),
  (2, 'Luis',  'XYZ'),       -- error de tipeo en el Excel
  (3, 'Sara',  'POO-101'),
  (4, 'Pedro', 'BD-1O1');    -- letra O en lugar de cero
SET FOREIGN_KEY_CHECKS = 1;
-- Volver a activarlas NO revisa lo que ya entró:

SELECT * FROM inscripciones_curso
WHERE id_curso NOT IN (SELECT id_curso FROM cursos);   -- 2 inscripciones huérfanas

-- 5B. LA SOLUCIÓN: importar con las FK activas; lo inválido se rechaza
DELETE FROM inscripciones_curso
WHERE id_curso NOT IN (SELECT id_curso FROM cursos);   -- limpiamos

INSERT INTO inscripciones_curso VALUES (5, 'Mario', 'XYZ');   -- DEBE FALLAR
-- ERROR 1452
