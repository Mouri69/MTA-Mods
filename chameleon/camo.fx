texture ScreenTexture;
sampler ScreenSampler = sampler_state { 
    Texture = <ScreenTexture>; 
    MinFilter = Linear;
    MagFilter = Linear;
    AddressU = Clamp;
    AddressV = Clamp;
};

float4x4 gWorldViewProjection : WORLDVIEWPROJECTION;

struct VSInput
{
    float3 Position : POSITION0;
    float4 Diffuse : COLOR0;
    float3 Normal : NORMAL0;
};

struct PSInput
{
    float4 Position : POSITION0;
    float4 Diffuse : COLOR0;
    float2 ScreenTexCoord : TEXCOORD0;
    float3 Normal : TEXCOORD1;
};

PSInput VertexShaderFunction(VSInput VS)
{
    PSInput PS = (PSInput)0;
    PS.Position = mul(float4(VS.Position, 1.0), gWorldViewProjection);
    PS.Diffuse = VS.Diffuse;
    PS.Normal = VS.Normal;

    // Convert to screen coordinates
    PS.ScreenTexCoord = PS.Position.xy / PS.Position.w;
    // Map from [-1, 1] to [0, 1]
    PS.ScreenTexCoord = PS.ScreenTexCoord * 0.5 + 0.5;
    // Flip Y
    PS.ScreenTexCoord.y = 1.0 - PS.ScreenTexCoord.y;

    return PS;
}

float4 PixelShaderFunction(PSInput PS) : COLOR0
{
    // Apply a very subtle distortion based on the ped's normal 
    // to give that "subtle 3D outline" effect.
    float2 distortion = PS.Normal.xy * 0.025;
    float2 uv = PS.ScreenTexCoord + distortion;
    
    // Clamp to avoid sampling outside the screen bounds
    uv = clamp(uv, 0.001, 0.999);
    
    float4 color = tex2D(ScreenSampler, uv);
    
    // Mix with a bit of shadow/diffuse to make the 3D shape slightly visible
    // Darkens the camo slightly where shadows fall on the ped
    float shadow = clamp(PS.Diffuse.r * 1.5, 0.5, 1.0);
    
    return float4(color.rgb * shadow, 1.0);
}

technique Camo
{
    pass P0
    {
        VertexShader = compile vs_2_0 VertexShaderFunction();
        PixelShader  = compile ps_2_0 PixelShaderFunction();
    }
}
