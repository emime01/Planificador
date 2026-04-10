# CONTEXT.md — Cotizador Movimagen 2026
> Archivo de contexto para Claude Code. Lee esto primero antes de cualquier tarea.

---

## 1. Resumen del proyecto

Aplicación web de **armado de propuestas publicitarias** para Movimagen, empresa de publicidad exterior en Uruguay. Permite a media planners y gerentes de marketing seleccionar soportes publicitarios de un catálogo, configurar semanas/salidas/cantidad, ver métricas en tiempo real (impactos, CPM, inversión) con gráficas interactivas, y exportar la propuesta en PDF.

**Stack:** HTML + CSS + JS vanilla · Supabase (PostgreSQL) · Chart.js · jsPDF  
**Deploy:** GitHub Pages (archivo HTML único, sin build step)  
**Estado:** Funcional y en producción

---

## 2. Credenciales Supabase

```
SUPABASE_URL = https://ghvwcmeplosopqznhmxy.supabase.co
SUPABASE_KEY = sb_publishable_T6Q_DuAi7OB9ya7WuLRNBg_7XAVZd6q
```

> La key es pública (anon/publishable). RLS habilitado con políticas de acceso público.

---

## 3. Base de datos — Supabase (PostgreSQL)

### Tabla: `soportes`
Catálogo de soportes publicitarios. Ya cargada con 64 soportes reales de Movimagen 2026.

```sql
CREATE TABLE soportes (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre                TEXT NOT NULL,
  seccion               TEXT,                    -- Agrupación dentro de categoría
  categoria             TEXT NOT NULL CHECK (categoria IN ('Digital', 'Shopping', 'Exterior', 'Bus')),
  tipo                  TEXT NOT NULL CHECK (tipo IN ('led', 'circuito', 'estatico_bus', 'banner_shopping', 'estatico_shopping', 'medianera')),
  ubicacion             TEXT NOT NULL,
  precio_semanal        NUMERIC(12,2) NOT NULL,
  iva_arrendamiento     BOOLEAN DEFAULT FALSE,
  salidas_por_hora      INTEGER,                 -- NULL para soportes estáticos
  horas_encendido       INTEGER,                 -- horas por día encendido (para LED/circuito)
  impactos_mensuales    INTEGER,                 -- NULL para soportes sin medición (buses, banners)
  costo_produccion      NUMERIC(12,2),           -- NULL si no aplica. Siempre lleva IVA 22%
  impuestos_municipales NUMERIC(12,2),           -- NULL si no aplica (solo medianeras y algunas pantallas)
  cantidad_default      INTEGER DEFAULT 1,       -- cantidad de unidades default (ej: circuito shopping = 12 pantallas)
  semanas_minimas       INTEGER DEFAULT 1,       -- Punta del Este temp alta = 13 semanas mínimo
  temporada_alta        BOOLEAN DEFAULT FALSE,   -- dic-feb Punta del Este
  temporada_baja        BOOLEAN DEFAULT FALSE,   -- mar-nov Punta del Este
  comentario            TEXT,
  url_imagen            TEXT,                    -- base64 o URL. Se sube desde modal admin
  activo                BOOLEAN DEFAULT TRUE,
  created_at            TIMESTAMPTZ DEFAULT NOW(),
  updated_at            TIMESTAMPTZ DEFAULT NOW()
);
```

### Tabla: `cotizaciones`
Cabecera de cada propuesta guardada (feature pendiente de implementar en frontend).

```sql
CREATE TABLE cotizaciones (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre          TEXT NOT NULL DEFAULT 'Nueva cotización',
  cliente         TEXT,
  marca           TEXT,
  observaciones   TEXT,
  estado          TEXT DEFAULT 'borrador' CHECK (estado IN ('borrador', 'enviada', 'aprobada', 'rechazada')),
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);
```

### Tabla: `cotizacion_items`
Soportes seleccionados dentro de cada cotización guardada.

```sql
CREATE TABLE cotizacion_items (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cotizacion_id     UUID NOT NULL REFERENCES cotizaciones(id) ON DELETE CASCADE,
  soporte_id        UUID NOT NULL REFERENCES soportes(id),
  semanas           INTEGER NOT NULL DEFAULT 1,
  salidas_elegidas  INTEGER,           -- múltiplo de 10 (circuito) o 30 (led)
  cantidad_soportes INTEGER DEFAULT 1,
  created_at        TIMESTAMPTZ DEFAULT NOW()
);
```

### Categorías y tipos de soportes

