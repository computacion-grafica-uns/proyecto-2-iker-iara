# Proyecto 2 — Shader Showcase: Presentation Reference

This document contains all technical and descriptive information about every shader built in Scene A. Use it as the source of truth when generating slides, explanations, or demos.

---

## Project Overview

The project implements a real-time shader library in Unity (Built-in Render Pipeline) covering:
- Classic lighting models (Blinn-Phong, Cook-Torrance, Toon)
- PBR metalness workflow
- Procedural textures (marble, wood grain, lava, animated water)
- Special materials (brushed metal, polished metal, glass/transparency)
- Normal mapping with proper TBN technique
- A custom multi-light system shared across all shaders

All shaders use a **custom ShaderInspector multi-light system** (`ShaderInspector.cginc`) that passes up to 20 lights (point, directional, spot) via uniform arrays, bypassing Unity's built-in lighting pipeline entirely.

---

## Custom Multi-Light System

**What it is:** Instead of relying on Unity's ForwardAdd passes, all shaders receive lights through manually-set uniform arrays:

```hlsl
float4 _L_Position[20];   // world-space position
float4 _L_Forward[20];    // direction (for directional/spot)
float4 _L_Color[20];      // RGB color
float  _L_Intensity[20];  // scalar intensity
float  _L_Type[20];       // 1=directional, 2=spot, other=point
float  _L_ConeCosine[20]; // spot cone angle cosine
float  _L_ConeFalloff[20];// spot falloff exponent
float  _L_Attenuation[20];// distance falloff exponent
float  _L_Count;           // active light count
```

**Why it matters:** Every shader — regardless of lighting model — iterates the same loop:
```hlsl
for (int i = 0; i < _L_Count; i++) { ... }
```
This means all shaders support an arbitrary number and mix of light types uniformly.

---

## Lighting Models

### 1. Blinn-Phong

**Files:** `BlinnPhong_Frag.shader`, `BlinnPhong_NormalMap.shader`, `BlinnPhong_Frag_Tex.shader`, `BlinnPhong_Frag_Transp.shader`

**Formula:**
```
diffuse  = k_d * albedo * saturate(N · L)
specular = k_s * pow(saturate(N · H), n)
final    = ambient + Σ (diffuse + specular) * lightColor * intensity / attenuation
```

Where `H = normalize(L + V)` is the half-vector. Blinn-Phong approximates Phong but is cheaper because it avoids computing the reflection vector.

**Key parameters:** `_k_d` (diffuse color), `_k_s` (specular color), `_n` (shininess — higher = tighter highlight).

---

### 2. Cook-Torrance (Microfacet BRDF)

**Files:** `CookTorrance_Frag.shader`, `CookTorrance_NormalMap_TBN.shader`, `CookTorrance_Frag_Tex.shader`, `CookTorrance_Frag_Transp.shader`

**Formula:**
```
f(L,V) = (D * G * F) / (4 * NL * NV)
```

Three terms:

**D — GGX Normal Distribution Function:**
```hlsl
float ndf = α² / (π * (NH²*(α²-1)+1)²)     where α = roughness²
```
Controls the shape and size of the specular highlight. Low roughness = sharp tiny highlight. High roughness = wide soft highlight.

**G — Cook-Torrance Geometry (masking/shadowing):**
```hlsl
float gv  = 2*NH*NV / VH
float gl  = 2*NH*NL / VH
float geo = min(1, min(gv, gl))
```
Prevents physically impossible energy (light cannot reflect more than it receives).

**F — Schlick Fresnel:**
```hlsl
float4 fresnel = F0 + (1 - F0) * pow(1 - NV, 5)
```
Metals reflect their own color (F0 = metal color). Dielectrics are mostly grey at F0 = 0.04 and shift toward white at grazing angles.

---

### 3. Toon Shader (Custom — Original)

**Files:** `ToonShader.shader`, `ToonShader_NormalMap.shader`, `ToonShader_Tex.shader`, `ToonShader_Transp.shader`

**What makes it original:**

Unlike standard toon shaders that just posterize a single diffuse value, this implementation:

