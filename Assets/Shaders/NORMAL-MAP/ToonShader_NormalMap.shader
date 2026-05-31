Shader "ToonShader_NormalMap"
{
    Properties
    {
        _NormalMap             ("Normal Map",            2D)           = "bump" {}
        _NormalStrength        ("Normal Strength",       Range(0, 2))  = 1.0
        _BaseColor             ("Base Color",            Color)        = (0.8, 0.1, 0.1, 1)
        _AmbientColor          ("Ambient Color",         Color)        = (0.2, 0.0, 0.0, 1)
        _SpecColor2            ("Specular Color",        Color)        = (1, 0.7, 0.8, 1)
        _Shininess             ("Shininess",             Range(1, 200)) = 40
        _OutlineColor          ("Outline Color",         Color)        = (0, 0, 0, 1)
        _OutlineWidth          ("Outline Width",         Range(0, 0.5)) = 0.1
        _StripeScale           ("Stripe Scale",          Range(0, 0.5)) = 0.5
        _StripeWidth           ("Stripe Width",          Range(0, 1))   = 0.5
        _StripeAngle           ("Stripe Angle",          Range(0, 6.28)) = 0.785
        _SpecHalftoneScale     ("Spec Halftone Scale",   Range(0.001, 0.1)) = 0.1
        _SpecHalftoneIntensity ("Spec Halftone Intensity", Range(0, 1)) = 0.4
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" }

        // Outline pass — no normal map needed here
        Pass
        {
            Cull Front
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

            v2f vert(appdata v) {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex + float4(v.normal * _OutlineWidth, 0));
                return o;
            }
            fixed4 frag(v2f i) : SV_Target {
                return _OutlineColor;
            }
            ENDCG
        }

        // Main shading pass
        Pass
        {
            Tags { "LightMode"="ForwardBase" }
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            #include "Assets/ShaderInspector/ShaderInspector.cginc"

            struct appdata {
                float4 vertex  : POSITION;
                float3 normal  : NORMAL;
                float4 tangent : TANGENT;
                float2 uv      : TEXCOORD0;
            };

            struct v2f {
                float4 pos              : SV_POSITION;
                float3 worldPos         : TEXCOORD0;
                float2 uv               : TEXCOORD1;
                float4 screenPos        : TEXCOORD2;
                float3 normal_versor    : TEXCOORD3;
                float3 tangent_versor   : TEXCOORD4;
                float3 bitangent_versor : TEXCOORD5;
            };

            sampler2D _NormalMap;
            float     _NormalStrength;
            fixed4    _BaseColor, _AmbientColor, _SpecColor2;
            float     _Shininess, _StripeAngle, _StripeScale, _StripeWidth;
            float     _SpecHalftoneIntensity, _SpecHalftoneScale;

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
                float4 worldPos4    = mul(unity_ObjectToWorld, v.vertex);
                o.pos               = mul(UNITY_MATRIX_VP, worldPos4);
                o.worldPos          = worldPos4.xyz;
                o.uv                = v.uv;
                o.screenPos         = ComputeScreenPos(o.pos);
                o.normal_versor     = UnityObjectToWorldNormal(v.normal);
                o.tangent_versor    = UnityObjectToWorldDir(v.tangent.xyz);
                o.bitangent_versor  = cross(o.tangent_versor, o.normal_versor) * (v.tangent.w * unity_WorldTransformParams.w);
                return o;
            }

            float stripes(float2 coord, float angle, float scale, float width) {
                float2 dir = float2(cos(angle), sin(angle));
                return step(frac(dot(coord, dir) * scale), width);
            }

            float halftone(float2 coord, float intensity, float scale) {
                float2 grid = frac(coord * scale) - 0.5;
                return step(length(grid), sqrt(1.0 - intensity) * 0.5);
            }

            FragOut frag(v2f i) : SV_Target {
                DEBUGGABLE;

                // TBN matrix — tangent space to world space
                float3 T = normalize(i.tangent_versor);
                float3 B = normalize(i.bitangent_versor);
                float3 N = normalize(i.normal_versor);
                float3x3 TBN = transpose(float3x3(-T, -B, N));

                float3 normalTS  = UnpackNormal(tex2D(_NormalMap, i.uv));
                normalTS.xy     *= _NormalStrength;
                float3 n         = normalize(mul(TBN, normalTS));

                float3 v         = normalize(_WorldSpaceCameraPos - i.worldPos);
                float2 screenUV  = i.screenPos.xy / i.screenPos.w * _ScreenParams.xy;

                float totalNdotL = 0;
                float totalSpec  = 0;

                for (int j = 0; j < _L_Count; j++) {
                    float coneL = 1.0;
                    float3 l;

                    if (_L_Type[j] == 1) {
                        l = normalize(_L_Forward[j].xyz);
                    } else {
                        l = normalize(_L_Position[j].xyz - i.worldPos);
                        if (_L_Type[j] == 2)
                            coneL = pow(saturate((_L_ConeCosine[j] - dot(_L_Forward[j].xyz, l)) / (_L_ConeCosine[j] - 1)), _L_ConeFalloff[j]);
                    }

                    float3 h    = normalize(l + v);
                    float NdotL = saturate(dot(n, l));
                    float NdotH = saturate(dot(n, h));

                    totalNdotL += NdotL * _L_Intensity[j] * coneL;
                    totalSpec  += pow(NdotH, _Shininess) * _L_Intensity[j] * coneL;
                }

                float diffBand      = floor(saturate(totalNdotL) * 3.0) / 3.0;
                float specBand      = step(0.5, totalSpec);
                float coreShadow    = 1.0 - step(0.01, diffBand);
                float shadowStripes = coreShadow * stripes(screenUV, _StripeAngle, _StripeScale, _StripeWidth);
                float specMask      = specBand * halftone(screenUV, _SpecHalftoneIntensity, _SpecHalftoneScale);

                float3 final = _AmbientColor.rgb
                             + _BaseColor.rgb  * diffBand
                             + _SpecColor2.rgb * specMask;
                final = lerp(final, _BaseColor.rgb * 0.4, shadowStripes);

                ret(fixed4(final, 1));
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}
