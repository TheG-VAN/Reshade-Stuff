/*=============================================================================
This work is licensed under the 
Creative Commons Attribution-NonCommercial 4.0 International (CC BY-NC 4.0) License
https://creativecommons.org/licenses/by-nc/4.0/	  

Original developer: Jak0bPCoder
Optimization by : Marty McFly
Compatibility by : MJ_Ehsan
=============================================================================*/

/*=============================================================================
	Preprocessor settings
=============================================================================*/
 
#define UI_ME_LAYER_MIN                                 6
#define UI_ME_MAX_ITERATIONS_PER_LEVEL                  2
#define UI_ME_SAMPLES_PER_ITERATION                     5

#ifndef UsePreviousFrame
    #define UsePreviousFrame 1
#endif

#ifndef GreyscaleResolution
    #define GreyscaleResolution 1
#endif

#if UsePreviousFrame

	uniform float Threshold <
		ui_type = "drag";
		ui_min = 0.0;
		ui_max = 0.25;
		ui_step = 0.001;
		ui_label = "Static threshold";
		ui_tooltip = "Increase to reduce flickering of static elements but also reduces total interpolation.";
	> = 0.001;

	uniform float Threshold2 <
		ui_type = "drag";
		ui_min = 0.0;
		ui_max = 1;
		ui_step = 0.001;
		ui_label = "Verification threshold";
		ui_tooltip = "Decrease to make interpolation more accurate but less intense (also causes artifacts).";
	> = 0.1;

#endif

uniform int UI_ME_LAYER_MAX <
	ui_type = "drag";
	ui_label = "Resolution divider";
	ui_tooltip = "0 = Full, 1 = Half, 2 = Quarter etc.";
	ui_min = 0;
	ui_max = 5;	
	ui_step = 1;
> = 2;

uniform float UI_ME_PYRAMID_UPSCALE_FILTER_RADIUS <
	ui_type = "drag";
	ui_label = "Filter Smoothness";
	ui_min = 0.0;
	ui_max = 6.0;	
	ui_step = 0.001;
> = 4.0;

uniform bool SHOWME <
	ui_label = "Debug Output";	
> = false;

/*=============================================================================
	Textures, Samplers, Globals, Structs
=============================================================================*/

#include "ReShadeUI.fxh"
#include "ReShade.fxh"

#ifndef PRE_BLOCK_SIZE_2_TO_7
 #define PRE_BLOCK_SIZE_2_TO_7	3   
#endif

#define BLOCK_SIZE (PRE_BLOCK_SIZE_2_TO_7)

//NEVER change these!!!
#define BLOCK_SIZE_HALF (BLOCK_SIZE * 0.5 - 0.5)
#define BLOCK_AREA 		(BLOCK_SIZE * BLOCK_SIZE)

uniform uint FRAME_COUNT < source = "framecount"; >;

texture GreyscaleCurr2          { Width = BUFFER_WIDTH * GreyscaleResolution;   Height = BUFFER_HEIGHT * GreyscaleResolution;   Format = R16F; MipLevels = 8; };
sampler sGreyscaleCurr         { Texture = GreyscaleCurr2;  };
texture GreyscalePrev2          { Width = BUFFER_WIDTH * GreyscaleResolution;   Height = BUFFER_HEIGHT * GreyscaleResolution;   Format = R16F; MipLevels = 8; };
sampler sGreyscalePrev         { Texture = GreyscalePrev2;   };

texture motionVectorTex          { Width = BUFFER_WIDTH >> 1;   Height = BUFFER_HEIGHT >> 1;   Format = RG16F; };
sampler sMotionVectorTex         { Texture = motionVectorTex;  };

