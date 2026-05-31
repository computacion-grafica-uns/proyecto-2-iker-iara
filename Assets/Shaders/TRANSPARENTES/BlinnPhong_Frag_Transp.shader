Shader "BlinnPhong_Frag_Transp"
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
        _Alpha("Alpha", Range(0,1)) = 1
    }

    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" }

        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

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

            float3 _L_pos;
            float  _L_int, _L_pow, _n, _Alpha;
            fixed4 _k_a, _k_d, _k_s;

            v2f vert(appdata i)
            {
                v2f o;
                o.world_pos     = mul(UNITY_MATRIX_M, i.pos);
                o.pos           = mul(UNITY_MATRIX_P, mul(UNITY_MATRIX_V, o.world_pos));
                o.uv            = i.uv;
                o.normal_versor = UnityObjectToWorldNormal(i.normal);
                return o;
            }

            float4 frag(v2f v) : SV_TARGET
            {
                float  L_dist   = length(_L_pos - v.world_pos);
                float3 L_versor = normalize(_L_pos - v.world_pos);
                float3 N_versor = normalize(v.normal_versor);
                float3 V_versor = normalize(_WorldSpaceCameraPos - v.world_pos);
                float3 H_versor = normalize(L_versor + V_versor);

                float4 ambient  = _k_a;
                float4 diffuse  = _k_d * saturate(dot(L_versor, N_versor));
                float4 specular = _k_s * pow(saturate(dot(N_versor, H_versor)), _n);

                float3 color = ambient + (_L_int * diffuse + _L_int * specular) / pow(L_dist, _L_pow);
                return float4(color, _Alpha);
            }

            ENDCG
        }
    }
}
