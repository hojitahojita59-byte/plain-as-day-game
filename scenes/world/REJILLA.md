# La rejilla de Broad Street

Todo el kit `art/models/Modular/` está importado con **root_scale = 5.0**. Eso
fija una rejilla, y **todo lo que coloques tiene que caer en ella**. Si te sales,
las piezas se solapan y ves el parpadeo de dos caras peleándose por el mismo
píxel (*z-fighting*).

## Los números

| Concepto | Valor | De dónde sale |
|---|---|---|
| Ancho / fondo de un módulo | **5** | 1 × 5 |
| **Altura de una planta** | **3,125** | 0,625 × 5 |
| Altura de una pieza de tejado | 1,06 | 0,212 × 5 |
| Superficie de la cubierta | 6,78 | 6,25 + 0,106 × 5 |
| Remate del pretil | 7,31 | 6,25 + 0,212 × 5 |

Las plantas van en `y = 0`, `3,125`, `6,25`… **Nunca redondees a 3 y 6.** La
diferencia de 0,125 es justo el solape.

En el editor: `Escena ▸ Ajustes de transformación`, *Translate Snap* a `2.5`.

## OJO: en un .tscn, Transform3D son FILAS, no columnas

Esto me costó un tejado mal montado, así que queda escrito.

```
Transform3D(a,b,c,  d,e,f,  g,h,i,  ox,oy,oz)
             fila0   fila1   fila2   origen
```

Son las **filas** de la matriz, no los vectores de los ejes. Para un giro sobre
Y de ángulo θ la matriz es:

```
 cos θ   0   sin θ        θ = +90°  →  Transform3D(0,0, 1,  0,1,0,  -1,0,0, …)
   0     1     0          θ = -90°  →  Transform3D(0,0,-1,  0,1,0,   1,0,0, …)
-sin θ   0   cos θ
```

Si lo lees como columnas te sale **el giro contrario**, y con piezas simétricas
(como los tramos rectos de tejado) ni te enteras: el fallo solo aparece en las
piezas asimétricas, como los remates.

Comprobación rápida: el `Sun` de esta escena es
`Transform3D(1,0,0, 0,0.5,0.866, 0,-0.866,0.5, …)`. Leído como filas es un giro
de -60° sobre X y el sol apunta hacia abajo. Leído como columnas apuntaría
hacia arriba y no habría sombras.

## Cómo está orientado el kit

Lo saqué leyendo la geometría de los `.glb`, no a ojo:

- **Las fachadas miran a +Z.** Toda la decoración está en la cara +Z. La cara
  -Z es un plano liso.
- **El origen de cada pieza está abajo y en el centro.**
- **El fondo del retranqueo está en `z = 0,4`** (world `-5,5` con los módulos en
  `z = -7,5`). Ahí es donde van los marcos y las hojas, no a ras de fachada.

### Huecos y qué pieza encaja en cada uno

Medidos, no estimados. Encajan **exactos**:

| Módulo | Hueco | Ancho × alto | Pieza | Y local |
|---|---|---|---|---|
| `building-windows` | 2 ventanas en `x = ±0,219` | 0,313 × 0,38 | `window-brown-detailed` | 0,12 |
| `building-window-door-window` | 2 ventanas en `x = ±0,3125` | 0,187 × 0,422 | `window-brown-narrow` | 0,078 |
| `building-window-door-window` | puerta centrada | 0,25 × 0,5 | `door-brown` | 0 |

Los módulos traen el **hueco**, no la carpintería. Si no colocas estos, las
ventanas se ven como agujeros negros.

## Las piezas de tejado

Se distinguen por en qué lados llevan el pretil:

| Pieza | Pretil en |
|---|---|
| `roof-flat-border-end` | -X, +X y +Z (abierta solo por -Z) |
| `roof-flat-border-straight` | -X y +X |
| `roof-flat-border-side` | solo +Z |
| `roof-flat-border-center` | los cuatro lados |

**Una casa de 2 módulos se cubre con dos `roof-flat-border-end` enfrentadas**:

- la de la izquierda con θ = **-90°** → `Transform3D(0,0,-1, 0,1,0, 1,0,0, …)`
- la de la derecha con θ = **+90°** → `Transform3D(0,0,1, 0,1,0, -1,0,0, …)`