| Categoría | Tipos | Descripción |
|-----------|-------|-------------|
| `Digital` | `led` | Pantallas gigantes LED. Salidas de 30 en 30. |
| `Digital` | `circuito` | Circuitos de pantallas en shoppings/locales. Salidas de 10 en 10. |
| `Shopping` | `banner_shopping` | Banners físicos en shoppings. Se elige cantidad. |
| `Shopping` | `estatico_shopping` | Puertas, escaleras, ascensores, pisos en shoppings. |
| `Exterior` | `medianera` | Medianeras en edificios de Montevideo. |
| `Bus` | `estatico_bus` | Carteles en buses COETC (trasero, lateral, interior). |

---

## 4. Lógica de negocio crítica

### Cálculo de precios

```javascript
const IVA_RATE = 0.22;

function calcItem(item) {
  const s = item.soporte;
  const semanas = Math.max(item.semanas, s.semanas_minimas || 1);
  const sal = item.salidasElegidas;
  const cant = item.cantidadSoportes;

  // Multiplicador de precio según salidas
  let mul = 1;
  if (s.tipo === 'circuito' && sal) mul = sal / 10;  // venden de 10 en 10
  if (s.tipo === 'led' && sal) mul = sal / 30;        // venden de 30 en 30

  const arr = s.precio_semanal * semanas * mul * cant;
  const ivaArr = s.iva_arrendamiento ? arr * IVA_RATE : 0;
  const prod = s.costo_produccion ? s.costo_produccion * cant : 0;
  const ivaProd = prod * IVA_RATE;                    // producción SIEMPRE lleva IVA
  const mun = s.impuestos_municipales ? s.impuestos_municipales * semanas * cant : 0;
  const impactos = s.impactos_mensuales
    ? Math.round(s.impactos_mensuales * semanas / 4.33 * cant * mul)
    : 0;
  const tot = arr + ivaArr + prod + ivaProd + mun;
  const cpm = impactos > 0 ? (tot / impactos) * 1000 : 0;

  return { arr, ivaArr, prod, ivaProd, mun, impactos, tot, mul, cpm };
}
```

### Reglas de negocio importantes

- **LED:** salidas se venden de **30 en 30**. El precio se multiplica: 30 sal = ×1, 60 sal = ×2, 90 sal = ×3.
- **Circuito:** salidas se venden de **10 en 10**. El precio se multiplica igual.
- **Temporada alta Punta del Este (dic-feb):** `semanas_minimas = 13`. Solo se aceptan reservas. El sistema fuerza mínimo 13 semanas y muestra alerta.
- **Producción:** SIEMPRE lleva IVA 22%, independientemente del `iva_arrendamiento` del soporte.
- **Arrendamiento:** solo lleva IVA si `iva_arrendamiento = true` en el soporte.
- **Impactos mensuales:** se convierten a impactos por campaña: `impactos_mensuales × (semanas / 4.33)`.
- **CPM:** `(costo_total / impactos) × 1000`.

---

## 5. Arquitectura del frontend

Archivo único: `cotizador.html`

### Estructura de 3 columnas
```
┌─────────────────┬─────────────────────┬──────────────────┐
│   SIDEBAR       │      CENTER         │   RIGHT PANEL    │
│   (280px)       │   (flex: 1)         │   (360px)        │
│                 │                     │                  │
│ • Logo          │ • Header + acciones │ • KPIs en negro  │
│ • Búsqueda      │ • Gráficas          │   (impactos,     │
│ • Filtros cat.  │   Chart.js          │   CPM, arrend.)  │
│ • Lista         │ • Empty state       │ • Lista items    │
│   soportes      │                     │   seleccionados  │
│   agrupados     │                     │ • Resumen total  │
│   por sección   │                     │   + desglose IVA │
└─────────────────┴─────────────────────┴──────────────────┘
```

### Estado global (JS)
```javascript
let allSupports = [];      // todos los soportes de Supabase
let selectedItems = [];    // [{soporte, semanas, salidasElegidas, cantidadSoportes, uid}]
let currentCat = 'all';   // filtro activo
let pendingSupport = null; // soporte en modal de configuración
let charts = {};           // instancias Chart.js activas
```

### Gráficas implementadas (Chart.js 4.4.1)
1. **Donut — Inversión por categoría** (arrendamiento base)
2. **Donut — Impactos por categoría**
3. **Line — Proyección acumulada de impactos** (semana a semana)
4. **Bar — Eficiencia global** (inversión vs impactos por categoría)
5. **Bar horizontal — Alcance por soporte** (impactos totales)
6. **Bar horizontal — CPM por soporte** (costo por mil impactos)

> Las gráficas solo se muestran si hay soportes seleccionados. Si un soporte no tiene `impactos_mensuales`, se muestra un badge de advertencia en las gráficas afectadas.

### Modales
- **Modal agregar soporte:** configura semanas, salidas, cantidad. Muestra preview de precios en tiempo real.
- **Modal login admin:** contraseña `6411`.
- **Modal admin — imágenes:** lista todos los soportes, permite subir imagen por soporte (se convierte a base64 y se guarda en Supabase via PATCH).

