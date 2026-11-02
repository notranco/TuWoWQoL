# TuWoW QoL

Addon experimental de calidad de vida para **TuWoW en World of Warcraft 3.3.5a** (`Interface: 30300`).

## Funciones

- Avisos y cuenta regresiva para Putrefacto y el vómito.
- Alertas de contagio, comida, inmunidad y jugadores cercanos. La detección puede usar miembros del grupo, unidades seleccionadas o nameplates amistosas.
- Opción experimental para activar las nameplates amistosas y ocultarlas visualmente mientras se detectan unidades.
- Sincronización de estado con usuarios del addon por grupo/banda y, opcionalmente, por `/decir`.
- Radar opcional, botón de minimapa y editor de interfaz para mover y ajustar los elementos.
- Opciones con desplazamiento vertical para acceder a todos los ajustes.
- Hotspot de luna/sol con tooltip de fase y cuenta regresiva día/noche de TuWoW, centrado sobre el icono nativo de ciclo de ForeverUI; si no existe, muestra su propio icono en una posición visible. El botón de TuWoWQoL queda reservado para abrir la configuración. Usa un ciclo de 2 horas y el horario 06:00–20:00 del juego. El addon avisa cinco minutos antes de la noche; al comenzar, muestra la información de Rabiar, loot x2 y +10% de experiencia que anuncia el servidor.

La detección depende de los hechizos, eventos y unidades que exponga el servidor. Puede ser incompleta; las funciones experimentales requieren pruebas en TuWoW.

## Instalación

1. Copia la carpeta `TuWoWQoL` en `World of Warcraft/Interface/AddOns/`.
2. Activa el addon en la pantalla de selección de personaje.
3. Abre las opciones desde **Interfaz > AddOns > TuWoW QoL**.

## Comandos

- `/twqol` o `/tuwowqol`: abrir opciones.
- `/twqol status`: mostrar tu estado y la sincronización.
- `/twqol debug`: activar o desactivar el registro de diagnóstico.
- `/twqol radar`: mostrar u ocultar el radar.
- `/twqol lista`: listar usuarios detectados del addon.
- `/twqol test`: simular entradas para probar el radar.
- `/twqol editar`: abrir el editor de interfaz.
- `/twqol ayuda`: mostrar la ayuda.

## Estado

Versión del addon: **0.5.14**. Incluye tooltips con filas alineadas, separadores y colores, muestra la versión junto al nombre en el botón de minimapa y centra el hotspot del ciclo sobre el icono nativo de ForeverUI. Verifica las detecciones dentro del servidor antes de depender de sus alertas.

El código se distribuye bajo la licencia [MIT](LICENSE).