texture MotionTexCur7               { Width = BUFFER_WIDTH >> 7;   Height = BUFFER_HEIGHT >> 7;   Format = RGBA16F;  };
sampler sMotionTexCur7              { Texture = MotionTexCur7;};
texture MotionTexCur6               { Width = BUFFER_WIDTH >> 6;   Height = BUFFER_HEIGHT >> 6;   Format = RGBA16F;  };
sampler sMotionTexCur6              { Texture = MotionTexCur6;};
texture MotionTexCur5               { Width = BUFFER_WIDTH >> 5;   Height = BUFFER_HEIGHT >> 5;   Format = RGBA16F;  };
sampler sMotionTexCur5              { Texture = MotionTexCur5;};
texture MotionTexCur4               { Width = BUFFER_WIDTH >> 4;   Height = BUFFER_HEIGHT >> 4;   Format = RGBA16F;  };
sampler sMotionTexCur4              { Texture = MotionTexCur4;};
texture MotionTexCur3               { Width = BUFFER_WIDTH >> 3;   Height = BUFFER_HEIGHT >> 3;   Format = RGBA16F;  };
sampler sMotionTexCur3              { Texture = MotionTexCur3;};
texture MotionTexCur2               { Width = BUFFER_WIDTH >> 2;   Height = BUFFER_HEIGHT >> 2;   Format = RGBA16F;  };
sampler sMotionTexCur2              { Texture = MotionTexCur2;};
texture MotionTexCur1               { Width = BUFFER_WIDTH >> 1;   Height = BUFFER_HEIGHT >> 1;   Format = RGBA16F;  };
sampler sMotionTexCur1              { Texture = MotionTexCur1;};

texture2D interpolatedTex { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA16F; MipLevels = 8; };
sampler2D interpolated { Texture = interpolatedTex; };
storage2D interpolatedStorage {Texture = interpolatedTex; };


struct VSOUT
{
    float4 vpos : SV_Position;
    float2 uv   : TEXCOORD0;
};

/*=============================================================================
	Functions
=============================================================================*/

float ResetInterpolated(float4 vpos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
	return 0;
}

void SetInterpolated(uint3 id : SV_DispatchThreadID, uint3 tid : SV_GroupThreadID)
{
	int2 c = int2(id.x % BUFFER_WIDTH, id.x / BUFFER_WIDTH);
	float2 m = tex2Dfetch(sMotionVectorTex, c / 2).xy;
	float4 col = tex2Dfetch(ReShade::BackBuffer, c);
	tex2Dstore(interpolatedStorage, c + m * 0.5 * float2(BUFFER_WIDTH, BUFFER_HEIGHT), col);
}

float noise(float2 co)
{
  return frac(sin(dot(co.xy ,float2(1.0,73))) * 437580.5453);
}

