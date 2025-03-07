uniform float ThresoldDiffBetweenPixels <
	ui_type = "slider";
	ui_min = 0.0; ui_max = 3.0;
> = 0;
uniform float UpLimit <
	ui_type = "slider";
	ui_min = 0.0; ui_max = 1.0;
> = 0;
uniform float Downlimit <
	ui_type = "slider";
	ui_min = 0.0; ui_max = 1.0;
> = 1;
uniform float LeftLimit <
	ui_type = "slider";
	ui_min = 0.0; ui_max = 1.0;
> = 0;
uniform float Rightlimit <
	ui_type = "slider";
	ui_min = 0.0; ui_max = 1.0;
> = 1;
uniform float LenLimit <
	ui_type = "slider";
	ui_min = 0.0; ui_max = 0.5;
> = 0.050;
uniform float LenLimitSquare <
	ui_type = "slider";
	ui_min = 0.0; ui_max = 0.5;
> = 0.150;

#include "ReShade.fxh"
texture TargetPS1 { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA16; };
sampler SamplerPS1 { Texture = TargetPS1; }; 
//texture TargetPS2 { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA8; };
//sampler SamplerPS2 { Texture = TargetPS2; }; 
texture TargetMask { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA16; };
sampler SamplerMask { Texture = TargetMask; }; 
bool Equal(float4 a, float4 b)
{
    return (abs(a.r-b.r)+abs(a.g-b.g)+abs(a.b-b.b)<=(ThresoldDiffBetweenPixels/10));
}
float2 LREdgesExample(float2 texcoord)
{
	float4 CurrentPixel = tex2D(ReShade::BackBuffer, texcoord).rgba;
	float4 NextPixel;
	float2 texcoord2;
	texcoord2.x=texcoord.x;
	texcoord2.y=texcoord.x;
	bool foundL = false;
	bool foundR = false;
    [loop]
    for(float i=(1.0/BUFFER_WIDTH);i<=(1.0/BUFFER_WIDTH)*128;i+=(1.0/BUFFER_WIDTH))
    {
    	if(!foundL)
        {
	        NextPixel=tex2D(ReShade::BackBuffer,float2(texcoord.x-i,texcoord.y)).rgba;
 	       if(!Equal(CurrentPixel,NextPixel))
 	       {
        		if(texcoord.x-i>LeftLimit)
				texcoord2.y = texcoord.x-i;//leftedge in y;
				foundL = true;
		    }
        }
    	if(!foundR)
        {
	        NextPixel=tex2D(ReShade::BackBuffer,float2(texcoord.x+i,texcoord.y)).rgba;
 	       if(!Equal(CurrentPixel,NextPixel))
 	       {
        		if(texcoord.x+i<Rightlimit)
				texcoord2.x = texcoord.x+i;//rightedge in x;
				foundR = true;
		    }
        }
    }
	return texcoord2;
}

float4 UDLREdges(float2 texcoord)
{
	float4 CurrentPixel = tex2D(ReShade::BackBuffer, texcoord).rgba;
	float4 NextPixel;
	float4 texcoord2;
	texcoord2.r=texcoord.y;
	texcoord2.g=texcoord.y;
	texcoord2.b=texcoord.x;
	texcoord2.a=texcoord.x;
	bool foundU = false;
	bool foundD = false;
	bool foundL = false;
	bool foundR = false;
    [loop]
    for(float i=(1.0/BUFFER_HEIGHT),j=(1.0/BUFFER_WIDTH);i<=(1.0/BUFFER_HEIGHT)*128;i+=(1.0/BUFFER_HEIGHT),j+=(1.0/BUFFER_WIDTH))
    {
    	if(!foundU)
        {
	        NextPixel=tex2D(ReShade::BackBuffer,float2(texcoord.x,texcoord.y-i)).rgba;
 	       if(!Equal(CurrentPixel,NextPixel))
 	       {
        		if(texcoord.y-i>UpLimit)
				texcoord2.r = texcoord.y-i;//upedge in r;
				foundU = true;
		    }
        }
    	if(!foundD)
        {
	        NextPixel=tex2D(ReShade::BackBuffer,float2(texcoord.x,texcoord.y+i)).rgba;
 	       if(!Equal(CurrentPixel,NextPixel))
 	       {
        		if(texcoord.y+i<Downlimit)
				texcoord2.g = texcoord.y+i;//downedge in g;
				foundD = true;
		    }
        }
    	if(!foundL)
        {
	        NextPixel=tex2D(ReShade::BackBuffer,float2(texcoord.x-j,texcoord.y)).rgba;
 	       if(!Equal(CurrentPixel,NextPixel))
 	       {
        		if(texcoord.x-j>LeftLimit)
				texcoord2.b = texcoord.x-j;//leftedge in b;
				foundL = true;
		    }
        }
    	if(!foundR)
        {
	        NextPixel=tex2D(ReShade::BackBuffer,float2(texcoord.x+j,texcoord.y)).rgba;
 	       if(!Equal(CurrentPixel,NextPixel))
 	       {
        		if(texcoord.x+j<Rightlimit)
				texcoord2.a = texcoord.x+j;//rightedge in a;
				foundR = true;
		    }
        }
    }
	return texcoord2;
}

