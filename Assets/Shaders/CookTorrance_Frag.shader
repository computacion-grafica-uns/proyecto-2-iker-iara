Shader "CookTorrance_Frag"
{
    Properties
    {
        _k_a("Ambient tint", Color) = (0,0,0,1)
        _k_d("Diffuse", Color) = (1,1,1,1)
        _r_d_coeff("Diffuse coefficient", Float) = 10
        _rp("Roughness", Range(0,1)) = 0.5
        _F_0("Reflectance", Color) = (1.022, 0.782, 0.344, 1)
        _L_pos("Light position", Vector) = (0,3,0)
        _L_int("Light intensity", Float) = 1
        _L_pow("Light decay power", Float) = 2
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
                float4 pos : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0; 
                float4 world_pos : TEXCOORD1;
                float3 normal_versor : TEXCOORD2;
                float3 tangent_versor : TEXCOORD3;
                float3 bitangent_versor : TEXCOORD4;
            };

            float3 _L_pos;
            float _L_int, _L_pow, _n, _r_d_coeff, _rp;
            float4 _k_a, _k_d, _F_0;

            v2f vert(appdata i)
            {
                v2f o;

                o.world_pos = mul(UNITY_MATRIX_M, i.pos);
                o.pos = mul(UNITY_MATRIX_P, mul(UNITY_MATRIX_V, o.world_pos));
                o.uv = i.uv;
                o.normal_versor = UnityObjectToWorldNormal(i.normal);
                o.tangent_versor = UnityObjectToWorldDir(i.tangent.xyz); 
                o.bitangent_versor = cross(o.tangent_versor, o.normal_versor) * (i.tangent.w * unity_WorldTransformParams.w);

                return o;
            }

            FragOut frag(v2f v) : SV_Target
            {
                DEBUGGABLE;
                fixed4 fragColor = 1;
                
                float L_dist = length(_L_pos - v.world_pos);
                float3 L_versor = normalize(_L_pos - v.world_pos);
                float3 N_versor = normalize(v.normal_versor);
                float3 V_versor =  normalize(_WorldSpaceCameraPos - v.world_pos);
                float3 H_versor = normalize((L_versor + V_versor) / length(L_versor + V_versor));

                float NV = dot(N_versor, V_versor);
                float NL = dot(N_versor, L_versor);
                float NH = dot(N_versor, H_versor);
                float VH = dot(V_versor, H_versor);

                float rp = _rp;
                float alpha = rp * rp;

                float4 fresnel = _F_0 + (float4(1,1,1,1) - _F_0) * pow(1 - NV, 5.0);
                float ndf = saturate(NL) * alpha * alpha / (UNITY_PI * pow((NH*NH * (alpha*alpha - 1) + 1), 2.0));
                float gv = 2 * NH * NV / VH;
                float gl = 2 * NH * NL / VH;
                float geo = min(1, min(gl, gv));

                float4 ambient  = _k_d * _k_a;
                float4 diffuse  = _k_d * _r_d_coeff * saturate(NL);
                float4 specular = saturate(fresnel * ndf * geo / (4 * NL * NV));
                specular.a = 1;
                
                insp4(1, fresnel);
                inspf(2, ndf);
                inspf(3, geo);
                inspf(4, gl);
                inspf(5, gv);
                inspf(6, NL);

                fragColor = ambient + (diffuse + specular) * _L_int / pow(L_dist, _L_pow);

                ret(fragColor);
            }

            ENDCG
        }
    }
}