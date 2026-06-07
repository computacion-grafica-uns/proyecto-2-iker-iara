# Proyecto 2 — Iluminación Local y Materiales

**Computación Gráfica 2026 · DCIC - UNS**  
Integrantes: Iker Ibarra, Giuliano Rosso

---

## Descripción

Implementación de iluminación local con múltiples materiales y texturas en Unity 2022.3.52f1. Los modelos de iluminación (Blinn-Phong, Cook-Torrance y Toon Shader) están implementados manualmente en HLSL, sin usar el pipeline de iluminación de Unity.

---

## Requisitos

- Unity **2022.3.52f1** (versión exacta requerida)
- Windows / macOS / Linux con soporte para Unity

---

## Cómo abrir el proyecto

1. Clonar o descomprimir el repositorio.
2. Abrir Unity Hub y seleccionar **Open > Add project from disk**.
3. Navegar a la carpeta raíz del proyecto.
4. Una vez abierto, cargar cualquiera de las escenas desde `Assets/Scenes/`.

---

## Escenas

| Escena | Archivo | Descripción |
|--------|---------|-------------|
| **Escena A** | `Assets/Scenes/Teteras.unity` | Grilla 3×6 de teteras con todas las combinaciones de material y shader |
| **Escena B** | `Assets/Scenes/EscenaB.unity` | Escena compuesta estilo cocina/hogar con todos los materiales integrados |

### Controles

| Acción | Control |
|--------|---------|
| Orbitar cámara | Click izquierdo + arrastrar |
| Zoom | Rueda del mouse |
| Pan | Click central / Alt + arrastrar |
| Ciclar objetos / cámara | Teclas numéricas |
| Seleccionar objeto | Doble click |
| Movimiento (modo primera persona) | WASD |
| Correr | Shift |
| Saltar | Espacio |

---

## Modelos de iluminación

### Blinn-Phong
Modelo clásico con término difuso (N·L) y especular usando el vector bisector (half-vector). Eficiente y con buenos resultados visuales.

### Cook-Torrance (PBR)
Modelo de microfacetas físicamente basado con:
- **D** — Distribución normal (GGX): `alpha = roughness²`
- **F** — Aproximación de Fresnel (Schlick): reflectancia a incidencia 0° configurable
- **G** — Función de visibilidad (Schlick-Beckmann): auto-sombrado entre microfacetas

### Toon Shader
Iluminación no fotorrealista con bandas cuantizadas, contorno por inflado de vértices, y patrones de rayas o semitono para el especular.

---

## Materiales

Cada modelo de iluminación se aplica a los siguientes materiales:

| Material | Descripción |
|----------|-------------|
| **Barro** | Difuso alto, baja especularidad |
| **Metal pulido** | Alta especularidad, baja componente difusa |
| **Vidrio** | Transparente con efecto Fresnel |
| **2D Map** | Color de textura como componente difusa |
| **Normal Map** | Detalle de superficie mediante mapas de normales en espacio TBN |
| **Procedural** | Texturas generadas por ruido (magma animado, agua, veta de madera) |

---

## Estructura del proyecto

```
Assets/
├── Scenes/             # Escenas Unity
├── Shaders/            # 34 shaders HLSL
│   ├── BARRO/
│   ├── METAL-PULIDO/
│   ├── TRANSPARENTES/
│   ├── 2DMAP/
│   ├── NORMAL-MAP/
│   └── PROCEDURAL/
├── Scripts/
│   ├── Shading/
│   │   ├── LightCasera.cs      # Componente de luz personalizada
│   │   └── Uninformer.cs       # Broadcaster de uniforms a los shaders
│   └── Player movement/
│       ├── OrbitalCamera.cs
│       └── FirstPersonCamera.cs
├── Modelos3D/          # Modelo de tetera
├── Texturas/           # Texturas y mapas PBR
└── Materials/          # Definiciones de materiales Unity
```

---

## Sistema de luces

Se implementó un sistema de luces propio (independiente de las luces de Unity):

- **Punto** — Atenuación cuadrática configurable
- **Direccional** — Sin atenuación, distancia infinita
- **Spot** — Cono con ángulo y caída (falloff) configurables

El componente `Uninformer.cs` transmite cada frame los datos de todas las luces activas (`LightCasera`) como uniforms globales a todos los shaders. Soporta hasta 20 luces simultáneas.

---

## Texturas procedurales

| Shader | Técnica |
|--------|---------|
| `ProceduralMagma.shader` | FBM con warping de dominio, grietas animadas con `_Time.y` |
| `AnimatedWater.shader` | Ruido animado con desplazamiento de UV |
| `WoodGrain.shader` | Ruido de Perlin para veta de madera |
