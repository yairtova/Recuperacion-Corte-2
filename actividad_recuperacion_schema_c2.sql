-- =============================================================
-- ACTIVIDAD DE RECUPERACIÓN · CORTE 2
-- Base de Datos Avanzadas · UP Chiapas · Marzo 2026
-- Mtro. Ramsés Alejandro Camas Nájera
--
-- Schema: Sistema de Clínica Veterinaria
--
-- Instrucciones:
--   1. Crear una base de datos limpia: CREATE DATABASE clinica_vet;
--   2. Conectarse a ella: \c clinica_vet
--   3. Ejecutar este archivo: \i actividad_recuperacion_schema.sql
--   4. NO modificar este archivo. Tu solución va en un archivo aparte.
-- =============================================================

DROP TABLE IF EXISTS alertas               CASCADE;
DROP TABLE IF EXISTS historial_movimientos CASCADE;
DROP TABLE IF EXISTS vacunas_aplicadas     CASCADE;
DROP TABLE IF EXISTS inventario_vacunas    CASCADE;
DROP TABLE IF EXISTS citas                 CASCADE;
DROP TABLE IF EXISTS mascotas              CASCADE;
DROP TABLE IF EXISTS veterinarios          CASCADE;
DROP TABLE IF EXISTS duenos                CASCADE;

-- =============================================================
-- TABLAS
-- =============================================================

CREATE TABLE duenos (
    id        SERIAL PRIMARY KEY,
    nombre    VARCHAR(100) NOT NULL,
    telefono  VARCHAR(20),
    email     VARCHAR(100)
);

CREATE TABLE veterinarios (
    id              SERIAL PRIMARY KEY,
    nombre          VARCHAR(100) NOT NULL,
    cedula          VARCHAR(20) NOT NULL UNIQUE,
    -- Días de descanso del veterinario, separados por coma.
    -- Ejemplos válidos: 'lunes,jueves'  'domingo'  '' (trabaja todos los días)
    -- IMPORTANTE: el procedure debe rechazar agendar cita en estos días.
    dias_descanso   VARCHAR(50) DEFAULT '',
    activo          BOOLEAN DEFAULT TRUE
);

CREATE TABLE mascotas (
    id                SERIAL PRIMARY KEY,
    nombre            VARCHAR(50) NOT NULL,
    especie           VARCHAR(30) NOT NULL,
    fecha_nacimiento  DATE,
    dueno_id          INT NOT NULL REFERENCES duenos(id)
);

CREATE TABLE citas (
    id              SERIAL PRIMARY KEY,
    mascota_id      INT NOT NULL REFERENCES mascotas(id),
    veterinario_id  INT NOT NULL REFERENCES veterinarios(id),
    fecha_hora      TIMESTAMP NOT NULL,
    motivo          TEXT,
    costo           NUMERIC(10, 2),
    estado          VARCHAR(20) DEFAULT 'AGENDADA'
                    CHECK (estado IN ('AGENDADA', 'COMPLETADA', 'CANCELADA'))
);

CREATE TABLE inventario_vacunas (
    id              SERIAL PRIMARY KEY,
    nombre          VARCHAR(80) NOT NULL,
    stock_actual    INT NOT NULL DEFAULT 0 CHECK (stock_actual >= 0),
    stock_minimo    INT NOT NULL DEFAULT 5,
    costo_unitario  NUMERIC(10, 2) NOT NULL
);

CREATE TABLE vacunas_aplicadas (
    id                  SERIAL PRIMARY KEY,
    mascota_id          INT NOT NULL REFERENCES mascotas(id),
    vacuna_id           INT NOT NULL REFERENCES inventario_vacunas(id),
    veterinario_id      INT NOT NULL REFERENCES veterinarios(id),
    fecha_aplicacion    DATE NOT NULL DEFAULT CURRENT_DATE,
    costo_cobrado       NUMERIC(10, 2)
);

CREATE TABLE historial_movimientos (
    id              SERIAL PRIMARY KEY,
    tipo            VARCHAR(30) NOT NULL,
    referencia_id   INT,
    descripcion     TEXT,
    fecha           TIMESTAMP DEFAULT NOW()
);

CREATE TABLE alertas (
    id              SERIAL PRIMARY KEY,
    tipo            VARCHAR(30) NOT NULL,
    descripcion     TEXT,
    fecha           TIMESTAMP DEFAULT NOW()
);

-- =============================================================
-- DATOS DE PRUEBA
-- =============================================================

-- Dueños
INSERT INTO duenos (nombre, telefono, email) VALUES
    ('María González Pérez',     '961-512-3401', 'maria.gonzalez@correo.mx'),
    ('Carlos Hernández Ruiz',    '961-512-3402', 'carlos.hernandez@correo.mx'),
    ('Lucía Martínez López',     '961-512-3403', 'lucia.martinez@correo.mx'),
    ('Diego Ramírez Solís',      '961-512-3404', 'diego.ramirez@correo.mx'),
    ('Ana Patricia Vázquez',     '961-512-3405', NULL),
    ('Roberto Cruz Domínguez',   '961-512-3406', 'roberto.cruz@correo.mx'),
    ('Valentina Ortiz Reyes',    '961-512-3407', 'valentina.ortiz@correo.mx');

