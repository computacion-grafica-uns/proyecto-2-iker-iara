Shader "CookTorrance_Textured"
{
    Properties
    {
        [NoScaleOffset] _k_d_tex("Diffuse map", 2D) = "white" {}
        _k_d_coeff("Diffuse coefficient", Float) = 1
        [NoScaleOffset] _k_s_tex("Roughness map", 2D) = "white" {}
        _k_s_coeff("Roughness map coefficient", Range(0,1)) = 1
        _rp("Roughness RMS", Range(0,1)) = 1
        _F_0("Reflectance", Color) = (1,1,1,1)
        [MaterialToggle] _FlipRoughness("Is this a roughness map instead of a specular map?", Float) = 1
        [NoScaleOffset] _N_tex("Normal map", 2D) = "bump" {}
        _N_coeff("Normal coefficient", Float) = 1
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

            float _n, _k_d_coeff, _k_s_coeff, _rp, _N_coeff, _FlipRoughness;
            float4 _k_a, _F_0;
            sampler2D _k_d_tex, _k_s_tex, _N_tex;

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
                fixed4 fragColor = 1;
                fixed4 brdf = 0;

                float4 _k_d = tex2D(_k_d_tex, v.uv);
                float4 _k_s = pow(_FlipRoughness + (-2 * _FlipRoughness + 1) * tex2D(_k_s_tex, v.uv), 2);
                float3 normal_map = lerp(float3(0,0,1), UnpackNormal(tex2D(_N_tex, v.uv)), _N_coeff);

                float3x3 TBN = transpose(float3x3(v.tangent_versor, v.bitangent_versor, v.normal_versor));
                
                float3 N_versor = normalize(mul(TBN, normal_map));
                float3 V_versor =  normalize(_WorldSpaceCameraPos - v.world_pos);
                float NV = dot(N_versor, V_versor);

                float rp = _rp;
                float alpha = rp * rp;

                float4 fresnel = _F_0 + (float4(1,1,1,1) - _F_0) * pow(1 - NV, 5.0);

                insp4(1, _k_d);
                inspf(2, alpha);
                insp3(3, N_versor);
                insp3(4, normal_map);
                insp3(5, _F_0.rgb);

                for (int i = 0; i < _L_Count; i++)
                {
                    // Default for point light
                    float coneL = 1;
                    float L_dist = length(_L_Position[i].xyz - v.world_pos);
                    float3 L_versor = normalize(_L_Position[i].xyz - v.world_pos);
                    float3 H_versor = normalize((L_versor + V_versor) / length(L_versor + V_versor));

                    float NL = dot(N_versor, L_versor);
                    float NH = dot(N_versor, H_versor);
                    float VH = dot(V_versor, H_versor);
                    
                    if (_L_Type[i] == 1) // Directional light
                    {
                        L_dist = 0;
                        L_versor = normalize(_L_Forward[i].xyz);
                        H_versor = normalize((L_versor + V_versor) / length(L_versor + V_versor));
                        NL = dot(N_versor, L_versor);
                        NH = dot(N_versor, H_versor);
                    }
                    else if (_L_Type[i] == 2) // Spot light
                    {
                        coneL = pow(saturate((_L_ConeCosine[i] - dot(_L_Forward[i].xyz, L_versor)) / (_L_ConeCosine[i] - 1)), _L_ConeFalloff[i]);
                    }
                    
                    float ndf = alpha * alpha / (UNITY_PI * pow((NH*NH * (alpha*alpha - 1) + 1), 2.0));
                    float gv = 2 * NH * NV / VH;
                    float gl = 2 * NH * NL / VH;
                    float geo = min(1, min(gl, gv));

                    float4 diffuse  = _k_d * _k_d_coeff;
                    float4 specular = fresnel * ndf * geo / (4 * NL * NV) * length(_k_s.rbg) * _k_s_coeff;
                    specular.a = 1;

                    brdf += saturate(diffuse + specular) * coneL * _L_Color[i] * _L_Intensity[i] / pow(1 + L_dist, _L_Attenuation[i]) * saturate(NL);
                }

                float4 ambient  = _k_d * _k_a;
                fragColor = ambient + brdf;

                insp3(6, N_versor);

                ret(fragColor);
            }

            ENDCG
        }
    }
}