Entre las dos queda el tejado cerrado por sus cuatro lados: pretil delante,
detrás y en las dos medianeras, y la cubierta continua en medio. Así cada casa
tiene **su** tejado, que es como funciona una hilera de verdad — la medianera
sube por encima de la cubierta y separa una vivienda de la siguiente.

`roof-flat-border-center` es para una casa **aislada**; en una hilera mete
pretil donde no toca.

## Cómo está montada la hilera

6 bahías de 5 en `x = -12,5 … +12,5` (la hilera va de -15 a +15), con los
módulos en `z = -7,5`, o sea la fachada en `z = -5`. **3 casas de 2 bahías.**

```
x:      -15    -12,5    -7,5    -5     -2,5    2,5     5      7,5    12,5   15
         ║  ventana  PUERTA  ║  ventana  PUERTA  ║  ventana  PUERTA  ║
         ╚═══ casa 1 ═══════╝╚═══ casa 2 ═══════╝╚═══ casa 3 ═══════╝
      pilastra          pilastra          pilastra          pilastra
      + medianera       + medianera       + medianera       + medianera
```

Las tres puertas interactuables están en `x = -7,5`, `2,5` y `12,5`.

Las líneas de medianera (`x = ±5` y los extremos `±15`) mandan sobre **tres**
cosas a la vez, y por eso la fachada se lee como tres casas y no como una tira:

1. la **pilastra** (`props/pilastra.tscn`), de 0 a 7,31, en `z = -4,925`
2. el **pretil** que separa un tejado del siguiente
3. la **chimenea** (`props/chimenea.tscn`), centrada en cada casa (`x = -10, 0,
   +10`), apoyada en la cubierta a `y = 6,78`, retrasada a `z = -8,6`

El `z = -4,925` de la pilastra no es capricho: tiene 0,35 de fondo, así que va
de `-5,10` a `-4,75`. Queda 0,10 enterrada en la fachada y 0,40 fuera. **Nunca
la dejes a ras**, porque dos caras en el mismo plano vuelven a dar z-fighting.

## Color y el pase de estilo

`art_style.gd` baja la saturación de TODA la escena a 0,35. Un color de prop
que en el inspector parece piedra cálida sale **gris** en pantalla. Hay que
elegirlo sobresaturado a propósito: la pilastra es `(0.74, 0.62, 0.44)` y el
ladrillo de la chimenea `(0.58, 0.34, 0.26)`, bastante más naranjas de lo que
se ve al final.

## Colisión

Hay **un solo** `StaticBody3D` para toda la hilera (`Terraza/Muro`), una caja
de 30 × 6,25 × 5 que coincide con la fachada.

Los interactuables de las puertas están en `z = -5`, o sea 0,2 por delante del
muro. Eso es lo que hace que el rayo del ratón toque la puerta antes que la
pared y se dispare el diálogo.

Los `.glb` de Kenney **no traen colisión** (Godot solo la genera si la malla
lleva el sufijo `-col`). La geometría es decorado; la colisión la pones tú.

---

# La calle

## Sección transversal (eje Z)

```
z = -5      fachada de la hilera
z = -5 …  -2,4   acera sur (2,6)   ← aquí van árboles y farolas
z = -2,4         bordillo
z = -2,4 … 2,4   calzada (4,8)     ← aquí van el jugador, la bomba y el carro
z =  2,4         bordillo
z =  2,4 … 8,5   acera norte (6,1) ← puestos de mercado
z =  8,5         muro bajo (0,9 de alto)
```

**El pavimento no tiene colisión.** Es todo mallas sueltas colgando de
`Calle/Pavimento`. Las aceras están levantadas 10 cm y el jugador es un
`CharacterBody3D` **sin gravedad** (mira `point_click_controller.gd`: la
velocidad lleva siempre `y = 0`). Si le pusieras colisión al bordillo, el
personaje se quedaría enganchado en él para siempre. La única colisión del
suelo es el `Floor` plano de debajo.

## Por qué la acera norte es tan ancha

No es un capricho urbanístico: es el **borde inferior del encuadre**.

