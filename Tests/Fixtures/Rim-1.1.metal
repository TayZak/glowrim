
    #include <metal_stdlib>
    using namespace metal;
    struct Vertex { float4 position [[position]]; float2 uv; };
    struct Uniforms {
        float2 size; float width; float softness; float4 color;
        float radius; float luminance; float fade; float blackout;
    };
    vertex Vertex fullscreen(uint id [[vertex_id]]) {
        float2 positions[3] = {float2(-1,-1), float2(3,-1), float2(-1,3)};
        Vertex v; v.position = float4(positions[id],0,1);
        v.uv = positions[id] * 0.5 + 0.5; return v;
    }
    fragment half4 rim(Vertex v [[stage_in]], constant Uniforms &u [[buffer(0)]]) {
        float2 p = v.uv * u.size;
        float radius = clamp(u.radius, 0.0, min(u.size.x,u.size.y)*0.5);
        float2 q = abs(p-u.size*0.5) - (u.size*0.5-radius);
        float distance = length(max(q,float2(0))) + min(max(q.x,q.y),0.0) - radius;
        float inset = max(0.0,-distance);
        float outside = 1.0-smoothstep(-0.75,0.75,distance);
        float core = 1.0-smoothstep(max(0.0,u.width-1.0),u.width+1.0,inset);
        float tail = u.softness > 0 ? exp(-3.0*pow(max(0.0,inset-u.width)/max(u.softness,1.0),2.0)) : core;
        float coverage = max(core,tail) * outside;
        // HDR is carried by RGB above 1, never by an invalid alpha value.
        float a = clamp(coverage*u.fade,0.0,1.0);
        float3 rgb = u.color.rgb*u.luminance*a;
        float blackAlpha = u.blackout*u.fade;
        return half4(half3(rgb),half(a+blackAlpha*(1.0-a)));
    }
