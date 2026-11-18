-- ============================================================
--  EJEMPLOS DE TABLAS MAL HECHAS (SIN CHECKS NI CONSTRAINTS)
--  Fundamentos de Bases de Datos — Caso "Granos del Bosque"
--  Motor: MySQL 8.0.16+ / MariaDB 10.2+
--
--  Idea: todas las tablas aceptan cualquier cosa. Cada INSERT
--  "malo" se ejecuta SIN ERROR, y luego las consultas de
--  agrupamiento devuelven resultados falsos.
--  Comparar con el script bueno: taller14_cafeterias.sql
-- ============================================================

DROP DATABASE IF EXISTS cafeteria_mal_hecha;
CREATE DATABASE cafeteria_mal_hecha;
USE cafeteria_mal_hecha;

-- ------------------------------------------------------------
--  TABLAS SIN RESTRICCIONES
--  Sin PRIMARY KEY, sin FOREIGN KEY, sin NOT NULL,
--  sin UNIQUE, sin CHECK, sin DEFAULT.
-- ------------------------------------------------------------
CREATE TABLE sede (
    id_sede  INT,
    nombre   VARCHAR(40),
    ciudad   VARCHAR(30)
);

CREATE TABLE producto (
    id_producto INT,
    nombre      VARCHAR(40),
    categoria   VARCHAR(30),      -- texto libre en vez de FK a categoria
    precio      DECIMAL(10,2),
    activo      INT
);

CREATE TABLE venta (
    id_venta    INT,
    id_sede     INT,
    fecha       VARCHAR(20),      -- fecha guardada como texto
    metodo_pago VARCHAR(20)
);

CREATE TABLE detalle_venta (
    id_venta        INT,
    id_producto     INT,
    cantidad        INT,
    precio_unitario DECIMAL(10,2)
);

-- ------------------------------------------------------------
--  DATOS "NORMALES"
-- ------------------------------------------------------------
INSERT INTO sede VALUES
(1, 'Bosque Popular', 'Bogotá'),
(2, 'Candelaria',     'Bogotá');

INSERT INTO producto VALUES
(1, 'Tinto',     'Bebidas calientes', 2500, 1),
(2, 'Capuchino', 'Bebidas calientes', 6500, 1),
(3, 'Pandebono', 'Panadería',         2800, 1);

INSERT INTO venta VALUES
(1, 1, '2026-11-03', 'EFECTIVO'),
(2, 2, '2026-11-04', 'NEQUI');

INSERT INTO detalle_venta VALUES
(1, 1, 2, 2500),
(1, 3, 2, 2800),
(2, 2, 1, 6500);

-- ============================================================
--  PROBLEMA 1. Sin PRIMARY KEY: identificadores repetidos
--  Dos sedes distintas con id 1. ¿A cuál pertenece la venta 1?
-- ============================================================
INSERT INTO sede VALUES (1, 'Cartagena Centro', 'Cartagena');

-- ============================================================
--  PROBLEMA 2. Sin UNIQUE: el mismo producto registrado dos veces
--  con precios distintos. ¿Cuál es el precio real del tinto?
-- ============================================================
INSERT INTO producto VALUES (4, 'Tinto', 'Bebidas calientes', 3000, 1);

-- ============================================================
--  PROBLEMA 3. Sin NOT NULL: filas a medias
-- ============================================================
INSERT INTO producto VALUES (5, NULL, NULL, NULL, NULL);
INSERT INTO venta    VALUES (NULL, 2, NULL, NULL);

-- ============================================================
--  PROBLEMA 4. Sin CHECK: valores imposibles para el negocio
-- ============================================================
INSERT INTO producto VALUES (6, 'Croissant', 'Panadería', -4500, 1);  -- precio negativo
INSERT INTO producto VALUES (7, 'Brownie',   'Snacks',     5500, 7);  -- activo = 7 (¿?)
INSERT INTO detalle_venta VALUES (2, 3, -10, 2800);                   -- cantidad negativa
INSERT INTO detalle_venta VALUES (2, 1,   0, 2500);                   -- cantidad cero