Con la cámara a `y = 9` y 42° de inclinación, el borde de abajo de la pantalla
corta el suelo a `9 / tan(42° + 26°) ≈ 3,6` unidades por delante de la cámara,
o sea en torno a `z = 7,4`. Todo lo que quede entre ahí y el muro se ve, y si
no hay nada, se ve una franja de suelo vacío que ocupa media pantalla.

Esa franja **no se quita moviendo la cámara**: al acercarla o alejarla, el
borde se mueve con ella y la proporción se mantiene. Se quita **llenándola**.
Por eso la acera llega hasta 8,5 y por eso hay puestos de mercado ahí.

Si algún día cambias la altura o el ángulo de la cámara, recalcula ese número
y estira o encoge la acera norte hasta él.

## Por qué no hay casas enfrente

Lo intenté y la cámara se metía dentro.

La cámara sigue al personaje **10 unidades por detrás en +Z**. El jugador llega
hasta `z ≈ 2`, así que la cámara llega a `z ≈ 12`. Cualquier edificio en la
acera de enfrente estaría o bien atravesado por la cámara, o bien **detrás**
de ella, que es peor: no se vería nunca y solo gastaría triángulos.

Con cámara de persecución mirando a -Z, el lado +Z de la calle solo admite
cosas **bajas**. De ahí el muro de 0,9 y los puestos.

## Los kits y sus escalas

| Kit | root_scale | Unidad resultante |
|---|---|---|
| `Modular/` | **5.0** | módulo de 5 × 3,125 × 5 |
| `Medieval/` | **2.0** | farola 3,1 m, carro 1,8 × 2,7 |

Los dos están normalizados **enteros**. Arrastra cualquier pieza y cae a la
escala correcta.

**Los cinco árboles del kit Medieval son coníferas.** Lo comprobé midiendo su
silueta por franjas: las cinco se estrechan de abajo arriba sin interrupción,
que es el perfil de un abeto. Un abeto en el Soho de 1854 canta muchísimo, así
que el árbol de calle es `props/arbol.tscn`, hecho a mano: tronco y tres
esferas solapadas. Con una sola esfera parece una piruleta.

## Color y el pase de estilo

`art_style.gd` dessatura TODO a 0,35. Cualquier color de prop hay que elegirlo
**sobresaturado**, o sale gris. Ejemplos que ya están calibrados: verde de copa
`(0.36, 0.48, 0.22)`, ladrillo `(0.58, 0.34, 0.26)`, pilastra
`(0.74, 0.62, 0.44)`.

Lo mismo con los oscuros: los herrajes de la bomba estaban en `(0.19, 0.20,
0.22)` y se fundían con el contorno negro; la bomba entera parecía una mancha.
Ahora van en `(0.44, 0.46, 0.48)`.

---

# Navegación: por qué el personaje ya no tiembla

El temblor contra la pared no era un fallo de la colisión, era **falta de mapa
de navegación**.

Sin él, `point_click_controller.gd` camina en línea recta hacia donde clicas.
Si clicabas al otro lado de un muro, el destino era inalcanzable: el personaje
empujaba contra la pared, la rutina de esquiva le hacía escurrirse a un lado,
volvía a empujar, y así 45 fotogramas hasta que `_is_stuck()` se rendía. Eso
era el temblor.

Ahora hay un `NavigationRegion3D` (nodo `NavRegion`) que se calcula al arrancar
y un `NavigationAgent3D` colgando de Whitehead. Con eso:

- **`map_get_closest_point()` recorta el destino** al punto caminable más
  cercano. Clicas a 25 metros y te manda al borde de la calle. Nunca hay un
  destino inalcanzable, así que nunca hay empuje contra el muro.
- El agente **rodea** árboles, farolas y puestos en vez de chocar con ellos.

Comprobado: clic en `x=25` → va a `14,68`. Clic en `z=14` → va a `7,92`.

## Cómo está configurado el horneado

```
geometry_parsed_geometry_type = 1   (STATIC_COLLIDERS)
geometry_source_geometry_mode = 1   (GROUP_WITH_CHILDREN)
geometry_source_group_name    = "navegable"
filter_baking_aabb            = AABB(-15.2, -1, -4.8, 30.4, 6, 13.2)
```

El nodo `Calle` está en el grupo **`navegable`**: de ahí saca la geometría.
Usa las **formas de colisión**, no las mallas, que es más barato y más preciso
(el pavimento no tiene colisión, así que no confunde al horneado).

