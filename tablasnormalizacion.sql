CREATE TABLE proveedor ( 

id_proveedor INTEGER PRIMARY KEY, 

nombre_proveedor VARCHAR(50) NOT NULL, 

contacto_proveedor VARCHAR(60) NOT NULL, 

telefono_proveedor VARCHAR(20) NOT NULL, 

pais_proveedor VARCHAR(40) NOT NULL 

); 

  

CREATE TABLE almacen ( 

id_almacen INTEGER PRIMARY KEY, 

nombre_almacen VARCHAR(60) NOT NULL UNIQUE, 

ubicacion_almacen VARCHAR(100) NOT NULL 

); 

  

CREATE TABLE categoria ( 

id_categoria INTEGER PRIMARY KEY, 

nombre_categoria VARCHAR(40) NOT NULL UNIQUE 

); 

  

CREATE TABLE subcategoria ( 

id_subcategoria INTEGER PRIMARY KEY, 

nombre_subcategoria VARCHAR(40) NOT NULL, 

id_categoria INTEGER NOT NULL, 

  

CONSTRAINT fk_subcategoria_categoria 

FOREIGN KEY (id_categoria) 

REFERENCES categoria(id_categoria), 

  

CONSTRAINT uq_subcategoria_categoria_nombre 

UNIQUE (id_categoria, nombre_subcategoria) 

); 

  

CREATE TABLE producto ( 

sku VARCHAR(20) PRIMARY KEY, 

nombre_producto VARCHAR(100) NOT NULL, 

precio NUMERIC(12,2) NOT NULL, 

costo_unitario NUMERIC(12,2) NOT NULL, 

id_proveedor INTEGER NOT NULL, 

id_subcategoria INTEGER NOT NULL, 

CONSTRAINT chk_producto_precio 

CHECK (precio >= 0), 

CONSTRAINT chk_producto_costo 

CHECK (costo_unitario >= 0), 

CONSTRAINT fk_producto_proveedor 

FOREIGN KEY (id_proveedor) 

REFERENCES proveedor(id_proveedor), 

CONSTRAINT fk_producto_subcategoria 

FOREIGN KEY (id_subcategoria) 

REFERENCES subcategoria(id_subcategoria) 

); 

  

CREATE TABLE inventario ( 

id_inventario INTEGER PRIMARY KEY, 

stock_minimo INTEGER NOT NULL, 

stock_actual INTEGER NOT NULL DEFAULT 0, 

cantidad_ultima_entrada INTEGER, 

fecha_ultima_entrada DATE, 

id_almacen INTEGER NOT NULL, 

sku VARCHAR(20) NOT NULL, 

CONSTRAINT chk_stock_minimo 

CHECK (stock_minimo >= 0), 

CONSTRAINT chk_stock_actual 

CHECK (stock_actual >= 0), 

CONSTRAINT chk_cantidad_ultima_entrada 

CHECK (cantidad_ultima_entrada >= 0), 

CONSTRAINT chk_datos_ultima_entrada 

CHECK ( 

(cantidad_ultima_entrada IS NULL 

AND fecha_ultima_entrada IS NULL) 

OR 

(cantidad_ultima_entrada IS NOT NULL 

AND fecha_ultima_entrada IS NOT NULL) 

), 

CONSTRAINT fk_inventario_almacen 

FOREIGN KEY (id_almacen) 

REFERENCES almacen(id_almacen), 

CONSTRAINT fk_inventario_producto 

FOREIGN KEY (sku) 

REFERENCES producto(sku), 

CONSTRAINT uq_inventario_almacen_sku 

UNIQUE (id_almacen, sku) 

); 

  

CREATE TABLE movimientoInventario ( 

id_movimiento INTEGER PRIMARY KEY, 

tipo_movimiento VARCHAR(30) NOT NULL, 

fecha_movimiento TIMESTAMP NOT NULL 

DEFAULT CURRENT_TIMESTAMP, 

cantidad INTEGER NOT NULL, 

id_almacen INTEGER NOT NULL, 

sku VARCHAR(20) NOT NULL, 

CONSTRAINT chk_tipo_movimiento 

CHECK (tipo_movimiento IN 

('ENTRADA', 'SALIDA')), 

CONSTRAINT chk_cantidad_movimiento 

CHECK (cantidad > 0), 

CONSTRAINT fk_movimiento_almacen 

FOREIGN KEY (id_almacen) 

REFERENCES almacen(id_almacen), 

CONSTRAINT fk_movimiento_producto 

FOREIGN KEY (sku) 

REFERENCES producto(sku) 

); 