-- Métodos de pago escritos "como sea": para SQL son 5 valores distintos
INSERT INTO venta VALUES
(3, 1, '2026-11-05', 'nequi'),
(4, 2, '2026-11-06', 'Nequi '),
(5, 1, '2026-11-07', 'NEKI'),
(6, 2, '2026-11-08', 'Efectivo'),
(7, 1, '2026-11-09', 'bitcoin');

-- Categorías en texto libre: "Panadería" vs "panaderia"
INSERT INTO producto VALUES (8, 'Almojábana', 'panaderia', 2800, 1);

-- ============================================================
--  PROBLEMA 5. Sin FOREIGN KEY: referencias a cosas que no existen
-- ============================================================
INSERT INTO venta         VALUES (8, 99, '2026-11-10', 'TARJETA');  -- la sede 99 no existe
INSERT INTO detalle_venta VALUES (8, 500, 3, 4000);                 -- el producto 500 no existe
INSERT INTO detalle_venta VALUES (777, 1, 5, 2500);                 -- la venta 777 no existe

-- Borrar un "padre" deja huérfanos a sus "hijos"
DELETE FROM sede WHERE nombre = 'Candelaria';   -- la venta 2 y la 4 quedan apuntando a nada

-- ============================================================
--  PROBLEMA 6. Sin PK compuesta en detalle_venta: filas duplicadas
--  El mismo producto, en la misma venta, dos veces.
-- ============================================================
INSERT INTO detalle_venta VALUES (1, 1, 2, 2500);

-- ============================================================
--  PROBLEMA 7. Fecha como texto: formatos mezclados
-- ============================================================
INSERT INTO venta VALUES (9, 1, '12/11/2026', 'EFECTIVO');
INSERT INTO venta VALUES (10, 1, 'ayer',      'EFECTIVO');


-- ############################################################
--  CONSECUENCIAS: LAS CONSULTAS DE AGRUPAMIENTO MIENTEN
-- ############################################################

-- C1. ¿Cuántas ventas por método de pago?
--     "NEKI", "bitcoin" y NULL aparecen como métodos de pago.
--     (Mayúsculas/espacios: MySQL/MariaDB por defecto no distinguen
--     'nequi' de 'NEQUI', pero otros motores sí y los separarían.)
SELECT metodo_pago, COUNT(*) AS ventas
FROM venta
GROUP BY metodo_pago
ORDER BY ventas DESC;

-- C2. ¿Cuántas ventas hay?  COUNT(*) y COUNT(id_venta) no coinciden
--     porque una venta no tiene id (NULL).
SELECT COUNT(*) AS filas, COUNT(id_venta) AS ventas_con_id
FROM venta;

-- C3. Precio promedio, mínimo y máximo de la carta:
--     el MIN es negativo y AVG ignora en silencio el precio NULL.
SELECT MIN(precio) AS minimo, MAX(precio) AS maximo,
       ROUND(AVG(precio), 0) AS promedio
FROM producto;

-- C4. Unidades vendidas: la cantidad -10 resta y el duplicado suma de más.
SELECT SUM(cantidad) AS unidades_vendidas
FROM detalle_venta;

-- C5. Productos por categoría: "Panadería" y "panaderia" se cuentan
--     aparte (según la intercalación), y aparece una categoría NULL.
SELECT categoria, COUNT(*) AS productos
FROM producto
GROUP BY categoria;

-- C6. Ingresos por sede: el INNER JOIN duplica la venta 1 (dos sedes
--     con id 1) y descarta en silencio las ventas huérfanas.
SELECT s.nombre, SUM(d.cantidad * d.precio_unitario) AS ingresos
FROM sede s
INNER JOIN venta v         ON v.id_sede  = s.id_sede
INNER JOIN detalle_venta d ON d.id_venta = v.id_venta
GROUP BY s.nombre;

-- C7. Ventas de noviembre: las fechas en texto no se pueden filtrar bien.
SELECT COUNT(*) AS ventas_noviembre
FROM venta
WHERE fecha BETWEEN '2026-11-01' AND '2026-11-30';
