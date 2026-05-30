# Project Context — Computación Gráfica 2026, Proyecto 2

## What this project is

A Unity project for the course **Computación Gráfica 2026** (DCIC - UNS). The goal is to render two scenes with **local illumination**, **multiple materials**, and **textures**, implementing the lighting and BRDFs **manually in HLSL** rather than relying on Unity's built-in lighting pipeline. This is an exposition / academic project — clarity and correctness of the lighting math matter more than performance.

### Important dates
- Preliminary presentation: **May 29, 2026**
- Final presentation: **June 5, 2026**
- Code must be pushed to the repo the day before each presentation, before 23:59.

## Scenes

### Scene A — The shader/material/texture grid
- A plane with **18 teapots** in a **3×6 arrangement**.
- Each teapot has a different material, forming a comparison matrix:

|               | Barro (clay) | Metal pulido | Vidrio semi-transparente | 2D mapping | Procedural | Normal mapping |
|---------------|--------------|--------------|--------------------------|------------|------------|----------------|
| Blinn-Phong   | ✓            | ✓            | ✓                        | ✓          | ✓          | ✓              |
| Cook-Torrance | ✓            | ✓            | ✓                        | ✓          | ✓          | ✓              |
| Toon          | ✓            | ✓            | ✓                        | ✓          | ✓          | ✓              |

- Orbital camera that can frame the whole scene OR focus on a single teapot (zoom + rotate around it).
- At least 1 point light, 1 directional light, 1 spot light — each independently toggleable. **All materials must react to all enabled lights simultaneously.**

### Scene B — The realistic composed scene
- Built on top of a base scene provided by the course.
- Must reuse the materials from Scene A (all of them must appear).
- All materials must be created by us — no Unity built-in materials.
- Two cameras: an **orbital camera** (frame whole scene / focus on important objects) and a **first-person camera** (WASD-style traversal).

## Architecture

Single `SceneManager` per Unity scene, coordinating cameras and lights.

```
SceneManager
├── Lights (abstract)             ← pushes uniforms to GPU every frame
│   ├── PointLight                  (position + attenuation)
│   ├── DirLight                    (direction only, no attenuation)
│   └── SpotLight                   (position + direction + cone angle + attenuation)
└── CameraController (abstract)
    ├── OrbitalCamera               (used in both scenes; cycles focus targets)
    └── FirstPersonCamera           (Scene B only)
```

### Data flow (critical)
Shaders do **not** reference C# classes. Data flow is one-way, CPU → GPU:

1. Each `Lights` subclass has an `UpdateShaderUniforms()` method.
2. `SceneManager` calls `UpdateShaderUniforms()` on every active light each frame (in `LateUpdate`).
3. Lights push their state via `Shader.SetGlobalVector` / `SetGlobalVectorArray` / `SetGlobalFloat`.
4. Shaders declare matching global uniforms and read them.

Use **uniform arrays** for point and spot lights, not numbered individual uniforms:
```hlsl
#define MAX_POINT_LIGHTS 4
float3 _PointLightPositions[MAX_POINT_LIGHTS];
float4 _PointLightColors[MAX_POINT_LIGHTS];
float  _PointLightIntensities[MAX_POINT_LIGHTS];
float  _PointLightEnabled[MAX_POINT_LIGHTS];
int    _PointLightCount;
```

Camera data: rely on Unity's built-ins (`_WorldSpaceCameraPos`, `UNITY_MATRIX_V`, `UNITY_MATRIX_P`). Do not manually push camera uniforms.

## Conventions

- **Render pipeline**: Built-in (not URP or HDRP) unless explicitly changed.
- **Shader language**: HLSL inside `.shader` files (Unity ShaderLab wrapper).
- **C# naming**: Unity's `Camera` class collides with ours — our camera base class is `CameraController`.
- **Lighting math**: Implement BRDFs from scratch in HLSL. Do **not** use `UnityLightingCommon` macros, `UnityCG.cginc` lighting helpers, or surface shaders. Vertex + fragment shaders only.
- **Spaces**: Do lighting in **world space** for clarity unless there's a strong reason to switch.
- **Coordinate system**: Unity's left-handed, Y-up.
- **Light toggling**: Multiply each light's contribution by its `_Enabled` flag (0 or 1) rather than `if` branches in the shader.

## Build order (currently working through this)

1. ✅ / ⬜ Phase 1 — Skeleton: empty class stubs, two empty scenes, one teapot.
2. ⬜ Phase 2 — Cameras: orbital (with target cycling) and first-person.
3. ⬜ Phase 3 — One light + Blinn-Phong shader, end-to-end pipeline proven.
4. ⬜ Phase 4 — Multi-light: point + spot with uniform arrays, all toggleable.
5. ⬜ Phase 5 — Replicate to Cook-Torrance and Toon shaders.
6. ⬜ Phase 6 — Materials (barro, metal, vidrio) × 3 shaders.
7. ⬜ Phase 7 — Textures (2D, procedural, normal mapping).
8. ⬜ Phase 8 — Scene B composition + polish.

(Update the checkmarks as we progress.)

## Working preferences

- **Commits**: Small, incremental, descriptive. The course explicitly grades commit history. Aim for one commit per meaningful substep, not giant dumps.
- **Comments**: When writing shader code, comment the lighting math (which term is the Fresnel, what `D`/`G`/`F` mean in Cook-Torrance, etc.) — this is an academic project and the comments help during the oral exposition.
- **Explanations**: When implementing something non-trivial (e.g., Cook-Torrance microfacet model), briefly explain the math in chat so I can reuse it in the presentation. I should be able to defend every line during the oral exam.
- **Don't over-engineer**: No DI containers, no event buses, no ScriptableObject configs unless they genuinely simplify something. Direct references and `[SerializeField]` are fine.
- **Procedural textures**: I'm allowed to use an LLM to help write them, but I must understand and explain them. Always include a comment block explaining how the procedural texture works.

## Out of scope

- Shadow mapping (not required by the assignment).
- PBR beyond Cook-Torrance (no full Disney/Burley model).
- Global illumination, light probes, lightmapping.
- Post-processing effects.
- Performance optimization beyond avoiding obvious waste.