1. **Accumulates all lights first**, then posterizes the total:
```hlsl
totalNdotL += NdotL * intensity * coneL;  // accumulate all lights
float diffBand = floor(saturate(totalNdotL) * 3.0) / 3.0;  // 3-step quantization
```

2. **Stripe pattern in the darkest shadow band** — cross-hatching effect:
```hlsl
float coreShadow    = 1.0 - step(0.01, diffBand);  // only in full shadow
float shadowStripes = coreShadow * stripes(screenUV, angle, scale, width);
```
Stripes are drawn in **screen space** (not UV space), so they remain stable regardless of mesh or camera movement.

3. **Halftone specular** — the specular highlight is rendered as a dot pattern:
```hlsl
float specHalftone = halftone(screenUV, intensity, scale);
float specMask     = specBand * specHalftone;
```

4. **Full multi-light support** — all 3 light types contribute to both diffuse bands and specular.

**Parameters:** `_StripeAngle`, `_StripeScale`, `_StripeWidth` control the shadow hatching. `_SpecHalftoneScale`, `_SpecHalftoneIntensity` control the specular dot pattern.

---

### 4. PBR Metalness (Standard Shader Clone)

**Files:** `CookTorrance_PBR_Metalness.shader`, `StandardLit.shader`

**Metalness workflow:**
```hlsl
float3 F0 = lerp(float3(0.04, 0.04, 0.04), albedo, metalness);
// dielectric: F0 = 0.04 (grey), metallic: F0 = albedo color
```

**Energy conservation:**
```hlsl
total = (1 - F) * diffuse + F * specular
// metals have no diffuse (F ≈ 1), dielectrics have both
```

`StandardLit.shader` replicates Unity's Standard shader inspector with: Albedo, Metallic map (R=metallic, A=smoothness), Normal map + scale, Occlusion map + strength, HDR Emission — all reacting to the custom multi-light system.

---

## Special Material Shaders

### 5. Polished Metal (Cook-Torrance, no diffuse)

**File:** `MetalPulido.shader`

**Key insight:** Conductors (metals) have no diffuse term. All energy goes to specular:
```hlsl
// No diffuse term at all
specular = saturate(fresnel * ndf * geo / (4 * NL * NV))
```

**F0 = metal color** — silver: `(0.972, 0.960, 0.915)`, gold: `(1.022, 0.782, 0.344)`, copper: `(0.955, 0.637, 0.538)`.

**Roughness map:** `_RoughnessMap` modulates per-pixel roughness:
```hlsl
float rp = _rp * lerp(1.0, tex2D(_RoughnessMap, uv).r, _RoughnessScale);
```
Setting `_RoughnessScale` to 0 ignores the map; 1 applies it fully. This enables brushed metal effects via texture.

---

### 6. Brushed Metal — Anisotropic Cook-Torrance (Original)

**File:** `BrushedMetal.shader`

**What makes it original:** Replaces the isotropic GGX NDF and G term with their anisotropic counterparts, giving the characteristic elongated specular streak of brushed metal.

**Anisotropic GGX NDF:**
```hlsl
// Two roughness values: αT (along brush) and αB (across brush)
float denom = (TH/αT)² + (BH/αB)² + NH²
float D = 1 / (π * αT * αB * denom²)
```
With `αT` high (rough along brush direction) and `αB` low (smooth perpendicular), the highlight stretches into a streak.

**Anisotropic Smith G:**
```hlsl
float g1v = 2*NV / (NV + sqrt(αT²*TV² + αB²*BV² + NV²))
float g1l = 2*NL / (NL + sqrt(αT²*TL² + αB²*BL² + NL²))
float G   = g1v * g1l
```

**Brush angle:** T and B are rotated in the tangent plane by `_BrushAngle` degrees before computing the anisotropic terms, allowing the streak direction to be adjusted in the inspector.

**Based on:** `CookTorrance_PBR_Metalness` — keeps the full metalness workflow (albedo, metalness map, normal map, AO) with only D and G replaced.

---

## Normal Mapping — TBN Technique