-- Veterinarios. Notar dias_descanso variado.
-- Dr. López: descansa lunes y jueves
-- Dra. García: descansa solo domingo
-- Dr. Méndez: trabaja todos los días (cadena vacía)
-- Dra. Sánchez: INACTIVA (no debe poder agendar)
INSERT INTO veterinarios (nombre, cedula, dias_descanso, activo) VALUES
    ('Dr. Fernando López Castro',    'VET-2018-001', 'lunes,jueves', TRUE),
    ('Dra. Sofía García Velasco',    'VET-2019-014', 'domingo',      TRUE),
    ('Dr. Andrés Méndez Bravo',      'VET-2021-027', '',             TRUE),
    ('Dra. Mónica Sánchez Aguilar',  'VET-2017-008', 'lunes',        FALSE);

-- Mascotas. Algunas tienen vacunas viejas, otras nunca, otras recientes.
INSERT INTO mascotas (nombre, especie, fecha_nacimiento, dueno_id) VALUES
    ('Firulais',  'perro',  '2019-03-15', 1),
    ('Misifú',    'gato',   '2020-07-22', 2),
    ('Rocky',     'perro',  '2018-11-08', 3),
    ('Luna',      'gato',   '2022-05-30', 4),
    ('Toby',      'perro',  '2017-02-14', 1),  -- sin vacunas registradas
    ('Pelusa',    'conejo', '2023-09-01', 5),  -- sin vacunas registradas
    ('Max',       'perro',  '2021-04-18', 6),
    ('Coco',      'gato',   '2024-08-12', 7),  -- sin vacunas registradas
    ('Dante',     'perro',  '2016-12-03', 2),
    ('Mango',     'gato',   '2023-01-20', 3);

-- Inventario de vacunas
INSERT INTO inventario_vacunas (nombre, stock_actual, stock_minimo, costo_unitario) VALUES
    ('Antirrábica canina',          25, 10, 350.00),
    ('Quíntuple felina',            18,  8, 480.00),
    ('Parvovirus canino',           12,  5, 290.00),
    ('Triple felina',                7,  8, 410.00),  -- bajo stock
    ('Bordetella canina',           20, 10, 270.00),
    ('Leucemia felina',              4,  5, 520.00);  -- bajo stock

-- Citas históricas y futuras.
-- Hay COMPLETADAS (cuentan en facturación) y AGENDADAS (no cuentan).
INSERT INTO citas (mascota_id, veterinario_id, fecha_hora, motivo, costo, estado) VALUES
    (1, 1, '2025-09-15 10:00:00', 'Revisión general',         450.00, 'COMPLETADA'),
    (1, 2, '2025-11-20 11:00:00', 'Vacunación anual',         350.00, 'COMPLETADA'),
    (2, 2, '2025-10-05 09:30:00', 'Limpieza dental',          780.00, 'COMPLETADA'),
    (3, 1, '2025-08-10 16:00:00', 'Curación de herida',       620.00, 'COMPLETADA'),
    (4, 3, '2026-01-12 12:00:00', 'Esterilización',          1850.00, 'COMPLETADA'),
    (5, 1, '2025-06-22 10:30:00', 'Revisión cojera',          550.00, 'COMPLETADA'),
    (7, 2, '2026-02-08 14:00:00', 'Vacunación múltiple',      650.00, 'COMPLETADA'),
    (9, 3, '2026-03-01 11:30:00', 'Geriatría',                820.00, 'COMPLETADA'),
    -- Citas agendadas a futuro (NO cuentan en facturación)
    (1, 1, '2026-04-20 10:00:00', 'Revisión seguimiento',     500.00, 'AGENDADA'),
    (4, 2, '2026-04-22 09:00:00', 'Control postoperatorio',   400.00, 'AGENDADA'),
    -- Citas canceladas
    (3, 1, '2025-12-15 15:00:00', 'Revisión cancelada',       550.00, 'CANCELADA');

-- Vacunas aplicadas. Distribución intencional:
--  - Mascotas 1, 2, 3, 4, 7, 9: tienen vacunas (algunas viejas, algunas recientes)
--  - Mascotas 5 (Toby), 6 (Pelusa), 8 (Coco), 10 (Mango): sin vacunas — debe aparecer en vista
INSERT INTO vacunas_aplicadas
    (mascota_id, vacuna_id, veterinario_id, fecha_aplicacion, costo_cobrado) VALUES
    (1, 1, 1, '2024-09-15', 350.00),  -- Firulais: hace +500 días → VENCIDA
    (1, 3, 1, '2025-09-15', 290.00),  -- Firulais: hace ~6 meses → vigente
    (2, 2, 2, '2024-08-22', 480.00),  -- Misifú: hace +500 días
    (2, 4, 2, '2025-08-22', 410.00),  -- Misifú: hace ~7 meses → vigente
    (3, 1, 1, '2024-04-10', 350.00),  -- Rocky: hace +700 días → VENCIDA
    (3, 3, 1, '2024-10-10', 290.00),  -- Rocky: hace +500 días → VENCIDA (la más reciente)
    (4, 4, 3, '2026-01-12', 410.00),  -- Luna: reciente → vigente
    (7, 2, 2, '2026-02-08', 480.00),  -- Max: muy reciente → vigente
    (9, 1, 3, '2024-12-01', 350.00);  -- Dante: hace +400 días → VENCIDA

