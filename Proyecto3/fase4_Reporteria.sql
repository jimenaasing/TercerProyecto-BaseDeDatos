-- Fase 4: Reportería 

-- DATOS DE PRUEBA
RESET ROLE;
INSERT INTO proveedor VALUES (1,'TechSup','Ana Mora','2222-0000','Costa Rica');
INSERT INTO almacen VALUES (1,'Almacén Central','San José'),(2,'Bodega Norte','Alajuela');
INSERT INTO categoria VALUES (1,'Hogar'),(2,'Electrónica');
INSERT INTO subcategoria VALUES (1,'Cocina',1),(2,'Periféricos',2);
INSERT INTO producto VALUES
    ('ELE-101','Monitor Gamer 27" 144Hz',280,200,1,2),
    ('ELE-102','Teclado Mecánico RGB',65,40,1,2),
    ('ELE-105','Cable DisplayPort 1.4',25,8,1,2),
    ('HOG-001','Sartén antiadherente',30,15,1,1);
INSERT INTO inventario VALUES
    (1,10,15,20,'2026-01-05',1,'ELE-101'),
    (2,10,4,10,'2026-01-05',1,'ELE-102'),
    (3,5,35,10,'2026-01-05',1,'ELE-105'),
    (4,8,0,NULL,NULL,1,'HOG-001'),
    (5,5,6,NULL,NULL,2,'ELE-101'),
    (6,3,20,NULL,NULL,2,'HOG-001');
INSERT INTO movimientoinventario VALUES
    (1,'ENTRADA','2026-01-02',40,1,'ELE-101'),
    (2,'SALIDA','2026-02-10',45,1,'ELE-101'),
    (3,'SALIDA','2026-02-11',28,1,'ELE-102'),
    (4,'SALIDA','2026-03-01',3,1,'ELE-105'),
    (5,'SALIDA','2026-03-31 18:00',5,2,'ELE-101'),
    (6,'SALIDA','2026-04-15',2,1,'ELE-101');

-- 

RESET ROLE;

