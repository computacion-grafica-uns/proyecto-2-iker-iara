Shader "BlinnPhong_Textured"
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

            FragOut frag(v2f v) : SV_TARGET
            {
                DEBUGGABLE;
                fixed4 fragColor = 1;

                float4 _k_d = tex2D(_k_d_tex, v.uv);
                float4 _k_s = pow(_IsRoughness + (-2 * _IsRoughness + 1) * tex2D(_k_s_tex, v.uv), 2);
                //float3 normal_map = lerp(float3(0,0,1), tex2D(_N_tex, v.uv) * 2.0 - 1.0, _N_coeff);
                float3 normal_map = lerp(float3(0,0,1), UnpackNormal(tex2D(_N_tex, v.uv)), _N_coeff);

                float3x3 TBN = transpose(float3x3(v.tangent_versor, v.bitangent_versor, v.normal_versor));
                
                float L_dist = length(_L_pos - v.world_pos);
                float3 L_versor = normalize(_L_pos - v.world_pos);
                float3 N_versor = normalize(mul(TBN, normal_map));
                float3 V_versor =  normalize(_WorldSpaceCameraPos - v.world_pos);
                float3 LV = (L_versor + V_versor);
                float3 H_versor = LV / length(LV);

                float4 ambient  = _k_d * _k_a;
                float4 diffuse  = _k_d * _k_d_coeff * saturate(dot(L_versor, N_versor));
                float4 specular = _k_s * _k_s_coeff * pow(saturate(dot(N_versor, H_versor)), _n);

                insp4(2, pow(saturate(dot(N_versor, H_versor)), _n));

                fragColor = ambient + (_L_int * diffuse + _L_int * specular) / pow(L_dist, _L_pow);

                ret(fragColor);
            }

            ENDCG
        }
    }
}