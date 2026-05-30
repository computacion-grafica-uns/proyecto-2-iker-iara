Shader "Custom/BrushedMetal"
{
    Properties
    {
        [NoScaleOffset] _AlbedoMap  ("Albedo map",            2D) = "white" {}
        [NoScaleOffset] _MetalnessMap("Metalness map",        2D) = "white" {}
        [NoScaleOffset] _NormalMap  ("Normal map",            2D) = "white" {}
        [NoScaleOffset] _AOMap      ("Ambient Occlusion map", 2D) = "white" {}

        [Header(Anisotropic Brush)]
        _rp_T       ("Roughness Along Brush",   Range(0.01, 1)) = 0.6
        _rp_B       ("Roughness Across Brush",  Range(0.01, 1)) = 0.05
        _BrushAngle ("Brush Angle (degrees)",   Range(0, 360))  = 0
    }

    SubShader
    {
        Pass
        {
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
                float4 pos               : SV_POSITION;
                float2 uv                : TEXCOORD0;
                float4 world_pos         : TEXCOORD1;
                float3 normal_versor     : TEXCOORD2;
                float3 tangent_versor    : TEXCOORD3;
                float3 bitangent_versor  : TEXCOORD4;
            };

            v2f vert(appdata i)
            {
                v2f o;
                o.world_pos         = mul(UNITY_MATRIX_M, i.pos);
                o.pos               = mul(UNITY_MATRIX_P, mul(UNITY_MATRIX_V, o.world_pos));
                o.uv                = i.uv;
                o.normal_versor     = UnityObjectToWorldNormal(i.normal);
                o.tangent_versor    = UnityObjectToWorldDir(i.tangent.xyz);
                o.bitangent_versor  = cross(o.tangent_versor, o.normal_versor) * (i.tangent.w * unity_WorldTransformParams.w);
                return o;
            }

            sampler2D _AlbedoMap, _MetalnessMap, _NormalMap, _AOMap;
            float  _rp_T, _rp_B, _BrushAngle;

            #define MAX_LIGHTS 20
            float4 _k_a;
            float4 _L_Position[MAX_LIGHTS];
            float4 _L_Forward[MAX_LIGHTS];
            float4 _L_Color[MAX_LIGHTS];
            float  _L_Intensity[MAX_LIGHTS];
            float  _L_Type[MAX_LIGHTS];
            float  _L_ConeCosine[MAX_LIGHTS];
            float  _L_ConeFalloff[MAX_LIGHTS];
            float  _L_Attenuation[MAX_LIGHTS];
            float  _L_Count;

            FragOut frag(v2f v) : SV_Target
            {
                float4 albedo    = tex2D(_AlbedoMap,    v.uv);
                float  metalness = tex2D(_MetalnessMap, v.uv).r;
                float3 normalTS  = UnpackNormal(tex2D(_NormalMap, v.uv)).rgb;
                float  ao        = tex2D(_AOMap,        v.uv).r;

                float3 T = normalize(v.tangent_versor);
                float3 B = normalize(v.bitangent_versor);
                float3 N = normalize(v.normal_versor);
                float3x3 TBN = transpose(float3x3(-T, -B, N));
                float3 N_versor = normalize(mul(TBN, normalTS));

                // rotacion
                float sinA = sin(_BrushAngle * UNITY_PI / 180.0);
                float cosA = cos(_BrushAngle * UNITY_PI / 180.0);
                float3 T_b =  cosA * T - sinA * B;
                float3 B_b =  sinA * T + cosA * B;

                float alphaT = _rp_T * _rp_T;
                float alphaB = _rp_B * _rp_B;

                float3 V_versor = normalize(_WorldSpaceCameraPos - v.world_pos.xyz);
                float  NV       = dot(N_versor, V_versor);
                float  TV       = dot(T_b, V_versor);
                float  BV       = dot(B_b, V_versor);

                // F0 from metalness workflow — same as CookTorrance_PBR_Metalness
                float3 reflectivity = lerp(float3(0.733, 0.697, 0.652), albedo.rgb, metalness);
                float3 fresnel      = reflectivity + (1.0 - reflectivity) * pow(1 - NV, 5.0);

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
                    float TH = dot(T_b, H_versor);
                    float BH = dot(B_b, H_versor);
                    float TL = dot(T_b, L_versor);
                    float BL = dot(B_b, L_versor);

                    if (_L_Type[i] == 1) // Directional
                    {
                        L_dist   = 0;
                        L_versor = normalize(L_forward);
                        H_versor = normalize(L_versor + V_versor);
                        NL = dot(N_versor, L_versor);
                        NH = dot(N_versor, H_versor);
                        VH = dot(V_versor, H_versor);
                        TH = dot(T_b, H_versor);
                        BH = dot(B_b, H_versor);
                        TL = dot(T_b, L_versor);
                        BL = dot(B_b, L_versor);
                    }
                    else if (_L_Type[i] == 2) // Spot
                    {
                        L_cone = pow(saturate((L_coneCosine - dot(L_forward, L_versor)) / (L_coneCosine - 1)), L_coneFalloff);
                    }

                    // D — Anisotropic GGX NDF
                    float denom_D = (TH / alphaT) * (TH / alphaT) + (BH / alphaB) * (BH / alphaB) + NH * NH;
                    float ndf     = 1.0 / (UNITY_PI * alphaT * alphaB * denom_D * denom_D);

                    // G — Anisotropic Smith GGX (separable)
                    float g1v = 2.0 * NV / (NV + sqrt(alphaT*alphaT*TV*TV + alphaB*alphaB*BV*BV + NV*NV));
                    float g1l = 2.0 * NL / (NL + sqrt(alphaT*alphaT*TL*TL + alphaB*alphaB*BL*BL + NL*NL));
                    float geo = g1v * g1l;

                    float3 brdf_diffuse  = albedo.rgb * (1.0 - metalness);
                    float3 brdf_specular = fresnel * ndf * geo / (4.0 * NL * NV);
                    float3 total_brdf    = saturate((1.0 - fresnel) * brdf_diffuse + fresnel * brdf_specular);

                    float3 incident_radiance = L_cone * L_color * L_intensity / pow(1 + L_dist, L_attenuation);

                    outgoing_radiance += max(total_brdf * incident_radiance * saturate(NL), 0);
                }

                float3 ambient = _k_a.rgb * albedo.rgb * ao;
                ret(float4(ambient + outgoing_radiance, 1));
            }
            ENDCG
        }
    }
}
