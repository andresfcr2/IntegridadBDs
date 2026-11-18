-- =====================================================================
--  01 · INTEGRIDAD DE ENTIDAD — seis escenarios
--  Fundamentos de Bases de Datos · Universidad Libre · Andrés Castaño
--  MySQL 8.0.16+ / MariaDB 10.4+
--
--  CÓMO USARLO
--  Ejecute sentencia por sentencia (Ctrl+Enter en Workbench).
--  Las líneas marcadas con  -- DEBE FALLAR  producen un error a propósito:
--  ese error ES la demostración. Lea el mensaje y continúe con la siguiente.
--  (Para correr todo de una vez: en Workbench active
--   Query > "Continue on SQL Query Error", o en consola: mysql --force)
-- =====================================================================

DROP DATABASE IF EXISTS demo_entidad;
CREATE DATABASE demo_entidad CHARACTER SET utf8mb4;
USE demo_entidad;


-- ---------------------------------------------------------------------
-- ESCENARIO 1 · Llave primaria con valor NULL
-- ---------------------------------------------------------------------
CREATE TABLE usuarios (
  id_usuario INT PRIMARY KEY,          -- PRIMARY KEY implica NOT NULL
  nombre     VARCHAR(60) NOT NULL
);

INSERT INTO usuarios VALUES (1, 'Ana');                 -- OK

INSERT INTO usuarios VALUES (NULL, 'Carlos');           -- DEBE FALLAR
-- ERROR 1048: Column 'id_usuario' cannot be null

SELECT * FROM usuarios;                                 -- Carlos no quedó guardado


-- ---------------------------------------------------------------------
-- ESCENARIO 2 · Llave primaria duplicada
-- ---------------------------------------------------------------------
CREATE TABLE productos (
  codigo_sku VARCHAR(10) PRIMARY KEY,
  nombre     VARCHAR(60) NOT NULL
);

INSERT INTO productos VALUES ('PROD-100', 'Teclado');   -- OK

INSERT INTO productos VALUES ('PROD-100', 'Monitor');   -- DEBE FALLAR
-- ERROR 1062: Duplicate entry 'PROD-100' for key 'PRIMARY'

SELECT * FROM productos WHERE codigo_sku = 'PROD-100';  -- devuelve una sola fila


-- ---------------------------------------------------------------------
-- ESCENARIO 3 · Llave primaria compuesta con una parte NULL
-- ---------------------------------------------------------------------
CREATE TABLE pedido (
  id_pedido INT PRIMARY KEY
);
INSERT INTO pedido VALUES (50);

CREATE TABLE detalle_pedido (
  id_pedido   INT,
  id_producto INT,
  cantidad    INT NOT NULL,
  PRIMARY KEY (id_pedido, id_producto)   -- ambas columnas quedan NOT NULL
);

INSERT INTO detalle_pedido VALUES (50, 7, 2);           -- OK

INSERT INTO detalle_pedido VALUES (50, NULL, 1);        -- DEBE FALLAR
-- ERROR 1048: Column 'id_producto' cannot be null

DESCRIBE detalle_pedido;   -- observe la columna Null = NO en las dos columnas de la PK


-- ---------------------------------------------------------------------
-- ESCENARIO 4 · Llave compuesta duplicada
-- ---------------------------------------------------------------------
-- 4A. EL PROBLEMA: la tabla usa un id propio y NO protege la combinación
CREATE TABLE inscripciones_mal (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  id_estudiante INT NOT NULL,
  id_materia    INT NOT NULL
);

INSERT INTO inscripciones_mal (id_estudiante, id_materia) VALUES (10, 502);
INSERT INTO inscripciones_mal (id_estudiante, id_materia) VALUES (10, 502);  -- se acepta

SELECT * FROM inscripciones_mal;   -- el estudiante 10 aparece DOS veces en la materia 502

-- 4B. LA SOLUCIÓN: llave primaria compuesta
CREATE TABLE inscripciones (
  id_estudiante INT NOT NULL,
  id_materia    INT NOT NULL,
  PRIMARY KEY (id_estudiante, id_materia)
);