**Files:** `BlinnPhong_NormalMap.shader`, `CookTorrance_NormalMap_TBN.shader`, `ToonShader_NormalMap.shader`

**What TBN is:** Normal maps store normals in tangent space (relative to the surface). To use them in world-space lighting, they must be transformed by a 3×3 TBN matrix built from the mesh's tangent frame.

**Implementation:**

Vertex shader passes the tangent frame to the fragment shader:
```hlsl
o.tangent_versor   = UnityObjectToWorldDir(i.tangent.xyz);
o.bitangent_versor = cross(tangent, normal) * (tangent.w * unity_WorldTransformParams.w);
// tangent.w encodes handedness — critical for mirrored UVs
```

Fragment shader builds the matrix and transforms the sampled normal:
```hlsl
float3x3 TBN    = transpose(float3x3(-T, -B, N));   // tangent → world
float3 normalTS = UnpackNormal(tex2D(_NormalMap, uv));
normalTS.xy    *= _NormalStrength;                    // scale XY only, Z stays 1
float3 N_versor = normalize(mul(TBN, normalTS));
```

**Why this matters vs the naive approach:** The existing `CookTorrance_NormalMap.shader` in the project uses `normalize(vertexNormal + normalMap.xyz)` — a world-space hack that only works on surfaces facing up and produces wrong results at angles. The TBN approach works correctly on any surface orientation.

---

## Procedural Shaders

### 7. Marble Shader (Original Split Material)

**File:** `MarbleShader.shader` (in METAL-PULIDO or moved folder)

**What makes it original:** The shader splits the object into two materials (marble top, black metal bottom) blended by a Y-axis cutoff with a smooth transition band.

**Noise pipeline:**
```
hash(p) → valueNoise(p) → fbm(p) [fractal brownian motion] → marblePattern(p)
```

**Marble pattern:**
```hlsl
float turb  = fbm(coord) * _Turbulence;
float veins = sin(coord.x * _VeinFreq + turb);  // sine creates the vein lines
veins       = pow(saturate(veins * 0.5 + 0.5), _VeinContrast);  // sharpen
```

**Split blend:**
```hlsl
float blend = smoothstep(cutoffY - band, cutoffY + band, worldY);
albedo      = lerp(metalColor, marbleColor, blend);
```

**Derivative normals:** No vertex normals required — the normal is computed from screen-space derivatives:
```hlsl
float3 N = normalize(cross(ddx(worldPos), ddy(worldPos)));
if (dot(N, V) < 0) N = -N;  // ensure it faces the camera
```

---

### 8. Wood Grain (Original Procedural)

**File:** `PROCEDURAL/WoodGrain.shader`

**Core idea:** Wood rings are concentric circles when you look at a log cross-section. This maps to a radial distance function:
```hlsl
float r    = sqrt(x² + z²);         // distance from Y axis = ring radius
float turb = fbm(coord) * _Turbulence;
float ring = sin((r + turb) * _RingFreq * π * 2);
```

**Difference from marble:** Marble uses `sin(x * freq + turb)` — linear waves along X. Wood uses `sin(√(x²+z²) * freq + turb)` — concentric rings around Y axis. The fbm turbulence distorts the rings to look like natural grain instead of perfect circles.

**Parameters:** `_RingFreq` (density of rings), `_Turbulence` (irregularity/knottiness), `_RingSharpness` (hard vs soft ring edges).

---

### 9. Animated Water (Original)

**File:** `AnimatedWater.shader`

**Wave generation:** Two fbm layers scroll in different directions using `_Time.y`:
```hlsl
float2 uv1 = uv * scale + float2( time * speed,        time * speed * 0.6);
float2 uv2 = uv * scale * 1.4 + float2(-time * speed * 0.7, time * speed * 0.4);
float h    = (fbm(uv1) + fbm(uv2)) * 0.5;
```
Two layers at different speeds and scales prevent the pattern from looking repetitive.

**Normal derivation from height field:**
```hlsl
float h  = waveHeight(uv);
float hx = waveHeight(uv + float2(eps, 0));
float hy = waveHeight(uv + float2(0, eps));
float3 n_tangent = normalize(float3((h-hx)*strength, eps, (h-hy)*strength));
// Transform to world space via TBN
```
No normal map texture needed — normals are computed analytically from the procedural height field.

