uniform float SIGMA <
	ui_type = "drag";
	ui_min = 1;
	ui_max = 20;
	ui_step = 1;
	ui_label = "Sigma";
> = 10;

uniform float BSIGMA <
	ui_type = "drag";
	ui_min = 0.01;
	ui_max = 0.5;
	ui_step = 0.01;
	ui_label = "BSigma";
> = 0.1;

uniform float Size <
	ui_type = "drag";
	ui_min = 1;
	ui_max = 20;
	ui_step = 0.1;
	ui_label = "Size";
> = 4;

uniform float Samples <
	ui_type = "drag";
	ui_min = 3;
	ui_max = 20;
	ui_step = 1;
	ui_label = "Samples";
> = 5;


#include "ReShade.fxh"

float normpdf(in float x, in float sigma)
{
	return 0.39894*exp(-0.5*x*x/(sigma*sigma))/sigma;
}

float normpdf3(in float3 v, in float sigma)
{
	return 0.39894*exp(-0.5*dot(v,v)/(sigma*sigma))/sigma;
}

float3 BilateralPass(float2 uv : TEXCOORD) : SV_Target
{
	float MSIZE = Samples;
	float2 OutputSize = tex2Dsize(ReShade::BackBuffer) / (Size / Samples);
	float2 fragcoord = uv * OutputSize.xy;
	float3 c = tex2D(ReShade::BackBuffer, uv).rgb;
	
	//declare stuff
	const int kSize = (MSIZE-1)/2;
	float3 final_colour = float3(0, 0, 0);
	
	float Z = 0.0;
	float3 cc;
	float factor;
	float bZ = 1.0/normpdf(0.0, BSIGMA);
	//read out the texels
	for (int i=-kSize; i <= kSize; ++i)
	{
		for (int j=-kSize; j <= kSize; ++j)
		{
			cc = tex2D(ReShade::BackBuffer, (fragcoord.xy+float2(float(i),float(j))) / OutputSize.xy).rgb;
			factor = normpdf3(cc-c, BSIGMA)*bZ*normpdf(float(abs(j)), SIGMA)*normpdf(float(abs(i)), SIGMA);
			Z += factor;
			final_colour += factor*cc;
		}
	}
	
	return final_colour/Z;
}

technique Bilateral
{
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = BilateralPass;
	}
}