INSERT INTO inscripciones VALUES (10, 502);             -- OK
INSERT INTO inscripciones VALUES (10, 503);             -- OK: otra materia
INSERT INTO inscripciones VALUES (11, 502);             -- OK: otro estudiante

INSERT INTO inscripciones VALUES (10, 502);             -- DEBE FALLAR
-- ERROR 1062: Duplicate entry '10-502' for key 'PRIMARY'

-- 4C. Si se quiere conservar el id propio, se protege la combinación con UNIQUE
DELETE FROM inscripciones_mal WHERE id = 2;             -- limpiamos el duplicado
ALTER TABLE inscripciones_mal
  ADD CONSTRAINT uq_inscripcion UNIQUE (id_estudiante, id_materia);

INSERT INTO inscripciones_mal (id_estudiante, id_materia) VALUES (10, 502);  -- DEBE FALLAR
-- ERROR 1062: Duplicate entry '10-502' for key 'uq_inscripcion'


-- ---------------------------------------------------------------------
-- ESCENARIO 5 · Tabla sin llave primaria
-- ---------------------------------------------------------------------
-- 5A. EL PROBLEMA
CREATE TABLE clientes_backup (
  nombre   VARCHAR(60),
  telefono VARCHAR(15)
);

INSERT INTO clientes_backup VALUES ('Ana Pérez', '6015551234');
INSERT INTO clientes_backup VALUES ('Ana Pérez', '6015551234');  -- fila idéntica, se acepta

-- Se quiere cambiar el teléfono de UNA de las dos Ana Pérez:
UPDATE clientes_backup
SET telefono = '3001112233'
WHERE nombre = 'Ana Pérez';
-- Mire el mensaje: "2 row(s) affected". Se cambiaron las DOS.

SELECT * FROM clientes_backup;

-- 5B. LA SOLUCIÓN: agregar una llave primaria
ALTER TABLE clientes_backup
  ADD id INT AUTO_INCREMENT PRIMARY KEY FIRST;

SELECT * FROM clientes_backup;          -- ahora cada fila tiene su id (1 y 2)

UPDATE clientes_backup SET telefono = '6015551234' WHERE id = 1;   -- solo 1 fila
SELECT * FROM clientes_backup;


-- ---------------------------------------------------------------------
-- ESCENARIO 6 · UPDATE de la llave primaria a un valor inválido
-- ---------------------------------------------------------------------
-- 6A. Documento como llave primaria
CREATE TABLE empleados (
  numero_documento VARCHAR(10) PRIMARY KEY,
  nombre           VARCHAR(60) NOT NULL
);

INSERT INTO empleados VALUES ('1010', 'Laura Gómez');
INSERT INTO empleados VALUES ('2020', 'Diego Rojas');

UPDATE empleados SET numero_documento = '2020' WHERE numero_documento = '1010';  -- DEBE FALLAR
-- ERROR 1062: Duplicate entry '2020' for key 'PRIMARY'

UPDATE empleados SET numero_documento = NULL WHERE numero_documento = '1010';    -- DEBE FALLAR
-- ERROR 1048: Column 'numero_documento' cannot be null

-- 6B. MEJOR DISEÑO: un id que nunca cambia y el documento como UNIQUE.
--     Si el documento se digitó mal, se corrige sin tocar la llave.
CREATE TABLE empleados_v2 (
  id               INT AUTO_INCREMENT PRIMARY KEY,
  numero_documento VARCHAR(10) NOT NULL UNIQUE,
  nombre           VARCHAR(60) NOT NULL
);

INSERT INTO empleados_v2 (numero_documento, nombre) VALUES ('1010', 'Laura Gómez');
INSERT INTO empleados_v2 (numero_documento, nombre) VALUES ('2020', 'Diego Rojas');

UPDATE empleados_v2 SET numero_documento = '1011' WHERE id = 1;   -- OK: corrección
UPDATE empleados_v2 SET numero_documento = '2020' WHERE id = 1;   -- DEBE FALLAR (UNIQUE)
-- ERROR 1062: Duplicate entry '2020' for key 'numero_documento'

SELECT * FROM empleados_v2;
