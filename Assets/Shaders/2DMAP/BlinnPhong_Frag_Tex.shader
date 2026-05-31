Shader "BlinnPhong_Frag_Tex"
{
    Properties
    {
        _MainTex("Albedo", 2D) = "white" {}
        _k_a("Ambient tint", Color) = (1,1,1,1)
        _k_d("Diffuse tint", Color) = (1,1,1,1)
        _k_s("Specular tint", Color) = (1,1,1,1)
        _n("Shinnyness", Float) = 10
    }

    SubShader
    {
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
                float4 pos    : POSITION;
                float3 normal : NORMAL;
                float2 uv     : TEXCOORD0;
            };

            struct v2f
            {
                float4 pos           : SV_POSITION;
                float2 uv            : TEXCOORD0;
                float4 world_pos     : TEXCOORD1;
                float3 normal_versor : TEXCOORD2;
            };

            float     _n;
            fixed4    _k_a, _k_d, _k_s;
            sampler2D _MainTex;

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
                o.world_pos     = mul(UNITY_MATRIX_M, i.pos);
                o.pos           = mul(UNITY_MATRIX_P, mul(UNITY_MATRIX_V, o.world_pos));
                o.uv            = i.uv;
                o.normal_versor = UnityObjectToWorldNormal(i.normal);
                return o;
            }

            FragOut frag(v2f v) : SV_Target
            {
                DEBUGGABLE;

                float4 texColor = tex2D(_MainTex, v.uv);
                float3 N_versor = normalize(v.normal_versor);
                float3 V_versor = normalize(_WorldSpaceCameraPos - v.world_pos);

                fixed4 brdf = 0;

                for (int i = 0; i < _L_Count; i++)
                {
                    float  coneL    = 1;
                    float  L_dist   = length(_L_Position[i].xyz - v.world_pos);
                    float3 L_versor = normalize(_L_Position[i].xyz - v.world_pos);

                    if (_L_Type[i] == 1) // Directional
                    {
                        L_dist   = 0;
                        L_versor = normalize(_L_Forward[i].xyz);
                    }
                    else if (_L_Type[i] == 2) // Spot
                    {
                        coneL = pow(saturate((_L_ConeCosine[i] - dot(_L_Forward[i].xyz, L_versor)) / (_L_ConeCosine[i] - 1)), _L_ConeFalloff[i]);
                    }

                    float3 H_versor = normalize(L_versor + V_versor);

                    float4 diffuse  = _k_d * texColor * saturate(dot(L_versor, N_versor));
                    float4 specular = _k_s * pow(saturate(dot(N_versor, H_versor)), _n);

                    brdf += saturate((diffuse + specular) * coneL * _L_Color[i] * _L_Intensity[i] / pow(1 + L_dist, _L_Attenuation[i]));
                }

                float4 ambient = _k_a * texColor;
                ret(ambient + brdf);
            }

            ENDCG
        }
    }
}
