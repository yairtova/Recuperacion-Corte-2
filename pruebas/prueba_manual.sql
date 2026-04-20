-- =======================================================================
-- ARCHIVO DE PRUEBAS MANUALES
-- Ejecutar después de cargar el schema y tu solucion.sql
-- =======================================================================

-- -----------------------------------------------------------------------
-- 1. PRUEBAS: sp_agendar_cita y trg_historial_cita
-- -----------------------------------------------------------------------

-- Prueba 1: Caso exitoso (Debe crear la cita y devolver un ID)
-- El veterinario 3 no tiene días de descanso.
DO $$ 
DECLARE 
    v_nueva_cita_id INT;
BEGIN
    CALL sp_agendar_cita(1, 3, '2026-04-25 10:00:00', 'Revisión General', v_nueva_cita_id);
    RAISE NOTICE 'Prueba 1 Exitosa. ID de nueva cita: %', v_nueva_cita_id;
END $$;

-- Verificar que el trigger funcionó (Debe mostrar el registro de "Cita para Firulais con Dr. Andrés...")
SELECT * FROM historial_movimientos ORDER BY id DESC LIMIT 2;

-- Prueba 2: Mascota inexistente (Debe lanzar error)
-- CALL sp_agendar_cita(999, 3, '2026-04-25 10:00:00', 'Test Mascota', NULL);

-- Prueba 3: Veterinario inactivo (Dra. Sánchez id=4. Debe lanzar error)
-- CALL sp_agendar_cita(1, 4, '2026-04-25 10:00:00', 'Test Inactivo', NULL);

-- Prueba 4: Día de descanso (Dr. López id=1 descansa lunes; 2026-04-20 es lunes. Debe lanzar error)
-- CALL sp_agendar_cita(1, 1, '2026-04-20 10:00:00', 'Test Descanso', NULL);

-- Prueba 5: Colisión de horario (Intentamos agendar a la misma hora que la Prueba 1 con el Vet 3. Debe lanzar error)
-- CALL sp_agendar_cita(2, 3, '2026-04-25 10:00:00', 'Test Colisión', NULL);


-- -----------------------------------------------------------------------
-- 2. PRUEBAS: fn_total_facturado
-- -----------------------------------------------------------------------

-- Prueba 6: Firulais en 2025 (Debe devolver 1090.00 -> 450 + 350 de citas + 290 de vacuna)
SELECT fn_total_facturado(1, 2025) AS total_firulais_2025;

-- Prueba 7: Pelusa en 2025 (Debe devolver 0, no NULL)
SELECT fn_total_facturado(6, 2025) AS total_pelusa_2025;

-- Prueba 8: Max en 2026 (Debe devolver 1130.00 -> 650 de cita + 480 de vacuna)
SELECT fn_total_facturado(7, 2026) AS total_max_2026;


-- -----------------------------------------------------------------------
-- 3. PRUEBAS: v_mascotas_vacunacion_pendiente
-- -----------------------------------------------------------------------

-- Prueba 9: Verificar la vista de vacunación
-- Deben aparecer Toby, Pelusa, Coco, Mango como 'NUNCA_VACUNADA'.
-- Deben aparecer Rocky, Dante como 'VENCIDA'.
SELECT * FROM v_mascotas_vacunacion_pendiente
ORDER BY prioridad, dias_desde_ultima_vacuna NULLS FIRST;