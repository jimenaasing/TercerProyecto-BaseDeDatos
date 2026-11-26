-- FASE 3: SEGURIDAD A NIVEL DE FILAS

--1. Función de apoyo para evaluar el contexto de la sesión
CREATE OR REPLACE FUNCTION fn_puede_acceder_almacen(p_id_almacen INTEGER)
RETURNS BOOLEAN AS $$
DECLARE
    v_almacen_texto TEXT := current_setting('app.current_id_almacen', true);
BEGIN
    -- Administrador o auditor: se revisa su rol REAL, no una variable
    IF pg_has_role(current_user, 'db_admin', 'member')
       OR pg_has_role(current_user, 'auditor', 'member') THEN
        RETURN TRUE;
    END IF;

    -- Si no hay almacén configurado en la sesión, niega por seguridad
    IF v_almacen_texto IS NULL OR v_almacen_texto = '' THEN
        RETURN FALSE;
    END IF;

    RETURN p_id_almacen = v_almacen_texto::INTEGER;
END;
$$ LANGUAGE plpgsql STABLE;

-- Permitir que los roles operativos ejecuten la función
GRANT EXECUTE ON FUNCTION fn_puede_acceder_almacen(INTEGER)
      TO inventory_manager, auditor, empleado_operativo, db_admin;

--2. Habilitar RLS en tablas operativas
ALTER TABLE inventario ENABLE ROW LEVEL SECURITY;
ALTER TABLE movimientoinventario ENABLE ROW LEVEL SECURITY;

--3. Crear politicas de seguridad
DROP POLICY IF EXISTS pol_rls_inventario ON inventario;
CREATE POLICY pol_rls_inventario ON inventario
    FOR ALL
    USING (fn_puede_acceder_almacen(id_almacen))
    WITH CHECK (fn_puede_acceder_almacen(id_almacen));

DROP POLICY IF EXISTS pol_rls_movimiento ON movimientoinventario;
CREATE POLICY pol_rls_movimiento ON movimientoinventario
    FOR ALL
    USING (fn_puede_acceder_almacen(id_almacen))
    WITH CHECK (fn_puede_acceder_almacen(id_almacen));

-- Pruebas de contexto de sesión con set local y set role
--prueba 1: empleado_operativo_1 trabajando solo en el almacé 1
SET ROLE empleado_operativo_1;
BEGIN;
	SET LOCAL app.current_user_role = 'empleado_operativo';
	SET LOCAL app.current_id_almacen = '1';
	SELECT * FROM inventario; -- solo se ven las filas de inventario donde id_almacen= 1
COMMIT;
RESET ROLE;

--prueba 2: gestor_inventario trabajando en almacén 2
SET ROLE gestor_inventario;
BEGIN;
    SET LOCAL app.current_user_role = 'inventory_manager';
    SET LOCAL app.current_almacen_id = '2';
    SELECT * FROM inventario;
    SELECT * FROM movimientoinventario;
COMMIT;
RESET ROLE;

--prueba 3: auditor con visibilidad de lectura en contexto de auditoría
SET ROLE auditor_petit;
BEGIN;
    SET LOCAL app.current_user_role = 'auditor';
    SELECT * FROM movimientoinventario;
COMMIT;
RESET ROLE;