float4 CalcMotionLayer(VSOUT i, int mip_gcurr, float2 searchStart, sampler sGreyscaleCurr, sampler sGreyscalePrev, in float2 texcoord)
{	
	float2 texelsize = rcp(BUFFER_SCREEN_SIZE / exp2(mip_gcurr)) / GreyscaleResolution;
	float localBlock[BLOCK_AREA];
	float searchBlock[BLOCK_AREA];	 

	float2 moments_local = 0;
	float2 moments_search = 0;
	float moment_covariate = 0;

	i.uv -= texelsize * BLOCK_SIZE_HALF; //since we only use to sample the blocks now, offset by half a block so we can do it easier inline

	for(uint k = 0; k < BLOCK_SIZE * BLOCK_SIZE; k++)
	{
		float2 tuv = i.uv + float2(k / BLOCK_SIZE, k % BLOCK_SIZE) * texelsize;
		float t_local = tex2Dlod(sGreyscaleCurr, float4(tuv, 0, mip_gcurr)).x;
		float t_search = tex2Dlod(sGreyscalePrev, float4(tuv + searchStart, 0, mip_gcurr)).x;

		localBlock[k] = t_local; 
		searchBlock[k] = t_search;

		moments_local += float2(t_local, t_local * t_local);			
		moments_search += float2(t_search, t_search * t_search);
		moment_covariate += t_local * t_search;
	}

	moments_local /= BLOCK_AREA;
	moments_search /= BLOCK_AREA;
	moment_covariate /= BLOCK_AREA;

	float best_sim = moment_covariate * rsqrt(moments_local.y * moments_search.y);

	float local_features = abs(moments_local.x * moments_local.x - moments_local.y);
	float best_features = abs(moments_search.x * moments_search.x - moments_search.y);

	float2 bestMotion = 0;
	float2 searchCenter = searchStart;    

	float randseed = noise(texcoord);
	randseed = frac(randseed + (FRAME_COUNT % 16) * UI_ME_SAMPLES_PER_ITERATION * UI_ME_MAX_ITERATIONS_PER_LEVEL * 0.6180339887498);
	float2 randdir; sincos(randseed * 6.283, randdir.x, randdir.y);
	float2 scale = texelsize;

	[loop]
	for(int j = 0; j < UI_ME_MAX_ITERATIONS_PER_LEVEL && best_sim < 0.999999; j++)
	{
		[loop]
		for (int s = 1; s < UI_ME_SAMPLES_PER_ITERATION && best_sim < 0.999999; s++) 
		{
			randdir = mul(randdir, float2x2(-0.7373688, 0.6754903, -0.6754903, -0.7373688));//rotate by larger golden angle			
			float2 pixelOffset = randdir * scale;
			float2 samplePos = i.uv + searchCenter + pixelOffset;			 

			float2 moments_candidate = 0;			
			moment_covariate = 0;

			[loop]
			for(uint k = 0; k < BLOCK_SIZE * BLOCK_SIZE; k++)
			{
				float t = tex2Dlod(sGreyscalePrev, float4(samplePos + float2(k / BLOCK_SIZE, k % BLOCK_SIZE) * texelsize, 0, mip_gcurr)).x;
				moments_candidate += float2(t, t * t);
				moment_covariate += t * localBlock[k];
			}
			moments_candidate /= BLOCK_AREA;
			moment_covariate /= BLOCK_AREA;

			float candidate_similarity = moment_covariate * rsqrt(moments_local.y * moments_candidate.y);

			[flatten]
			if(candidate_similarity > best_sim)					
			{
				best_sim = candidate_similarity;
				bestMotion = pixelOffset;
				best_features = abs(moments_candidate.x * moments_candidate.x - moments_candidate.y);
			}			
		}
		searchCenter += bestMotion;
		bestMotion = 0;
		scale *= 0.5;
	}

	return float4(searchCenter, sqrt(best_features), best_sim * best_sim * best_sim * best_sim);  //delayed sqrt for variance -> stddev, cossim^4 for filter
}

float4 atrous_upscale(VSOUT i, int mip_gcurr, sampler sMotionLow, sampler sGreyscaleCurr, sampler sGreyscalePrev)
{	
    /*float2 texelsize = rcp(BUFFER_SCREEN_SIZE / exp2(mip_gcurr + 1)) / GreyscaleResolution;	
	float rand = frac(mip_gcurr * 0.2114 + (FRAME_COUNT % 16) * 0.6180339887498) * 3.1415927*0.5;
	float2x2 rotm = float2x2(cos(rand), -sin(rand), sin(rand), cos(rand)) * UI_ME_PYRAMID_UPSCALE_FILTER_RADIUS;
	const float3 gauss = float3(1, 0.85, 0.65);

	float4 gbuffer_sum = 0;
	float wsum = 1e-6;

	for(int x = -1; x <= 1; x++)
	for(int y = -1; y <= 1; y++)
	{
		float2 offs = mul(float2(x, y), rotm) * texelsize;
		float2 sample_uv = i.uv + offs;

		float4 sample_gbuf = tex2Dlod(sMotionLow, float4(sample_uv, 0, 0));

		float ws = saturate(1 - sample_gbuf.w * 4);
		float wf = saturate(1 - sample_gbuf.b * 128.0);
		float wm = dot(sample_gbuf.xy, sample_gbuf.xy) * 4;

		float weight = exp2(-(ws + wm + wf)) * gauss[abs(x)] * gauss[abs(y)];
		gbuffer_sum += sample_gbuf * weight;
		wsum += weight;		
	}

	return gbuffer_sum / wsum;*/
	float2 texelsize = rcp(BUFFER_SCREEN_SIZE / exp2(mip_gcurr)) / GreyscaleResolution;	
	float localBlock[BLOCK_AREA];
	float mse = 0;

	i.uv -= texelsize * BLOCK_SIZE_HALF; //since we only use to sample the blocks now, offset by half a block so we can do it easier inline
	// sample each pixel in 3x3 grid
	for(uint k = 0; k < BLOCK_SIZE * BLOCK_SIZE; k++)
	{
		float2 tuv = i.uv + float2(k / BLOCK_SIZE, k % BLOCK_SIZE) * texelsize;
		float t_local = tex2Dlod(sGreyscaleCurr, float4(tuv, 0, mip_gcurr)).x;
		float t_search = tex2Dlod(sGreyscalePrev, float4(tuv, 0, mip_gcurr)).x;
		localBlock[k] = t_local; 
		mse += (t_local - t_search) * (t_local - t_search);
	}

	float min_mse = mse;
	if (min_mse < 0.0001) {
		return float4(0, 0, 0, min_mse);
	}

	float2 best_motion = 0;
	for(int x = -1; x <= 1; x++)
	for(int y = -1; y <= 1; y++) {
		float2 motion = tex2Dlod(sMotionLow, float4(i.uv + texelsize * BLOCK_SIZE_HALF + texelsize * 2 * float2(x, y) * BLOCK_SIZE, 0, 0)).xy;
		float2 samplePos = i.uv + motion;
		mse = 0;
		[loop]
		for(uint k = 0; k < BLOCK_SIZE * BLOCK_SIZE; k++) {
			float t = tex2Dlod(sGreyscalePrev, float4((samplePos + float2(k / BLOCK_SIZE, k % BLOCK_SIZE) * texelsize), 0, mip_gcurr)).x;
			mse += (localBlock[k] - t) * (localBlock[k] - t);
		}

		float new_mse = mse;

		[flatten]
		if(new_mse < min_mse) {
			min_mse = new_mse;
			best_motion = motion;
		}
	}
	
	return float4(best_motion, 0, min_mse);
}

