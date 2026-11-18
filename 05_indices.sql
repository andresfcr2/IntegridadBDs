-- =====================================================================
--  05 · ÍNDICES — concepto, tipos, compuesto, EXPLAIN y errores comunes
--  Fundamentos de Bases de Datos · Universidad Libre · Andrés Castaño
--  MySQL 8.0.16+ / MariaDB 10.4+
--
--  ANTES DE EMPEZAR: ejecute completo  tienda_indices.sql
--  (crea 20 000 clientes, 5 000 productos y 200 000 pedidos).
--  Si quiere repetir esta práctica desde cero, vuelva a ejecutarlo.
--
--  En cada EXPLAIN mire cuatro columnas:
--    type  -> ALL = recorre toda la tabla (lo peor); range, ref, const = usa índice
--    key   -> el índice que eligió (NULL = ninguno)
--    rows  -> cuántas filas estima leer
--    Extra -> "Using filesort" = tuvo que ordenar aparte
-- =====================================================================

USE tienda_indices;


-- ---------------------------------------------------------------------
-- 1 · ¿Qué índices existen? (InnoDB crea uno por cada PK y FK)
-- ---------------------------------------------------------------------
SHOW INDEX FROM cliente;    -- solo PRIMARY
SHOW INDEX FROM pedido;     -- PRIMARY y fk_pedido_cliente (creado por la FOREIGN KEY)


-- ---------------------------------------------------------------------
-- 2 · Sin índice vs con índice (UNIQUE) — búsqueda por correo
-- ---------------------------------------------------------------------
EXPLAIN SELECT * FROM cliente WHERE email = 'natalia.mora1234@correo.com';
-- type = ALL, key = NULL, rows ≈ 20 000  -> lee toda la tabla

SELECT * FROM cliente WHERE email = 'natalia.mora1234@correo.com';

CREATE UNIQUE INDEX uq_cliente_email ON cliente(email);

EXPLAIN SELECT * FROM cliente WHERE email = 'natalia.mora1234@correo.com';
-- type = const, key = uq_cliente_email, rows = 1  -> una sola fila

-- El índice UNIQUE además impide correos repetidos:
INSERT INTO cliente VALUES
  (20001, '9999999999', 'Natalia', 'Mora', 'natalia.mora1234@correo.com', 'Cali', NOW());
-- DEBE FALLAR: ERROR 1062 Duplicate entry ... for key 'uq_cliente_email'


-- ---------------------------------------------------------------------
-- 3 · Índice normal (INDEX) — admite valores repetidos
-- ---------------------------------------------------------------------
EXPLAIN SELECT id, nombre, apellido FROM cliente WHERE ciudad = 'Pereira';
-- type = ALL

CREATE INDEX idx_cliente_ciudad ON cliente(ciudad);

EXPLAIN SELECT id, nombre, apellido FROM cliente WHERE ciudad = 'Pereira';
-- type = ref, key = idx_cliente_ciudad, rows ≈ 2 000 (solo los de Pereira)


-- ---------------------------------------------------------------------
-- 4 · Índice compuesto — panel "Mis pedidos" de un cliente
-- ---------------------------------------------------------------------
-- Últimos 10 pedidos entregados del cliente 1500, del más reciente al más antiguo
EXPLAIN
SELECT id, fecha_pedido, total
FROM pedido
WHERE cliente_id = 1500 AND estado = 'ENTREGADO'
ORDER BY fecha_pedido DESC
LIMIT 10;
-- key = fk_pedido_cliente, Extra = Using where; Using filesort  -> ordena aparte

CREATE INDEX idx_cli_est_fecha ON pedido(cliente_id, estado, fecha_pedido);

EXPLAIN
SELECT id, fecha_pedido, total
FROM pedido
WHERE cliente_id = 1500 AND estado = 'ENTREGADO'
ORDER BY fecha_pedido DESC
LIMIT 10;
-- key = idx_cli_est_fecha, ref = const,const, desaparece "Using filesort"

-- Regla del prefijo izquierdo: sin la PRIMERA columna el índice no sirve
EXPLAIN SELECT id, fecha_pedido FROM pedido WHERE estado = 'PENDIENTE';
-- rows ≈ 200 000: recorre todo (type ALL o index); el índice no le permite saltar