-- =============================================================
-- VERIFICACIÓN DE CARGA
-- =============================================================
DO $$
DECLARE
    v_duenos     INT;
    v_vets       INT;
    v_mascotas   INT;
    v_citas      INT;
    v_vacunas    INT;
BEGIN
    SELECT COUNT(*) INTO v_duenos    FROM duenos;
    SELECT COUNT(*) INTO v_vets      FROM veterinarios;
    SELECT COUNT(*) INTO v_mascotas  FROM mascotas;
    SELECT COUNT(*) INTO v_citas     FROM citas;
    SELECT COUNT(*) INTO v_vacunas   FROM vacunas_aplicadas;

    RAISE NOTICE '=================================================';
    RAISE NOTICE 'Schema cargado correctamente.';
    RAISE NOTICE '  Dueños: %      Veterinarios: %', v_duenos, v_vets;
    RAISE NOTICE '  Mascotas: %    Citas: %', v_mascotas, v_citas;
    RAISE NOTICE '  Vacunas aplicadas: %', v_vacunas;
    RAISE NOTICE '=================================================';
    RAISE NOTICE 'Casos de prueba esperados:';
    RAISE NOTICE '  - Mascotas SIN vacunas: Toby, Pelusa, Coco, Mango';
    RAISE NOTICE '  - Mascotas con vacuna VENCIDA: Firulais, Misifú,';
    RAISE NOTICE '    Rocky, Dante (>365 días desde la última)';
    RAISE NOTICE '  - Veterinario INACTIVO: Dra. Sánchez (id=4)';
    RAISE NOTICE '  - Vet con días de descanso: Dr. López (lun, jue),';
    RAISE NOTICE '    Dra. García (dom)';
    RAISE NOTICE '  - Inventario bajo stock: Triple felina, Leucemia';
    RAISE NOTICE '=================================================';
END $$;

-- =============================================================
-- CASOS DE PRUEBA SUGERIDOS PARA TU PROCEDURE
-- (NO ejecutar aquí — son referencia para que pruebes tu solución)
-- =============================================================
--
-- 1. Caso exitoso:
--    CALL sp_agendar_cita(1, 3, '2026-04-25 10:00:00', 'Revisión', NULL);
--    Esperado: cita creada, p_cita_id devuelto, evento en historial.
--
-- 2. Mascota inexistente:
--    CALL sp_agendar_cita(999, 3, '2026-04-25 10:00:00', 'Test', NULL);
--    Esperado: EXCEPTION 'mascota no existe' (o similar).
--
-- 3. Veterinario inactivo:
--    CALL sp_agendar_cita(1, 4, '2026-04-25 10:00:00', 'Test', NULL);
--    Esperado: EXCEPTION 'veterinario no activo'.
--
-- 4. Día de descanso (Dr. López descansa lunes; 2026-04-20 es lunes):
--    CALL sp_agendar_cita(1, 1, '2026-04-20 10:00:00', 'Test', NULL);
--    Esperado: EXCEPTION 'día de descanso'.
--    (Ya hay una cita AGENDADA en esa fecha — también sirve para test 5.)
--
-- 5. Colisión de horario (otra cita en mismo vet+fecha_hora):
--    Primero agenda una; luego intenta agendar otra al mismo vet a la
--    misma hora. Esperado: EXCEPTION 'horario ocupado'.
--
-- =============================================================
-- CASOS DE PRUEBA SUGERIDOS PARA fn_total_facturado
-- =============================================================
--
-- SELECT fn_total_facturado(1, 2025);  -- Firulais en 2025
--   Esperado: 800.00 (cita 450 + cita 350; vacuna 290 cuenta en 2025)
--   = 450 + 350 + 290 = 1090.00
--
-- SELECT fn_total_facturado(6, 2025);  -- Pelusa (sin actividad)
--   Esperado: 0 (NO NULL — esto es lo que más falló).
--
-- SELECT fn_total_facturado(7, 2026);  -- Max
--   Esperado: 650 (cita) + 480 (vacuna) = 1130.00
--
-- =============================================================
-- CASOS DE PRUEBA SUGERIDOS PARA v_mascotas_vacunacion_pendiente
-- =============================================================
--
-- SELECT * FROM v_mascotas_vacunacion_pendiente
-- ORDER BY prioridad, dias_desde_ultima_vacuna NULLS FIRST;
--
--   Esperado al menos:
--     - Toby, Pelusa, Coco, Mango     → 'NUNCA_VACUNADA'
--     - Rocky, Dante                  → 'VENCIDA' (>365 días)
--     - Firulais, Misifú              → NO aparecen (vacunas <365 días)