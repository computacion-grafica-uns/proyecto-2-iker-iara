Shader "ToonShader_Transp"
{
    Properties
    {
        _BaseColor ("Base Color", Color) = (0.8, 0.1, 0.1, 1)
        _AmbientColor ("Ambient Color", Color) = (0.2, 0.0, 0.0, 1)
        _SpecColor2 ("Specular Color", Color) = (1, 0.7, 0.8, 1)
        _Shininess ("Shininess", Range(1, 200)) = 120
        _OutlineColor("Outline color", Color) = (0, 0, 0, 1)
        _OutlineWidth("Grosor del borde", Range(0,0.5)) = 0.1
        _StripeScale ("Stripe Scale",  Range(0,0.5)) = 0.5
        _StripeWidth ("Stripe Width",  Range(0, 1))   = 0.5
        _StripeAngle ("Stripe Angle",  Range(0, 6.28)) = 0.785
        _SpecHalftoneScale ("Spec Halftone Scale", Range(0.001, 0.1)) = 0.1
        _SpecHalftoneIntensity ("Spec Halftone Intensity", Range(0, 1)) = 0.4
        _Alpha ("Alpha", Range(0,1)) = 1
    }

    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" }

        // Outline pass
        Pass
        {
            Cull Front
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct appdata {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct v2f {
                float4 pos : SV_POSITION;
            };

            fixed4 _OutlineColor;
            float  _OutlineWidth;
            float  _Alpha;

            v2f vert(appdata v) {
                v2f o;
                float4 inflated = v.vertex + float4(v.normal * _OutlineWidth, 0);
                o.pos = UnityObjectToClipPos(inflated);
                return o;
            }

            fixed4 frag(v2f i) : SV_Target {
                return fixed4(_OutlineColor.rgb, _Alpha);
            }
            ENDCG
        }

        // Main shading pass
        Pass
        {
            Tags { "LightMode"="ForwardBase" }
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            #include "Assets/ShaderInspector/ShaderInspector.cginc"

            struct appdata {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv     : TEXCOORD0;
            };

            struct v2f {
                float4 pos         : SV_POSITION;
                float3 worldNormal : TEXCOORD0;
                float3 worldPos    : TEXCOORD1;
                float2 uv          : TEXCOORD2;
                float4 screenPos   : TEXCOORD3;
            };

            fixed4 _BaseColor, _AmbientColor, _SpecColor2;
            float  _Shininess, _StripeAngle, _StripeScale, _StripeWidth;
            float  _SpecHalftoneIntensity, _SpecHalftoneScale, _Alpha;

            #define MAX_LIGHTS 20
            float4 _L_Position[MAX_LIGHTS];
            float4 _L_Forward[MAX_LIGHTS];
            float4 _L_Color[MAX_LIGHTS];
            float  _L_Intensity[MAX_LIGHTS];
            float  _L_Type[MAX_LIGHTS];
            float  _L_ConeCosine[MAX_LIGHTS];
            float  _L_ConeFalloff[MAX_LIGHTS];
            float  _L_Count;

            v2f vert(appdata v) {
                v2f o;
                o.pos         = UnityObjectToClipPos(v.vertex);
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.worldPos    = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.uv          = v.uv;
                o.screenPos   = ComputeScreenPos(o.pos);
                return o;
            }

            float stripes(float2 coord, float angle, float scale, float width) {
                float2 dir = float2(cos(angle), sin(angle));
                float t = dot(coord, dir) * scale;
                return step(frac(t), width);
            }

            float halftone(float2 coord, float intensity, float scale) {
                float2 grid = frac(coord * scale) - 0.5;
                float dist = length(grid);
                float radius = sqrt(1.0 - intensity) * 0.5;
                return step(dist, radius);
            }

            FragOut frag(v2f i) : SV_Target {
                DEBUGGABLE;
                float3 n = normalize(i.worldNormal);
                float3 v = normalize(_WorldSpaceCameraPos - i.worldPos);
                float2 screenUV = i.screenPos.xy / i.screenPos.w * _ScreenParams.xy;

                float totalNdotL = 0;
                float totalSpec  = 0;

                for (int j = 0; j < _L_Count; j++) {
                    float coneL = 1.0;
                    float3 l;

                    if (_L_Type[j] == 1) {
                        l = normalize(_L_Forward[j].xyz);
                    } else {
                        l = normalize(_L_Position[j].xyz - i.worldPos);
                        if (_L_Type[j] == 2) {
                            coneL = pow(saturate((_L_ConeCosine[j] - dot(_L_Forward[j].xyz, l)) / (_L_ConeCosine[j] - 1)), _L_ConeFalloff[j]);
                        }
                    }

                    float3 h    = normalize(l + v);
                    float NdotL = saturate(dot(n, l));
                    float NdotH = saturate(dot(n, h));

                    totalNdotL += NdotL * _L_Intensity[j] * coneL;
                    totalSpec  += pow(NdotH, _Shininess) * _L_Intensity[j] * coneL;
                }

                float diffBand  = floor(saturate(totalNdotL) * 3.0) / 3.0;
                float specBand  = step(0.8, totalSpec);

                float coreShadow   = 1.0 - step(0.01, diffBand);
                float stripeMask   = stripes(screenUV, _StripeAngle, _StripeScale, _StripeWidth);
                float specHalftone = halftone(screenUV, _SpecHalftoneIntensity, _SpecHalftoneScale);
                float specMask     = specBand * specHalftone;
                float shadowStripes = coreShadow * stripeMask;

                float3 ambient  = _AmbientColor.rgb;
                float3 diffuse  = _BaseColor.rgb * diffBand;
                float3 specular = _SpecColor2.rgb * specMask;
                float3 final    = ambient + diffuse + specular;
                final = lerp(final, _BaseColor.rgb * 0.4, shadowStripes);

                ret(fixed4(final, _Alpha));
            }
            ENDCG
        }
    }
}
