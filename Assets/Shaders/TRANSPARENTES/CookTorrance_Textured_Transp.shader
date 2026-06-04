Shader "CookTorrance_Textured_Transp"
{
    Properties
    {
        [NoScaleOffset] _Albedo("Diffuse map", 2D) = "white" {}
        _a_coeff("Transparency coeff", Float) = 1
        _r("Roughness", Range(0,1)) = 1
        _F_0("Reflectance", Color) = (1,1,1,1)
        _FresnelStrength("Fresnel Strength", Range(0,1)) = 1
        [NoScaleOffset] _N_tex("Normal map", 2D) = "bump" {}
        _N_coeff("Normal coefficient", Float) = 1
    }

    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" }
        LOD 200
        ZWrite Off // Often necessary to stop objects hiding behind it
        Blend SrcAlpha OneMinusSrcAlpha
        
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

            float _n, _r, _N_coeff, _a_coeff, _FresnelStrength;
            float4 _k_a, _F_0;
            sampler2D _Albedo, _N_tex;

            // Lights
            #define MAX_LIGHTS 20
            float4 _L_Position[MAX_LIGHTS];
            float4 _L_Forward[MAX_LIGHTS];
            float4 _L_Color[MAX_LIGHTS];
            float _L_Intensity[MAX_LIGHTS];
            float _L_Type[MAX_LIGHTS];
            float _L_ConeCosine[MAX_LIGHTS];
            float _L_ConeFalloff[MAX_LIGHTS];
            float _L_Attenuation[MAX_LIGHTS];
            float _L_Count;

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

            FragOut frag(v2f v) : SV_Target
            {
                DEBUGGABLE;
                float4 fragColor = float4(0,0,0,1);
                float3 outgoing_radiance = float3(0,0,0);

                float4 albedo = tex2D(_Albedo, v.uv);
                float3 normal_map = lerp(float3(0,0,1), UnpackNormal(tex2D(_N_tex, v.uv)), _N_coeff);

                float3x3 TBN = transpose(float3x3(v.tangent_versor, v.bitangent_versor, v.normal_versor));
                
                float3 N_versor = normalize(mul(TBN, normal_map));
                float3 V_versor =  normalize(_WorldSpaceCameraPos - v.world_pos);
                float NV = dot(N_versor, V_versor);

                float alpha = _r * _r;

                float4 fresnel = _F_0 + (float4(1,1,1,1) - _F_0) * pow(1 - NV, 5.0);
                float4 fresnel_glass = float4(0.04, 0.04, 0.04, 1) + (float4(1,1,1,1) - float4(0.04, 0.04, 0.04, 1)) * pow(1 - NV, 5.0);

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
                    
                    float ndf = alpha * alpha / (UNITY_PI * pow((NH*NH * (alpha*alpha - 1) + 1), 2.0));
                    float gv  = 2 * NH * NV / VH;
                    float gl  = 2 * NH * NL / VH;
                    float geo = min(1, min(gl, gv));

                    float3 brdf_diffuse  = albedo.rgb;
                    float3 brdf_specular = fresnel * ndf * geo / (4 * NL * NV);
                    float3 total_brdf    = saturate((1 - fresnel) * brdf_diffuse + fresnel * brdf_specular);

                    float3 incident_radiance = L_cone * L_color * L_intensity / pow(1 + L_dist, L_attenuation);

                    outgoing_radiance += max(total_brdf * incident_radiance * saturate(NL), 0);

                    if (floor(_Time.y % _L_Count) == i) // Only show the first 3 lights in the inspector to avoid clutter
                    {
                        insp3(1, brdf_diffuse);
                        insp3(2, brdf_specular);
                        insp3(3, total_brdf);
                    }
                }
                
                float3 ambient  = _k_a.rgb * albedo;
                fragColor = float4(ambient + outgoing_radiance, saturate(max(albedo.a / _a_coeff, fresnel_glass.r * _FresnelStrength)));

                ret(fragColor);
            }

            ENDCG
        }
    }
}