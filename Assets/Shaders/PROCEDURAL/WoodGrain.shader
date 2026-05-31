Shader "Custom/WoodGrain"
{
    Properties
    {
        [Header(Wood Colors)]
        _LightWood      ("Light Wood",      Color) = (0.80, 0.52, 0.25, 1)
        _DarkWood       ("Dark Wood",       Color) = (0.38, 0.19, 0.07, 1)

        [Header(Ring Pattern)]
        _GrainScale     ("Grain Scale",     Float)       = 4.0
        _RingFreq       ("Ring Frequency",  Float)       = 6.0
        _RingSharpness  ("Ring Sharpness",  Range(0.5, 8)) = 2.0
        _Turbulence     ("Turbulence",      Float)       = 2.0
        _Octaves        ("Noise Octaves",   Range(1, 6)) = 4
        [Toggle(_WORLDSPACE)] _UseWorldSpace ("Use World Space", Float) = 0

        [Header(Lighting)]
        _SpecColor2     ("Specular Color",  Color)           = (0.3, 0.2, 0.1, 1)
        _Shininess      ("Shininess",       Range(1, 256))   = 32
        _k_a            ("Ambient",         Color)           = (0.1, 0.1, 0.1, 1)
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" }

        Pass
        {
            Tags { "LightMode"="ForwardBase" }
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma shader_feature_local _WORLDSPACE
            #include "UnityCG.cginc"
            #include "Assets/ShaderInspector/ShaderInspector.cginc"

            float4 _LightWood, _DarkWood, _SpecColor2, _k_a;
            float  _GrainScale, _RingFreq, _RingSharpness, _Turbulence, _Octaves, _Shininess;

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

            struct appdata {
                float4 pos    : POSITION;
                float3 normal : NORMAL;
            };

            struct v2f {
                float4 pos         : SV_POSITION;
                float4 world_pos   : TEXCOORD0;
                float3 worldNormal : TEXCOORD1;
                float3 localPos    : TEXCOORD2;
            };

            v2f vert(appdata i) {
                v2f o;
                o.world_pos   = mul(UNITY_MATRIX_M, i.pos);
                o.pos         = mul(UNITY_MATRIX_P, mul(UNITY_MATRIX_V, o.world_pos));
                o.worldNormal = UnityObjectToWorldNormal(i.normal);
                o.localPos    = i.pos.xyz;
                return o;
            }

            // ---- Noise ----
            float hash(float3 p) {
                p = frac(p * 0.3183099 + 0.1);
                p *= 17.0;
                return frac(p.x * p.y * p.z * (p.x + p.y + p.z));
            }

            float valueNoise(float3 p) {
                float3 i = floor(p);
                float3 f = frac(p);
                float3 u = f * f * (3.0 - 2.0 * f);

                return lerp(
                    lerp(lerp(hash(i),               hash(i+float3(1,0,0)), u.x),
                         lerp(hash(i+float3(0,1,0)), hash(i+float3(1,1,0)), u.x), u.y),
                    lerp(lerp(hash(i+float3(0,0,1)), hash(i+float3(1,0,1)), u.x),
                         lerp(hash(i+float3(0,1,1)), hash(i+float3(1,1,1)), u.x), u.y),
                    u.z);
            }

            float fbm(float3 p) {
                float v = 0.0, a = 0.5;
                int oct = (int)_Octaves;
                [unroll(6)]
                for (int k = 0; k < 6; k++) {
                    if (k >= oct) break;
                    v += a * valueNoise(p);
                    p *= 2.0; a *= 0.5;
                }
                return v;
            }

            // ---- Wood pattern ----
            float woodPattern(float3 p) {
                // Radial distance from Y axis — cross-section of a log
                float r    = sqrt(p.x * p.x + p.z * p.z);
                float turb = fbm(p) * _Turbulence;

                // Rings: sine over distorted radius
                float ring = sin((r + turb) * _RingFreq * UNITY_PI * 2.0);
                ring = ring * 0.5 + 0.5;                       // remap to 0..1
                ring = pow(saturate(ring), _RingSharpness);    // sharpen
                return ring;
            }

            FragOut frag(v2f v) : SV_Target {
                DEBUGGABLE;

            #if defined(_WORLDSPACE)
                float3 coord = v.world_pos.xyz * _GrainScale;
            #else
                float3 coord = v.localPos * _GrainScale;
            #endif

                float  ring      = woodPattern(coord);
                float3 woodColor = lerp(_LightWood.rgb, _DarkWood.rgb, ring);

                float3 N_versor = normalize(v.worldNormal);
                float3 V_versor = normalize(_WorldSpaceCameraPos - v.world_pos.xyz);

                float3 totalDiffuse  = float3(0, 0, 0);
                float3 totalSpecular = float3(0, 0, 0);

                for (int i = 0; i < _L_Count; i++) {
                    float  coneL    = 1;
                    float  L_dist   = length(_L_Position[i].xyz - v.world_pos.xyz);
                    float3 L_versor = normalize(_L_Position[i].xyz - v.world_pos.xyz);
                    float3 H_versor = normalize(L_versor + V_versor);

                    float NL = saturate(dot(N_versor, L_versor));
                    float NH = saturate(dot(N_versor, H_versor));

                    if (_L_Type[i] == 1) {
                        L_dist   = 0;
                        L_versor = normalize(_L_Forward[i].xyz);
                        H_versor = normalize(L_versor + V_versor);
                        NL = saturate(dot(N_versor, L_versor));
                        NH = saturate(dot(N_versor, H_versor));
                    }
                    else if (_L_Type[i] == 2) {
                        coneL = pow(saturate((_L_ConeCosine[i] - dot(_L_Forward[i].xyz, L_versor)) / (_L_ConeCosine[i] - 1)), _L_ConeFalloff[i]);
                    }

                    float3 lightColor = _L_Color[i].rgb * _L_Intensity[i] * coneL / pow(1 + L_dist, _L_Attenuation[i]);

                    totalDiffuse  += woodColor * NL * lightColor;
                    totalSpecular += _SpecColor2.rgb * pow(NH, _Shininess) * NL * lightColor;
                }

                float3 ambient = _k_a.rgb * woodColor;
                ret(float4(ambient + totalDiffuse + totalSpecular, 1));
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}