El `filter_baking_aabb` es el que recorta la zona jugable. **Es el número que
hay que tocar si quieres agrandar o encoger por dónde se puede andar**, y no
tiene nada que ver con lo que se ve.

`nav_region.gd` solo hornea si la malla viene vacía. Cuando la calle esté
cerrada, selecciona el nodo en el editor y dale a *Bake NavigationMesh*: se
guardan los polígonos y el guion se calla solo.

# Qué lleva colisión y qué no

| | Colisión | Por qué |
|---|---|---|
| Fachada (`MuroSur`) | Sí, caja de 50 × 6,25 × 5 | El rayo del ratón tiene que chocar con algo |
| Puertas | Sí, 0,2 por delante del muro | Para que el rayo las toque antes que la pared |
| Árbol, farola | Sí, de fábrica en el prop | — |
| Puestos y carros | Sí, en `Calle/Solidos` | Los `.glb` de Kenney no traen colisión |
| **Pavimento** | **No** | Bordillo con colisión = personaje enganchado (no hay gravedad) |
| Copa de los árboles | **No** | Pararías a dos metros del árbol sin motivo visible |

Los árboles llevan la colisión solo en el **tronco**, a propósito.

# El mundo que se ve pero no se pisa

La hilera tiene **10 bahías** (`x = -22,5 … 22,5`), pero solo se puede andar
entre `x = ±15,2`. Las dos bahías de cada extremo existen únicamente para que
la calle parezca continuar.

**El límite es invisible y no hay ningún muro.** No hace falta: el mapa de
navegación acaba ahí, así que `map_get_closest_point()` devuelve siempre un
punto dentro de la calle. Si clicas más allá, el personaje camina hasta el
borde y se planta. Nunca empuja contra nada, porque no hay nada contra lo que
empujar.

Hubo un momento una valla de obra para justificar el corte, pero se quitó a
propósito: cortaba la vista de la calle que continúa, que era justo lo que se
quería enseñar.

Para mover el límite se toca **`filter_baking_aabb`**, no la geometría.

# El adoquinado

`materials/adoquin.gdshader`, procedimental. No hay ninguna imagen.

La razón de fondo no es la falta de texturas: es que el patrón se calcula sobre
las **coordenadas del mundo**, no sobre las UV. La calzada mide 100 × 4,8 y la
acera 100 × 6,1; con una textura UV normal, cada una estiraría el dibujo de
forma distinta y se vería el salto justo en el bordillo. Calculándolo en
coordenadas de mundo, la losa mide lo mismo en toda la calle.

Mismo shader para las dos, cambiando parámetros:

| | celdas | proporcion | alabeo |
|---|---|---|---|
| Calzada (adoquín ~40 cm) | 2.6 | 1.0 | 0.5 (a matajunta) |
| Acera (losa rectangular) | 1.05 | 1.7 | 0.0 (a hueso) |

# Las farolas encendidas

`props/farola.tscn` = modelo del kit + `OmniLight3D` + colisión.

La luz va con **`shadow_enabled = false` a propósito**. Cada sombra de luz
puntual cuesta seis pasadas de render (una por cara del cubo). Son cinco
farolas: treinta pasadas para unas sombras que a esta distancia no se
distinguen. Las sombras que importan las tira el sol, que sí las tiene.

La esfera `Vidrio` con emisión no es decorativa: sin ella la luz sale de la
nada y el ojo no se lo cree.

# La trampa de la altura: por qué el personaje no andaba

Este falló de una forma engañosa: la ruta se calculaba bien (9 puntos), el
agente decía que no había terminado, y aun así el personaje **no se movía ni
un milímetro**.

La causa: el origen de Whitehead está en el **centro** de la cápsula
(`y = 0,9`), pero el mapa de navegación es una alfombra pegada al suelo
(`y = 0,2`). Los puntos de la ruta llegaban 0,7 m por debajo de sus pies.

Eso rompía **dos cosas a la vez**, y por eso costó verlo:

1. `point_click_controller.gd` hace `step.y = 0` para que nadie vuele. Si la
   única diferencia entre el personaje y el siguiente punto era esa altura, el
   paso quedaba de longitud **cero** y no se andaba.
