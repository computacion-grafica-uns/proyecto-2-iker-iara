Shader "CookTorrance_Textured"
{
    Properties
    {
        _k_a("Ambient tint", Color) = (0,0,0,1)
        [NoScaleOffset] _k_d_tex("Diffuse", 2D) = "white" {}
        _r_d_coeff("Diffuse coefficient", Float) = 10
        [NoScaleOffset] _k_s_tex("Roughness", 2D) = "white" {}
        _r_s_coeff("Roughness coefficient", Float) = 10
        _F_0("Reflectance", Color) = (1.022, 0.782, 0.344, 1)
        [MaterialToggle] _FlipRoughness("Is this a roughness map instead of a specular map?", Float) = 1
        [NoScaleOffset] _N_tex("Normal map", 2D) = "bump" {}
        _N_coeff("Normal coefficient", Float) = 1
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
            float _L_int, _L_pow, _n, _r_d_coeff, _r_s_coeff, _N_coeff, _FlipRoughness;
            float4 _k_a, _F_0;
            sampler2D _k_d_tex, _k_s_tex, _N_tex;

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

                float4 _k_d = tex2D(_k_d_tex, v.uv);
                float4 _k_s = pow(_FlipRoughness + (-2 * _FlipRoughness + 1) * tex2D(_k_s_tex, v.uv), 2);
                float3 normal_map = lerp(float3(0,0,1), UnpackNormal(tex2D(_N_tex, v.uv)), _N_coeff);

                float3x3 TBN = transpose(float3x3(v.tangent_versor, v.bitangent_versor, v.normal_versor));
                
                float L_dist = length(_L_pos - v.world_pos);
                float3 L_versor = normalize(_L_pos - v.world_pos);
                float3 N_versor = normalize(mul(TBN, normal_map));
                float3 V_versor =  normalize(_WorldSpaceCameraPos - v.world_pos);
                float3 H_versor = normalize((L_versor + V_versor) / length(L_versor + V_versor));

                float NV = dot(N_versor, V_versor);
                float NL = dot(N_versor, L_versor);
                float NH = dot(N_versor, H_versor);
                float VH = dot(V_versor, H_versor);

                float rp = length(_k_s.rbg) * _r_s_coeff;
                float alpha = rp * rp;
                float k = alpha / 2.0;

                float4 fresnel = _F_0 + (float4(1,1,1,1) - _F_0) * pow(1 - NV, 5.0);
                float ndf = alpha * alpha / (UNITY_PI * pow((NH*NH * (alpha*alpha - 1) + 1), 2.0));
                float gv = max(NV / (NV * (1 - k) + k), 0);
                float gl = max(NL / (NL * (1 - k) + k), 0);
                float geo = gl*gv;

                float4 ambient  = _k_d * _k_a;
                float4 diffuse  = _k_d * _r_d_coeff * saturate(NL);
                float4 specular = saturate(fresnel * ndf * geo / (1 * NL * NV));
                specular.a = 1;
                
                insp4(1, fresnel);
                inspf(2, saturate(ndf));
                inspf(3, geo);
                insp4(4,  _L_int * diffuse / pow(L_dist, _L_pow));
                insp4(5, (_L_int * diffuse + _L_int * float4(ndf, ndf, ndf, 1)) / pow(L_dist, _L_pow));

                fragColor = ambient + (_L_int * diffuse + _L_int * specular) / pow(L_dist, _L_pow);

                ret(fragColor);
            }

            ENDCG
        }
    }
}