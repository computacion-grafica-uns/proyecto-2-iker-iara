Shader "CookTorrance_Anisotropic_GGX"
{
    Properties
    {
        _Diffuse("Diffuse", Color) = (0,0,0,1)
        _Reflectance("Reflectance 'F_0'", Color) = (0,0,0,1)
        _Roughness("Roughness", Range(0,1)) = 0.2
        _Aniso("Anisotropy", Range(-1,1)) = 0
        [NoScaleOffset] _TangentMap("Tangent map", 2D) = "bump" {}
        [NoScaleOffset] _NormalMap("Normal map", 2D) = "bump" {}
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
        
            float _Roughness, _Aniso;
            float4 _Reflectance, _Diffuse;
            sampler2D _TangentMap, _NormalMap;

            // Lights
            #define MAX_LIGHTS 20
            float4 _k_a;
            float4 _L_Position[MAX_LIGHTS];
            float4 _L_Forward[MAX_LIGHTS];
            float4 _L_Color[MAX_LIGHTS];
            float _L_Intensity[MAX_LIGHTS];
            float _L_Type[MAX_LIGHTS];
            float _L_ConeCosine[MAX_LIGHTS];
            float _L_ConeFalloff[MAX_LIGHTS];
            float _L_Attenuation[MAX_LIGHTS];
            float _L_Count;

            FragOut frag(v2f v) : SV_Target
            {
                DEBUGGABLE;
                float4 fragColor = float4(0,0,0,1);
                float3 outgoing_radiance = float3(0,0,0);

                float4 albedo  = _Diffuse;
                float3 normal  = UnpackNormal(tex2D(_NormalMap, v.uv)).rgb;
                float3 tangent = UnpackNormal(tex2D(_TangentMap, v.uv)).rgb;

                float3 reflectivity = _Reflectance.rgb;

                // Bring normal map from tangent space to world space
                // float3 T = normalize(v.tangent_versor);
                // float3 B = normalize(v.bitangent_versor);
                // float3 N = normalize(v.normal_versor);
                // float3x3 TBN = transpose(float3x3(T, B, N));

                // float3 N_versor = normalize(mul(TBN, normal));

                float3 N_versor = normalize(v.normal_versor);
                float3 Y_versor = UnityObjectToWorldNormal(float3(0.1,1,0));
                float3 X_versor = normalize(cross(Y_versor, N_versor));
                Y_versor = normalize(cross(N_versor, X_versor));
                
                float3x3 TBN = transpose(float3x3(X_versor, Y_versor, N_versor));
                X_versor = normalize(mul(TBN, tangent));
                Y_versor = normalize(cross(N_versor, X_versor));
                X_versor = normalize(cross(N_versor, Y_versor));

                float3 V_versor =  normalize(_WorldSpaceCameraPos - v.world_pos.xyz);
                float NV = dot(N_versor, V_versor);

                float alpha = _Roughness * _Roughness;
                float alpha_u = _Roughness * (1 + _Aniso);
                float alpha_v = _Roughness * (1 - _Aniso);
                float alpha_u2 = alpha_u*alpha_u;
                float alpha_v2 = alpha_v*alpha_v;

                float3 fresnel = reflectivity + (float3(1,1,1) - reflectivity) * pow(1 - NV, 5.0);

                // Debug
                insp4(1, albedo);
                insp2(2, float2(alpha_u, alpha_v));
                insp3(3, N_versor);
                insp3(4, normal);
                insp3(5, reflectivity);

                for (int i = 0; i < _L_Count; i++)
                {
                    // Grab the values for the current light
                    float3 L_pos         = _L_Position[i].xyz;
                    float3 L_color       = _L_Color[i].rgb;
                    float3 L_forward     = _L_Forward[i].xyz;
                    float  L_coneCosine  = _L_ConeCosine[i];
                    float  L_coneFalloff = _L_ConeFalloff[i];
                    float  L_intensity   = _L_Intensity[i];
                    float  L_attenuation = _L_Attenuation[i];

                    // Default for point light
                    float L_cone = 1;
                    float L_dist = length(L_pos - v.world_pos.xyz);
                    float3 L_versor = normalize(L_pos - v.world_pos.xyz);
                    float3 H_versor = normalize((L_versor + V_versor) / length(L_versor + V_versor));

                    float NL = dot(N_versor, L_versor);
                    float NH = dot(N_versor, H_versor);
                    float VH = dot(V_versor, H_versor);
                    float HX = dot(H_versor, X_versor);
                    float HY = dot(H_versor, Y_versor);
                    float HN = dot(H_versor, N_versor);
                    
                    if (_L_Type[i] == 1) // Directional light
                    {
                        L_dist = 0;
                        L_versor = normalize(L_forward);
                        H_versor = normalize((L_versor + V_versor) / length(L_versor + V_versor));
                        NL = dot(N_versor, L_versor);
                        NH = dot(N_versor, H_versor);
                    }
                    else if (_L_Type[i] == 2) // Spot light
                    {
                        L_cone = pow(saturate((L_coneCosine - dot(L_forward, L_versor)) / (L_coneCosine - 1)), L_coneFalloff);
                    }
                    
                    //float ndf = alpha * alpha / (UNITY_PI * pow((NH*NH * (alpha*alpha - 1) + 1), 2.0));
                    float ndf = 1 / (UNITY_PI * alpha_u * alpha_v * pow(HX*HX/alpha_u2 + HY*HY/alpha_v2 + HN*HN, 2.0));
                    float gv  = 2 * NH * NV / VH;
                    float gl  = 2 * NH * NL / VH;
                    float geo = min(1, min(gl, gv));

                    float3 brdf_diffuse  = albedo.rgb * (1 - reflectivity.rgb);
                    float3 brdf_specular = fresnel * ndf * geo / (4 * NL * NV);
                    float3 total_brdf    = saturate((1 - fresnel) * brdf_diffuse + fresnel * brdf_specular);

                    float3 incident_radiance = L_cone * L_color * L_intensity / pow(1 + L_dist, L_attenuation);

                    outgoing_radiance += max(total_brdf * incident_radiance * saturate(NL), 0);
                }

                float3 ambient  = _k_a.rgb * albedo;
                fragColor = float4(ambient + outgoing_radiance, 1);

                ret(fragColor);
            }
            ENDCG
        }
    }
}