2. El agente decide que ha llegado a un punto por distancia **en 3D**. Los 0,7
   de altura nunca bajaban de su umbral (`path_desired_distance = 0,4`), así
   que no pasaba jamás al punto siguiente: clavado en el primero para siempre.

La solución es `path_height_offset`, que se **resta** de la altura de cada
punto de la ruta. Pero **no está escrito a mano**: `_ajustar_altura_de_ruta()`
lo mide al arrancar preguntando dónde cae el suelo bajo los pies. Así sigue
funcionando aunque cambies la altura de la cápsula o el `cell_height` del mapa.

## Y otra trampa dentro de la trampa

La primera versión de esa medición daba `-0,90` en vez de `-0,70`, y **también
funcionaba**, lo cual es peor que fallar.

El motivo: el servidor de navegación sincroniza sus mapas por su cuenta, y si
le preguntas antes de tiempo la consulta falla y devuelve `(0,0,0)`. Un cero
es un número perfectamente creíble, así que el error pasaba desapercibido.

Por eso el bucle no espera un número fijo de fotogramas: pregunta hasta que la
respuesta **tenga sentido**. El personaje arranca de pie sobre el mapa, luego
el punto más cercano tiene que caer casi bajo sus pies; si sale a metros de
distancia, es que todavía no hay mapa.

**Regla general para este proyecto:** cuando midas algo del servidor de
navegación, valida que la respuesta sea plausible. No te fíes de que no haya
error en consola.

---

# La calle ya no se coloca a mano

**Esto es lo que cambió el 30 de agosto de 2026, y cambia cómo se trabaja.**

`broad_street.tscn` ya no existe. Había mil líneas de piezas puestas una a una,
y ese era el motivo real de llevar un mes en tres casas: añadir una calle
costaba una tarde y añadir una puerta costaba abrir el editor y acordarse de
siete números.

Ahora hay **una sola escena** —`calle.tscn`— y **un archivo por calle** en
`res://data/barrio/`. La escena trae lo que no cambia (cielo, sol, pavimento,
jugador, cámara, pase de estilo) y `constructor_calle.gd` levanta lo demás
leyendo el archivo de `Barrio.actual`.

## Poner una calle nueva

1. Un `.json` en `data/barrio/`.
2. Su id en `data/barrio/_indice.json`.

No hay paso tres. **No se abre el editor.**

## Poner una puerta

```json
{ "x": 7.5, "numero": "40", "dialogo": "ch1_s3_puerta_40",
  "nombre": "Number forty", "requiere": ["knows_the_coal_womans_house"],
  "si_no": "ch1_s3_door_unknown",
  "ropa": { "abrigo": [0.26,0.21,0.24], "chal": true, "estatura": 0.94 } }
```

La `x` tiene que caer en una bahía (`origen_x + 5·n`). El constructor entonces
pone **a la vez** el módulo con hueco, las dos ventanas estrechas, la hoja que
gira, el vecino vestido y el número pintado.

**Ese «a la vez» es el arreglo del número 40.** Ese portal se hizo a mano y se
quedó a medias: sin hoja, y con la ventana ancha de cuando era ventana metida
encima del hueco estrecho. Ahora una bahía con puerta no puede quedarse a
medias, porque las cinco piezas salen de la misma línea del archivo.

## Poner un vecino

Ya no hace falta un `.tscn` por persona. `figura.tscn` + un diccionario de
`ropa` (los nombres están en `vestuario.gd`) y ya existe. Es el generador de
NPC del que hablabas el primer día, con una diferencia: **no genera al azar.**
Cada vecino está escrito, para que puedas abrir el archivo y saber quién es
quién.

**Vestir va antes de `add_child()`.** La figura se viste en su `_ready()`, así
que un color puesto después no lo lee nadie y sale con el uniforme de fábrica —
que es «todos los NPC son iguales» disfrazado de dato mal escrito.

## Los topes, y por qué son dos números y no uno

| Campo | Qué es |
|---|---|
| `andable` | Por dónde se puede **andar**. Sale del `filter_baking_aabb` del mapa de navegación, que ahora lo pone el constructor |
| `camara` | Hasta dónde **acompaña la vista**. Siempre por dentro de la hilera, o se ve el borde del mundo |

La cámara se quedó una vez en `(-8, 8)` con la calle llegando a 12,5 y parecía
que se había atascado. **Si alargas una calle, toca los dos.**

