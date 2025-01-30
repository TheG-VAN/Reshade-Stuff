

#include "ReShadeUI.fxh"

uniform int GaussianBlurRadius < __UNIFORM_SLIDER_INT1
	ui_min = 0; ui_max = 4;
	ui_tooltip = "[0|1|2|3|4] Adjusts the blur radius. Higher values increase the radius";
> = 1;

uniform float GaussianBlurOffset < __UNIFORM_SLIDER_FLOAT1
	ui_min = 0.00; ui_max = 1.00;
	ui_tooltip = "Additional adjustment for the blur radius. Values less than 1.00 will reduce the radius.";
> = 1.00;

uniform float GaussianBlurStrength < __UNIFORM_SLIDER_FLOAT1
	ui_min = 0.00; ui_max = 1.00;
	ui_tooltip = "Adjusts the strength of the effect.";
> = 0.300;

uniform bool enable_weber <
    ui_category = "Banding analysis";
    ui_label = "Weber ratio";
    ui_tooltip = "Weber ratio analysis that calculates the ratio of the each local pixel's intensity to average background intensity of all the local pixels.";
    ui_type = "radio";
> = true;

uniform bool enable_sdeviation <
    ui_category = "Banding analysis";
    ui_label = "Standard deviation";
    ui_tooltip = "Modified standard deviation analysis that calculates nearby pixels' intensity deviation from the current pixel instead of the mean.";
    ui_type = "radio";
> = true;

uniform bool enable_depthbuffer <
    ui_category = "Banding analysis";
    ui_label = "Depth detection";
    ui_tooltip = "Allows depth information to be used when analysing banding, pixels will only be analysed if they are in a certain depth. (e.g. debanding only the sky)";
    ui_type = "radio";
> = false;

uniform float t1 <
    ui_category = "Banding analysis";
    ui_label = "Standard deviation threshold";
    ui_max = 0.5;
    ui_min = 0.0;
    ui_step = 0.001;
    ui_tooltip = "Standard deviations lower than this threshold will be flagged as flat regions with potential banding.";
    ui_type = "slider";
> = 0.007;

uniform float t2 <
    ui_category = "Banding analysis";
    ui_label = "Weber ratio threshold";
    ui_max = 2.0;
    ui_min = 0.0;
    ui_step = 0.01;
    ui_tooltip = "Weber ratios lower than this threshold will be flagged as flat regions with potential banding.";
    ui_type = "slider";
> = 0.04;

uniform float banding_depth <
    ui_category = "Banding analysis";
    ui_label = "Banding depth";
    ui_max = 1.0;
    ui_min = 0.0;
    ui_step = 0.001;
    ui_tooltip = "Pixels under this depth threshold will not be processed and returned as they are.";
    ui_type = "slider";
> = 1.0;

uniform float range <
    ui_category = "Banding detection & removal";
    ui_label = "Radius";
    ui_max = 32.0;
    ui_min = 1.0;
    ui_step = 1.0;
    ui_tooltip = "The radius increases linearly for each iteration. A higher radius will find more gradients, but a lower radius will smooth more aggressively.";
    ui_type = "slider";
> = 24.0;

uniform int iterations <
    ui_category = "Banding detection & removal";
    ui_label = "Iterations";
    ui_max = 4;
    ui_min = 1;
    ui_tooltip = "The number of debanding steps to perform per sample. Each step reduces a bit more banding, but takes time to compute.";
    ui_type = "slider";
> = 1;

uniform float BandingBlur <
	ui_min = 0.00; ui_max = 10;
	ui_tooltip = "Adjustment for the banding blur radius.";
	ui_type = "slider";
> = 2.00;

#include "ReShade.fxh"

texture GaussianBlurTex < pooled = true; > { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA8; };
texture DebandTex < pooled = false; > { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA8; };
sampler GaussianBlurSampler { Texture = GaussianBlurTex;};
sampler DebandSampler { Texture = DebandTex;};

// Reshade uses C rand for random, max cannot be larger than 2^15-1
uniform int drandom < source = "random"; min = 0; max = 32767; >;

float rand(float x)
{
    return frac(x / 41.0);
}

float permute(float x)
{
    return ((34.0 * x + 1.0) * x) % 289.0;
}