-- Para la bodega ("pendientes más antiguos primero") se necesita otro índice:
CREATE INDEX idx_estado_fecha ON pedido(estado, fecha_pedido);

EXPLAIN
SELECT id, cliente_id, fecha_pedido
FROM pedido
WHERE estado = 'PENDIENTE'
ORDER BY fecha_pedido
LIMIT 20;
-- key = idx_estado_fecha, sin filesort


-- ---------------------------------------------------------------------
-- 5 · ERROR 1: función sobre la columna — reporte de ventas de diciembre 2025
-- ---------------------------------------------------------------------
CREATE INDEX idx_pedido_fecha ON pedido(fecha_pedido);

EXPLAIN SELECT COUNT(*), SUM(total) FROM pedido
WHERE YEAR(fecha_pedido) = 2025 AND MONTH(fecha_pedido) = 12;
-- type = ALL, rows ≈ 200 000: YEAR() y MONTH() se calculan fila por fila,
-- el índice sobre fecha_pedido no se puede usar

EXPLAIN SELECT COUNT(*), SUM(total) FROM pedido
WHERE fecha_pedido >= '2025-12-01' AND fecha_pedido < '2026-01-01';
-- type = range, key = idx_pedido_fecha, rows ≈ 4 400: va directo a diciembre

-- Mismo resultado, distinta forma de llegar:
SELECT COUNT(*), SUM(total) FROM pedido
WHERE YEAR(fecha_pedido) = 2025 AND MONTH(fecha_pedido) = 12;
SELECT COUNT(*), SUM(total) FROM pedido
WHERE fecha_pedido >= '2025-12-01' AND fecha_pedido < '2026-01-01';


-- ---------------------------------------------------------------------
-- 6 · ERROR 2: LIKE con comodín al inicio — buscador de productos
-- ---------------------------------------------------------------------
CREATE INDEX idx_producto_nombre ON producto(nombre);

EXPLAIN SELECT id, nombre, precio FROM producto WHERE nombre LIKE 'Taladro%';
-- type = range: el índice sirve, sabe dónde empieza "Taladro"

EXPLAIN SELECT id, nombre, precio FROM producto WHERE nombre LIKE '%taladro%';
-- type = ALL: con % al inicio puede estar en cualquier parte

-- Para buscar palabras dentro del texto: índice FULLTEXT
CREATE FULLTEXT INDEX ft_producto_nombre ON producto(nombre);

EXPLAIN SELECT id, nombre, precio FROM producto
WHERE MATCH(nombre) AGAINST ('taladro');
-- type = fulltext, key = ft_producto_nombre

SELECT id, nombre, precio FROM producto
WHERE MATCH(nombre) AGAINST ('taladro')
LIMIT 10;


-- ---------------------------------------------------------------------
-- 7 · ERROR 3: indexar todo "por si acaso" — el costo de escribir
-- ---------------------------------------------------------------------
-- Dos copias vacías de pedido: una solo con PK y otra con 5 índices extra
CREATE TABLE pedido_pocos_idx (
  id INT PRIMARY KEY, cliente_id INT NOT NULL, estado VARCHAR(12) NOT NULL,
  fecha_pedido DATETIME NOT NULL, total DECIMAL(12,2) NOT NULL
);
CREATE TABLE pedido_muchos_idx LIKE pedido_pocos_idx;
CREATE INDEX i1 ON pedido_muchos_idx(cliente_id);
CREATE INDEX i2 ON pedido_muchos_idx(estado);
CREATE INDEX i3 ON pedido_muchos_idx(fecha_pedido);
CREATE INDEX i4 ON pedido_muchos_idx(total);
CREATE INDEX i5 ON pedido_muchos_idx(cliente_id, estado, fecha_pedido);

-- Copie los 200 000 pedidos en cada una y compare el tiempo (Duration)
INSERT INTO pedido_pocos_idx  SELECT * FROM pedido;
INSERT INTO pedido_muchos_idx SELECT * FROM pedido;
-- La segunda tarda más: cada fila se escribe en la tabla y en 5 índices.

DROP TABLE pedido_pocos_idx;
DROP TABLE pedido_muchos_idx;

-- Resumen de los índices creados en esta práctica
SHOW INDEX FROM cliente;
SHOW INDEX FROM pedido;
SHOW INDEX FROM producto;
