# TuWoW QoL

Addon experimental de calidad de vida para **TuWoW en World of Warcraft 3.3.5a** (`Interface: 30300`).

## Funciones

- Avisos y cuenta regresiva para Putrefacto y el vómito.
- Alertas de contagio, comida, inmunidad y jugadores cercanos. La detección puede usar miembros del grupo, unidades seleccionadas o nameplates amistosas.
- Opción experimental para activar las nameplates amistosas y ocultarlas visualmente mientras se detectan unidades.
- Sincronización de estado con usuarios del addon por grupo/banda y, opcionalmente, por `/decir`.
- Radar opcional, botón de minimapa y editor de interfaz para mover y ajustar los elementos.
- Reconocimiento del mensaje de náuseas al vomitar para cerrar la cuenta regresiva existente sin duplicar alertas.
- Opciones con el scroll nativo de WoW (barra, flechas y rueda del mouse).
- Hotspot de luna/sol con tooltip de fase y cuenta regresiva día/noche de TuWoW, centrado sobre el icono nativo de ciclo de ForeverUI; si no existe, muestra su propio icono en una posición visible. El botón de TuWoWQoL queda reservado para abrir la configuración. El ciclo completo dura 2 horas. El addon toma como referencia el anuncio del servidor (día o noche), lo guarda con la hora real —así sobrevive a relogueos— y calcula la fase desde ahí; aprende la duración real del día y de la noche al ver dos anuncios seguidos (mientras tanto estima 06:00–20:00 dentro del ciclo de 2 h). Avisa cinco minutos antes de la noche; al comenzar, muestra la información de Rabiar, loot x2 y +10% de experiencia que anuncia el servidor.
- Banner al empezar la noche (Rabiar activo, loot x2, +10% de experiencia) y al amanecer, textos editables. Comando `/twqol ciclo` para ver la fase y calibrarla a mano (`/twqol ciclo dia|noche [minutos]`, `/twqol ciclo reset`) cuando se pierde un anuncio. Las duraciones aprendidas solo se aceptan si día + noche cierra con el ciclo de 2 h, y los anuncios que escribe un jugador (decir, aviso de raid, enlaces `|Hplayer:`) se ignoran.
- Aviso opcional por `/decir` antes de vomitar si hay gente cerca (apagado por defecto, una vez por cuenta regresiva), para quienes no tienen el addon.
- El aviso "¡Alejate!" considera grupo, nameplates (aunque estén ocultas), objetivo, foco y cursor, no solo el grupo.
- Si hay un addon que traiga LibRangeCheck-3.0, las distancias usan esa librería (10 y 28 yd más precisas); si no, se usa `CheckInteractDistance`.
- Los spellIds de vómito reconocidos por nombre se guardan y se listan con `/twqol ids` para completar `NS.VOMIT_SPELL_IDS`.
- Aviso de actualización por comunicación entre addons: compara la versión de TuWoWQoL con la que anuncian otros jugadores del grupo, banda o hermandad y avisa si detecta una superior. Envía el saludo de versión aunque la sincronización de estados esté desactivada.

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
- `/twqol ciclo [dia|noche [min] | reset]`: ver o calibrar el ciclo día/noche.
- `/twqol ids`: listar los spellIds de vómito aprendidos.
- `/twqol ayuda`: mostrar la ayuda.

## Estado

Versión del addon: **0.7.0**. Correcciones del editor, de la migración de opciones y de las nameplates silenciosas; ciclo día/noche más robusto con calibración manual; avisos de "alejate" ampliados; mejoras de rendimiento.

## Estructura

Todos los archivos comparten una tabla de espacio de nombres (`local _, NS = ...`); el orden de carga está en `TuWoWQoL.toc`.

- `Modules/DayNight.lua`: ciclo día/noche, botón del minimapa y tooltip.
- `Core/Constants.lua`: constantes, estilos de mensaje, textos, valores por defecto y estado compartido.
- `Core/Utilities.lua`: pruebas, estado y ayuda de los comandos.
- `Core/Events.lua`: eventos, bucle principal y comandos `/twqol`.
- `UI/Banner.lua`, `UI/Bar.lua`, `UI/Messages.lua`: aviso en pantalla, barra de tiempo y mensajes.
- `UI/Radar.lua`: radar de contagio.
- `UI/Minimap.lua`: botón de minimapa.
- `UI/Options.lua`: panel en Interfaz > AddOns (con el scroll nativo de WoW).
- `UI/Editor.lua`: editor de interfaz.
- `Detection/Auras.lua`, `Detection/People.lua`, `Detection/CombatLog.lua`, `Detection/Contagion.lua`: detección de Putrefacto, jugadores cercanos, combat log y contagio.
- `Sync/Sync.lua`: sincronización entre usuarios del addon.
- `Logic/Countdown.lua`, `Logic/Maintenance.lua`: cuenta regresiva del vómito y tareas periódicas.

El código se distribuye bajo la licencia [MIT](LICENSE).
