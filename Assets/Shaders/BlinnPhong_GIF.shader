Shader "BlinnPhong_GIF"
{
    Properties
    {
        [NoScaleOffset] _atlas("Frame atlas", 2D) = "white" {}
        _Frametime("Frame duration in ms", Float) = 100.0
        _Framecount("Frame count", Float) = 100.0
        _Rows("Rows", Float) = 10.0
        _Columns("Columns", Float) = 10.0
        
        [NoScaleOffset] _k_s("Specular tint", Color) = (1,1,1,1)

        _k_d_coeff("Diffuse coefficient", Float) = 1
        _k_s_coeff("Specular coefficient", Float) = 1
        
        _n("Shinnyness", Float) = 10
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

            float _n, _k_d_coeff, _k_s_coeff;
            float _Frametime, _Framecount, _Rows, _Columns;
            float4 _k_a, _k_s;
            sampler2D _atlas;

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

            FragOut frag(v2f v) : SV_TARGET
            {
                DEBUGGABLE;
                fixed4 fragColor = 1;
                fixed4 brdf = 0;

                float frame = (_Time.y * 1000 / _Frametime) % _Framecount;
                float column = floor(frame % _Columns);
                float row = _Rows - 1 - floor(frame / _Columns);
                float width = 1.0 / _Columns;
                float height = 1.0 / _Rows;

                float2 uv = float2((v.uv.x + column) * width, (v.uv.y + row) * height);
                float4 _k_d = tex2D(_atlas, uv);
                
                float3 N_versor = normalize(v.normal_versor);
                float3 V_versor =  normalize(_WorldSpaceCameraPos - v.world_pos);

                insp3(4, N_versor);

                for (int i = 0; i < _L_Count; i++)
                {
                    float coneL = 1;
                    float3 _L_pos = _L_Position[i].xyz;
                    float L_dist = length(_L_pos - v.world_pos);
                    float3 L_versor = normalize(_L_pos - v.world_pos);

                    if (_L_Type[i] == 1) // Directional light
                    {
                        L_dist = 0;
                        L_versor = normalize(_L_Forward[i].xyz);
                    }
                    else if (_L_Type[i] == 2) // Spot light
                    {
                        coneL = pow(saturate((_L_ConeCosine[i] - dot(_L_Forward[i].xyz, L_versor)) / (_L_ConeCosine[i] - 1)), _L_ConeFalloff[i]);
                    }

                    float3 LV = (L_versor + V_versor);
                    float3 H_versor = LV / length(LV);

                    float4 specular = _k_s * _k_s_coeff * pow(saturate(dot(N_versor, H_versor)), _n);
                    
                    brdf += saturate(specular * coneL * _L_Color[i] * _L_Intensity[i] / pow(1 + L_dist, _L_Attenuation[i]));
                }
                
                float4 ambient = _k_d * _k_a;
                float4 diffuse  = _k_d * _k_d_coeff;
                fragColor = ambient + diffuse + brdf;

                ret(fragColor);
            }

            ENDCG
        }
    }
}