**Water color:** Three-way blend based on wave height + Fresnel:
```hlsl
waterColor = lerp(deepColor, shallowColor, h);
waterColor = lerp(waterColor, foamColor, smoothstep(foamThreshold, 1, h));
waterColor = lerp(waterColor, shallowColor, fresnel * 0.5);  // rim brightening
```

---

### 10. Procedural Lava / Magma

**File:** `PROCEDURAL/ProceduralMagma.shader`

Animated procedural lava using time-scrolled fbm noise mapped to a lava color ramp (dark crust → orange → bright yellow-white at peaks). Built before this session.

---

## Variant Families

Each core shader was extended into three variants:

### Transparent Variants
**Files:** `BlinnPhong_Frag_Transp`, `CookTorrance_Frag_Transp`, `ToonShader_Transp`

Changes from opaque originals:
- `Tags { "Queue"="Transparent" "RenderType"="Transparent" }`
- `Blend SrcAlpha OneMinusSrcAlpha`
- `ZWrite Off`
- `_Alpha` property → output `float4(color.rgb, _Alpha)`

### Texture Map (2D Albedo) Variants
**Files:** `BlinnPhong_Frag_Tex`, `CookTorrance_Frag_Tex`, `ToonShader_Tex`

Each adds a `_MainTex` sampler multiplied into the diffuse/base color. `CookTorrance_Frag_Tex` required switching `fixed4 brdf` → `float4 brdf` to prevent premature clamping that made the texture invisible.

---

## Grass Animation Shader

**File:** `GrassAnimated.shader`

**Vertex animation technique:** `uv.y` masks the displacement — base of blade (uv.y = 0) stays fixed, tip (uv.y = 1) sways fully:
```hlsl
float sway  = i.uv.y;
float phase = worldPos.x * freq + worldPos.z * freq;  // per-blade variation
float wind  = sin(time * speed + phase) * 0.6
            + sin(time * speed * 1.7 + phase) * 0.4;  // two waves = organic
worldPos.xyz += windDir * wind * strength * sway;
```

**Lighting:** Uses `abs(NdotL)` instead of `saturate(NdotL)` and `Cull Off` so both sides of each blade receive light.

**Color:** Gradient from `_RootColor` (dark) to `_TipColor` (bright) based on `uv.y`.

---

## Camera System

**File:** `AutoOrbitCamera.cs`

Replaces the manual orbital camera with an automatic orbit:
- `Transform[] targets` — list of objects to orbit (ordered as in inspector)
- Fixed distance orbit that auto-rotates at `orbitSpeed` degrees/second
- Press `1` to advance to the next target
- `_currentLookTarget` lerps smoothly to new target position on switch

---

## Key Technical Concepts Summary (for slides)

| Concept | Where used | One-liner |
|---|---|---|
| GGX NDF | CookTorrance, MetalPulido, BrushedMetal | Physically correct specular lobe shape |
| Anisotropic GGX | BrushedMetal | Two roughness axes = elongated streak |
| Fresnel (Schlick) | CookTorrance, PBR, MetalPulido | Edge reflectance — makes metals look metallic |
| Metalness workflow | StandardLit, BrushedMetal | F0 = lerp(0.04, albedo, metalness) |
| TBN normal mapping | BlinnPhong_NM, CT_NM, Toon_NM | Tangent-space normals → world space |
| Derivative normals | MarbleShader, AnimatedWater | Normal from ddx/ddy, no vertex normals |
| Procedural fbm | Marble, Wood, Water, Lava | Layered noise for organic patterns |
| Screen-space stripes | ToonShader | Stable hatching in shadow regions |
| Halftone specular | ToonShader | Dot-pattern specular highlight |
| Vertex animation | GrassAnimated | UV.y-masked sine wave displacement |
| Transparent render | _Transp shaders | Blend + ZWrite Off + Transparent queue |
| Multi-light loop | All shaders | ShaderInspector uniform arrays |
