# Actividad de Recuperación - Corte 2
**Estudiante:** Cesar Yair Toledo Villarreal
**Matrícula:** 243739
**Carrera:** Ingeniería en Software - Universidad Politécnica de Chiapas  
**Asignatura:** Base de Datos Avanzadas  
**Docente:** Mtro. Ramsés Alejandro Camas Nájera  
**Fecha:** Marzo 2026  

---

## Documento de Decisiones

Este documento justifica las decisiones técnicas tomadas en la implementación del sistema de la Clínica Veterinaria, siguiendo los principios de la guía de estudio proporcionada.

### 1. ¿Por qué tu trigger es AFTER y no BEFORE (o viceversa)?
+El trigger `trg_historial_cita` es **AFTER** porque su propósito es la auditoría y el registro de un historial de movimientos. Se debe ejecutar solo cuando la inserción en la tabla `citas` ha sido garantizada y ha pasado todas las restricciones; usar un trigger `BEFORE` podría generar registros en el historial de eventos que finalmente no se concretaron debido a errores posteriores en la transacción.

### 2. ¿Por qué usaste OUT y no INOUT (o viceversa) para el parámetro `p_cita_id` del procedure?
Se utilizó **OUT** porque el objetivo del parámetro es únicamente devolver al llamador el ID generado por la base de datos tras la inserción. Dado que el llamador no proporciona un valor inicial significativo para este campo, el uso de `OUT` es semánticamente correcto y evita la necesidad de pasar un valor de entrada innecesario.

### 3. ¿Por qué tu vista usa CTE y no una subconsulta directa? ¿Qué calcula tu CTE en una sola frase?
La vista `v_mascotas_vacunacion_pendiente` utiliza un **CTE** para mejorar la legibilidad y documentar la intención del código al separar el cálculo intermedio de la consulta principal. 
**Frase descriptiva:** *El CTE calcula la fecha de la última aplicación de vacuna y los días transcurridos desde entonces para cada mascota registrada.* 

### 4. ¿Cómo manejaste el caso de que una mascota no tenga ninguna cita ni vacuna en tu function `fn_total_facturado`? Muestra la línea exacta donde lo manejas.
Se manejó utilizando la función `COALESCE`, la cual devuelve 0 en lugar de `NULL` cuando las funciones de agregación (`SUM`) no encuentran filas que coincidan con los criterios.
**Línea exacta:** `SELECT COALESCE(SUM(costo), 0) INTO v_total_citas FROM citas ...` 

### 5. Si usaste FOR UPDATE en algún lugar, ¿dónde y por qué?
Se utilizó **FOR UPDATE** dentro del procedure `sp_agendar_cita`, específicamente al consultar el estado del veterinario y al verificar colisiones de horario. Esto se implementó para proteger el patrón *read-decide-write*, bloqueando las filas leídas y forzando a otras transacciones simultáneas a esperar, evitando así que dos secretarias agenden al mismo veterinario en la misma hora exacta.

### 6. ¿Tu procedure tiene ROLLBACK o COMMIT explícito? Si sí, ¿por qué? Si no, ¿cómo se deshacen los cambios cuando ocurre una excepción?
**No tiene** `ROLLBACK` ni `COMMIT` explícitos. Se optó por dejar que la excepción se propague mediante un bloque `EXCEPTION` con la instrucción `RAISE;`. De esta manera, PostgreSQL realiza un rollback automático de todas las operaciones de la transacción al detectar una excepción no atrapada, evitando el error de "invalid transaction termination" que ocurre cuando un procedure intenta gestionar transacciones de las que no es "dueño".