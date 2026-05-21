#pragma multi_compile __ SHADER_INSPECTOR_ON

#if defined(SHADER_INSPECTOR_ON)
    #define FragOut __FragOut
    #define DEBUGGABLE __FragOut output
    #define inspf(a, b) output.channel_ ## a = float4(## b, ## b, ## b, 1);
    #define insp2(a, b) output.channel_ ## a = float4(float3(## b, 0), 1);
    #define insp3(a, b) output.channel_ ## a = float4(## b, 1);
    #define insp4(a, b) output.channel_ ## a = ## b;
    #define ret(x) if (1) { \
        output.channel_0 = ## x;  \
        return output;      \
    }
#else
    #define FragOut float4
    #define DEBUGGABLE ;
    #define inspf(a, b) ;
    #define insp2(a, b) ;
    #define insp3(a, b) ;
    #define insp4(a, b) ;
    #define ret(x) return x
#endif

struct __FragOut {
    float4 channel_0 : SV_Target0;
    float4 channel_1 : SV_Target1;
    float4 channel_2 : SV_Target2;
    float4 channel_3 : SV_Target3;
    float4 channel_4 : SV_Target4;
    float4 channel_5 : SV_Target5;
    float4 channel_6 : SV_Target6;
    float4 channel_7 : SV_Target7;
};