float2 UDEdges(float2 texcoord)
{
	float4 CurrentPixel = tex2D(ReShade::BackBuffer, texcoord).rgba;
	float4 NextPixel;
	float2 texcoord2;
	texcoord2.x=texcoord.y;
	texcoord2.y=texcoord.y;
	bool foundU = false;
	bool foundD = false;
    [loop]
    for(float i=(1.0/BUFFER_HEIGHT);i<=(1.0/BUFFER_HEIGHT)*128;i+=(1.0/BUFFER_HEIGHT))
    {
    	if(!foundU)
        {
	        NextPixel=tex2D(ReShade::BackBuffer,float2(texcoord.x,texcoord.y-i)).rgba;
 	       if(!Equal(CurrentPixel,NextPixel))
 	       {
        		if(texcoord.y-i>UpLimit)
				texcoord2.y = texcoord.y-i;//upedge in y;
				foundU = true;
		    }
        }
    	if(!foundD)
        {
	        NextPixel=tex2D(ReShade::BackBuffer,float2(texcoord.x,texcoord.y+i)).rgba;
 	       if(!Equal(CurrentPixel,NextPixel))
 	       {
        		if(texcoord.y+i<Downlimit)
				texcoord2.x = texcoord.y+i;//downedge in x;
				foundD = true;
		    }
        }
    }
	return texcoord2;
}
float2 UpEdge(float2 texcoord)
{
	float4 CurrentPixel = tex2D(ReShade::BackBuffer, texcoord).rgba;
	float4 NextPixel;
	bool found = false;
    [loop]
    for(float i=(1.0/BUFFER_HEIGHT);i<=(1.0/BUFFER_HEIGHT)*128;i+=(1.0/BUFFER_HEIGHT))
    {
       	if(!found)
        {
        NextPixel=tex2D(ReShade::BackBuffer,float2(texcoord.x,texcoord.y-i)).rgba;
        if(!Equal(CurrentPixel,NextPixel))
        {
        		if(texcoord.y-i>UpLimit)
				texcoord = float2(texcoord.x,texcoord.y-i);
				found = true;
				//i=((1.0/BUFFER_HEIGHT)*127);
				//i=i+0.1;
                //return texcoord;
	    }
        }
    }
	return texcoord;
}
float2 DownEdge(float2 texcoord)
{
	float4 CurrentPixel = tex2D(ReShade::BackBuffer, texcoord).rgba;
	float4 NextPixel;
	bool found = false;
    [loop]
    for(float i=(1.0/BUFFER_HEIGHT);i<=(1.0/BUFFER_HEIGHT)*128;i+=(1.0/BUFFER_HEIGHT))
    {
       	if(!found)
        {
        NextPixel=tex2D(ReShade::BackBuffer,float2(texcoord.x,texcoord.y+i)).rgba;
        if(!Equal(CurrentPixel,NextPixel))
        {
        		if(texcoord.y+i<Downlimit)
				texcoord = float2(texcoord.x,texcoord.y+i);
				found = true;
                //return texcoord;
	    }
        }
    }
	return texcoord;
}

