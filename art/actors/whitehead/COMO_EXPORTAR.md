# Cómo exportar a Whitehead desde Krita

## Los tres nombres

| Archivo | Cuándo |
|---|---|
| `frente.png` | **Obligatorio.** Es el único que hace falta para que funcione |
| `espalda.png` | Opcional. En cuanto esté, se usa solo al alejarse de la cámara |
| `lado.png` | Opcional. Dibujado **mirando a la derecha**; el motor lo voltea |

Nada más. No hay que tocar ningún guion cuando aparezcan los otros dos.

## Las tres cosas que hay que hacer antes de exportar

1. **Fondo transparente.** Borra la capa blanca de fondo. Si no, aparece una
   caja blanca alrededor.
2. **Capa de relleno debajo de la tinta.** Ahora mismo el abrigo está vacío, y
   vacío significa que se ve la calle a través de él. Una capa nueva por
   debajo, bote de pintura dentro de la silueta. Para la prueba vale un gris
   claro cualquiera; el color de verdad va después.
3. **Los pies tocando el borde de abajo.** Recorta al contenido y luego amplía
   el lienzo hacia arriba y a los lados. Si dejas margen transparente debajo de
   las botas, Whitehead flota — y si hace falta se corrige con `ajuste_altura`
   en el Inspector, pero es mejor exportarlo bien.

## El tamaño

**250 px = 1 metro.** Whitehead mide 1,85 m, así que **462 px** de suela a copa
del sombrero. Un lienzo de **512 × 512** le deja aire de sobra.

Si exportas a otro tamaño no se rompe nada: cambia `px_por_metro` en el nodo
`FiguraSprite` y ya. Pero si mantienes 250 px/m, todos los personajes del juego
encajan entre sí sin pensar.

## Al meterlo en Godot

Selecciona el PNG en el panel FileSystem, pestaña **Import**, marca
**Mipmaps > Generate** y pulsa **Reimport**. El dibujo se ve en pantalla a
menos de un tercio de su tamaño real; sin mipmaps, las líneas de tinta
centellean mientras camina.
