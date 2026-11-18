-- ============================================================
--  VISTAS (VIEWS) — Fundamentos de Bases de Datos
--  Caso: Red de cafeterías "Granos del Bosque"
--  Motor: MySQL 8.0.16+ / MariaDB 10.2+
--
--  REQUISITO: ejecutar antes taller14_cafeterias.sql
--  (crea la base granos_del_bosque con sus tablas y datos).
--  Este script inserta y modifica datos (secciones 4 y 5): para
--  ejecutarlo otra vez, corra de nuevo primero taller14_cafeterias.sql.
-- ============================================================
--
--  ¿QUÉ ES UNA VISTA?
--  Una vista es una CONSULTA GUARDADA CON NOMBRE. Se usa como si
--  fuera una tabla (SELECT * FROM la_vista), pero NO guarda datos:
--  cada vez que se consulta, el motor ejecuta el SELECT que la
--  define sobre las tablas reales. Por eso siempre muestra los
--  datos actualizados.
--
--  ¿PARA QUÉ SIRVE?
--   1. Simplificar: esconder JOINs y GROUP BY largos detrás de un
--      nombre fácil.
--   2. Reutilizar: escribir la consulta una vez y usarla muchas.
--   3. Seguridad: mostrar solo ciertas columnas o filas a ciertos
--      usuarios, sin darles acceso a las tablas completas.
--   4. Consistencia: todos calculan "ingresos" de la misma forma.
--
--  SINTAXIS BÁSICA
--   CREATE VIEW nombre_vista AS
--   SELECT ... ;
-- ============================================================
USE granos_del_bosque;

-- Limpieza por si el script se ejecuta más de una vez
DROP VIEW IF EXISTS v_carta_activa;

DROP VIEW IF EXISTS v_detalle_completo;

DROP VIEW IF EXISTS v_ingresos_por_sede;

DROP VIEW IF EXISTS v_ventas_por_metodo;

DROP VIEW IF EXISTS v_productos_snacks;

-- ============================================================
--  1. VISTA SENCILLA: filtrar filas y columnas
--  La carta que ve el cajero: solo productos activos, sin la
--  columna "activo" ni los ids internos.
-- ============================================================
CREATE VIEW
    v_carta_activa AS
SELECT
    nombre,
    precio
FROM
    producto
WHERE
    activo = 1;

-- Se consulta igual que una tabla
SELECT
    *
FROM
    v_carta_activa
ORDER BY
    precio DESC;

-- Y se le pueden aplicar WHERE, ORDER BY, funciones, etc.
SELECT
    COUNT(*) AS productos_en_carta,
    ROUND(AVG(precio), 0) AS precio_promedio
FROM
    v_carta_activa;

-- ============================================================
--  2. VISTA QUE ESCONDE UN JOIN
--  Une las 5 tablas una sola vez. Después nadie tiene que volver
--  a escribir los INNER JOIN.
-- ============================================================
CREATE VIEW
    v_detalle_completo AS
SELECT
    v.id_venta,
    v.fecha,
    v.metodo_pago,
    s.nombre AS sede,
    s.ciudad,
    c.nombre AS categoria,
    p.nombre AS producto,
    d.cantidad,
    d.precio_unitario,
    d.cantidad * d.precio_unitario AS subtotal
FROM
    venta v
    INNER JOIN sede s ON s.id_sede = v.id_sede
    INNER JOIN detalle_venta d ON d.id_venta = v.id_venta
    INNER JOIN producto p ON p.id_producto = d.id_producto
    INNER JOIN categoria c ON c.id_categoria = p.id_categoria;

-- Antes: 4 INNER JOIN. Ahora: una consulta corta.
SELECT
    *
FROM
    v_detalle_completo
WHERE
    id_venta = 6;

-- Agrupar sobre la vista es igual que agrupar sobre una tabla
SELECT
    categoria,
    SUM(cantidad) AS unidades,
    SUM(subtotal) AS ingresos
FROM
    v_detalle_completo
GROUP BY
    categoria
ORDER BY
    ingresos DESC;

SELECT
    ciudad,
    COUNT(DISTINCT id_venta) AS ventas,
    SUM(subtotal) AS ingresos
FROM
    v_detalle_completo
GROUP BY
    ciudad;

-- ============================================================
--  3. VISTA CON GROUP BY: un "reporte" listo
--  El gerente solo escribe: SELECT * FROM v_ingresos_por_sede;
-- ============================================================
CREATE VIEW
    v_ingresos_por_sede AS
SELECT
    s.nombre AS sede,
    COUNT(DISTINCT v.id_venta) AS numero_ventas,
    SUM(d.cantidad * d.precio_unitario) AS ingresos
FROM
    sede s
    INNER JOIN venta v ON v.id_sede = s.id_sede
    INNER JOIN detalle_venta d ON d.id_venta = v.id_venta
GROUP BY
    s.nombre;

