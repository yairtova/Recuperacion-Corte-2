-- =======================================================================
-- 1. Stored Procedure: sp_agendar_cita
-- =======================================================================
CREATE OR REPLACE PROCEDURE sp_agendar_cita(
    p_mascota_id INT,
    p_veterinario_id INT,
    p_fecha_hora TIMESTAMP,
    p_motivo TEXT,
    OUT p_cita_id INT
)
LANGUAGE plpgsql AS $$
DECLARE
    v_mascota_existe BOOLEAN;
    v_vet_activo BOOLEAN;
    v_dias_descanso VARCHAR(50);
    v_dia_semana_cita VARCHAR(15);
    v_colision INT;
BEGIN
    -- 1. Validar existencia de mascota manejando explícitamente el NULL
    SELECT EXISTS(SELECT 1 FROM mascotas WHERE id = p_mascota_id) INTO v_mascota_existe;
    IF v_mascota_existe IS NOT TRUE THEN
        RAISE EXCEPTION 'La mascota con ID % no existe.', p_mascota_id;
    END IF;

    -- 2. Validar veterinario y bloquear fila por concurrencia (Patrón Read-Decide-Write)
    -- Usamos FOR UPDATE para que si alguien más intenta agendar a este vet, espere.
    SELECT activo, dias_descanso INTO v_vet_activo, v_dias_descanso
    FROM veterinarios
    WHERE id = p_veterinario_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El veterinario con ID % no existe.', p_veterinario_id;
    ELSIF v_vet_activo IS NOT TRUE THEN
        RAISE EXCEPTION 'El veterinario no está activo en el sistema.';
    END IF;

    -- 3. Validar día de descanso.
    -- Mapeamos DOW (Day Of Week) a español para asegurar compatibilidad exacta con "lunes,jueves"
    v_dia_semana_cita := CASE EXTRACT(DOW FROM p_fecha_hora)
        WHEN 0 THEN 'domingo' WHEN 1 THEN 'lunes' WHEN 2 THEN 'martes'
        WHEN 3 THEN 'miercoles' WHEN 4 THEN 'jueves' WHEN 5 THEN 'viernes' WHEN 6 THEN 'sabado'
    END;

    IF position(v_dia_semana_cita in v_dias_descanso) > 0 THEN
        RAISE EXCEPTION 'No se puede agendar. El veterinario descansa los días %.', v_dia_semana_cita;
    END IF;

    -- 4. Prevenir colisiones exactas de horario (Concurrencia)
    SELECT id INTO v_colision
    FROM citas
    WHERE veterinario_id = p_veterinario_id
      AND fecha_hora = p_fecha_hora
    FOR UPDATE; -- Bloqueamos también la lectura de citas

    IF FOUND THEN
        RAISE EXCEPTION 'Horario ocupado. Ya existe una cita para ese veterinario en esa fecha y hora.';
    END IF;

    -- 5. Insertar cita y devolver el ID en el parámetro OUT
    INSERT INTO citas (mascota_id, veterinario_id, fecha_hora, motivo, estado)
    VALUES (p_mascota_id, p_veterinario_id, p_fecha_hora, p_motivo, 'AGENDADA')
    RETURNING id INTO p_cita_id;

EXCEPTION
    WHEN OTHERS THEN
        -- EXCEPCIÓN SIN ROLLBACK: Solo propagamos el error para no tronar la transacción externa
        RAISE;
END;
$$;


-- =======================================================================
-- 2. Trigger: trg_historial_cita (y su función)
-- =======================================================================
CREATE OR REPLACE FUNCTION fn_registrar_historial_cita()
RETURNS TRIGGER AS $$
DECLARE
    v_mascota_nombre VARCHAR(50);
    v_vet_nombre VARCHAR(100);
    v_descripcion TEXT;
BEGIN
    -- Buscamos los nombres legibles
    SELECT nombre INTO v_mascota_nombre FROM mascotas WHERE id = NEW.mascota_id;
    SELECT nombre INTO v_vet_nombre FROM veterinarios WHERE id = NEW.veterinario_id;
    
    -- Formateamos la descripción solicitada
    v_descripcion := format('Cita para %s con %s el %s', v_mascota_nombre, v_vet_nombre, to_char(NEW.fecha_hora, 'DD/MM/YYYY'));

    INSERT INTO historial_movimientos (tipo, referencia_id, descripcion, fecha)
    VALUES ('CITA_AGENDADA', NEW.id, v_descripcion, NOW());

    -- Retornamos NULL porque es un trigger AFTER
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Definimos el Trigger como AFTER para garantizar que la cita SÍ se insertó con éxito
CREATE TRIGGER trg_historial_cita
AFTER INSERT ON citas
FOR EACH ROW
EXECUTE FUNCTION fn_registrar_historial_cita();


-- =======================================================================
-- 3. Function: fn_total_facturado
-- =======================================================================
CREATE OR REPLACE FUNCTION fn_total_facturado(
    p_mascota_id INT,
    p_anio INT
) RETURNS NUMERIC
LANGUAGE plpgsql AS $$
DECLARE
    v_total_citas NUMERIC;
    v_total_vacunas NUMERIC;
BEGIN
    -- Sumamos citas usando COALESCE para devolver 0 si no hay registros, evitando el NULL
    SELECT COALESCE(SUM(costo), 0) INTO v_total_citas
    FROM citas
    WHERE mascota_id = p_mascota_id
      AND estado = 'COMPLETADA'
      AND EXTRACT(YEAR FROM fecha_hora) = p_anio;

    -- Sumamos vacunas usando COALESCE
    SELECT COALESCE(SUM(costo_cobrado), 0) INTO v_total_vacunas
    FROM vacunas_aplicadas
    WHERE mascota_id = p_mascota_id
      AND EXTRACT(YEAR FROM fecha_aplicacion) = p_anio;

    RETURN v_total_citas + v_total_vacunas;
END;
$$;


-- =======================================================================
-- 4. Vista: v_mascotas_vacunacion_pendiente
-- =======================================================================
CREATE OR REPLACE VIEW v_mascotas_vacunacion_pendiente AS
-- Utilizamos el CTE para aislar la lógica del cálculo de la última vacuna por mascota
WITH calculo_vacunas AS (
    SELECT 
        mascota_id,
        MAX(fecha_aplicacion) AS fecha_ultima_vacuna,
        CURRENT_DATE - MAX(fecha_aplicacion) AS dias_desde_ultima
    FROM vacunas_aplicadas
    GROUP BY mascota_id
)
SELECT 
    m.nombre AS nombre,
    m.especie,
    d.nombre AS nombre_dueno,
    d.telefono AS telefono_dueno,
    cv.fecha_ultima_vacuna,
    cv.dias_desde_ultima,
    CASE 
        WHEN cv.fecha_ultima_vacuna IS NULL THEN 'NUNCA_VACUNADA'
        WHEN cv.dias_desde_ultima > 365 THEN 'VENCIDA'
    END AS prioridad
FROM mascotas m
-- LEFT JOIN indispensable para no perder a las mascotas que nunca se han vacunado
LEFT JOIN duenos d ON m.dueno_id = d.id
LEFT JOIN calculo_vacunas cv ON m.id = cv.mascota_id
WHERE cv.fecha_ultima_vacuna IS NULL 
   OR cv.dias_desde_ultima > 365;