float2 LeftEdge(float2 texcoord)
{
	float4 CurrentPixel = tex2D(ReShade::BackBuffer, texcoord).rgba;
	float4 NextPixel;
	bool found = false;
    [loop]
    for(float i=(1.0/BUFFER_WIDTH);i<=(1.0/BUFFER_WIDTH)*128;i+=(1.0/BUFFER_WIDTH))
    {
       	if(!found)
        {
        NextPixel=tex2D(ReShade::BackBuffer,float2(texcoord.x-i,texcoord.y)).rgba;
        if(!Equal(CurrentPixel,NextPixel))
        {
        		if(texcoord.x-i>LeftLimit)
				texcoord = float2(texcoord.x-i,texcoord.y);
				found = true;
				//[unroll]
				//i=1;
                //return texcoord;
	    }
        }
    }
	return texcoord;
}
float2 LREdges(float2 texcoord)
{
	float4 CurrentPixel = tex2D(ReShade::BackBuffer, texcoord).rgba;
	float4 NextPixel;
	float2 texcoord2;
	texcoord2.x=texcoord.x;
	texcoord2.y=texcoord.x;
	bool foundL = false;
	bool foundR = false;
    [loop]
    for(float i=(1.0/BUFFER_WIDTH);i<=(1.0/BUFFER_WIDTH)*128;i+=(1.0/BUFFER_WIDTH))
    {
    	if(!foundL)
        {
	        NextPixel=tex2D(ReShade::BackBuffer,float2(texcoord.x-i,texcoord.y)).rgba;
 	       if(!Equal(CurrentPixel,NextPixel))
 	       {
        		if(texcoord.x-i>LeftLimit)
				texcoord2.y = texcoord.x-i;//leftedge in y;
				foundL = true;
		    }
        }
    	if(!foundR)
        {
	        NextPixel=tex2D(ReShade::BackBuffer,float2(texcoord.x+i,texcoord.y)).rgba;
 	       if(!Equal(CurrentPixel,NextPixel))
 	       {
        		if(texcoord.x+i<Rightlimit)
				texcoord2.x = texcoord.x+i;//rightedge in x;
				foundR = true;
		    }
        }
    }
	return texcoord2;
}