--1. Reporte 1: valoración de inventario y reabastecimiento
CREATE OR REPLACE FUNCTION sp_reporte_valoracion_reabastecimiento(
    p_id_almacen INTEGER,
    p_margen_alerta NUMERIC(5,2)
)
RETURNS TABLE (
    id_almacen INTEGER,
    almacen VARCHAR,
    sku VARCHAR,
    producto VARCHAR,
    categoria VARCHAR,
    stock_actual INTEGER,
    stock_minimo INTEGER,
    stock_optimo INTEGER,
    valor_inventario NUMERIC,
    valor_total_almacen NUMERIC,
    estado VARCHAR,
    cantidad_a_pedir INTEGER,
    costo_reposicion NUMERIC
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Validar parámetros
    IF p_margen_alerta IS NULL OR p_margen_alerta < 0 OR p_margen_alerta > 100 THEN
        RAISE EXCEPTION 'El margen de alerta debe estar entre 0 y 100. Operación cancelada.';
    END IF;

    IF p_id_almacen IS NOT NULL THEN
        IF NOT EXISTS (SELECT 1 FROM almacen a WHERE a.id_almacen = p_id_almacen) THEN
            RAISE EXCEPTION 'El almacén con ID % no existe. Operación cancelada.', p_id_almacen;
        END IF;
    END IF;

    -- Tabla temporal para guardar los cálculos
    CREATE TEMP TABLE tmp_reporte1 (
        id_almacen INTEGER,
        almacen VARCHAR(60),
        sku VARCHAR(20),
        producto VARCHAR(100),
        categoria VARCHAR(40),
        stock_actual INTEGER,
        stock_minimo INTEGER,
        stock_optimo INTEGER,
        costo_unitario NUMERIC(12,2),
        valor_inventario NUMERIC(14,2),
        estado VARCHAR(20),
        cantidad_a_pedir INTEGER,
        costo_reposicion NUMERIC(14,2),
        prioridad INTEGER
    );

    -- Paso 1: cargar el inventario (aquí aplica el RLS)
    -- El stock óptimo es el doble del stock mínimo
    INSERT INTO tmp_reporte1 (id_almacen, almacen, sku, producto, categoria,
                              stock_actual, stock_minimo, stock_optimo,
                              costo_unitario, valor_inventario)
    SELECT i.id_almacen, a.nombre_almacen, p.sku, p.nombre_producto, c.nombre_categoria,
           i.stock_actual, i.stock_minimo, i.stock_minimo * 2,
           p.costo_unitario, i.stock_actual * p.costo_unitario
    FROM inventario i
    JOIN almacen a ON a.id_almacen = i.id_almacen
    JOIN producto p ON p.sku = i.sku
    JOIN subcategoria s ON s.id_subcategoria = p.id_subcategoria
    JOIN categoria c ON c.id_categoria = s.id_categoria
    WHERE p_id_almacen IS NULL OR i.id_almacen = p_id_almacen;

    -- Paso 2: estado de cada producto
    -- Crítico: está por debajo del mínimo más el margen de alerta
    UPDATE tmp_reporte1 t
    SET estado = CASE
                     WHEN t.stock_actual = 0 THEN 'Agotado'
                     WHEN t.stock_actual <= t.stock_minimo + (t.stock_minimo * p_margen_alerta / 100) THEN 'Crítico'
                     ELSE 'Óptimo'
                 END;

    -- Paso 3: cantidad a pedir y prioridad
    UPDATE tmp_reporte1 t
    SET cantidad_a_pedir = CASE
                               WHEN t.estado = 'Óptimo' THEN 0
                               ELSE t.stock_optimo - t.stock_actual
                           END,
        prioridad = CASE
                        WHEN t.estado = 'Agotado' THEN 1
                        WHEN t.estado = 'Crítico' THEN 2
                        ELSE 3
                    END;

    -- Paso 4: costo de reposición
    UPDATE tmp_reporte1 t
    SET costo_reposicion = t.cantidad_a_pedir * t.costo_unitario;

    -- Paso 5: valor total del inventario por almacén
    CREATE TEMP TABLE tmp_total_almacen (
        id_almacen INTEGER,
        valor_total NUMERIC(14,2)
    );

    INSERT INTO tmp_total_almacen (id_almacen, valor_total)
    SELECT t.id_almacen, SUM(t.valor_inventario)
    FROM tmp_reporte1 t
    GROUP BY t.id_almacen;

    -- Resultado ordenado por prioridad
    RETURN QUERY
    SELECT t.id_almacen, t.almacen, t.sku, t.producto, t.categoria,
           t.stock_actual, t.stock_minimo, t.stock_optimo,
           t.valor_inventario, ta.valor_total,
           t.estado, t.cantidad_a_pedir, t.costo_reposicion
    FROM tmp_reporte1 t
    JOIN tmp_total_almacen ta ON ta.id_almacen = t.id_almacen
    ORDER BY t.prioridad, t.costo_reposicion DESC;

    -- Borrar tablas temporales
    DROP TABLE tmp_reporte1;
    DROP TABLE tmp_total_almacen;
END;
$$;


--2. Reporte 2: rotación de inventario en un rango de fechas
CREATE OR REPLACE FUNCTION sp_reporte_rotacion_inventario(
    p_fecha_inicio DATE,
    p_fecha_fin DATE,
    p_id_categoria INTEGER
)
RETURNS TABLE (
    sku VARCHAR,
    producto VARCHAR,
    categoria VARCHAR,
    stock_promedio NUMERIC,
    total_salidas_unidades INTEGER,
    valor_total_salidas_usd NUMERIC,
    promedio_diario_salidas NUMERIC,
    dias_inventario_restante INTEGER,
    clasificacion_abc VARCHAR
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_dias INTEGER;
    v_valor_total NUMERIC;
    v_acumulado NUMERIC := 0;
    v_fila RECORD;
BEGIN
    -- Validar parámetros
    IF p_fecha_inicio > p_fecha_fin THEN
        RAISE EXCEPTION 'La fecha de inicio (%) no puede ser posterior a la fecha fin (%). Operación cancelada.',
              p_fecha_inicio, p_fecha_fin;
    END IF;

    -- Cantidad de días del período
    v_dias := p_fecha_fin - p_fecha_inicio + 1;

    -- Tabla temporal para guardar los cálculos
    CREATE TEMP TABLE tmp_reporte2 (
        sku VARCHAR(20),
        producto VARCHAR(100),
        categoria VARCHAR(40),
        precio NUMERIC(12,2),
        stock_actual INTEGER,
        total_entradas INTEGER,
        total_salidas INTEGER,
        stock_promedio NUMERIC(10,1),
        valor_salidas NUMERIC(14,2),
        promedio_diario NUMERIC(10,2),
        dias_restantes INTEGER,
        clasificacion VARCHAR(30)
    );

    -- Paso 1: cargar productos con su stock actual (aquí aplica el RLS)
    INSERT INTO tmp_reporte2 (sku, producto, categoria, precio, stock_actual)
    SELECT p.sku, p.nombre_producto, c.nombre_categoria, p.precio, SUM(i.stock_actual)
    FROM inventario i
    JOIN producto p ON p.sku = i.sku
    JOIN subcategoria s ON s.id_subcategoria = p.id_subcategoria
    JOIN categoria c ON c.id_categoria = s.id_categoria
    WHERE p_id_categoria IS NULL OR c.id_categoria = p_id_categoria
    GROUP BY p.sku, p.nombre_producto, c.nombre_categoria, p.precio;

    -- Paso 2: sumar salidas y entradas del período (aquí también aplica el RLS)
    UPDATE tmp_reporte2 t
    SET total_salidas = (SELECT COALESCE(SUM(m.cantidad), 0)
                         FROM movimientoinventario m
                         WHERE m.sku = t.sku
                           AND m.tipo_movimiento = 'SALIDA'
                           AND CAST(m.fecha_movimiento AS DATE) BETWEEN p_fecha_inicio AND p_fecha_fin),
        total_entradas = (SELECT COALESCE(SUM(m.cantidad), 0)
                          FROM movimientoinventario m
                          WHERE m.sku = t.sku
                            AND m.tipo_movimiento = 'ENTRADA'
                            AND CAST(m.fecha_movimiento AS DATE) BETWEEN p_fecha_inicio AND p_fecha_fin);

    -- Paso 3: métricas
    -- Stock al inicio del período = stock actual + salidas - entradas
    -- Stock promedio = (stock al inicio + stock actual) / 2
    UPDATE tmp_reporte2 t
    SET valor_salidas = t.total_salidas * t.precio,
        promedio_diario = ROUND(t.total_salidas * 1.0 / v_dias, 2),
        stock_promedio = ((t.stock_actual + t.total_salidas - t.total_entradas) + t.stock_actual) / 2.0;

    -- Días de inventario restante = stock actual / promedio diario
    UPDATE tmp_reporte2 t
    SET dias_restantes = CASE
                             WHEN t.promedio_diario > 0 THEN FLOOR(t.stock_actual / t.promedio_diario)
                             ELSE NULL
                         END;

    -- Paso 4: clasificación ABC
    -- Se recorren los productos del que más vendió al que menos.
    -- A: los que forman el primer 80% del valor, B: hasta el 95%, C: el resto
    SELECT SUM(t.valor_salidas) INTO v_valor_total FROM tmp_reporte2 t;

    FOR v_fila IN SELECT t.sku, t.valor_salidas FROM tmp_reporte2 t ORDER BY t.valor_salidas DESC LOOP
        IF v_fila.valor_salidas = 0 THEN
            UPDATE tmp_reporte2 t SET clasificacion = 'Clase C (Baja Rotación)' WHERE t.sku = v_fila.sku;
        ELSIF v_acumulado / v_valor_total < 0.80 THEN
            UPDATE tmp_reporte2 t SET clasificacion = 'Clase A (Alta Rotación)' WHERE t.sku = v_fila.sku;
        ELSIF v_acumulado / v_valor_total < 0.95 THEN
            UPDATE tmp_reporte2 t SET clasificacion = 'Clase B (Rotación Media)' WHERE t.sku = v_fila.sku;
        ELSE
            UPDATE tmp_reporte2 t SET clasificacion = 'Clase C (Baja Rotación)' WHERE t.sku = v_fila.sku;
        END IF;

        v_acumulado := v_acumulado + v_fila.valor_salidas;
    END LOOP;

    -- Resultado ordenado por valor de salidas
    RETURN QUERY
    SELECT t.sku, t.producto, t.categoria, t.stock_promedio, t.total_salidas,
           t.valor_salidas, t.promedio_diario, t.dias_restantes, t.clasificacion
    FROM tmp_reporte2 t
    ORDER BY t.valor_salidas DESC;

    -- Borrar tabla temporal
    DROP TABLE tmp_reporte2;
END;
$$;


--3. Permisos de ejecución
REVOKE ALL ON FUNCTION sp_reporte_valoracion_reabastecimiento(INTEGER, NUMERIC) FROM PUBLIC;
REVOKE ALL ON FUNCTION sp_reporte_rotacion_inventario(DATE, DATE, INTEGER) FROM PUBLIC;

-- Reporte 1: solo admin y gestor
GRANT EXECUTE ON FUNCTION sp_reporte_valoracion_reabastecimiento(INTEGER, NUMERIC)
      TO db_admin, inventory_manager;

-- Reporte 2: también el auditor
GRANT EXECUTE ON FUNCTION sp_reporte_rotacion_inventario(DATE, DATE, INTEGER)
      TO db_admin, inventory_manager, auditor;


--Pruebas:
--prueba 1: admin, toda la empresa y almacén 1
SET ROLE admin_petit;
SELECT * FROM sp_reporte_valoracion_reabastecimiento(NULL, 10.0);
SELECT * FROM sp_reporte_valoracion_reabastecimiento(1, 10.0);
RESET ROLE;

--prueba 2: gestor en almacén 2, aunque mande NULL solo ve el almacén 2
SET ROLE gestor_inventario;
SET app.current_id_almacen = '2';
SELECT * FROM sp_reporte_valoracion_reabastecimiento(NULL, 10.0);
RESET app.current_id_almacen;
RESET ROLE;

--prueba 3: auditor, primer trimestre 2026, categoría 2
SET ROLE auditor_petit;
SELECT * FROM sp_reporte_rotacion_inventario('2026-01-01', '2026-03-31', 2);
RESET ROLE;

--prueba 4: el auditor no puede ejecutar el reporte 1
SET ROLE auditor_petit;
SELECT * FROM sp_reporte_valoracion_reabastecimiento(1, 10.0);
RESET ROLE;

--prueba 5: fechas al revés
SELECT * FROM sp_reporte_rotacion_inventario('2026-05-01', '2026-01-01', NULL);

--prueba 6: el empleado operativo no puede ejecutar el reporte 2
SET ROLE empleado_operativo_1;
SELECT * FROM sp_reporte_rotacion_inventario('2026-01-01', '2026-03-31', NULL);
RESET ROLE;