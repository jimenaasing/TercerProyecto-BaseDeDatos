-- Pruebas Mich

RESET ROLE;

-- Función de apoyo para imprimir el número de cada prueba
CREATE OR REPLACE FUNCTION fn_imprimir_prueba(p_mensaje VARCHAR)
RETURNS VOID AS $$
BEGIN
    RAISE NOTICE '%', p_mensaje;
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION fn_imprimir_prueba(VARCHAR)
      TO db_admin, inventory_manager, auditor, empleado_operativo;

--prueba 1: el administrador tiene control total (estructura, usuarios y reportes)
SET ROLE admin_petit;
SELECT fn_imprimir_prueba('Ejecutando prueba 1');

-- Crear y borrar una tabla (estructura)
CREATE TABLE prueba_admin (
    id INTEGER PRIMARY KEY,
    descripcion VARCHAR(50) NOT NULL
);
INSERT INTO prueba_admin VALUES (1, 'Tabla creada por el administrador');
SELECT * FROM prueba_admin;

-- Dar y quitar permisos
GRANT SELECT ON prueba_admin TO auditor;
REVOKE SELECT ON prueba_admin FROM auditor;
DROP TABLE prueba_admin;

-- Crear y borrar un usuario
CREATE USER usuario_prueba WITH PASSWORD 'prueba_123';
DROP USER usuario_prueba;

-- Ve todos los almacenes (el RLS no lo limita)
SELECT * FROM inventario;

-- Ejecutar los dos reportes
SELECT * FROM sp_reporte_valoracion_reabastecimiento(NULL, 10.0);
SELECT * FROM sp_reporte_rotacion_inventario('2026-01-01', '2026-03-31', NULL);
RESET ROLE;

--prueba 4: el administrador ejecuta el reporte de valoración para el almacén 1 con margen de 10%
SET ROLE admin_petit;
SELECT fn_imprimir_prueba('Ejecutando prueba 4');
SELECT * FROM sp_reporte_valoracion_reabastecimiento(1, 10.0);
RESET ROLE;

--prueba 13: el auditor ejecuta el reporte de rotación (primer trimestre 2026, Electrónica)
SET ROLE auditor_petit;
SELECT fn_imprimir_prueba('Ejecutando prueba 13');
SELECT * FROM sp_reporte_rotacion_inventario('2026-01-01', '2026-03-31', 2);
RESET ROLE;

--prueba 14: el auditor ejecuta el reporte de rotación con fechas al revés (debe dar error)
-- Ejecutar por separado (seleccionar y presionar F5)
-- SET ROLE auditor_petit;
-- SELECT fn_imprimir_prueba('Ejecutando prueba 14');
-- SELECT * FROM sp_reporte_rotacion_inventario('2026-05-01'::DATE, '2026-01-01'::DATE, NULL);
-- RESET ROLE;