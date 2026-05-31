Shader "Custom/StandardLit"
{
    Properties
    {
        // Albedo
        _Color          ("Color",           Color)  = (1,1,1,1)
        [NoScaleOffset]
        _MainTex        ("Albedo",          2D)     = "white" {}

        // Metallic workflow — R = metallic, A = smoothness (same as Unity Standard)
        _Metallic       ("Metallic",        Range(0,1)) = 0.0
        _Glossiness     ("Smoothness",      Range(0,1)) = 0.5
        [NoScaleOffset]
        _MetallicGlossMap ("Metallic (R) Smoothness (A)", 2D) = "white" {}

        // Normal map
        [NoScaleOffset]
        _BumpMap        ("Normal Map",      2D)     = "bump" {}
        _BumpScale      ("Normal Scale",    Float)  = 1.0

        // Occlusion
        [NoScaleOffset]
        _OcclusionMap   ("Occlusion",       2D)     = "white" {}
        _OcclusionStrength ("Strength",     Range(0,1)) = 1.0

        // Emission
        [HDR]
        _EmissionColor  ("Emission Color",  Color)  = (0,0,0,1)
        [NoScaleOffset]
        _EmissionMap    ("Emission",        2D)     = "black" {}

        // Ambient
        _k_a            ("Ambient",         Color)  = (0.1,0.1,0.1,1)
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
            #include "UnityCG.cginc"
            #include "Assets/ShaderInspector/ShaderInspector.cginc"

            struct appdata
            {
                float4 pos     : POSITION;
                float3 normal  : NORMAL;
                float4 tangent : TANGENT;
                float2 uv      : TEXCOORD0;
            };

            struct v2f
            {
                float4 pos              : SV_POSITION;
                float2 uv               : TEXCOORD0;
                float4 world_pos        : TEXCOORD1;
                float3 normal_versor    : TEXCOORD2;
                float3 tangent_versor   : TEXCOORD3;
                float3 bitangent_versor : TEXCOORD4;
            };

            // Albedo
            float4    _Color;
            sampler2D _MainTex;

            // Metallic / smoothness
            float     _Metallic;
            float     _Glossiness;
            sampler2D _MetallicGlossMap;

            // Normal
            sampler2D _BumpMap;
            float     _BumpScale;

            // Occlusion
            sampler2D _OcclusionMap;
            float     _OcclusionStrength;

            // Emission
            float4    _EmissionColor;
            sampler2D _EmissionMap;

            // Ambient
            float4    _k_a;

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

            v2f vert(appdata i)
            {
                v2f o;
                o.world_pos        = mul(UNITY_MATRIX_M, i.pos);
                o.pos              = mul(UNITY_MATRIX_P, mul(UNITY_MATRIX_V, o.world_pos));
                o.uv               = i.uv;
                o.normal_versor    = UnityObjectToWorldNormal(i.normal);
                o.tangent_versor   = UnityObjectToWorldDir(i.tangent.xyz);
                o.bitangent_versor = cross(o.tangent_versor, o.normal_versor) * (i.tangent.w * unity_WorldTransformParams.w);
                return o;
            }

            FragOut frag(v2f v) : SV_Target
            {
                DEBUGGABLE;

                // --- Sample maps ---
                float4 albedo        = _Color * tex2D(_MainTex, v.uv);
                float4 metallicSample = tex2D(_MetallicGlossMap, v.uv);
                float  metalness     = _Metallic     * metallicSample.r;
                float  smoothness    = _Glossiness   * metallicSample.a;
                float  roughness     = 1.0 - smoothness;
                float  ao            = lerp(1.0, tex2D(_OcclusionMap, v.uv).r, _OcclusionStrength);
                float3 emission      = _EmissionColor.rgb * tex2D(_EmissionMap, v.uv).rgb;

                // --- Normal map (world space) ---
                float3 T = normalize(v.tangent_versor);
                float3 B = normalize(v.bitangent_versor);
                float3 N = normalize(v.normal_versor);
                float3x3 TBN = transpose(float3x3(-T, -B, N));
                float3 normalTS  = UnpackNormal(tex2D(_BumpMap, v.uv));
                normalTS.xy     *= _BumpScale;
                float3 N_versor  = normalize(mul(TBN, normalTS));

                float3 V_versor  = normalize(_WorldSpaceCameraPos - v.world_pos.xyz);
                float  NV        = dot(N_versor, V_versor);

                // --- F0 from metalness workflow ---
                float3 reflectivity = lerp(float3(0.04, 0.04, 0.04), albedo.rgb, metalness);
                float3 fresnel      = reflectivity + (1.0 - reflectivity) * pow(1.0 - NV, 5.0);

                float alpha = roughness * roughness;

                // Debug
                insp4(1, albedo);
                inspf(2, metalness);
                inspf(3, roughness);
                insp3(4, N_versor);
                insp3(6, reflectivity);

                float3 outgoing_radiance = float3(0, 0, 0);

                for (int i = 0; i < _L_Count; i++)
                {
                    float3 L_pos         = _L_Position[i].xyz;
                    float3 L_color       = _L_Color[i].rgb;
                    float3 L_forward     = _L_Forward[i].xyz;
                    float  L_coneCosine  = _L_ConeCosine[i];
                    float  L_coneFalloff = _L_ConeFalloff[i];
                    float  L_intensity   = _L_Intensity[i];
                    float  L_attenuation = _L_Attenuation[i];

                    float  L_cone   = 1;
                    float  L_dist   = length(L_pos - v.world_pos.xyz);
                    float3 L_versor = normalize(L_pos - v.world_pos.xyz);
                    float3 H_versor = normalize(L_versor + V_versor);

                    float NL = dot(N_versor, L_versor);
                    float NH = dot(N_versor, H_versor);
                    float VH = dot(V_versor, H_versor);

                    if (_L_Type[i] == 1) // Directional
                    {
                        L_dist   = 0;
                        L_versor = normalize(L_forward);
                        H_versor = normalize(L_versor + V_versor);
                        NL = dot(N_versor, L_versor);
                        NH = dot(N_versor, H_versor);
                        VH = dot(V_versor, H_versor);
                    }
                    else if (_L_Type[i] == 2) // Spot
                    {
                        L_cone = pow(saturate((L_coneCosine - dot(L_forward, L_versor)) / (L_coneCosine - 1)), L_coneFalloff);
                    }

                    // D — GGX
                    float ndf = alpha * alpha / (UNITY_PI * pow((NH*NH * (alpha*alpha - 1) + 1), 2.0));

                    // G — Cook-Torrance
                    float gv  = 2 * NH * NV / VH;
                    float gl  = 2 * NH * NL / VH;
                    float geo = min(1, min(gl, gv));

                    // BRDF — energy conserving (same as CookTorrance_PBR_Metalness)
                    float3 brdf_diffuse  = albedo.rgb * (1.0 - metalness);
                    float3 brdf_specular = fresnel * ndf * geo / (4.0 * NL * NV);
                    float3 total_brdf    = saturate((1.0 - fresnel) * brdf_diffuse + fresnel * brdf_specular);

                    float3 incident_radiance = L_cone * L_color * L_intensity / pow(1 + L_dist, L_attenuation);

                    outgoing_radiance += max(total_brdf * incident_radiance * saturate(NL), 0);
                }

                float3 ambient = _k_a.rgb * albedo.rgb * ao;
                ret(float4(ambient + outgoing_radiance + emission, albedo.a));
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}
