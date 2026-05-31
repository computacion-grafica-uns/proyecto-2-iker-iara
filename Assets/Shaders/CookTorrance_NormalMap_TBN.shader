Shader "CookTorrance_NormalMap_TBN"
{
    Properties
    {
        _MainTex        ("Albedo",          2D)           = "white" {}
        _NormalMap      ("Normal Map",      2D)           = "bump"  {}
        _NormalStrength ("Normal Strength", Range(0, 2))  = 1.0
        _k_a            ("Ambient",         Color)        = (0.1, 0.1, 0.1, 1)
        _k_d            ("Diffuse tint",    Color)        = (1, 1, 1, 1)
        _r_d_coeff      ("Diffuse coeff",   Float)        = 1.0
        _rp             ("Roughness",       Range(0, 1))  = 0.5
        _F_0            ("Reflectance",     Color)        = (1.022, 0.782, 0.344, 1)
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

            struct appdata {
                float4 pos     : POSITION;
                float3 normal  : NORMAL;
                float4 tangent : TANGENT;
                float2 uv      : TEXCOORD0;
            };

            struct v2f {
                float4 pos              : SV_POSITION;
                float2 uv               : TEXCOORD0;
                float4 world_pos        : TEXCOORD1;
                float3 normal_versor    : TEXCOORD2;
                float3 tangent_versor   : TEXCOORD3;
                float3 bitangent_versor : TEXCOORD4;
            };

            sampler2D _MainTex, _NormalMap;
            float     _NormalStrength, _r_d_coeff, _rp;
            float4    _k_a, _k_d, _F_0;

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

            v2f vert(appdata i) {
                v2f o;
                o.world_pos        = mul(UNITY_MATRIX_M, i.pos);
                o.pos              = mul(UNITY_MATRIX_P, mul(UNITY_MATRIX_V, o.world_pos));
                o.uv               = i.uv;
                o.normal_versor    = UnityObjectToWorldNormal(i.normal);
                o.tangent_versor   = UnityObjectToWorldDir(i.tangent.xyz);
                o.bitangent_versor = cross(o.tangent_versor, o.normal_versor) * (i.tangent.w * unity_WorldTransformParams.w);
                return o;
            }

            FragOut frag(v2f v) : SV_Target {
                DEBUGGABLE;

                // TBN matrix — tangent space to world space
                float3 T = normalize(v.tangent_versor);
                float3 B = normalize(v.bitangent_versor);
                float3 N = normalize(v.normal_versor);
                float3x3 TBN = transpose(float3x3(-T, -B, N));

                float3 normalTS  = UnpackNormal(tex2D(_NormalMap, v.uv));
                normalTS.xy     *= _NormalStrength;
                float3 N_versor  = normalize(mul(TBN, normalTS));

                float4 albedo   = tex2D(_MainTex, v.uv);
                float3 V_versor = normalize(_WorldSpaceCameraPos - v.world_pos.xyz);

                float NV    = dot(N_versor, V_versor);
                float alpha = _rp * _rp;

                float4 fresnel = _F_0 + (float4(1,1,1,1) - _F_0) * pow(1 - NV, 5.0);

                float4 brdf = 0;

                for (int i = 0; i < _L_Count; i++) {
                    float  coneL    = 1;
                    float  L_dist   = length(_L_Position[i].xyz - v.world_pos.xyz);
                    float3 L_versor = normalize(_L_Position[i].xyz - v.world_pos.xyz);
                    float3 H_versor = normalize(L_versor + V_versor);

                    float NL = dot(N_versor, L_versor);
                    float NH = dot(N_versor, H_versor);
                    float VH = dot(V_versor, H_versor);

                    if (_L_Type[i] == 1) {
                        L_dist   = 0;
                        L_versor = normalize(_L_Forward[i].xyz);
                        H_versor = normalize(L_versor + V_versor);
                        NL = dot(N_versor, L_versor);
                        NH = dot(N_versor, H_versor);
                        VH = dot(V_versor, H_versor);
                    }
                    else if (_L_Type[i] == 2) {
                        coneL = pow(saturate((_L_ConeCosine[i] - dot(_L_Forward[i].xyz, L_versor)) / (_L_ConeCosine[i] - 1)), _L_ConeFalloff[i]);
                    }

                    float ndf = saturate(NL) * alpha * alpha / (UNITY_PI * pow((NH*NH * (alpha*alpha - 1) + 1), 2.0));
                    float gv  = 2 * NH * NV / VH;
                    float gl  = 2 * NH * NL / VH;
                    float geo = min(1, min(gl, gv));

                    float4 diffuse  = _k_d * albedo * _r_d_coeff * saturate(NL) * coneL;
                    float4 specular = saturate(fresnel * ndf * geo / (4 * NL * NV));
                    specular.a = 1;

                    brdf += (diffuse + specular) * _L_Color[i] * _L_Intensity[i] / pow(1 + L_dist, _L_Attenuation[i]);
                }

                ret(_k_a * albedo + brdf);
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}
