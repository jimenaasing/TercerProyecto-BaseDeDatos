-- Pruebs funvionales de RAISE NOTICE (2, 7, 8, 10, 11, 12, 15)

-- PRUEBA 2(DEBE FALLAR)
RESET ROLE;
SET ROLE inventory_manager;
DO $$ BEGIN RAISE NOTICE 'PRUEBA 2: inventory_manager intenta crear rol / alterar estructura'; 
END $$;
CREATE ROLE rol_prueba_no_autorizado LOGIN;
RESET ROLE;

-- PRUEBA 7
DO $$ BEGIN RAISE NOTICE 'PRUEBA 7: RLS filtra las existencias; gestor_inventario (almacén 2) solo ve su almacén'; 
END $$;
SET ROLE gestor_inventario;
BEGIN;
    SET LOCAL app.current_id_almacen = '2';
    SELECT id_inventario, sku, stock_actual, id_almacen FROM inventario ORDER BY id_inventario;
COMMIT;
RESET ROLE;

-- PRUEBA 8
RESET ROLE;
SET ROLE inventory_manager;
BEGIN;
    SET LOCAL app.current_id_almacen = '2';
    DO $$ BEGIN RAISE NOTICE 'PRUEBA 8: RLS bloquea acceso/modificación a almacén ajeno (ID 1)';
	END $$;
    -- No debe devolver filas del almacén 1:
    SELECT id_inventario, sku, stock_actual, id_almacen FROM inventario WHERE id_almacen = 1;
    -- No debe modificar filas del almacén 1:
    UPDATE inventario SET stock_actual = stock_actual WHERE id_almacen = 1;
ROLLBACK;
RESET ROLE;

-- PRUEBA 10: (DEBE FALLAR)
DO $$ BEGIN RAISE NOTICE 'PRUEBA 10: el empleado operativo no puede ejecutar el reporte de valoración'; END $$;
SET ROLE empleado_operativo_1;
SELECT * FROM sp_reporte_valoracion_reabastecimiento(1, 10.0);
RESET ROLE;

-- PRUEBA 11
DO $$ BEGIN RAISE NOTICE 'PRUEBA 11: el auditor no puede insertar en producto'; END $$;
SET ROLE auditor_petit;
INSERT INTO producto (sku, nombre_producto, precio, costo_unitario, id_proveedor, id_subcategoria)
VALUES ('TST-001', 'Producto de prueba', 10, 5, 1, 1);
RESET ROLE;

-- PRUEBA 12
RESET ROLE;
SET ROLE auditor;
DO $$ BEGIN RAISE NOTICE 'PRUEBA 12: auditor consulta historial de movimientos de inventario';
END $$;
SELECT * FROM movimientoinventario;
RESET ROLE;

-- PRUEBA 15: (DEBE FALLAR)
-- DO $$ BEGIN RAISE NOTICE '>>> PRUEBA 15: el auditor no puede ejecutar Checkout ni Transferencia'; END $$;
-- SET ROLE auditor_petit;
-- SELECT * FROM sp_checkout --parámetros reales;
-- RESET ROLE;

-- SET ROLE auditor_petit;
-- SELECT * FROM sp_transferencia --parámetros reales;
-- RESET ROLE;