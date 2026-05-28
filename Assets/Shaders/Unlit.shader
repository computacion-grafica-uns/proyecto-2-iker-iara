Shader "Unlit_Textured"
{
    Properties
    {
        [NoScaleOffset] _diffuse("Texture", 2D) = "white" {}
        _tint("Tint", Color) = (1,1,1,1)
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
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            float4 _tint;
            sampler2D _diffuse;

            v2f vert(appdata i)
            {
                v2f o;

                o.pos = mul(UNITY_MATRIX_P, mul(UNITY_MATRIX_V, mul(UNITY_MATRIX_M, i.pos)));
                o.uv = i.uv;

                return o;
            }

            float4 frag(v2f v) : SV_TARGET
            {
                fixed4 fragColor = 1;

                fragColor = tex2D(_diffuse, v.uv) * _tint;

                return fragColor;
            }

            ENDCG
        }
    }
}