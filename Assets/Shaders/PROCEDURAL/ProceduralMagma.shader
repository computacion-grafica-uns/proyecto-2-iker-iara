Shader "Custom/LavaRockMk2" {
    Properties {
        _Scale          ("Scale",              Range(0.5, 8))   = 3.5
        _CrustSpeed     ("Crust drift",        Range(0.0, 0.5)) = 0.04
        _MoltenSpeed    ("Vein flow",          Range(0.0, 1))   = 0.15
        _CrackWidth     ("Vein width",         Range(0.01, 0.3))= 0.06
        _CrackThreshold ("Vein threshold",     Range(0.0, 1))   = 0.5
        _BranchAmount   ("Micro-crack amount", Range(0.0, 1))   = 0.5
        _BranchWidth    ("Micro-crack width",  Range(0.005,0.1))= 0.025
        _FlowChaos      ("Flow chaos",         Range(0.0, 2))   = 1.0
        _GlowStr        ("Glow strength",      Range(0.0, 5))   = 2.5
        _CrustDarkness  ("Crust darkness",     Range(0.0, 1))   = 0.9
        _CrustBumpiness ("Crust bumpiness",    Range(0.0, 3))   = 1.8
        _NormalStrength ("Normal strength",    Range(0.0, 5))   = 3.5
        _CrackDepth     ("Crack depth",        Range(0.0, 1))   = 0.8
        _RoughnessMap   ("Crust roughness",    2D)              = "white" {}
        _UseRoughnessMap("Use roughness map",  Range(0,1))      = 0
        _k_d            ("Diffuse tint",       Color)           = (1,1,1,1)
        _r_d_coeff      ("Diffuse coeff",      Float)           = 6
        _rp             ("Roughness",          Range(0,1))      = 0.92
        _F_0            ("Reflectance",        Color)           = (0.08, 0.04, 0.02, 1)
    }
    SubShader {
        Tags { "RenderType"="Opaque" }
        Pass {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            #include "Assets/ShaderInspector/ShaderInspector.cginc"

            struct appdata {
                float4 pos    : POSITION;
                float3 normal : NORMAL;
                float2 uv     : TEXCOORD0;
            };
            struct v2f {
                float4 pos          : SV_POSITION;
                float2 uv           : TEXCOORD0;
                float4 world_pos    : TEXCOORD1;
                float3 normal_versor: TEXCOORD2;
            };

            float _Scale, _CrustSpeed, _MoltenSpeed;
            float _CrackWidth, _CrackThreshold;
            float _BranchAmount, _BranchWidth, _FlowChaos;
            float _GlowStr, _CrustDarkness, _CrustBumpiness;
            float _NormalStrength, _CrackDepth;
            float _UseRoughnessMap;
            float _r_d_coeff, _rp;
            float4 _k_a, _k_d, _F_0;
            sampler2D _RoughnessMap;
            float4 _RoughnessMap_ST;

            #define MAX_LIGHTS 20
            float4 _L_Position[MAX_LIGHTS];
            float4 _L_Forward[MAX_LIGHTS];
            float4 _L_Color[MAX_LIGHTS];
            float  _L_Intensity[MAX_LIGHTS];
            float  _L_Type[MAX_LIGHTS];
            float  _L_ConeCosine[MAX_LIGHTS];
            float  _L_ConeFalloff[MAX_LIGHTS];
            float  _L_Attenuation[MAX_LIGHTS];
            float  _L_Count;

            float hash(float2 p) {
                p = frac(p * float2(127.1, 311.7));
                p += dot(p, p + 45.32);
                return frac(p.x * p.y);
            }
            float noise(float2 p) {
                float2 i = floor(p);
                float2 f = frac(p);
                float2 u = f*f*(3.0 - 2.0*f);
                return lerp(
                    lerp(hash(i),            hash(i+float2(1,0)), u.x),
                    lerp(hash(i+float2(0,1)),hash(i+float2(1,1)), u.x), u.y);
            }
            float fbm(float2 p) {
                float v = 0, a = 0.5;
                for (int i = 0; i < 6; i++) {
                    v += a * noise(p);
                    p  = p * 2.1 + float2(1.7, 9.2);
                    a *= 0.5;
                }
                return v;
            }
            float fbmShort(float2 p) {
                float v = 0, a = 0.5;
                for (int i = 0; i < 4; i++) {
                    v += a * noise(p);
                    p  = p * 2.1 + float2(1.7, 9.2);
                    a *= 0.5;
                }
                return v;
            }
            float ridgedFbm(float2 p) {
                float v = 0, a = 0.5;
                for (int i = 0; i < 5; i++) {
                    float n = 1.0 - abs(noise(p) * 2.0 - 1.0);
                    v += a * n * n;
                    p  = p * 2.2 + float2(3.1, 1.7);
                    a *= 0.5;
                }
                return v;
            }
            float ridgedFbmHigh(float2 p) {
                float v = 0, a = 0.5;
                for (int i = 0; i < 4; i++) {
                    float n = 1.0 - abs(noise(p) * 2.0 - 1.0);
                    v += a * n * n;
                    p  = p * 2.4 + float2(5.7, 2.3);
                    a *= 0.55;
                }
                return v;
            }

            struct LavaSample {
                float height;       // for normal computation
                float veinMask;     // 0..1 main veins
                float branchMask;   // 0..1 micro-cracks
            };

            LavaSample lavaField(float2 p, float tCrust, float tMolten) {
                // Multi-directional domain warping
                float2 warpA = float2(
                    fbm(p * 0.6 + float2(0.0, tCrust)),
                    fbm(p * 0.6 + float2(5.2, -tCrust * 0.8))
                );
                float2 warpB = float2(
                    fbm(p * 1.1 + warpA + float2(7.3, tMolten * 0.7)),
                    fbm(p * 1.1 + warpA + float2(2.8, -tMolten * 0.9))
                );
                float2 warpC = float2(
                    fbm(p * 1.7 + warpB.yx * 1.5 + tMolten * float2(0.5, -0.3)),
                    fbm(p * 1.7 - warpB.yx * 1.2 + tMolten * float2(-0.4, 0.6))
                );
                float2 totalWarp = (warpA + warpB * 0.7 + warpC * 0.4) * _FlowChaos;

                // Base rock height with bumpiness
                float baseRock = fbm(p + totalWarp * 0.5);
                float crustBumps = fbmShort(p * 4.5 + totalWarp * 0.3) * _CrustBumpiness * 0.25;

                // Main vein pattern
                float mainVeins = ridgedFbm(p * 1.3 + totalWarp);
                // Secondary micro-cracks - higher freq, follow same flow
                float microVeins = ridgedFbmHigh(p * 3.8 + totalWarp * 1.4);

                float height = baseRock + crustBumps - mainVeins * 0.4;

                LavaSample s;
                s.height = height;
                s.veinMask = smoothstep(_CrackThreshold + _CrackWidth, _CrackThreshold, height);

                // Micro-cracks only appear NEAR the main veins (branching off them)
                float branchProximity = smoothstep(_CrackThreshold + _CrackWidth * 4.0, _CrackThreshold + _CrackWidth, height);
                float branchPattern = smoothstep(0.7 - _BranchWidth, 0.7, microVeins);
                s.branchMask = branchPattern * branchProximity * _BranchAmount * (1.0 - s.veinMask);

                return s;
            }

            v2f vert(appdata i) {
                v2f o;
                o.world_pos     = mul(UNITY_MATRIX_M, i.pos);
                o.pos           = mul(UNITY_MATRIX_P, mul(UNITY_MATRIX_V, o.world_pos));
                o.uv            = i.uv;
                o.normal_versor = UnityObjectToWorldNormal(i.normal);
                return o;
            }

            FragOut frag(v2f v) : SV_Target {
                DEBUGGABLE;

                float tCrust  = _Time.y * _CrustSpeed;
                float tMolten = _Time.y * _MoltenSpeed;
                float2 p      = v.uv * _Scale;

                float e = 0.006;
                LavaSample sC = lavaField(p,                tCrust, tMolten);
                LavaSample sR = lavaField(p + float2(e, 0), tCrust, tMolten);
                LavaSample sU = lavaField(p + float2(0, e), tCrust, tMolten);

                // Combine main vein depression + micro-crack micro-depression
                float dispC = sC.height - sC.veinMask * _CrackDepth - sC.branchMask * _CrackDepth * 0.35;
                float dispR = sR.height - sR.veinMask * _CrackDepth - sR.branchMask * _CrackDepth * 0.35;
                float dispU = sU.height - sU.veinMask * _CrackDepth - sU.branchMask * _CrackDepth * 0.35;

                float3 normalTS = normalize(float3(
                    (dispC - dispR) * _NormalStrength * 18.0,
                    (dispC - dispU) * _NormalStrength * 18.0,
                    1.0
                ));

                // TBN
                float3 N = normalize(v.normal_versor);
                float3 dPdx = ddx(v.world_pos.xyz);
                float3 dPdy = ddy(v.world_pos.xyz);
                float2 dUdx = ddx(v.uv);
                float2 dUdy = ddy(v.uv);
                float3 T =  normalize(dPdx * dUdy.y - dPdy * dUdx.y);
                float3 B =  normalize(-dPdx * dUdy.x + dPdy * dUdx.x);
                float3x3 TBN = transpose(float3x3(T, B, N));
                float3 N_versor = normalize(mul(TBN, normalTS));

                // Color palette
                float crustVariation = fbm(p * 2.0);
                float3 deepCrust   = float3(0.008, 0.005, 0.004);
                float3 midCrust    = float3(0.04, 0.025, 0.02);
                float3 hotEdge     = float3(0.45, 0.12, 0.02);
                float3 veinOrange  = float3(1.00, 0.32, 0.04);
                float3 veinHot     = float3(1.00, 0.75, 0.20);
                float3 branchColor = float3(0.95, 0.22, 0.03);

                float3 crustColor = lerp(deepCrust, midCrust, crustVariation);
                crustColor *= (1.0 - _CrustDarkness * 0.75);

                // Hot edges around main veins
                float edgeBand = smoothstep(_CrackThreshold + _CrackWidth * 1.8, _CrackThreshold + _CrackWidth, sC.height)
                               - smoothstep(_CrackThreshold + _CrackWidth, _CrackThreshold + _CrackWidth * 0.5, sC.height);
                crustColor = lerp(crustColor, hotEdge, edgeBand * 0.7);

                // Main vein color
                float veinCore = smoothstep(_CrackThreshold, _CrackThreshold - _CrackWidth * 0.4, sC.height);
                float3 veinColor = lerp(veinOrange, veinHot, veinCore);

                // Branch (micro-crack) color — slightly dimmer
                float3 albedo = lerp(crustColor, veinColor, sC.veinMask);
                albedo = lerp(albedo, branchColor, sC.branchMask);

                // Pulse
                float pulse = 0.75 + 0.25 * sin(_Time.y * _CrustSpeed * 4.0 + sC.height * 6.0);

                // Emissive
                float3 emissive = veinColor * sC.veinMask * _GlowStr * pulse;
                emissive += branchColor * sC.branchMask * _GlowStr * 0.6 * pulse;
                emissive += hotEdge * edgeBand * 0.5;

                // Roughness
                float roughness = _rp;
                if (_UseRoughnessMap > 0.5) {
                    float r = tex2D(_RoughnessMap, TRANSFORM_TEX(v.uv, _RoughnessMap)).r;
                    roughness = lerp(0.4, 1.0, r);
                }
                roughness = lerp(roughness, 0.3, sC.veinMask);

                // Cook-Torrance (crust + branches get shaded; main veins are pure emissive)
                float crustMask = (1.0 - sC.veinMask);
                float3 V_versor = normalize(_WorldSpaceCameraPos - v.world_pos);
                float  NV       = dot(N_versor, V_versor);
                float  alpha    = roughness * roughness;
                float4 fresnel  = _F_0 + (1.0 - _F_0) * pow(1.0 - NV, 5.0);

                float4 brdf = 0;
                for (int i = 0; i < _L_Count; i++) {
                    float  coneL    = 1;
                    float  L_dist   = length(_L_Position[i].xyz - v.world_pos);
                    float3 L_versor = normalize(_L_Position[i].xyz - v.world_pos);
                    float3 H_versor = normalize(L_versor + V_versor);
                    float  NL = dot(N_versor, L_versor);
                    float  NH = dot(N_versor, H_versor);
                    float  VH = dot(V_versor, H_versor);

                    if (_L_Type[i] == 1) {
                        L_dist   = 0;
                        L_versor = normalize(_L_Forward[i].xyz);
                        H_versor = normalize(L_versor + V_versor);
                        NL = dot(N_versor, L_versor); NH = dot(N_versor, H_versor); VH = dot(V_versor, H_versor);
                    }
                    else if (_L_Type[i] == 2) {
                        coneL = pow(saturate((_L_ConeCosine[i] - dot(_L_Forward[i].xyz, L_versor)) / (_L_ConeCosine[i] - 1)), _L_ConeFalloff[i]);
                    }

                    float ndf = saturate(NL) * alpha*alpha / (UNITY_PI * pow((NH*NH*(alpha*alpha-1)+1), 2.0));
                    float gv  = 2*NH*NV/VH;
                    float gl  = 2*NH*NL/VH;
                    float geo = min(1, min(gl, gv));

                    float4 diffuse  = float4(_k_d.rgb * albedo * _r_d_coeff * saturate(NL) * coneL, 1);
                    float4 specular = saturate(fresnel * ndf * geo / (4*NL*NV));
                    specular.a = 1;

                    brdf += crustMask * (diffuse + specular) * _L_Color[i] * _L_Intensity[i] / pow(1 + L_dist, _L_Attenuation[i]);
                }

                float4 ambient   = float4(_k_d.rgb * albedo * crustMask, 1) * _k_a;
                float4 fragColor = ambient + brdf + float4(emissive, 1);

                ret(fragColor);
            }
            ENDCG
        }
    }
}