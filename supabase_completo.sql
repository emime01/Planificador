-- ============================================================
-- COTIZADOR MOVIMAGEN 2026 — Setup completo desde cero
-- Ejecutar en: Supabase Dashboard > SQL Editor
-- ============================================================

-- ============================================================
-- 1. TABLAS
-- ============================================================
CREATE TABLE IF NOT EXISTS soportes (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre                TEXT NOT NULL,
  seccion               TEXT,
  categoria             TEXT NOT NULL CHECK (categoria IN ('Digital', 'Shopping', 'Exterior', 'Bus')),
  tipo                  TEXT NOT NULL CHECK (tipo IN ('led', 'circuito', 'estatico_bus', 'banner_shopping', 'estatico_shopping', 'medianera')),
  ubicacion             TEXT NOT NULL,
  precio_semanal        NUMERIC(12,2) NOT NULL,
  iva_arrendamiento     BOOLEAN DEFAULT FALSE,
  salidas_por_hora      INTEGER,
  horas_encendido       INTEGER,
  impactos_mensuales    INTEGER,
  costo_produccion      NUMERIC(12,2),
  impuestos_municipales NUMERIC(12,2),
  cantidad_default      INTEGER DEFAULT 1,
  semanas_minimas       INTEGER DEFAULT 1,
  temporada_alta        BOOLEAN DEFAULT FALSE,
  temporada_baja        BOOLEAN DEFAULT FALSE,
  comentario            TEXT,
  url_imagen            TEXT,
  activo                BOOLEAN DEFAULT TRUE,
  created_at            TIMESTAMPTZ DEFAULT NOW(),
  updated_at            TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cotizaciones (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre          TEXT NOT NULL DEFAULT 'Nueva cotización',
  cliente         TEXT,
  marca           TEXT,
  observaciones   TEXT,
  estado          TEXT DEFAULT 'borrador' CHECK (estado IN ('borrador', 'enviada', 'aprobada', 'rechazada')),
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cotizacion_items (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cotizacion_id     UUID NOT NULL REFERENCES cotizaciones(id) ON DELETE CASCADE,
  soporte_id        UUID NOT NULL REFERENCES soportes(id),
  semanas           INTEGER NOT NULL DEFAULT 1,
  salidas_elegidas  INTEGER,
  cantidad_soportes INTEGER DEFAULT 1,
  created_at        TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 2. RLS — acceso público
-- ============================================================
ALTER TABLE soportes ENABLE ROW LEVEL SECURITY;
ALTER TABLE cotizaciones ENABLE ROW LEVEL SECURITY;
ALTER TABLE cotizacion_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "soportes_read_public" ON soportes;
DROP POLICY IF EXISTS "cotizaciones_all_public" ON cotizaciones;
DROP POLICY IF EXISTS "cotizacion_items_all_public" ON cotizacion_items;

CREATE POLICY "soportes_read_public" ON soportes FOR SELECT USING (true);
CREATE POLICY "cotizaciones_all_public" ON cotizaciones FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "cotizacion_items_all_public" ON cotizacion_items FOR ALL USING (true) WITH CHECK (true);

-- ============================================================
-- 3. FUNCIÓN updated_at
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS soportes_updated_at ON soportes;
DROP TRIGGER IF EXISTS cotizaciones_updated_at ON cotizaciones;

CREATE TRIGGER soportes_updated_at
  BEFORE UPDATE ON soportes
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER cotizaciones_updated_at
  BEFORE UPDATE ON cotizaciones
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- 4. DATOS REALES — Movimagen 2026 (64 soportes)
-- ============================================================
INSERT INTO soportes (nombre, seccion, categoria, tipo, ubicacion, precio_semanal, iva_arrendamiento,
  salidas_por_hora, horas_encendido, impactos_mensuales, costo_produccion, impuestos_municipales,
  cantidad_default, semanas_minimas, temporada_alta, temporada_baja, comentario, activo) VALUES
  ('PANTALLA GIGANTE CURVA', 'PANTALLAS GIGANTES', 'Digital', 'led', 'Rivera y L.A.Herrera', 23000.0, FALSE, 30, 16, 3154539, NULL, 2200.0, 1, 1, FALSE, FALSE, '', TRUE),
  ('PANTALLA GIGANTE', 'PANTALLAS GIGANTES', 'Digital', 'led', 'Av Italia y Ricaldoni', 23000.0, FALSE, 30, 16, 4586760, NULL, 2200.0, 1, 1, FALSE, FALSE, '', TRUE),
  ('PANTALLA GIGANTE', 'PANTALLAS GIGANTES', 'Digital', 'led', 'Rivera y Bvar Batlle y Ordoñez', 23000.0, FALSE, 30, 16, 2117435, NULL, 2200.0, 1, 1, FALSE, FALSE, '', TRUE),
  ('PANTALLA GIGANTE 360', 'PANTALLAS GIGANTES', 'Digital', 'led', 'Atlántico Shopping Punta del Este', 32000.0, FALSE, 30, 16, 5236278, NULL, NULL, 1, 13, TRUE, FALSE, 'Temporada alta Punta del Este (dic-feb). Mínimo 13 semanas, solo reservas.', TRUE),
  ('PANTALLA GIGANTE 360', 'PANTALLAS GIGANTES', 'Digital', 'led', 'Atlántico Shopping Punta del Este', 21000.0, FALSE, 30, 16, 201397, NULL, NULL, 1, 1, FALSE, TRUE, 'Temporada baja Punta del Este (mar-nov).', TRUE),
  ('CIRCUITO SHOPPING', 'CIRCUITOS DE PANTALLAS SHOPPINGS', 'Digital', 'circuito', 'Atlántico Shopping Punta del Este', 2100.0, FALSE, 10, 16, 7854416, NULL, NULL, 12, 13, TRUE, FALSE, 'Temporada alta Punta del Este (dic-feb). Mínimo 13 semanas, solo reservas.', TRUE),
  ('CIRCUITO SHOPPING', 'CIRCUITOS DE PANTALLAS SHOPPINGS', 'Digital', 'circuito', 'Atlántico Shopping Punta del Este', 1300.0, FALSE, 10, 16, 251746, NULL, NULL, 12, 1, FALSE, TRUE, 'Temporada baja Punta del Este (mar-nov).', TRUE),
  ('CIRCUITO SHOPPING', 'CIRCUITOS DE PANTALLAS SHOPPINGS', 'Digital', 'circuito', 'Minas (2 gigantes en circuito)', 5900.0, FALSE, 10, 16, 185034, NULL, NULL, 2, 1, FALSE, FALSE, '', TRUE),
  ('CIRCUITO SHOPPING', 'CIRCUITOS DE PANTALLAS SHOPPINGS', 'Digital', 'circuito', 'Salto', 1300.0, FALSE, 10, 16, 308387, NULL, NULL, 8, 1, FALSE, FALSE, '', TRUE),
  ('CIRCUITO SHOPPING', 'CIRCUITOS DE PANTALLAS SHOPPINGS', 'Digital', 'circuito', 'Paysandú', 1300.0, FALSE, 10, 16, 307127, NULL, NULL, 9, 1, FALSE, FALSE, '', TRUE),
  ('CIRCUITO SHOPPING', 'CIRCUITOS DE PANTALLAS SHOPPINGS', 'Digital', 'circuito', 'Mercedes', 1300.0, FALSE, 10, 16, 205593, NULL, NULL, 5, 1, FALSE, FALSE, '', TRUE),
  ('CIRCUITO SHOPPING', 'CIRCUITOS DE PANTALLAS SHOPPINGS', 'Digital', 'circuito', 'Colonia', 1300.0, FALSE, 10, 16, 138772, NULL, NULL, 5, 1, FALSE, FALSE, '', TRUE),
  ('PUERTA ENTRADA SHOPPING', 'PLOTEO PUERTAS', 'Shopping', 'estatico_shopping', 'Atlántico Shopping Punta del Este', 19700.0, FALSE, NULL, NULL, NULL, 44625.0, NULL, 1, 13, TRUE, FALSE, 'Temporada alta Punta del Este (dic-feb). Mínimo 13 semanas, solo reservas.', TRUE),
  ('PUERTA ENTRADA SHOPPING', 'PLOTEO PUERTAS', 'Shopping', 'estatico_shopping', 'Atlántico Shopping Punta del Este', 11800.0, FALSE, NULL, NULL, NULL, 44625.0, NULL, 1, 1, FALSE, TRUE, 'Temporada baja Punta del Este (mar-nov).', TRUE),
  ('PUERTA ENTRADA SHOPPING', 'PLOTEO PUERTAS', 'Shopping', 'estatico_shopping', 'Salto', 11800.0, FALSE, NULL, NULL, NULL, 44625.0, NULL, 1, 1, FALSE, FALSE, '', TRUE),
  ('PUERTA ENTRADA SHOPPING', 'PLOTEO PUERTAS', 'Shopping', 'estatico_shopping', 'Paysandú', 11800.0, FALSE, NULL, NULL, NULL, 44625.0, NULL, 1, 1, FALSE, FALSE, '', TRUE),
  ('PUERTA ENTRADA SHOPPING', 'PLOTEO PUERTAS', 'Shopping', 'estatico_shopping', 'Mercedes', 11800.0, FALSE, NULL, NULL, NULL, 44625.0, NULL, 1, 1, FALSE, FALSE, '', TRUE),
  ('PUERTA ENTRADA SHOPPING', 'PLOTEO PUERTAS', 'Shopping', 'estatico_shopping', 'Colonia', 11800.0, FALSE, NULL, NULL, NULL, 44625.0, NULL, 1, 1, FALSE, FALSE, '', TRUE),
  ('PUERTA ENTRADA SHOPPING', 'PLOTEO PUERTAS', 'Shopping', 'estatico_shopping', 'Minas', 11800.0, FALSE, NULL, NULL, NULL, 44625.0, NULL, 1, 1, FALSE, FALSE, '', TRUE),
  ('BANNER EXTRA GIGANTE', 'BANNERS EN SHOPPINGS', 'Shopping', 'banner_shopping', 'Atlántico Shopping Punta del Este', 19700.0, FALSE, NULL, NULL, NULL, 101050.0, NULL, 1, 13, TRUE, FALSE, 'Temporada alta Punta del Este (dic-feb). Mínimo 13 semanas, solo reservas.', TRUE),
  ('BANNER EXTRA GIGANTE', 'BANNERS EN SHOPPINGS', 'Shopping', 'banner_shopping', 'Atlántico Shopping Punta del Este', 11800.0, FALSE, NULL, NULL, NULL, 101050.0, NULL, 1, 1, FALSE, TRUE, 'Temporada baja Punta del Este (mar-nov).', TRUE),
  ('BANNER GIGANTE SHOPPING', 'BANNERS EN SHOPPINGS', 'Shopping', 'banner_shopping', 'Salto', 5800.0, FALSE, NULL, NULL, NULL, 34150.0, NULL, 1, 1, FALSE, FALSE, '', TRUE),
  ('BANNER GIGANTE SHOPPING', 'BANNERS EN SHOPPINGS', 'Shopping', 'banner_shopping', 'Paysandú', 5800.0, FALSE, NULL, NULL, NULL, 34150.0, NULL, 1, 1, FALSE, FALSE, '', TRUE),
  ('BANNER GIGANTE SHOPPING', 'BANNERS EN SHOPPINGS', 'Shopping', 'banner_shopping', 'Mercedes', 5800.0, FALSE, NULL, NULL, NULL, 34150.0, NULL, 1, 1, FALSE, FALSE, '', TRUE),
  ('BANNER GIGANTE SHOPPING', 'BANNERS EN SHOPPINGS', 'Shopping', 'banner_shopping', 'Colonia', 5800.0, FALSE, NULL, NULL, NULL, 28900.0, NULL, 1, 1, FALSE, FALSE, '', TRUE),
  ('BANNER GIGANTE SHOPPING', 'BANNERS EN SHOPPINGS', 'Shopping', 'banner_shopping', 'Minas', 5800.0, FALSE, NULL, NULL, NULL, 26250.0, NULL, 1, 1, FALSE, FALSE, '', TRUE),
  ('BANNER STANDARD SHOPPING', 'BANNERS EN SHOPPINGS', 'Shopping', 'banner_shopping', 'Salto', 2900.0, FALSE, NULL, NULL, NULL, 5250.0, NULL, 1, 1, FALSE, FALSE, '', TRUE),
  ('BANNER STANDARD SHOPPING', 'BANNERS EN SHOPPINGS', 'Shopping', 'banner_shopping', 'Paysandú', 2900.0, FALSE, NULL, NULL, NULL, 5250.0, NULL, 1, 1, FALSE, FALSE, '', TRUE),
  ('BANNER STANDARD SHOPPING', 'BANNERS EN SHOPPINGS', 'Shopping', 'banner_shopping', 'Mercedes', 2900.0, FALSE, NULL, NULL, NULL, 5250.0, NULL, 1, 1, FALSE, FALSE, '', TRUE),
  ('BANNER PARKING SHOPPING', 'BANNERS EN SHOPPINGS', 'Shopping', 'banner_shopping', 'Atlántico Shopping Punta del Este', 4350.0, FALSE, NULL, NULL, NULL, 8150.0, NULL, 1, 13, TRUE, FALSE, 'Temporada alta Punta del Este (dic-feb). Mínimo 13 semanas, solo reservas.', TRUE),
  ('BANNER PARKING SHOPPING', 'BANNERS EN SHOPPINGS', 'Shopping', 'banner_shopping', 'Atlántico Shopping Punta del Este', 2900.0, FALSE, NULL, NULL, NULL, 8150.0, NULL, 1, 1, FALSE, TRUE, 'Temporada baja Punta del Este (mar-nov).', TRUE),
  ('BANNER PARKING SHOPPING', 'BANNERS EN SHOPPINGS', 'Shopping', 'banner_shopping', 'Salto', 2900.0, FALSE, NULL, NULL, NULL, 8150.0, NULL, 1, 1, FALSE, FALSE, '', TRUE),
  ('BANNER PARKING SHOPPING', 'BANNERS EN SHOPPINGS', 'Shopping', 'banner_shopping', 'Paysandú', 2900.0, FALSE, NULL, NULL, NULL, 8150.0, NULL, 1, 1, FALSE, FALSE, '', TRUE),
  ('BANNER PARKING SHOPPING', 'BANNERS EN SHOPPINGS', 'Shopping', 'banner_shopping', 'Minas', 2900.0, FALSE, NULL, NULL, NULL, 8150.0, NULL, 1, 1, FALSE, FALSE, '', TRUE),
  ('BANNER PARKING SHOPPING', 'BANNERS EN SHOPPINGS', 'Shopping', 'banner_shopping', 'Colonia', 2900.0, FALSE, NULL, NULL, NULL, 8150.0, NULL, 1, 1, FALSE, FALSE, '', TRUE),
  ('LONA PARKING SHOPPING', 'BANNERS EN SHOPPINGS', 'Shopping', 'banner_shopping', 'Mercedes', 5800.0, FALSE, NULL, NULL, NULL, 28875.0, NULL, 1, 1, FALSE, FALSE, '', TRUE),
  ('ESCALERA SHOPPING', 'PLOTEO ESCALERAS Y ASCENSORES', 'Shopping', 'estatico_shopping', 'Atlántico Shopping Punta del Este', 19700.0, FALSE, NULL, NULL, NULL, 42250.0, NULL, 1, 13, TRUE, FALSE, 'Temporada alta Punta del Este (dic-feb). Mínimo 13 semanas, solo reservas.', TRUE),
  ('ESCALERA SHOPPING', 'PLOTEO ESCALERAS Y ASCENSORES', 'Shopping', 'estatico_shopping', 'Atlántico Shopping Punta del Este', 11800.0, FALSE, NULL, NULL, NULL, 42250.0, NULL, 1, 1, FALSE, TRUE, 'Temporada baja Punta del Este (mar-nov).', TRUE),
  ('ESCALERA SHOPPING', 'PLOTEO ESCALERAS Y ASCENSORES', 'Shopping', 'estatico_shopping', 'Salto', 11800.0, FALSE, NULL, NULL, NULL, 42250.0, NULL, 1, 1, FALSE, FALSE, '', TRUE),
  ('ASCENSOR SHOPPING', 'PLOTEO ESCALERAS Y ASCENSORES', 'Shopping', 'estatico_shopping', 'Atlántico Shopping Punta del Este', 11800.0, FALSE, NULL, NULL, NULL, 34650.0, NULL, 1, 13, TRUE, FALSE, 'Temporada alta Punta del Este (dic-feb). Mínimo 13 semanas, solo reservas.', TRUE),
  ('ASCENSOR SHOPPING', 'PLOTEO ESCALERAS Y ASCENSORES', 'Shopping', 'estatico_shopping', 'Atlántico Shopping Punta del Este', 7900.0, FALSE, NULL, NULL, NULL, 34650.0, NULL, 1, 1, FALSE, TRUE, 'Temporada baja Punta del Este (mar-nov).', TRUE),
  ('ASCENSOR SHOPPING', 'PLOTEO ESCALERAS Y ASCENSORES', 'Shopping', 'estatico_shopping', 'Salto', 7900.0, FALSE, NULL, NULL, NULL, 34650.0, NULL, 1, 1, FALSE, FALSE, '', TRUE),
  ('CARA PALETAS BACKLIGHT SHOPPING', 'CARA PALETAS BACKLIGHT Y PLOTEO PISOS', 'Shopping', 'estatico_shopping', 'Salto', 2900.0, FALSE, NULL, NULL, NULL, 8150.0, NULL, 1, 1, FALSE, FALSE, '', TRUE),
  ('CARA PALETAS BACKLIGHT SHOPPING', 'CARA PALETAS BACKLIGHT Y PLOTEO PISOS', 'Shopping', 'estatico_shopping', 'Mercedes', 2900.0, FALSE, NULL, NULL, NULL, 8150.0, NULL, 1, 1, FALSE, FALSE, '', TRUE),
  ('CARA PALETAS BACKLIGHT SHOPPING', 'CARA PALETAS BACKLIGHT Y PLOTEO PISOS', 'Shopping', 'estatico_shopping', 'Colonia', 2900.0, FALSE, NULL, NULL, NULL, 8150.0, NULL, 1, 1, FALSE, FALSE, '', TRUE),
  ('PISOS PASILLO SHOPPING', 'CARA PALETAS BACKLIGHT Y PLOTEO PISOS', 'Shopping', 'estatico_shopping', 'Atlántico Shopping Punta del Este', 4350.0, FALSE, NULL, NULL, NULL, 13650.0, NULL, 1, 13, TRUE, FALSE, 'Temporada alta Punta del Este (dic-feb). Mínimo 13 semanas, solo reservas.', TRUE),
  ('PISOS PASILLO SHOPPING', 'CARA PALETAS BACKLIGHT Y PLOTEO PISOS', 'Shopping', 'estatico_shopping', 'Atlántico Shopping Punta del Este', 2900.0, FALSE, NULL, NULL, NULL, 13650.0, NULL, 1, 1, FALSE, TRUE, 'Temporada baja Punta del Este (mar-nov).', TRUE),
  ('PISOS PASILLO SHOPPING', 'CARA PALETAS BACKLIGHT Y PLOTEO PISOS', 'Shopping', 'estatico_shopping', 'Salto', 2900.0, FALSE, NULL, NULL, NULL, 13650.0, NULL, 1, 1, FALSE, FALSE, '', TRUE),
  ('PISOS PASILLO SHOPPING', 'CARA PALETAS BACKLIGHT Y PLOTEO PISOS', 'Shopping', 'estatico_shopping', 'Paysandú', 2900.0, FALSE, NULL, NULL, NULL, 13650.0, NULL, 1, 1, FALSE, FALSE, '', TRUE),
  ('PISOS PASILLO SHOPPING', 'CARA PALETAS BACKLIGHT Y PLOTEO PISOS', 'Shopping', 'estatico_shopping', 'Mercedes', 2900.0, FALSE, NULL, NULL, NULL, 13650.0, NULL, 1, 1, FALSE, FALSE, '', TRUE),
  ('PISOS PASILLO SHOPPING', 'CARA PALETAS BACKLIGHT Y PLOTEO PISOS', 'Shopping', 'estatico_shopping', 'Colonia', 2900.0, FALSE, NULL, NULL, NULL, 13650.0, NULL, 1, 1, FALSE, FALSE, '', TRUE),
  ('PISOS PASILLO SHOPPING', 'CARA PALETAS BACKLIGHT Y PLOTEO PISOS', 'Shopping', 'estatico_shopping', 'Minas', 2900.0, FALSE, NULL, NULL, NULL, 13650.0, NULL, 1, 1, FALSE, FALSE, '', TRUE),
  ('MEDIANERA EDIFICIO', 'MEDIANERAS EN EDIFICIOS', 'Exterior', 'medianera', 'Av 18 de Julio y Roxlo - visual  publico al Este', 21650.0, FALSE, NULL, NULL, NULL, 111550.0, 3812.5, 1, 1, FALSE, FALSE, '', TRUE),
  ('MEDIANERA EDIFICIO', 'MEDIANERAS EN EDIFICIOS', 'Exterior', 'medianera', 'Bvar. Batlle y Ordoñez y Av. Rivera - visual hacia N y E', 21650.0, FALSE, NULL, NULL, NULL, 133875.0, 4600.0, 1, 1, FALSE, FALSE, '', TRUE),
  ('MEDIANERA EDIFICIO', 'MEDIANERAS EN EDIFICIOS', 'Exterior', 'medianera', 'Av Italia y Caldas - visual publico hacia el Este', 21650.0, FALSE, NULL, NULL, NULL, 127300.0, 4262.5, 1, 1, FALSE, FALSE, '', TRUE),
  ('MegaBus Exclusivo', 'CARTELES EN BUSES', 'Bus', 'estatico_bus', 'Coetc - Línea D9 y DM1 (Montevideo)', 27550.0, FALSE, NULL, NULL, NULL, 107800.0, NULL, 1, 1, FALSE, FALSE, '', TRUE),
  ('FullBus Exclusivo', 'CARTELES EN BUSES', 'Bus', 'estatico_bus', 'Coetc - Líneas Suburbanas (Mvd y Canelones)', 17050.0, FALSE, NULL, NULL, NULL, 63525.0, NULL, 1, 1, FALSE, FALSE, '', TRUE),
  ('InteriorBus Exclusivo', 'CARTELES EN BUSES', 'Bus', 'estatico_bus', 'Coetc - Líneas Urbanas (Montevideo)', 5650.0, FALSE, NULL, NULL, NULL, 20450.0, NULL, 1, 1, FALSE, FALSE, '', TRUE),
  ('TraseroFull', 'CARTELES EN BUSES', 'Bus', 'estatico_bus', 'Coetc - Líneas Suburbanas (Mvd y Canelones)', 2100.0, FALSE, NULL, NULL, NULL, 7600.0, NULL, 1, 1, FALSE, FALSE, '', TRUE),
  ('LateralFull', 'CARTELES EN BUSES', 'Bus', 'estatico_bus', 'Coetc - Líneas Suburbanas (Mvd y Canelones)', 6550.0, FALSE, NULL, NULL, NULL, 36500.0, NULL, 4, 1, FALSE, FALSE, '', TRUE),
  ('Lateral Extra o 2 Paños', 'CARTELES EN BUSES', 'Bus', 'estatico_bus', 'Coetc - Líneas Urbanas (Montevideo)', 1050.0, FALSE, NULL, NULL, NULL, 2900.0, NULL, 1, 1, FALSE, FALSE, '', TRUE),
  ('Lateral 1 Paño', 'CARTELES EN BUSES', 'Bus', 'estatico_bus', 'Coetc - Líneas Urbanas (Montevideo)', 900.0, FALSE, NULL, NULL, NULL, 2350.0, NULL, 1, 1, FALSE, FALSE, '', TRUE),
  ('Trasero Premium', 'CARTELES EN BUSES', 'Bus', 'estatico_bus', 'Coetc - Líneas Urbanas (Montevideo)', 850.0, FALSE, NULL, NULL, NULL, 1575.0, NULL, 1, 1, FALSE, FALSE, '', TRUE),
  ('Luneta Premium', 'CARTELES EN BUSES', 'Bus', 'estatico_bus', 'Coetc - Líneas Urbanas (Montevideo)', 850.0, FALSE, NULL, NULL, NULL, 2625.0, NULL, 1, 1, FALSE, FALSE, '', TRUE);

-- ============================================================
-- 5. VERIFICAR
-- ============================================================
SELECT categoria, seccion, COUNT(*) as cant
FROM soportes
GROUP BY categoria, seccion
ORDER BY categoria, seccion;