/*=============================================================================
	Shader Entry Points
=============================================================================*/

void PSWriteGreyscale(in VSOUT i, out float2 o : SV_Target0)
{    
    o = dot(tex2D(ReShade::BackBuffer, i.uv).rgb, float3(0.299, 0.587, 0.114));
}

void PSWriteGreyscalePrev(in VSOUT i, out float2 o : SV_Target0)
{    
    o = tex2D(sGreyscaleCurr, i.uv).r;
}

float4 motion_estimation(in VSOUT i, sampler sMotionLow, sampler sGreyscaleCurr, sampler sGreyscalePrev, int mip_gcurr, float2 texcoord : TexCoord)
{
	float4 upscaledLowerLayer = 0;

	[branch]
	if(UI_ME_LAYER_MIN < mip_gcurr) 
		return 0;

	[branch]
    if(mip_gcurr < UI_ME_LAYER_MIN)
    	upscaledLowerLayer = atrous_upscale(i, mip_gcurr, sMotionLow, sGreyscaleCurr, sGreyscalePrev);
	
	[branch]
	if(mip_gcurr >= UI_ME_LAYER_MAX) 
		upscaledLowerLayer = CalcMotionLayer(i, mip_gcurr, upscaledLowerLayer.xy, sGreyscaleCurr, sGreyscalePrev, texcoord);
	  

    return upscaledLowerLayer;
}

void PSMotion6(in VSOUT i, out float4 o : SV_Target0, float2 texcoord : TexCoord){o = motion_estimation(i, sMotionTexCur7, sGreyscaleCurr, sGreyscalePrev, 6, texcoord);}
void PSMotion5(in VSOUT i, out float4 o : SV_Target0, float2 texcoord : TexCoord){o = motion_estimation(i, sMotionTexCur6, sGreyscaleCurr, sGreyscalePrev, 5, texcoord);}
void PSMotion4(in VSOUT i, out float4 o : SV_Target0, float2 texcoord : TexCoord){o = motion_estimation(i, sMotionTexCur5, sGreyscaleCurr, sGreyscalePrev, 4, texcoord);}
void PSMotion3(in VSOUT i, out float4 o : SV_Target0, float2 texcoord : TexCoord){o = motion_estimation(i, sMotionTexCur4, sGreyscaleCurr, sGreyscalePrev, 3, texcoord);}
void PSMotion2(in VSOUT i, out float4 o : SV_Target0, float2 texcoord : TexCoord){o = motion_estimation(i, sMotionTexCur3, sGreyscaleCurr, sGreyscalePrev, 2, texcoord);}
void PSMotion1(in VSOUT i, out float4 o : SV_Target0, float2 texcoord : TexCoord){o = motion_estimation(i, sMotionTexCur2, sGreyscaleCurr, sGreyscalePrev, 1, texcoord);}