## Las esquinas

Una esquina es un sitio, no un menú: se anda hasta ella y se cruza.

- `"calle": "peter_street"` → lleva ahí directamente.
- `"dialogo": "..."` → manda la conversación (así vuelve a casa la esquina de
  Marshall Street, con el campo `escena` de su propio JSON).

La calle de destino tiene que tener **una entrada con el nombre de la de
origen** en su `entradas`, o aparecerás en mitad de la calle como si te
hubieran teletransportado. `prueba_barrio.tscn` lo comprueba.

**Ninguna puerta a menos de tres metros de una esquina.** El rótulo de la
esquina se le monta encima al número; es el mismo fallo que tapó el 40 con un
árbol, pero con letras.

## Cómo se comprueba que no se ha roto nada

```
Godot_v4.7.1-stable_win64.exe --headless --path game \
    res://scenes/herramientas/prueba_barrio.tscn
```

Levanta las cuatro calles y mira, una por una: que cada puerta tenga hoja,
ocupante y número; que se pueda **llegar andando** a cada puerta y a cada
esquina; que cada esquina lleve a una calle que existe y que esa calle tenga
entrada por este lado; y que ningún vecino se haya quedado dentro de la
fachada. Veinte segundos.

Existe porque el fallo del 40 solo se descubrió por una captura de pantalla, y
con cuatro calles y trece puertas eso ya no escala.

## El barrio, tal y como está hoy: BROAD STREET Y UN CRUCE

Estuvo hecho como cuatro escenas que se cruzaban por las esquinas, y luego
como una sola calle recta de ciento treinta y cinco metros. Las dos estaban
mal por lo mismo: **una línea no es un barrio.** Sin cruces no se dobla nada,
y los puntos del plano no pueden formar una mancha porque solo hay un eje.

```
       Broad Street  ────────────────────────────────────────►  x
  2 4 6     ▓    38  39 40 41    ▓         5 7 9
                ↑bomba
           ═════╗      ╔═════
                ║ 12   ║      Cambridge Street: se mete hacia el
                ║   14 ║      fondo de la pantalla, en -Z
                ║ 16   ║
                ╚══════╝
```

### Los tramos

La fachada ya no es una hilera: son **tramos**. Cada uno dice dónde empieza,
hacia dónde crece y hacia dónde mira.

| Campo | Qué es |
|---|---|
| `desde` | El ORIGEN DEL PRIMER MÓDULO, no el plano de la fachada: esta cae 2,5 por delante |
| `eje` | `+x` `-x` `+z` `-z`. **El signo importa** |
| `mira` | `+z` `-z` `+x` `-x`. La cara decorada del kit es la +Z, así que `+z` es giro cero |
| `bahias` | Cuántos módulos |
| `huecos` | Bahías sin casa CON fondo: un callejón. Se entra dos metros y se para uno |
| `bocas` | Bahías sin casa SIN fondo: la entrada de otra calle. Se cruza y se sigue |

**Un eje sin signo es medio eje.** La primera versión solo distinguía `x` y `z`
y siempre crecía en positivo: Cambridge Street salió creciendo *hacia* la
cámara, cruzó Broad Street entera y dejó dos muros de treinta metros
atravesados en la calzada. Media calle dejó de tener camino.

**Y un hueco no es una boca.** Cuando la entrada de Cambridge era un hueco
normal, la calle se veía perfectamente —sus casas, sus números— y no se podía
entrar: el muro del tramo iba de punta a punta. Ahora la colisión se monta a
trozos, uno por cada tirada de bahías seguidas con casa.

### Por qué las laterales se meten hacia el fondo y no cruzan de lado a lado

La cámara va detrás del personaje mirando a -Z y **no gira nunca**. Una calle
que se aleja se ve como un pasillo en escorzo y funciona. Una que cruzara de
lado a lado la estaríamos mirando de canto: no se vería.

### Y a una puerta se llama de frente

`Interactable.mirar_de_frente`. El sitio donde uno se para se calculaba
siempre hacia quien venía, y en una puerta que mira de lado ese punto caía
DENTRO del muro de al lado: la puerta se veía, tenía número y vecino, y no
había camino hasta ella. Ahora se sale por la normal de la propia puerta.

---