float3 GaussianBlurFinal(in float4 pos : SV_Position, in float2 texcoord : TEXCOORD) : COLOR
{

float3 color = tex2D(GaussianBlurSampler, texcoord).rgb;
float3 prev = tex2D(ReShade::BackBuffer, texcoord).rgb;

if(GaussianBlurRadius == 0)	
{
	float offset[4] = { 0.0, 1.1824255238, 3.0293122308, 5.0040701377 };
	float weight[4] = { 0.39894, 0.2959599993, 0.0045656525, 0.00000149278686458842 };
	
	color *= weight[0];
	
	[loop]
	for(int i = 1; i < 4; ++i)
	{
		color += tex2D(GaussianBlurSampler, texcoord + float2(0.0, offset[i] * BUFFER_PIXEL_SIZE.y) * GaussianBlurOffset).rgb * weight[i];
		color += tex2D(GaussianBlurSampler, texcoord - float2(0.0, offset[i] * BUFFER_PIXEL_SIZE.y) * GaussianBlurOffset).rgb * weight[i];
	}
}	

if(GaussianBlurRadius == 1)	
{
	float offset[6] = { 0.0, 1.4584295168, 3.40398480678, 5.3518057801, 7.302940716, 9.2581597095 };
	float weight[6] = { 0.13298, 0.23227575, 0.1353261595, 0.0511557427, 0.01253922, 0.0019913644 };
	
	color *= weight[0];
	
	[loop]
	for(int i = 1; i < 6; ++i)
	{
		color += tex2D(GaussianBlurSampler, texcoord + float2(0.0, offset[i] * BUFFER_PIXEL_SIZE.y) * GaussianBlurOffset).rgb * weight[i];
		color += tex2D(GaussianBlurSampler, texcoord - float2(0.0, offset[i] * BUFFER_PIXEL_SIZE.y) * GaussianBlurOffset).rgb * weight[i];
	}
}	

if(GaussianBlurRadius == 2)	
{
	float offset[11] = { 0.0, 1.4895848401, 3.4757135714, 5.4618796741, 7.4481042327, 9.4344079746, 11.420811147, 13.4073334, 15.3939936778, 17.3808101174, 19.3677999584 };
	float weight[11] = { 0.06649, 0.1284697563, 0.111918249, 0.0873132676, 0.0610011113, 0.0381655709, 0.0213835661, 0.0107290241, 0.0048206869, 0.0019396469, 0.0006988718 };
	
	color *= weight[0];
	
	[loop]
	for(int i = 1; i < 11; ++i)
	{
		color += tex2D(GaussianBlurSampler, texcoord + float2(0.0, offset[i] * BUFFER_PIXEL_SIZE.y) * GaussianBlurOffset).rgb * weight[i];
		color += tex2D(GaussianBlurSampler, texcoord - float2(0.0, offset[i] * BUFFER_PIXEL_SIZE.y) * GaussianBlurOffset).rgb * weight[i];
	}
}	

if(GaussianBlurRadius == 3)	
{
	float offset[15] = { 0.0, 1.4953705027, 3.4891992113, 5.4830312105, 7.4768683759, 9.4707125766, 11.4645656736, 13.4584295168, 15.4523059431, 17.4461967743, 19.4401038149, 21.43402885, 23.4279736431, 25.4219399344, 27.4159294386 };
	float weight[15] = { 0.0443266667, 0.0872994708, 0.0820892038, 0.0734818355, 0.0626171681, 0.0507956191, 0.0392263968, 0.0288369812, 0.0201808877, 0.0134446557, 0.0085266392, 0.0051478359, 0.0029586248, 0.0016187257, 0.0008430913 };
	
	color *= weight[0];
	
	[loop]
	for(int i = 1; i < 15; ++i)
	{
		color += tex2D(GaussianBlurSampler, texcoord + float2(0.0, offset[i] * BUFFER_PIXEL_SIZE.y) * GaussianBlurOffset).rgb * weight[i];
		color += tex2D(GaussianBlurSampler, texcoord - float2(0.0, offset[i] * BUFFER_PIXEL_SIZE.y) * GaussianBlurOffset).rgb * weight[i];
	}
}

if(GaussianBlurRadius == 4)	
{
	float offset[18] = { 0.0, 1.4953705027, 3.4891992113, 5.4830312105, 7.4768683759, 9.4707125766, 11.4645656736, 13.4584295168, 15.4523059431, 17.4461967743, 19.4661974725, 21.4627427973, 23.4592916956, 25.455844494, 27.4524015179, 29.4489630909, 31.445529535, 33.4421011704 };
	float weight[18] = { 0.033245, 0.0659162217, 0.0636705814, 0.0598194658, 0.0546642566, 0.0485871646, 0.0420045997, 0.0353207015, 0.0288880982, 0.0229808311, 0.0177815511, 0.013382297, 0.0097960001, 0.0069746748, 0.0048301008, 0.0032534598, 0.0021315311, 0.0013582974 };
	
	color *= weight[0];
	
	[loop]
	for(int i = 1; i < 18; ++i)
	{
		color += tex2D(GaussianBlurSampler, texcoord + float2(0.0, offset[i] * BUFFER_PIXEL_SIZE.y) * GaussianBlurOffset).rgb * weight[i];
		color += tex2D(GaussianBlurSampler, texcoord - float2(0.0, offset[i] * BUFFER_PIXEL_SIZE.y) * GaussianBlurOffset).rgb * weight[i];
	}
}		

	float3 orig = tex2D(ReShade::BackBuffer, texcoord).rgb;
	
	float3 banding_map = float3(0, 0, 0);
	
	for (int x = -4; x <= 4; x++) {
		for (int y = -4; y <= 4; y++) {
			banding_map += tex2D(DebandSampler, texcoord + float2(x * BUFFER_PIXEL_SIZE.x, y * BUFFER_PIXEL_SIZE.y) * BandingBlur).rgb;
		}
	}
	banding_map /= 81;
	
	orig = lerp(orig, color, banding_map * GaussianBlurStrength);

	return saturate(orig);
}

