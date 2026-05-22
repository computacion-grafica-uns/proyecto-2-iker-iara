Shader "BlinPhong"
{
    Properties
    {
    //Parametros del shader
    _MainTex ("ALbedo", 2D) = "white" {}
    _Kd("Kd", Color) = (1,1,1,1)
    _Ks("Ks", Color) = (1,1,1,1)
    _Ka("Ka", Color) = (0.1, 0.1, 0.1, 1)

    _Ia("Ia", Color) = (1,1,1,1)
    _Ip("Ip", Color) = (1,1,1,1)

    //_LightPosition("Light  Position", ) = () //posicion de luz .
    _Shininess("Shininess",          Range(1, 256)) = 32
    _SpecStrength ("Specular Strength",  Range(0, 2))   = 1
    _NormalMap("Normal Map", 2D) = "white" {}
    _NormalStrenght("Normal Strenght", Range(0,1)) = 1
    }
    SubShader
    {
        Tags{"RenderType" = "Opaque" }
        Pass
        {
            Tags { "LightMode" = "ForwardBase" }
            CGPROGRAM
            // declaramos que la función llamada "vert" definirá el shader de vértices
            #pragma vertex vert
            // declaramos que la función llamada "frag" definirá el shader de fragmentos
            #pragma fragment frag


            #include "UnityCG.cginc"
            #include "UnityLightingCommon.cginc"

            sampler2D _MainTex;
            float4 _MainTex_ST;
            fixed4 _Ks;
            fixed4 _Kd;
            fixed4 _Ka;

            fixed4 _Ia;
            fixed4 _Ip;

            float _Shininess;
            float _SpecStrength;
            sampler2D _NormalMap;
            float _NormalStrenght;

            //datos de cada vértice
            struct appdata {
                float4 vertex : POSITION; //posicion del vertice del objeto
                float3 normal : NORMAL; //normales del modelo
                float2 uv : TEXCOORD0; //coordenadas uv
            };

            //datos que pasaremos del shader de vértices al de fragmentos
            struct v2f {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
                float3 worldNorm  : TEXCOORD2;
            };
            // shader de vértices
            v2f vert(appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.worldNorm = UnityObjectToWorldNormal(v.normal);
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                fixed4 normalmap = tex2D(_NormalMap, i.uv);
                normalmap = normalmap * _NormalStrenght;

                //calculamos todos los vectores a utilizar
                float3 N = normalize(i.worldNorm + normalmap.xyz);
                float3 L = normalize(_WorldSpaceLightPos0.xyz);
                float3 V = normalize(_WorldSpaceCameraPos - i.worldPos);
                float3 H = normalize(L + V);

                //calculamos ambient difusse etc..
                fixed4 albedo = tex2D(_MainTex, i.uv); 
                
                fixed3 ambient = _Ka.rgb * _Ia;

                float  NdotL   = saturate(dot(N, L));

                fixed3 diffuse = _Ip * _Kd.rgb * NdotL * albedo.rgb;

                float  NdotH    = saturate(dot(N, H));
                float  specTerm = pow(NdotH, _Shininess);
                fixed3 specular = _Ks * _Ip * specTerm;

                fixed3 color = ambient + diffuse + specular;
                return fixed4(color, albedo.a);
            }
            ENDCG
        }
    }

    Fallback "Diffuse"
}