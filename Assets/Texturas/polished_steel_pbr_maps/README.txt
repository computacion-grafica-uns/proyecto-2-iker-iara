POLISHED STEEL PBR TEXTURE SET
Resolution: 1024x1024
Maps:
- polished_steel_albedo.png: RGB base color; does not contain reflections or shadows.
- polished_steel_metalness.png: grayscale; white = fully metallic.
- polished_steel_roughness.png: grayscale; dark = polished / sharp reflections.
- polished_steel_normal.png: RGB tangent-space normal map; very subtle micrograin.
- polished_steel_ao.png: grayscale; white = no occlusion.

Notes:
- This is a generic polished steel set for a metalness/roughness workflow.
- For a mirror-like chrome effect, reduce roughness further in the shader.
- For Unity Standard/Lit workflows that expect smoothness, use:
    smoothness = 1.0 - roughness
- AO for object-specific corners and creases should ideally be baked from the actual mesh UVs.
- A polished metal needs an HDRI, skybox, reflection probe or visible scene geometry to reflect.