float3 Deband(float4 vpos : SV_Position, float2 texcoord : TexCoord) : COLOR {
	float3 ori = tex2Dlod(ReShade::BackBuffer, float4(texcoord, 0.0, 0.0)).rgb;

    if (enable_depthbuffer && (ReShade::GetLinearizedDepth(texcoord) < banding_depth))
        return ori;

    // Initialize the PRNG by hashing the position + a random uniform
    float3 m = float3(texcoord + 1.0, 1.0);
    float h = permute(permute(permute(m.x) + m.y) + m.z);

    // Compute a random angle
    float dir  = rand(permute(h)) * 6.2831853;
    float2 o;
    sincos(dir, o.y, o.x);
    
    // Distance calculations
    float2 pt;
    float dist;

    for (int i = 1; i <= iterations; ++i) {
        dist = rand(h) * range * i;
        pt = dist * BUFFER_PIXEL_SIZE;
    
        h = permute(h);
    }
    
    // Sample at quarter-turn intervals around the source pixel
    float3 ref[4] = {
        tex2Dlod(ReShade::BackBuffer, float4(mad(pt,                  o, texcoord), 0.0, 0.0)).rgb, // SE
        tex2Dlod(ReShade::BackBuffer, float4(mad(pt,                 -o, texcoord), 0.0, 0.0)).rgb, // NW
        tex2Dlod(ReShade::BackBuffer, float4(mad(pt, float2(-o.y,  o.x), texcoord), 0.0, 0.0)).rgb, // NE
        tex2Dlod(ReShade::BackBuffer, float4(mad(pt, float2( o.y, -o.x), texcoord), 0.0, 0.0)).rgb  // SW
    };

    // Calculate weber ratio
    float3 mean = (ori + ref[0] + ref[1] + ref[2] + ref[3]) * 0.2;
    float3 k = abs(ori - mean);
    for (int j = 0; j < 4; ++j) {
        k += abs(ref[j] - mean);
    }

    k = k * 0.2 / mean;

    // Calculate std. deviation
    float3 sd = 0.0;

    for (int j = 0; j < 4; ++j) {
        sd += pow(ref[j] - ori, 2);
    }

    sd = sqrt(sd * 0.25);

    // Generate final output
    float3 output;
	
    output = (ref[0] + ref[1] + ref[2] + ref[3]) * 0.25;

    // Generate a binary banding map
    float3 banding_map = float3(1, 1, 1);

    if (enable_weber)
        banding_map = banding_map && k <= t2 * iterations;

    if (enable_sdeviation)
        banding_map = banding_map && sd <= t1 * iterations;
	
	return banding_map;
}

