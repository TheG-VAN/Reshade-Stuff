/* 
   Copyright 2020 Morgan McGuire & Mara Gagiu. 
   Provided under the Open Source MIT license https://opensource.org/licenses/MIT
   by Morgan McGuire and Mara Gagiu.
*/

/*=============================================================================

    ReShade 4 effect file
    github.com/martymcmodding

    Basic implementation of MMPX by McGuire & Mara Gagiu for ReShade
    ported after the GLSL version

    Some notes:

    ReShade cannot upscale the backbuffer. This means that this
    implementation will only work if the game draws the sprites in 2x2, 4x4 
    or similar pixel blocks. If 1 sprite texel == 1 backbuffer pixel, 
    this will not work. ReShade cannot force the game to supersample.

    Since MMPX is a compute shader, a prepass will first downscale the input
    to the actual input size, i.e. 1920x1080 w/ sprite texel size 4x4 -> 480x270

    MMPX will then upscale by x2, in this example to 960x540

    A final pass (in ReShade, CS cannot write to backbuffer directly) will
    upscale 960x540 MMPX output to 1920x1080 again with nearest neighbour.
    The result is a 2x resolution increase for the sprites.

    Implementation is not very clean at the moment. ReShade does not have
    32 bit uint texture type, hence the conversion argb8 <-> uint is done
    on the fly to retain as much original code as possible.
    
    I'd like to extend this implementation to a pixel shader to ensure DX9
    compatibility and make the upscaling dynamically adjustable without
    recompiling.

=============================================================================*/

/*=============================================================================
    Preprocessor settings
=============================================================================*/

#ifndef INPUT_SCALE
 #define INPUT_SCALE 2  //2 := input is half resolution, i.e. each source pixel covers a 2x2 block
#endif

/*=============================================================================
    UI Uniforms
=============================================================================*/

uniform bool SHOW_INPUT <
    ui_label = "Show Input";    
> = false;

uniform int UIHELP <
    ui_type = "radio";
    ui_label = " "; 
    ui_text ="Set INPUT_SCALE to the size of the sprite texel the game uses.\nE.g. if 1 sprite texel maps to 4x4 screen pixels, set it to 4.";
>;

/*=============================================================================
    Textures, Samplers, Globals
=============================================================================*/

//integer divide, rounding up, required if backbuffer is not divisible by NxN
//CS will do overdraw, but since last pass does a direct texture fetch, this overdraw is invisible
#define CEIL_DIV(num, denom) (((num - 1) / denom) + 1)

 #define INPUT_SIZE_X CEIL_DIV(BUFFER_WIDTH, INPUT_SCALE) 
 #define INPUT_SIZE_Y CEIL_DIV(BUFFER_HEIGHT, INPUT_SCALE) 

texture2D MMPXInputTex          { Width = INPUT_SIZE_X;   Height = INPUT_SIZE_Y;  Format = RGBA8; };
sampler2D sMMPXInputTex         { Texture = MMPXInputTex;  };

texture2D MMPXDestinationTex    { Width = INPUT_SIZE_X * 2;   Height = INPUT_SIZE_Y * 2;  Format = RGBA8; };
sampler2D sMMPXDestinationTex   { Texture = MMPXDestinationTex;  };
storage stMMPXDestinationTex    { Texture = MMPXDestinationTex; };

texture ColorInputTex : COLOR;
sampler ColorInput    { Texture = ColorInputTex; };

/*=============================================================================
    Vertex Shader
=============================================================================*/

struct CSIN 
{
    uint3 groupthreadid     : SV_GroupThreadID;         //XYZ idx of thread inside group
    uint3 groupid           : SV_GroupID;               //XYZ idx of group inside dispatch
    uint3 dispatchthreadid  : SV_DispatchThreadID;      //XYZ idx of thread inside dispatch
    uint threadid           : SV_GroupIndex;            //flattened idx of thread inside group
};

