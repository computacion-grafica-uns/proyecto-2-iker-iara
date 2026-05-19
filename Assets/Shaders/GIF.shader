Shader "GIF"
{
    Properties
    {
        [NoScaleOffset] _atlas("Frame atlas", 2D) = "white" {}
        _Frametime("Frame duration in ms", Float) = 100.0
        _Framecount("Frame count", Float) = 100.0
        _Rows("Rows", Float) = 10.0
        _Columns("Columns", Float) = 10.0
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
            };

            float _Frametime, _Framecount, _Rows, _Columns;
            sampler2D _atlas;

            v2f vert(appdata i)
            {
                v2f o;

                o.pos = UnityObjectToClipPos(i.pos);
                o.uv = i.uv;

                return o;
            }

            float4 frag(v2f v) : SV_TARGET
            {
                fixed4 fragColor = 1;

                float frame = (_Time.y * 1000 / _Frametime) % _Framecount;
                float column = floor(frame % _Columns);
                float row = _Rows - 1 - floor(frame / _Columns);
                float width = 1.0 / _Columns;
                float height = 1.0 / _Rows;

                float2 uv = float2((v.uv.x + column) * width, (v.uv.y + row) * height);
                fragColor = tex2D(_atlas, uv);

                return fragColor;
            }

            ENDCG
        }
    }
}