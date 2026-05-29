Shader "BlinnPhong-BARRO"
{
    Properties
    {
        _MainTex ("Albedo", 2D) = "white" {}
        _Kd("Kd", Color) = (1,1,1,1)
        _Ks("Ks", Color) = (1,1,1,1)
        _Ka("Ka", Color) = (0.1, 0.1, 0.1, 1)
        _Shininess("Shininess", Range(1, 256)) = 32
        _SpecStrength("Specular Strength", Range(0, 2)) = 1
        _NormalMap("Normal Map", 2D) = "white" {}
        _NormalStrenght("Normal Strenght", Range(0,1)) = 1
    }
    SubShader
    {
        Tags { "RenderType" = "Opaque" }
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            sampler2D _MainTex;
            float4 _MainTex_ST;
            fixed4 _Ks;
            fixed4 _Kd;
            fixed4 _Ka;
            float _Shininess;
            float _SpecStrength;
            sampler2D _NormalMap;
            float _NormalStrenght;

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

            struct appdata {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct v2f {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
                float3 worldNorm : TEXCOORD2;
            };

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
                // Tangentless TBN from screen-space derivatives (Schüler 2009)
                float3 dPdx = ddx(i.worldPos);
                float3 dPdy = ddy(i.worldPos);
                float2 dUdx = ddx(i.uv);
                float2 dUdy = ddy(i.uv);
                float3 T = normalize( dPdx * dUdy.y - dPdy * dUdx.y);
                float3 B = normalize(-dPdx * dUdy.x + dPdy * dUdx.x);
                float3 Ng = normalize(i.worldNorm);
                float3x3 TBN = transpose(float3x3(T, B, Ng));
                float3 normalTS = UnpackNormal(tex2D(_NormalMap, i.uv));
                normalTS.xy *= _NormalStrenght;
                float3 N = normalize(mul(TBN, normalTS));
                float3 V = normalize(_WorldSpaceCameraPos - i.worldPos);

                fixed4 albedo = tex2D(_MainTex, i.uv);
                fixed3 accumulated = 0;

                for (int j = 0; j < _L_Count; j++)
                {
                    float coneL  = 1;
                    float L_dist = length(_L_Position[j].xyz - i.worldPos);
                    float3 L     = normalize(_L_Position[j].xyz - i.worldPos);

                    if (_L_Type[j] == 1) // Directional
                    {
                        L_dist = 0;
                        L      = normalize(_L_Forward[j].xyz);
                    }
                    else if (_L_Type[j] == 2) // Spot
                    {
                        coneL = pow(saturate((_L_ConeCosine[j] - dot(_L_Forward[j].xyz, L)) / (_L_ConeCosine[j] - 1)), _L_ConeFalloff[j]);
                    }

                    float3 H    = normalize(L + V);
                    float NdotL = saturate(dot(N, L));
                    float NdotH = saturate(dot(N, H));

                    fixed3 diffuse  = _Kd.rgb * NdotL * albedo.rgb * coneL;
                    fixed3 specular = _Ks.rgb * _SpecStrength * pow(NdotH, _Shininess) * coneL;

                    float atten = 1.0 / pow(1 + L_dist, _L_Attenuation[j]);
                    accumulated += (diffuse + specular) * _L_Color[j].rgb * _L_Intensity[j] * atten;
                }

                fixed3 color = _Ka.rgb + accumulated;
                return fixed4(color, albedo.a);
            }
            ENDCG
        }
    }

    Fallback "Diffuse"
}