void VS_FullscreenTriangle(in uint id : SV_VertexID, out float4 vpos : SV_Position, out float2 uv : TEXCOORD)
{
    uv.x = (id == 2) ? 2.0 : 0.0;
    uv.y = (id == 1) ? 2.0 : 0.0;
    vpos = float4(uv * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
}

/*=============================================================================
    Functions
=============================================================================*/

#define ABGR8 uint

uint luma(ABGR8 C) {
    uint alpha = (C & 0xFF000000u) >> 24;
    return (((C & 0x00FF0000u) >> 16) + ((C & 0x0000FF00u) >> 8) + (C & 0x000000FFu) + 1u) * (256u - alpha);
}

bool all_eq2(ABGR8 B, ABGR8 A0, ABGR8 A1) {
    return ((B ^ A0) | (B ^ A1)) == 0u;
}

bool all_eq3(ABGR8 B, ABGR8 A0, ABGR8 A1, ABGR8 A2) {
    return ((B ^ A0) | (B ^ A1) | (B ^ A2)) == 0u;
}

bool all_eq4(ABGR8 B, ABGR8 A0, ABGR8 A1, ABGR8 A2, ABGR8 A3) {
    return ((B ^ A0) | (B ^ A1) | (B ^ A2) | (B ^ A3)) == 0u;
}

bool any_eq3(ABGR8 B, ABGR8 A0, ABGR8 A1, ABGR8 A2) {
    return B == A0 || B == A1 || B == A2;
}

bool none_eq2(ABGR8 B, ABGR8 A0, ABGR8 A1) {
    return (B != A0) && (B != A1);
}

bool none_eq4(ABGR8 B, ABGR8 A0, ABGR8 A1, ABGR8 A2, ABGR8 A3) {
    return B != A0 && B != A1 && B != A2 && B != A3;
}

uint encode_abgr8(float4 color)
{
    uint4 c = uint4(color * 255) & 0xFF;
    uint ret = 
    (c.a << 24) | (c.b << 16) | (c.g << 8) | (c.r);
    return ret;
}

float4 decode_abgr8(uint abgr8)
{
    return float4(
         abgr8 & 0x000000FF,
        (abgr8 & 0x0000FF00) >> 8,
        (abgr8 & 0x00FF0000) >> 16,
        (abgr8 & 0xFF000000) >> 24
    ) / 255.0;
}

uint fetch_src(uint x, uint y)
{
    return encode_abgr8(tex2Dfetch(sMMPXInputTex, int2(x, y)));
}

/*=============================================================================
    Pixel Shaders
=============================================================================*/

void PSDownsample(in float4 vpos : SV_Position, in float2 uv : TEXCOORD, out float3 o : SV_Target0)
{
    o = tex2D(ColorInput, uv).rgb;
}

void CS_MMPX(in CSIN i)
{
    int srcX = int(i.dispatchthreadid.x);
    int srcY = int(i.dispatchthreadid.y);

    ABGR8 A = fetch_src(srcX - 1, srcY - 1), B = fetch_src(srcX, srcY - 1), C = fetch_src(srcX + 1, srcY - 1);
    ABGR8 D = fetch_src(srcX - 1, srcY + 0), E = fetch_src(srcX, srcY + 0), F = fetch_src(srcX + 1, srcY + 0);
    ABGR8 G = fetch_src(srcX - 1, srcY + 1), H = fetch_src(srcX, srcY + 1), I = fetch_src(srcX + 1, srcY + 1);

    ABGR8 J = E, K = E, L = E, M = E;

    if (((A ^ E) | (B ^ E) | (C ^ E) | (D ^ E) | (F ^ E) | (G ^ E) | (H ^ E) | (I ^ E)) != 0u) 
    {
        ABGR8 P = fetch_src(srcX, srcY - 2), S = fetch_src(srcX, srcY + 2);
        ABGR8 Q = fetch_src(srcX - 2, srcY), R = fetch_src(srcX + 2, srcY);
        ABGR8 Bl = luma(B), Dl = luma(D), El = luma(E), Fl = luma(F), Hl = luma(H);

        // 1:1 slope rules
        if ((D == B && D != H && D != F) && (El >= Dl || E == A) && any_eq3(E, A, C, G) && ((El < Dl) || A != D || E != P || E != Q)) J = D;
        if ((B == F && B != D && B != H) && (El >= Bl || E == C) && any_eq3(E, A, C, I) && ((El < Bl) || C != B || E != P || E != R)) K = B;
        if ((H == D && H != F && H != B) && (El >= Hl || E == G) && any_eq3(E, A, G, I) && ((El < Hl) || G != H || E != S || E != Q)) L = H;
        if ((F == H && F != B && F != D) && (El >= Fl || E == I) && any_eq3(E, C, G, I) && ((El < Fl) || I != H || E != R || E != S)) M = F;

        // Intersection rules
        if ((E != F && all_eq4(E, C, I, D, Q) && all_eq2(F, B, H)) && (F != fetch_src(srcX + 3, srcY))) K = M = F;
        if ((E != D && all_eq4(E, A, G, F, R) && all_eq2(D, B, H)) && (D != fetch_src(srcX - 3, srcY))) J = L = D;
        if ((E != H && all_eq4(E, G, I, B, P) && all_eq2(H, D, F)) && (H != fetch_src(srcX, srcY + 3))) L = M = H;
        if ((E != B && all_eq4(E, A, C, H, S) && all_eq2(B, D, F)) && (B != fetch_src(srcX, srcY - 3))) J = K = B;
        if (Bl < El && all_eq4(E, G, H, I, S) && none_eq4(E, A, D, C, F)) J = K = B;
        if (Hl < El && all_eq4(E, A, B, C, P) && none_eq4(E, D, G, I, F)) L = M = H;
        if (Fl < El && all_eq4(E, A, D, G, Q) && none_eq4(E, B, C, I, H)) K = M = F;
        if (Dl < El && all_eq4(E, C, F, I, R) && none_eq4(E, B, A, G, H)) J = L = D;

        // 2:1 slope rules
        if (H != B) { 
            if (H != A && H != E && H != C) {
                if (all_eq3(H, G, F, R) && none_eq2(H, D, fetch_src(srcX + 2, srcY - 1))) L = M;
                if (all_eq3(H, I, D, Q) && none_eq2(H, F, fetch_src(srcX - 2, srcY - 1))) M = L;
            }
            
            if (B != I && B != G && B != E) {
                if (all_eq3(B, A, F, R) && none_eq2(B, D, fetch_src(srcX + 2, srcY + 1))) J = K;
                if (all_eq3(B, C, D, Q) && none_eq2(B, F, fetch_src(srcX - 2, srcY + 1))) K = J;
            }
        } // H !== B
        
        if (F != D) { 
            if (D != I && D != E && D != C) {
                if (all_eq3(D, A, H, S) && none_eq2(D, B, fetch_src(srcX + 1, srcY + 2))) J = L;
                if (all_eq3(D, G, B, P) && none_eq2(D, H, fetch_src(srcX + 1, srcY - 2))) L = J;
            }
            
            if (F != E && F != A && F != G) {    
                if (all_eq3(F, C, H, S) && none_eq2(F, B, fetch_src(srcX - 1, srcY + 2))) K = M;
                if (all_eq3(F, I, B, P) && none_eq2(F, H, fetch_src(srcX - 1, srcY - 2))) M = K;
            }
        } // F !== D
    } // not constant

    /*
        JK
        LM
    */
    tex2Dstore(stMMPXDestinationTex, int2(srcX * 2 + 0, srcY * 2 + 0), decode_abgr8(J));
    tex2Dstore(stMMPXDestinationTex, int2(srcX * 2 + 1, srcY * 2 + 0), decode_abgr8(K));
    tex2Dstore(stMMPXDestinationTex, int2(srcX * 2 + 0, srcY * 2 + 1), decode_abgr8(L));
    tex2Dstore(stMMPXDestinationTex, int2(srcX * 2 + 1, srcY * 2 + 1), decode_abgr8(M));
}

void PSVisualize(in float4 vpos : SV_Position, in float2 uv : TEXCOORD, out float3 o : SV_Target0)
{
    o = SHOW_INPUT 
    ? tex2Dfetch(sMMPXInputTex,       vpos.xy / INPUT_SCALE).rgb
    : tex2Dfetch(sMMPXDestinationTex, vpos.xy / INPUT_SCALE * 2).rgb;
}

/*=============================================================================
    Techniques
=============================================================================*/

technique MMPX
{
    pass
    {
        VertexShader = VS_FullscreenTriangle;
        PixelShader  = PSDownsample; 
        RenderTarget = MMPXInputTex;    
    }
    pass
    {
        ComputeShader = CS_MMPX<8, 8>;
        DispatchSizeX = CEIL_DIV(INPUT_SIZE_X, 8);
        DispatchSizeY = CEIL_DIV(INPUT_SIZE_Y, 8);
    }
    pass
    {
        VertexShader = VS_FullscreenTriangle;
        PixelShader  = PSVisualize;     
    }
}


