Shader "BlinnPhong_Vtx"
{
    Properties
    {
        _k_a("Ambient tint", Color) = (1,1,1,1)
        _k_d("Diffuse tint", Color) = (1,1,1,1)
        _k_s("Specular tint", Color) = (1,1,1,1)
        _n("Shinnyness", Float) = 1
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
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                fixed4 color : TEXCOORD1;
            };

            float3 _L_pos;
            float _L_int, _L_pow, _n;
            fixed4 _k_a, _k_d, _k_s;

            v2f vert(appdata i)
            {
                v2f o;

                float4 world_pos = mul(UNITY_MATRIX_M, i.pos);
                o.pos = mul(UNITY_MATRIX_P, mul(UNITY_MATRIX_V, world_pos));
                o.uv = i.uv;

                float L_dist = length(_L_pos.xyz - world_pos.xyz);
                float3 L_versor = normalize(_L_pos.xyz - world_pos.xyz);
                float3 N_versor = UnityObjectToWorldNormal(i.normal);
                float3 V_versor =  normalize(_WorldSpaceCameraPos - world_pos);
                float3 LV = (L_versor + V_versor);
                float3 H_versor = LV / length(LV);

                float4 ambient  = _k_a;
                float4 diffuse  = _k_d * saturate(dot(L_versor, N_versor));
                float4 specular = _k_s * pow(saturate(dot(N_versor, H_versor)), _n);

                o.color = ambient + (_L_int * diffuse + _L_int * specular) / pow(L_dist, _L_pow);

                return o;
            }

            float4 frag(v2f v) : SV_TARGET
            {
                fixed4 fragColor = v.color;

                return fragColor;
            }

            ENDCG
        }
    }
}