SELECT
    *
FROM
    v_ingresos_por_sede
ORDER BY
    ingresos DESC;

-- Una vista también puede construirse SOBRE otra vista
CREATE VIEW
    v_ventas_por_metodo AS
SELECT
    metodo_pago,
    COUNT(DISTINCT id_venta) AS numero_ventas,
    SUM(subtotal) AS ingresos
FROM
    v_detalle_completo
GROUP BY
    metodo_pago;

SELECT
    *
FROM
    v_ventas_por_metodo
ORDER BY
    ingresos DESC;

-- ============================================================
--  4. LA VISTA NO GUARDA DATOS: siempre está al día
--  Registramos una venta nueva en las TABLAS y la vista la
--  muestra sin hacer nada más.
-- ============================================================
SELECT
    *
FROM
    v_ingresos_por_sede
WHERE
    sede = 'Candelaria';

-- antes
INSERT INTO
    venta (id_sede, fecha, metodo_pago)
VALUES
    (2, '2026-11-17', 'TARJETA');

INSERT INTO
    detalle_venta (id_venta, id_producto, cantidad, precio_unitario)
VALUES
    (LAST_INSERT_ID (), 5, 2, 9500.00);

SELECT
    *
FROM
    v_ingresos_por_sede
WHERE
    sede = 'Candelaria';

-- después: +1 venta, +19.000
-- ============================================================
--  5. VISTAS ACTUALIZABLES Y WITH CHECK OPTION
--  Si la vista sale de UNA sola tabla, sin GROUP BY, DISTINCT
--  ni funciones de agregación, se puede hacer INSERT/UPDATE
--  sobre ella y el cambio llega a la tabla real.
-- ============================================================
CREATE VIEW
    v_productos_snacks AS
SELECT
    id_producto,
    nombre,
    id_categoria,
    precio
FROM
    producto
WHERE
    id_categoria = 4 -- 4 = Snacks
WITH
    CHECK OPTION;

-- no deja salirse del WHERE
-- UPDATE a través de la vista: cambia la tabla producto
UPDATE v_productos_snacks
SET
    precio = 6000.00
WHERE
    nombre = 'Brownie';

SELECT
    nombre,
    precio
FROM
    producto
WHERE
    nombre = 'Brownie';

-- INSERT válido: es un snack (id_categoria = 4)
INSERT INTO
    v_productos_snacks (nombre, id_categoria, precio)
VALUES
    ('Muffin de arándanos', 4, 5000.00);

-- INSERT inválido: id_categoria = 1 no cumple el WHERE de la vista.
-- WITH CHECK OPTION lo rechaza (ERROR 1369 CHECK OPTION failed).
-- Descomente para probarlo:
-- INSERT INTO v_productos_snacks (nombre, id_categoria, precio)
-- VALUES ('Té chai', 1, 7000.00);
-- Las restricciones de la tabla SIGUEN aplicando a través de la vista:
-- CHECK (precio > 0) rechaza esto. Descomente para probarlo:
-- UPDATE v_productos_snacks SET precio = -100 WHERE nombre = 'Brownie';
-- Una vista con GROUP BY NO es actualizable: ¿a qué fila real le
-- cambiaría el "total"? Descomente para ver el error (1288):
-- UPDATE v_ingresos_por_sede SET ingresos = 0 WHERE sede = 'Candelaria';
-- ============================================================
--  6. ADMINISTRAR VISTAS
-- ============================================================
-- Listar tablas y vistas (columna Table_type = VIEW)
SHOW FULL TABLES
WHERE
    Table_type = 'VIEW';

-- Ver la consulta con la que se creó una vista
SHOW
CREATE VIEW
    v_carta_activa;

-- Modificar una vista: CREATE OR REPLACE (agregamos la categoría)
CREATE
OR REPLACE VIEW v_carta_activa AS
SELECT
    c.nombre AS categoria,
    p.nombre,
    p.precio
FROM
    producto p
    INNER JOIN categoria c ON c.id_categoria = p.id_categoria
WHERE
    p.activo = 1;

SELECT
    *
FROM
    v_carta_activa
ORDER BY
    categoria,
    precio;

-- Borrar una vista NO borra datos: solo borra la consulta guardada
DROP VIEW v_productos_snacks;

SELECT
    COUNT(*) AS productos_siguen_ahi
FROM
    producto;

-- ============================================================
--  RESUMEN
--   - Vista = SELECT guardado con nombre; se consulta como tabla.
--   - No almacena datos: refleja siempre el estado actual.
--   - Simplifica JOINs y GROUP BY, y limita qué se muestra.
--   - Solo es actualizable si viene de una tabla, sin agregaciones.
--   - WITH CHECK OPTION impide insertar/actualizar filas que la
--     vista no podría mostrar.
--   - DROP VIEW elimina la vista, nunca los datos de las tablas.
-- ============================================================