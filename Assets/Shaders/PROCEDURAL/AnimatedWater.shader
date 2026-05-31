Shader "Custom/AnimatedWater"
{
    Properties
    {
        [Header(Colors)]
        _DeepColor      ("Deep Color",      Color) = (0.0,  0.15, 0.30, 1)
        _ShallowColor   ("Shallow Color",   Color) = (0.1,  0.50, 0.60, 1)
        _FoamColor      ("Foam Color",      Color) = (0.9,  0.95, 1.0,  1)

        [Header(Waves)]
        _WaveScale      ("Wave Scale",      Float)       = 3.0
        _WaveSpeed      ("Wave Speed",      Float)       = 0.5
        _WaveStrength   ("Wave Height",     Range(0.1, 10)) = 3.0
        _WaveOctaves    ("Wave Octaves",    Range(1, 6)) = 4
        _FoamThreshold  ("Foam Threshold",  Range(0, 1)) = 0.7

        [Header(Lighting)]
        _SpecColor2     ("Specular Color",  Color)       = (1, 1, 1, 1)
        _Shininess      ("Shininess",       Range(1, 512)) = 200
        _FresnelPower   ("Fresnel Power",   Range(1, 10)) = 4
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" }

        Pass
        {
            Tags { "LightMode"="ForwardBase" }
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            #include "Assets/ShaderInspector/ShaderInspector.cginc"

            float4 _DeepColor, _ShallowColor, _FoamColor, _SpecColor2;
            float  _WaveScale, _WaveSpeed, _WaveStrength, _WaveOctaves;
            float  _FoamThreshold, _Shininess, _FresnelPower;

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
                float4 pos     : POSITION;
                float3 normal  : NORMAL;
                float4 tangent : TANGENT;
                float2 uv      : TEXCOORD0;
            };

            struct v2f {
                float4 pos              : SV_POSITION;
                float4 world_pos        : TEXCOORD0;
                float3 normal_versor    : TEXCOORD1;
                float3 tangent_versor   : TEXCOORD2;
                float3 bitangent_versor : TEXCOORD3;
                float2 uv               : TEXCOORD4;
            };

            v2f vert(appdata i) {
                v2f o;
                o.world_pos        = mul(UNITY_MATRIX_M, i.pos);
                o.pos              = mul(UNITY_MATRIX_P, mul(UNITY_MATRIX_V, o.world_pos));
                o.normal_versor    = UnityObjectToWorldNormal(i.normal);
                o.tangent_versor   = UnityObjectToWorldDir(i.tangent.xyz);
                o.bitangent_versor = cross(o.tangent_versor, o.normal_versor) * (i.tangent.w * unity_WorldTransformParams.w);
                o.uv               = i.uv;
                return o;
            }

            // ---- Noise ----
            float hash(float2 p) {
                p = frac(p * float2(127.1, 311.7));
                p += dot(p, p + 19.19);
                return frac(p.x * p.y);
            }

            float valueNoise(float2 p) {
                float2 i = floor(p);
                float2 f = frac(p);
                float2 u = f * f * (3.0 - 2.0 * f);
                return lerp(
                    lerp(hash(i),               hash(i + float2(1,0)), u.x),
                    lerp(hash(i + float2(0,1)), hash(i + float2(1,1)), u.x),
                    u.y);
            }

            float fbm(float2 p) {
                float v = 0.0, a = 0.5;
                int oct = (int)_WaveOctaves;
                [unroll(6)]
                for (int k = 0; k < 6; k++) {
                    if (k >= oct) break;
                    v += a * valueNoise(p);
                    p *= 2.0; a *= 0.5;
                }
                return v;
            }

            // Two fbm layers scrolling in different directions
            float waveHeight(float2 uv) {
                float2 uv1 = uv * _WaveScale + float2( _Time.y * _WaveSpeed,        _Time.y * _WaveSpeed * 0.6);
                float2 uv2 = uv * _WaveScale * 1.4 + float2(-_Time.y * _WaveSpeed * 0.7, _Time.y * _WaveSpeed * 0.4);
                return (fbm(uv1) + fbm(uv2)) * 0.5;
            }

            FragOut frag(v2f v) : SV_Target {
                DEBUGGABLE;

                float2 uv = v.uv;

                // Sample height field at three points to derive a tangent-space normal
                float eps = 0.005;
                float h   = waveHeight(uv);
                float hx  = waveHeight(uv + float2(eps, 0.0));
                float hy  = waveHeight(uv + float2(0.0, eps));

                float3 n_tangent = normalize(float3(
                    (h - hx) * _WaveStrength,
                    eps,
                    (h - hy) * _WaveStrength
                ));

                // Tangent-space → world-space
                float3 T = normalize(v.tangent_versor);
                float3 B = normalize(v.bitangent_versor);
                float3 N = normalize(v.normal_versor);
                float3x3 TBN    = transpose(float3x3(T, B, N));
                float3 N_versor = normalize(mul(TBN, n_tangent));

                float3 V_versor = normalize(_WorldSpaceCameraPos - v.world_pos.xyz);
                float  NV       = saturate(dot(N_versor, V_versor));

                // Fresnel rim
                float fresnel = pow(1.0 - NV, _FresnelPower);

                // Water color: deep → shallow blended by height, foam on peaks
                float  foamMask   = smoothstep(_FoamThreshold, 1.0, h);
                float3 waterColor = lerp(_DeepColor.rgb, _ShallowColor.rgb, h);
                waterColor        = lerp(waterColor, _FoamColor.rgb, foamMask);
                waterColor        = lerp(waterColor, _ShallowColor.rgb, fresnel * 0.5);

                // Multi-light Blinn-Phong
                float3 totalDiffuse  = float3(0, 0, 0);
                float3 totalSpecular = float3(0, 0, 0);

                for (int i = 0; i < _L_Count; i++) {
                    float  coneL    = 1;
                    float  L_dist   = length(_L_Position[i].xyz - v.world_pos.xyz);
                    float3 L_versor = normalize(_L_Position[i].xyz - v.world_pos.xyz);
                    float3 H_versor = normalize(L_versor + V_versor);

                    float NL = saturate(dot(N_versor, L_versor));
                    float NH = saturate(dot(N_versor, H_versor));

                    if (_L_Type[i] == 1) {
                        L_dist   = 0;
                        L_versor = normalize(_L_Forward[i].xyz);
                        H_versor = normalize(L_versor + V_versor);
                        NL = saturate(dot(N_versor, L_versor));
                        NH = saturate(dot(N_versor, H_versor));
                    }
                    else if (_L_Type[i] == 2) {
                        coneL = pow(saturate((_L_ConeCosine[i] - dot(_L_Forward[i].xyz, L_versor)) / (_L_ConeCosine[i] - 1)), _L_ConeFalloff[i]);
                    }

                    float3 lightColor = _L_Color[i].rgb * _L_Intensity[i] * coneL / pow(1 + L_dist, _L_Attenuation[i]);

                    totalDiffuse  += waterColor * NL * lightColor;
                    totalSpecular += _SpecColor2.rgb * pow(NH, _Shininess) * NL * lightColor;
                }

                float3 ambient = waterColor * 0.15;
                ret(float4(ambient + totalDiffuse + totalSpecular, 1));
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}