float2 RightEdge(float2 texcoord)
{
	float4 CurrentPixel = tex2D(ReShade::BackBuffer, texcoord).rgba;
	float4 NextPixel;
	bool found = false;
    [loop]
    for(float i=(1.0/BUFFER_WIDTH);i<=(1.0/BUFFER_WIDTH)*128;i+=(1.0/BUFFER_WIDTH))
    {
       	if(!found)
        {
        NextPixel=tex2D(ReShade::BackBuffer,float2(texcoord.x+i,texcoord.y)).rgba;
        if(!Equal(CurrentPixel,NextPixel))
        {
        		if(texcoord.x+i<Rightlimit)
				texcoord = float2(texcoord.x+i,texcoord.y);
				found = true;
                //return texcoord;
	    }
        }
    }
	return texcoord;
}
float4 Mask(float4 vois : SV_Position, float2 texcoord : TexCoord) : SV_Target
{
	
//    float4 msk = tex2D(ReShade::BackBuffer, texcoord).rgba;
//    float4 UDLREdges2 = UDLREdges(texcoord);
//    msk.r= UDLREdges2.r;
//    msk.g= UDLREdges2.g;
//    msk.b= UDLREdges2.b;
//    msk.a= UDLREdges2.a;
//    return msk;
   
    return UDLREdges(texcoord);
}
float3 DePixel(float4 vois : SV_Position, float2 texcoord : TexCoord) : SV_Target
{
    float3 col = tex2D(ReShade::BackBuffer, texcoord).rgb;
    //float2 current  = texcoord;
    //float2 upedge   = UpEdge  (texcoord);    
//    float4 UDEdges2 = UDLREdges(texcoord);
    float4 UDEdges2 = tex2D(SamplerMask,texcoord).rgba;
    float2 upedge;
    upedge.x=texcoord.x;
    upedge.y=UDEdges2.r;//upedge in r
//    upedge.y=UpEdge  (texcoord).y;

    //float2 downedge = DownEdge(texcoord);
    float2 downedge;
    downedge.x = texcoord.x;
    downedge.y = UDEdges2.g;//downedge in g
//    downedge.y = DownEdge(texcoord).y;
    float2 centery  = (upedge+downedge)/2;
//	if(texcoord.y!=centery.y)
    float lenght = abs(downedge.y-upedge.y);
    //near square pixel test
	float2 leftedge;
	leftedge.y=texcoord.y;
	leftedge.x=UDEdges2.b;//leftedge in b
	float2 rightedge;
	rightedge.y=texcoord.y;
	rightedge.x=UDEdges2.a;//rightedge in a
    
    float lenght2= abs(rightedge.x-leftedge.x);
    //near square pixel test
    
    //if(lenght
    if(abs(lenght-lenght2)<=LenLimitSquare)    //near square pixel test
    if(centery.y-upedge.y!=0&&downedge.y-centery.y!=0)
    if(texcoord.y<=centery.y)
    {
    	//float realcentery
    	float lenghtu=abs(tex2D(SamplerMask,upedge).g-tex2D(SamplerMask,upedge).r);
    	if((lenght-lenghtu)<=LenLimit)
//    	{
//    		centery.y-=abs(lenght-lenghtu);
//		}
    	{
	    float lerpstep=1/(centery.y-upedge.y);
	    	  lerpstep=lerpstep*(texcoord.y-upedge.y);
	    	  float3 ColorUpEdge=tex2D(ReShade::BackBuffer, upedge).rgb;
	    	  float3 Blended50Color=(ColorUpEdge+col)/2;
	    	  col=lerp(Blended50Color,col,lerpstep);
	    }
	    	  //col=Blended50Color;
	}
	else
	{
    	float lenghtd=abs(tex2D(SamplerMask,downedge).g-tex2D(SamplerMask,downedge).r);
    	if((lenght-lenghtd)<=LenLimit)
    	{
	    float lerpstep=1/(downedge.y-centery.y);
	    	  lerpstep=lerpstep*(downedge.y-texcoord.y);
	    	  float3 ColorDownEdge=tex2D(ReShade::BackBuffer, downedge).rgb;
	    	  float3 Blended50Color=(ColorDownEdge+col)/2;
	    	  col=lerp(Blended50Color,col,lerpstep);	
	    }
	}
    return col;
}
float3 DePixelH(float4 vois : SV_Position, float2 texcoord : TexCoord) : SV_Target
{
    float3 col      = tex2D(ReShade::BackBuffer, texcoord).rgb;
	float3 colPS1   = tex2D(SamplerPS1         , texcoord).rgb;
//	float2 leftedge = LeftEdge ( texcoord);
//	float2 rightedge= RightEdge (texcoord);

//	float4 LREdges2 = UDLREdges(texcoord);
	float4 LREdges2 = tex2D(SamplerMask,texcoord).rgba;
	float2 leftedge;
	leftedge.y=texcoord.y;
	leftedge.x=LREdges2.b;//leftedge in b
	float2 rightedge;
	rightedge.y=texcoord.y;
	rightedge.x=LREdges2.a;//rightedge in a
	
	float2 centerx  = (leftedge+rightedge)/2;
    //float2 upedge   = UpEdge  (texcoord);    
    //float2 downedge = DownEdge(texcoord);
    //float2 centery  = (upedge+downedge)/2;

    //(centery-centerx);
	//if(abs(rightedge.x-leftedge.x-downedge.y-upedge.y)<=0.2)
//	if(texcoord.x!=centerx.x)
    //near square pixel test
    float2 upedge;
    upedge.x=texcoord.x;
    upedge.y=LREdges2.r;//upedge in r
//    upedge.y=UpEdge  (texcoord).y;

    //float2 downedge = DownEdge(texcoord);
    float2 downedge;
    downedge.x = texcoord.x;
    downedge.y = LREdges2.g;//downedge in g
    float lenght2= abs(downedge.y-upedge.y);
    
    //near square pixel test

    float lenght = abs(rightedge.x-leftedge.x);


    if(abs(lenght-lenght2)<=LenLimitSquare)    //near square pixel test
	if(centerx.x-leftedge.x!=0&&rightedge.x-centerx.x!=0)
    if(texcoord.x<centerx.x)
    {
    	float lenghtl=abs(tex2D(SamplerMask,leftedge).a-tex2D(SamplerMask,leftedge).b);
    	if((lenght-lenghtl)<=LenLimit)
    	{
	    float lerpstep=1/(centerx.x-leftedge.x);
	    	  lerpstep=lerpstep*(texcoord.x-leftedge.x);
	    	  float3 ColorLeftEdge=tex2D(SamplerPS1, leftedge).rgb;
	    	  float3 Blended50Color=(ColorLeftEdge+colPS1)/2;
	    	  col=lerp(Blended50Color,colPS1,lerpstep);
	    }
	}
	else
	{
    	float lenghtr=abs(tex2D(SamplerMask,rightedge).a-tex2D(SamplerMask,rightedge).b);
    	if((lenght-lenghtr)<=LenLimit)
    	{
	    float lerpstep=1/(rightedge.x-centerx.x);
	    	  lerpstep=lerpstep*(rightedge.x-texcoord.x);
	    	  float3 ColorRightEdge=tex2D(SamplerPS1, rightedge).rgb;
	    	  float3 Blended50Color=(ColorRightEdge+colPS1)/2;
	    	  col=lerp(Blended50Color,colPS1,lerpstep);
		}	
	}
    return col;
}

technique DePixel3
{
    pass
    {
		VertexShader = PostProcessVS;
		PixelShader = Mask;
		RenderTarget = TargetMask;
	}
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = DePixel;
		RenderTarget = TargetPS1;
	}
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = DePixelH;
		//RenderTarget = TargetPS2;
	}
}
