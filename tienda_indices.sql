-- =====================================================================
--  tienda_indices.sql
--  Fundamentos de Bases de Datos · Universidad Libre · Andrés Castaño
--  Base de datos con volumen para el Ítem 3 (índices).
--  20 000 clientes · 5 000 productos · 200 000 pedidos
--  Compatible con MySQL 8.0.16+ y MariaDB 10.4+
--  Tiempo de carga aproximado: 10 a 40 segundos.
-- =====================================================================

DROP DATABASE IF EXISTS tienda_indices;
CREATE DATABASE tienda_indices CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
USE tienda_indices;

-- ---------------------------------------------------------------------
-- Tablas (solo PK y FK; los índices secundarios los crean ustedes)
-- ---------------------------------------------------------------------
CREATE TABLE cliente (
  id          INT PRIMARY KEY,
  documento   VARCHAR(10)  NOT NULL,
  nombre      VARCHAR(60)  NOT NULL,
  apellido    VARCHAR(60)  NOT NULL,
  email       VARCHAR(120) NOT NULL,
  ciudad      VARCHAR(40)  NOT NULL,
  creado_en   DATETIME     NOT NULL
);

CREATE TABLE producto (
  id          INT PRIMARY KEY,
  sku         VARCHAR(12)   NOT NULL,
  nombre      VARCHAR(120)  NOT NULL,
  categoria   VARCHAR(40)   NOT NULL,
  precio      DECIMAL(12,2) NOT NULL
);

CREATE TABLE pedido (
  id            INT PRIMARY KEY,
  cliente_id    INT           NOT NULL,
  estado        VARCHAR(12)   NOT NULL,
  fecha_pedido  DATETIME      NOT NULL,
  total         DECIMAL(12,2) NOT NULL,
  CONSTRAINT fk_pedido_cliente FOREIGN KEY (cliente_id) REFERENCES cliente(id)
);

-- ---------------------------------------------------------------------
-- Tabla auxiliar de números 0..999 (solo para generar datos)
-- ---------------------------------------------------------------------
CREATE TABLE digito (d INT PRIMARY KEY);
INSERT INTO digito VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9);

CREATE TABLE numero (n INT PRIMARY KEY);
INSERT INTO numero (n)
SELECT a.d + b.d * 10 + c.d * 100
FROM digito a CROSS JOIN digito b CROSS JOIN digito c;

-- ---------------------------------------------------------------------
-- Clientes: 20 000
-- ---------------------------------------------------------------------
INSERT INTO cliente (id, documento, nombre, apellido, email, ciudad, creado_en)
SELECT x.id,
       CAST(1000000000 + x.id * 37 AS CHAR),
       ELT(1 + x.id % 20, 'Ana','Luis','Camila','Andres','Valentina','Juan','Daniela','Carlos',
           'Laura','Santiago','Paula','Felipe','Sofia','Diego','Natalia','Sebastian',
           'Mariana','Julian','Carolina','Mateo'),
       ELT(1 + (x.id DIV 20) % 20, 'Ruiz','Mora','Gomez','Rodriguez','Martinez','Lopez','Garcia',
           'Hernandez','Diaz','Torres','Ramirez','Vargas','Rojas','Castro','Ortiz','Suarez',
           'Pardo','Rincon','Acosta','Salazar'),
       '',
       ELT(1 + (x.id * 7) % 10, 'Bogota','Medellin','Cali','Barranquilla','Cartagena',
           'Bucaramanga','Pereira','Manizales','Cucuta','Ibague'),
       DATE_ADD('2021-01-01', INTERVAL (x.id * 13) % 1800 DAY)
FROM (SELECT a.n * 1000 + b.n + 1 AS id
      FROM numero a CROSS JOIN numero b
      WHERE a.n < 20) x;

UPDATE cliente
SET email = LOWER(CONCAT(nombre, '.', apellido, id, '@correo.com'));

-- ---------------------------------------------------------------------
-- Productos: 5 000
-- ---------------------------------------------------------------------
INSERT INTO producto (id, sku, nombre, categoria, precio)
SELECT x.id,
       CONCAT('SKU-', LPAD(x.id, 6, '0')),
       CONCAT(ELT(1 + x.id % 10, 'Taladro percutor','Pulidora angular','Martillo de una',
                  'Juego de destornilladores','Cinta metrica','Llave inglesa','Sierra circular',
                  'Nivel de burbuja','Pistola de silicona','Lijadora orbital'),
              ' ',
              ELT(1 + (x.id DIV 10) % 8, 'Bosch','DeWalt','Stanley','Truper','Makita',
                  'Black+Decker','Total','Ingco'),
              ' ref ', x.id),
       ELT(1 + x.id % 5, 'Herramienta electrica','Herramienta manual','Medicion',
           'Corte','Acabados'),
       ROUND(15000 + (x.id * 7919) % 885000, -2)
FROM (SELECT a.n * 1000 + b.n + 1 AS id
      FROM numero a CROSS JOIN numero b
      WHERE a.n < 5) x;

-- ---------------------------------------------------------------------
-- Pedidos: 200 000 (cliente, estado, fecha y total pseudoaleatorios)
-- ---------------------------------------------------------------------
INSERT INTO pedido (id, cliente_id, estado, fecha_pedido, total)
SELECT x.id,
       1 + (x.id * 7919) % 20000,
       CASE
         WHEN x.id % 100 < 70 THEN 'ENTREGADO'
         WHEN x.id % 100 < 80 THEN 'ENVIADO'
         WHEN x.id % 100 < 88 THEN 'PAGADO'
         WHEN x.id % 100 < 95 THEN 'PENDIENTE'
         ELSE 'CANCELADO'
       END,
       DATE_ADD(DATE_ADD('2023-01-01', INTERVAL (x.id * 104729) % 1400 DAY),
                INTERVAL (x.id * 31) % 86400 SECOND),
       ROUND(20000 + (x.id * 6007) % 2500000, -2)
FROM (SELECT a.n * 1000 + b.n + 1 AS id
      FROM numero a CROSS JOIN numero b
      WHERE a.n < 200) x;

DROP TABLE numero;
DROP TABLE digito;

ANALYZE TABLE cliente, producto, pedido;

-- Verificación: debe mostrar 20000, 5000 y 200000
SELECT (SELECT COUNT(*) FROM cliente)  AS clientes,
       (SELECT COUNT(*) FROM producto) AS productos,
       (SELECT COUNT(*) FROM pedido)   AS pedidos;