float3 GaussianBlur1(in float4 pos : SV_Position, in float2 texcoord : TEXCOORD) : COLOR
{

float3 color = tex2D(ReShade::BackBuffer, texcoord).rgb;

if(GaussianBlurRadius == 0)	
{
	float offset[4] = { 0.0, 1.1824255238, 3.0293122308, 5.0040701377 };
	float weight[4] = { 0.39894, 0.2959599993, 0.0045656525, 0.00000149278686458842 };
	
	color *= weight[0];
	
	[loop]
	for(int i = 1; i < 4; ++i)
	{
		color += tex2D(ReShade::BackBuffer, texcoord + float2(offset[i] * BUFFER_PIXEL_SIZE.x, 0.0) * GaussianBlurOffset).rgb * weight[i];
		color += tex2D(ReShade::BackBuffer, texcoord - float2(offset[i] * BUFFER_PIXEL_SIZE.x, 0.0) * GaussianBlurOffset).rgb * weight[i];
	}
}	

if(GaussianBlurRadius == 1)	
{
	float offset[6] = { 0.0, 1.4584295168, 3.40398480678, 5.3518057801, 7.302940716, 9.2581597095 };
	float weight[6] = { 0.13298, 0.23227575, 0.1353261595, 0.0511557427, 0.01253922, 0.0019913644 };
	
	color *= weight[0];
	
	[loop]
	for(int i = 1; i < 6; ++i)
	{
		color += tex2D(ReShade::BackBuffer, texcoord + float2(offset[i] * BUFFER_PIXEL_SIZE.x, 0.0) * GaussianBlurOffset).rgb * weight[i];
		color += tex2D(ReShade::BackBuffer, texcoord - float2(offset[i] * BUFFER_PIXEL_SIZE.x, 0.0) * GaussianBlurOffset).rgb * weight[i];
	}
}	

if(GaussianBlurRadius == 2)	
{
	float offset[11] = { 0.0, 1.4895848401, 3.4757135714, 5.4618796741, 7.4481042327, 9.4344079746, 11.420811147, 13.4073334, 15.3939936778, 17.3808101174, 19.3677999584 };
	float weight[11] = { 0.06649, 0.1284697563, 0.111918249, 0.0873132676, 0.0610011113, 0.0381655709, 0.0213835661, 0.0107290241, 0.0048206869, 0.0019396469, 0.0006988718 };
	
	color *= weight[0];
	
	[loop]
	for(int i = 1; i < 11; ++i)
	{
		color += tex2D(ReShade::BackBuffer, texcoord + float2(offset[i] * BUFFER_PIXEL_SIZE.x, 0.0) * GaussianBlurOffset).rgb * weight[i];
		color += tex2D(ReShade::BackBuffer, texcoord - float2(offset[i] * BUFFER_PIXEL_SIZE.x, 0.0) * GaussianBlurOffset).rgb * weight[i];
	}
}	

if(GaussianBlurRadius == 3)	
{
	float offset[15] = { 0.0, 1.4953705027, 3.4891992113, 5.4830312105, 7.4768683759, 9.4707125766, 11.4645656736, 13.4584295168, 15.4523059431, 17.4461967743, 19.4401038149, 21.43402885, 23.4279736431, 25.4219399344, 27.4159294386 };
	float weight[15] = { 0.0443266667, 0.0872994708, 0.0820892038, 0.0734818355, 0.0626171681, 0.0507956191, 0.0392263968, 0.0288369812, 0.0201808877, 0.0134446557, 0.0085266392, 0.0051478359, 0.0029586248, 0.0016187257, 0.0008430913 };
	
	color *= weight[0];
	
	[loop]
	for(int i = 1; i < 15; ++i)
	{
		color += tex2D(ReShade::BackBuffer, texcoord + float2(offset[i] * BUFFER_PIXEL_SIZE.x, 0.0) * GaussianBlurOffset).rgb * weight[i];
		color += tex2D(ReShade::BackBuffer, texcoord - float2(offset[i] * BUFFER_PIXEL_SIZE.x, 0.0) * GaussianBlurOffset).rgb * weight[i];
	}
}	

if(GaussianBlurRadius == 4)	
{
	float offset[18] = { 0.0, 1.4953705027, 3.4891992113, 5.4830312105, 7.4768683759, 9.4707125766, 11.4645656736, 13.4584295168, 15.4523059431, 17.4461967743, 19.4661974725, 21.4627427973, 23.4592916956, 25.455844494, 27.4524015179, 29.4489630909, 31.445529535, 33.4421011704 };
	float weight[18] = { 0.033245, 0.0659162217, 0.0636705814, 0.0598194658, 0.0546642566, 0.0485871646, 0.0420045997, 0.0353207015, 0.0288880982, 0.0229808311, 0.0177815511, 0.013382297, 0.0097960001, 0.0069746748, 0.0048301008, 0.0032534598, 0.0021315311, 0.0013582974 };
	
	color *= weight[0];
	
	[loop]
	for(int i = 1; i < 18; ++i)
	{
		color += tex2D(ReShade::BackBuffer, texcoord + float2(offset[i] * BUFFER_PIXEL_SIZE.x, 0.0) * GaussianBlurOffset).rgb * weight[i];
		color += tex2D(ReShade::BackBuffer, texcoord - float2(offset[i] * BUFFER_PIXEL_SIZE.x, 0.0) * GaussianBlurOffset).rgb * weight[i];
	}
}	
	return saturate(color);
}

technique DebandBlur
{
	pass Deband
	{
		VertexShader = PostProcessVS;
		PixelShader = Deband;
		RenderTarget = DebandTex;
	}
	pass Blur1
	{
		VertexShader = PostProcessVS;
		PixelShader = GaussianBlur1;
		RenderTarget = GaussianBlurTex;
	}
	pass BlurFinal
	{
		VertexShader = PostProcessVS;
		PixelShader = GaussianBlurFinal;
	}
}