### Export PDF (jsPDF 2.5.1)
Incluye: header Movimagen, 4 KPIs, desglose de inversión (arrendamiento/IVA/municipales/producción), detalle de cada soporte, y capturas de todas las gráficas como imágenes PNG embebidas.

---

## 6. Diseño / Estética

**Tema:** Dark industrial con naranja eléctrico  
**Fuentes:** `Outfit` (display/UI) + `DM Mono` (datos técnicos, labels, monospace)  
**Paleta:**

```css
--bg: #0F0F0F;
--surface: #161616;
--surface2: #1E1E1E;
--surface3: #252525;
--border: #2A2A2A;
--o: #FF5C1A;          /* naranja principal */
--o2: #FF7A42;         /* naranja hover */
--o-dim: rgba(255,92,26,.12);
--text: #F0EDE8;
--text2: #9A9590;
--text3: #5A5652;
--digital: #FF5C1A;    /* color categoría Digital */
--shopping: #A78BFA;   /* color categoría Shopping */
--exterior: #34D399;   /* color categoría Exterior */
--bus: #FCD34D;        /* color categoría Bus */
```

---

## 7. Features implementadas ✅

- [x] Catálogo lateral con búsqueda y filtros por categoría
- [x] Soportes agrupados por sección (Pantallas Gigantes, Circuitos, etc.)
- [x] Tooltip con imagen y datos al hacer hover en cada soporte
- [x] Modal de configuración con preview de precios en tiempo real
- [x] Lógica de multiplicadores LED (×30) y circuito (×10)
- [x] Restricción temporada alta Punta del Este (mín 13 semanas)
- [x] Panel derecho con KPIs (impactos, CPM, arrendamiento)
- [x] Desglose de costos (IVA, municipales, producción) con colores diferenciados
- [x] 6 gráficas con Chart.js en tiempo real
- [x] Export PDF con desglose + gráficas embebidas
- [x] Modal admin protegido con contraseña para subir imágenes
- [x] Imágenes guardadas en Supabase como base64
- [x] Remove de soportes funcional (bug corregido)
- [x] Logo desde `logo.png` con fallback SVG

---

## 8. Features pendientes / próximos pasos 🔜

- [ ] **Guardar cotizaciones** en Supabase (tabla `cotizaciones` + `cotizacion_items` ya existe)
- [ ] **Cargar cotizaciones guardadas** — historial de propuestas
- [ ] **Nombre del cliente/marca** en la propuesta (campo de texto en header)
- [ ] **Datos del cliente en el PDF** (nombre empresa, contacto, fecha)
- [ ] **Modo de edición** — cargar una cotización guardada y editarla
- [ ] **Compartir propuesta** — link único por cotización
- [ ] **Panel admin completo** — CRUD de soportes (agregar, editar, desactivar) sin tocar Supabase directamente
- [ ] **Responsive/mobile** — actualmente solo desktop
- [ ] **Múltiples monedas** — actualmente todo en UYU

---

## 9. Setup para Claude Code

### Instalar la skill UI UX Pro Max (para mejor diseño)
```bash
npm install -g uipro-cli
uipro init --ai claude --global
```

### Estructura de archivos recomendada para el repo
```
cotizador-movimagen/
├── cotizador.html          # App principal (archivo único)
├── logo.png                # Logo Movimagen
├── CONTEXT.md              # Este archivo
├── sql/
│   ├── supabase_completo.sql    # Setup completo de tablas desde cero
│   └── supabase_datos_reales.sql # Solo los datos (si las tablas ya existen)
└── README.md
```

### Cómo correr localmente
No requiere build ni servidor. Simplemente abrir `cotizador.html` en el navegador. Las llamadas a Supabase funcionan por CORS desde cualquier origen.

> **Nota:** Las imágenes de soportes se guardan como base64 en Supabase, lo que puede hacer las filas pesadas. Para producción considerar migrar a Supabase Storage.

---

## 10. Contexto de negocio

**Cliente:** Movimagen — empresa de publicidad exterior en Uruguay  
**Usuarios:** Media planners y gerentes de marketing  
**Objetivo:** Armar propuestas publicitarias multi-soporte con cálculo automático de inversión, impactos y CPM  
**Soportes disponibles:** 64 soportes reales en Uruguay (Montevideo, Punta del Este, interior del país)  
**Categorías:** Digital (pantallas LED + circuitos), Shopping (banners y ploteos), Exterior (medianeras), Bus (COETC)  
**Particularidad importante:** Punta del Este tiene temporada alta (dic-feb) con precios diferentes y mínimo 13 semanas obligatorio  
**Moneda:** Pesos uruguayos (UYU)  
**IVA:** 22% (aplica a arrendamiento de algunos soportes, y siempre a producción)

---

*Generado desde conversación claude.ai — Abril 2026*
