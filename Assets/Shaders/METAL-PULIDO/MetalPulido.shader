Shader "Custom/MetalPulido"
{
    Properties
    {
        _F_0          ("Metal Color (F0)", Color) = (0.673, 0.673, 0.585, 1)
        _rp           ("Roughness", Range(0.01, 1)) = 0.1
        _RoughnessMap   ("Roughness Map", 2D) = "white" {}
        _RoughnessScale ("Roughness Map Scale", Range(0, 1)) = 1.0
        _k_a            ("Ambient", Color) = (0.05, 0.05, 0.05, 1)
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

            float4    _F_0;
            float     _rp;
            float     _RoughnessScale;
            sampler2D _RoughnessMap;
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

            struct appdata {
                float4 pos    : POSITION;
                float3 normal : NORMAL;
                float2 uv     : TEXCOORD0;
            };

            struct v2f {
                float4 pos         : SV_POSITION;
                float4 worldPos    : TEXCOORD0;
                float3 worldNormal : TEXCOORD1;
                float2 uv          : TEXCOORD2;
            };

            v2f vert(appdata i) {
                v2f o;
                o.worldPos    = mul(UNITY_MATRIX_M, i.pos);
                o.pos         = mul(UNITY_MATRIX_P, mul(UNITY_MATRIX_V, o.worldPos));
                o.worldNormal = UnityObjectToWorldNormal(i.normal);
                o.uv          = i.uv;
                return o;
            }

            FragOut frag(v2f v) : SV_Target {
                DEBUGGABLE;

                float3 N_versor = normalize(v.worldNormal);
                float3 V_versor = normalize(_WorldSpaceCameraPos - v.worldPos.xyz);

                float rp    = _rp * lerp(1.0, tex2D(_RoughnessMap, v.uv).r, _RoughnessScale);
                float alpha = rp * rp;
                float NV    = dot(N_versor, V_versor);

                // Fresnel computed once with NV — matches CookTorrance_Frag convention
                float4 fresnel = _F_0 + (float4(1,1,1,1) - _F_0) * pow(1 - NV, 5.0);

                fixed4 brdf = 0;

                for (int i = 0; i < _L_Count; i++)
                {
                    float  coneL    = 1;
                    float  L_dist   = length(_L_Position[i].xyz - v.worldPos.xyz);
                    float3 L_versor = normalize(_L_Position[i].xyz - v.worldPos.xyz);
                    float3 H_versor = normalize(L_versor + V_versor);

                    float NL = dot(N_versor, L_versor);
                    float NH = dot(N_versor, H_versor);
                    float VH = dot(V_versor, H_versor);

                    if (_L_Type[i] == 1) // Directional
                    {
                        L_dist   = 0;
                        L_versor = normalize(_L_Forward[i].xyz);
                        H_versor = normalize(L_versor + V_versor);
                        NL = dot(N_versor, L_versor);
                        NH = dot(N_versor, H_versor);
                        VH = dot(V_versor, H_versor);
                    }
                    else if (_L_Type[i] == 2) // Spot
                    {
                        coneL = pow(saturate((_L_ConeCosine[i] - dot(_L_Forward[i].xyz, L_versor)) / (_L_ConeCosine[i] - 1)), _L_ConeFalloff[i]);
                    }
                    float ndf = saturate(NL) * alpha * alpha / (UNITY_PI * pow((NH*NH * (alpha*alpha - 1) + 1), 2.0));
                    float gv  = 2 * NH * NV / VH;
                    float gl  = 2 * NH * NL / VH;
                    float geo = min(1, min(gl, gv));
                    float4 specular = saturate(fresnel * ndf * geo / (4 * NL * NV));
                    specular.a = 1;
                    brdf += specular * _L_Color[i] * _L_Intensity[i] * coneL / pow(1 + L_dist, _L_Attenuation[i]);
                }

                float4 ambient = _F_0 * _k_a;
                ret(ambient + brdf);
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}