void PSWriteVectors(in VSOUT i, out float2 o : SV_Target0)
{
	o = tex2D(sMotionTexCur1, i.uv).xy;
}

float4 FrameInterpolationPass(float4 vpos : SV_Position, float2 uv : TEXCOORD) : SV_Target {
	float2 m = tex2D(sMotionVectorTex, uv).xy;
	if (SHOWME) {
		float2 shift = uv - m * 0.5;
		return tex2D(ReShade::BackBuffer, shift);
		//return float4(m * 100, (m.x + m.y) * -100, 1);
	}
	float2 shift = uv - m * 0.5;
	float4 im = tex2D(sGreyscaleCurr, uv);
	float4 shifted = tex2D(sGreyscaleCurr, shift);
	#if UsePreviousFrame
		if (distance(shifted, tex2D(sGreyscalePrev, shift)) < Threshold ||
			distance(im, tex2D(sGreyscalePrev, uv)) < Threshold ||
			distance(shifted, tex2D(sGreyscalePrev, uv + m * 0.5)) > Threshold2) {
			return tex2D(ReShade::BackBuffer, uv);
		}
	#endif
	//return tex2D(ReShade::BackBuffer, shift);
	float2 texelsize = rcp(BUFFER_SCREEN_SIZE);
	float4 interped = tex2D(interpolated, uv);
	/*if (interped.w == 0) {
		float4 avg = 0;
		for (int x = -1; x <= 1; x++)
		for (int y = -1; y <= 1; y++) {
			avg += tex2D(interpolated, uv + texelsize * float2(x, y));
		}
		if (avg.w == 0) {
			return tex2D(ReShade::BackBuffer, uv);
		}
		return avg / avg.w;
	}*/
	for (int i = 0; i < 9; i++) {
		float4 output = tex2Dlod(interpolated, float4(uv, 0, i));
		if (output.w > UI_ME_PYRAMID_UPSCALE_FILTER_RADIUS) {
			return output / output.w;
		}
	}
	
	return interped;

}

/*=============================================================================
	Techniques
=============================================================================*/

technique FrameInterpolationBuiltIn2
{
    pass
	{
		VertexShader = PostProcessVS;
		PixelShader  = PSWriteGreyscale; 
        RenderTarget = GreyscaleCurr2; 

	}

    pass {VertexShader = PostProcessVS;PixelShader = PSMotion6;RenderTarget = MotionTexCur6;}
    pass {VertexShader = PostProcessVS;PixelShader = PSMotion5;RenderTarget = MotionTexCur5;}
    pass {VertexShader = PostProcessVS;PixelShader = PSMotion4;RenderTarget = MotionTexCur4;}
    pass {VertexShader = PostProcessVS;PixelShader = PSMotion3;RenderTarget = MotionTexCur3;}
    pass {VertexShader = PostProcessVS;PixelShader = PSMotion2;RenderTarget = MotionTexCur2;}
    pass {VertexShader = PostProcessVS;PixelShader = PSMotion1;RenderTarget = MotionTexCur1;}
	
	pass  
	{
		VertexShader = PostProcessVS;
		PixelShader  = PSWriteVectors; 
		RenderTarget = motionVectorTex;
	} 
	
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = ResetInterpolated;
		RenderTarget = interpolatedTex;
	}
	
	pass
	{
		ComputeShader = SetInterpolated<1024,1>;
		DispatchSizeX = BUFFER_WIDTH * BUFFER_HEIGHT / 1024;
		DispatchSizeY = 1;
	}

	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = FrameInterpolationPass;
	}  

	pass  
	{
		VertexShader = PostProcessVS;
		PixelShader  = PSWriteGreyscalePrev; 
        RenderTarget = GreyscalePrev2; 
	}
}

