Shader "CookTorrance_Textured"
{
    Properties
    {
        _k_a("Ambient tint", Color) = (0,0,0,1)
        [NoScaleOffset] _k_d_tex("Diffuse", 2D) = "white" {}
        _k_d_coeff("Diffuse coefficient", Float) = 10
        [NoScaleOffset] _k_s_tex("Specular", 2D) = "white" {}
        _k_s_coeff("Specular coefficient", Float) = 10
        [MaterialToggle] _IsRoughness("Is this a roughness map instead of a specular map?", Float) = 1
        [NoScaleOffset] _N_tex("Normal map", 2D) = "bump" {}
        _N_coeff("Normal coefficient", Float) = 1
        _n("Shinnyness", Float) = 10
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
            float _L_int, _L_pow, _n, _k_d_coeff, _k_s_coeff, _N_coeff, _IsRoughness;
            float4 _k_a;
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

            float4 frag(v2f v) : SV_TARGET
            {
                fixed4 fragColor = 1;

                float4 _k_d = tex2D(_k_d_tex, v.uv);
                float4 _k_s = pow(_IsRoughness + (-2 * _IsRoughness + 1) * tex2D(_k_s_tex, v.uv), 2);
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

                float rp = 0.2;
                float alpha = rp * rp;
                float4 _F_0 = float4(1.022, 0.782, 0.344, 1);
                float k = alpha / 2.0;

                float4 fresnel = _F_0 + (float4(1,1,1,1) - _F_0) * pow(1 - VH, 5.0);
                float ndf = alpha * alpha / (UNITY_PI * pow((NH*NH * (alpha*alpha - 1) + 1), 2.0));
                float gv = max(NV / (NV * (1 - k) + k), 0);
                float gl = max(NL / (NL * (1 - k) + k), 0);
                float geo = gl*gv;

                float4 ambient  = _k_d * _k_a;
                float4 diffuse  = _k_d * _k_d_coeff * saturate(NL);
                float4 specular = saturate(_k_s * _k_s_coeff * fresnel * ndf * geo / (4 * NL * NV));
                specular.a = 1;

                fragColor = ambient + (_L_int * diffuse + _L_int * specular) / pow(L_dist, _L_pow);

                return fragColor;
            }

            ENDCG
        }
    }
}