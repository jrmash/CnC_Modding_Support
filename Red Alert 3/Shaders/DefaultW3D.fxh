//////////////////////////////////////////////////////////////////////////////
// �2005 Electronic Arts Inc
//
// FX Shader for simple Phong lighting
//////////////////////////////////////////////////////////////////////////////

#define USE_INTERACTIVE_LIGHTS 1
#define SUPPORT_RECOLORING 1
//#define SUPPORT_CLOUDS 0	// disable clouds
//#define SUPPORT_FOG 0		// disable fog
//#define SUPPORT_SSAO 0	// disable SSAO
#define SUPPORT_GLOBAL_LIGHTS 1
#define SUPPORT_LOCAL_LIGHTS 1
#define MaxNumPointLights 3

#if !defined(CAST_SHADOWS)
#define CAST_SHADOWS 1		// define to 0 before to disable shadow casting
#endif

#include "Common.fxh"
#include "Gamma.fxh"
#include "SSAO.fxh"
#include "ShadowMap.fxh"

int _SasGlobal : SasGlobal
<
	string UIWidget = "None";
	int3 SasVersion = int3(1, 0, 0);
	
	int MaxLocalLights = MaxNumPointLights;
	int MaxSupportedInstancingMode = INSTANCING_MODE_ONE_PER_DRAW_CALL;
> = 0;

#if defined(EA_PLATFORM_WINDOWS) && defined(_3DSMAX_)
// ----------------------------------------------------------------------------
// SAMPLER : nhendricks : had to pull these in here for MAX to compile
// ----------------------------------------------------------------------------
#define SAMPLER_2D_BEGIN(samplerName, annotations) \
	texture samplerName \
	< \
		annotations \
	>; \
	sampler2D samplerName##Sampler = sampler_state \
	{ \
		Texture = < samplerName >;
		
#define SAMPLER_2D_END	};

#define SAMPLER( samplerName )	samplerName##Sampler

#define SAMPLER_CUBE_BEGIN(samplerName, annotations) \
	texture samplerName \
	< \
		annotations \
	>; \
	samplerCUBE samplerName##Sampler = sampler_state \
	{ \
		Texture = < samplerName >;
		
#define SAMPLER_CUBE_END };
#endif

// ----------------------------------------------------------------------------
// Skinning
// ----------------------------------------------------------------------------
#define MaxSkinningBonesPerVertex 2

#include "Skinning.fxh"

// ----------------------------------------------------------------------------
// Material parameters
// ----------------------------------------------------------------------------
float3 ColorAmbient
<
	string UIName = "Ambient Material Color";
    string UIWidget = "Color";
> = float3(1.0, 1.0, 1.0);

float3 ColorDiffuse
<
	string UIName = "Diffuse Material Color";
    string UIWidget = "Color";
> = float3(1.0, 1.0, 1.0);

float3 ColorSpecular
<
	string UIName = "Specular Material Color";
    string UIWidget = "Color";
> = float3(0.0, 0.0, 0.0);

float Shininess
<
	string UIName = "Specular Shininess";
    string UIWidget = "Slider";
    float UIMax = 100;
> = 1.0;

float3 ColorEmissive
<
	string UIName = "Emissive Material Color";
    string UIWidget = "Color";
> = float3(0.0, 0.0, 0.0);

float EmissiveHDRMultipler
<
	string UIName = "Emissive HDR Multiplier";
    string UIWidget = "Slider";
    float UIMax = 200;
> = 1.0;

float Opacity
<
	string UIName = "Opacity";
    string UIWidget = "Slider";
> = 1.0;

float EdgeFadeOut
<
	string UIName = "Edge fade out";
    string UIWidget = "Slider";
> = 0.0f;

int NumTextures
<
	string UIName = "Number of textures to use";
	int UIMin = 0;
	int UIMax = 2;
> = 1;

SAMPLER_2D_BEGIN( Texture_0,
	string UIName = "Base Texture";
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
	AddressU = Wrap;
	AddressV = Wrap;
SAMPLER_2D_END

SAMPLER_2D_BEGIN( Texture_1,
	string UIName = "Secondary Texture";
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
	AddressU = Wrap;
	AddressV = Wrap;
SAMPLER_2D_END

bool UseRecolorColors
<
	string UIName = "Allow House Color";
> = false;

bool HouseColorPulse
<
	string UIName = "House Color Pulse Enable";
> = false;

bool UseWorldCords
<
	string UIName = "World UV Enable";
> = false;
 

bool DepthWriteEnable
<
	string UIName = "Depth Write Enable";
> = true;

bool AlphaTestEnable
<
	string UIName = "Alpha Test Enable";
> = false;

bool CullingEnable
<
	string UIName = "Culling Enable";
> = true;


static const int BlendMode_Opaque = 0;
static const int BlendMode_Alpha = 1;
static const int BlendMode_Additive = 2;

int BlendMode
<
	string UIName = "Blend mode (0: opaque, 1: alpha, 2: additive)";
	int UIMin = 0;
	int UIMax = 2;
> = BlendMode_Opaque;

static const int SecTexBlend_Modulate = 0;
static const int SecTexBlend_Modulate2X = 1;
static const int SecTexBlend_AlphaBlend = 2;
static const int SecTexBlend_SpecularAlpha = 3;

int SecondaryTextureBlendMode
<
	string UIName = "Sec tex func (0: mul, 1: mul2x, 2: alph, 3: specularAlph)";
	int UIMin = 0;
	int UIMax = 3;
> = SecTexBlend_Modulate;

static const int TexCoordMapper_Direct = 0;
static const int TexCoordMapper_ScaleMove = 1;
static const int TexCoordMapper_Video = 2;
// TODO: static const int TexCoordMapper_Rotate = 3;


static const int MaxTexCoordMapper_0 = 2;

int TexCoordMapper_0
<
	string UIName = "TexMapper0 (0: direct, 1: scl/move, 2: video)";
	int UIMin = 0;
	int UIMax = MaxTexCoordMapper_0;
> = TexCoordMapper_Direct;

float4 TexCoordTransform_0
<
	string UIName = "UV0 Scl/Move";
	string UIWidget = "Spinner";
	int UIMin = -1000;
	int UIMax = 1000;
> = float4(1.0, 1.0, 0.0, 0.0);

float4 TextureAnimation_FPS_NumPerRow_LastFrame_FrameOffset_0
<
	string UIName = "UV0 Video Tex";
    string UIWidget = "Spinner";
    float4 UIMin = float4(-100, 1, 1, 0);
    float4 UIMax = float4(100, 32, 1024, 1024);
> = float4(0.0, 1.0, 1.0, 0.0);

static const int MaxTexCoordMapper_1 = 1;

int TexCoordMapper_1
<
	string UIName = "TexMapper1 (0: direct, 1: scl/move)";
	int UIMin = 0;
	int UIMax = MaxTexCoordMapper_1;
> = TexCoordMapper_Direct;

float4 TexCoordTransform_1
<
	string UIName = "UV1 Scl/Move";
	string UIWidget = "Spinner";
	int UIMin = -1000;
	int UIMax = 1000;
> = float4(1.0, 1.0, 0.0, 0.0);

// ----------------------------------------------------------------------------
// Shroud
// ----------------------------------------------------------------------------
ShroudSetup Shroud
<
	string UIWidget = "None";
#if !defined(_W3DVIEW_)
	string SasBindAddress = "Terrain.Shroud";
#endif
> = DEFAULT_SHROUD;


SAMPLER_2D_BEGIN( ShroudTexture,
	string UIWidget = "None";
	string SasBindAddress = "Terrain.Shroud.Texture";
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
    AddressU = Clamp;
    AddressV = Clamp;
SAMPLER_2D_END


// ----------------------------------------------------------------------------
// Clouds
// ----------------------------------------------------------------------------
SAMPLER_2D_BEGIN( CloudTexture,
	string UIWidget = "None";
	string SasBindAddress = "Terrain.Cloud.Texture";
	string ResourceName = "ShaderPreviewCloud.dds";
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
    AddressU = Wrap;
    AddressV = Wrap;
SAMPLER_2D_END

#if !defined(USE_INDIRECT_CONSTANT)

#if !SUPPORT_CLOUDS
float3 NoCloudMultiplier
<
	string UIWidget = "None";
	string SasBindAddress = "Terrain.Cloud.NoCloudMultiplier";
> = float3(1, 1, 1);
#endif // #if !SUPPORT_CLOUDS

float OpacityOverride
<
	string UIWidget = "None";
	string SasBindAddress = "WW3D.OpacityOverride";
> = 1.0;
#endif// #if !defined(USE_INDIRECT_CONSTANT)

// Variations for handling fog in the pixel shader
static const int FogMode_Disabled = 0;
static const int FogMode_Opaque = 1;
static const int FogMode_Additive = 2;

// ----------------------------------------------------------------------------
// Transformations
// ----------------------------------------------------------------------------
float4x4 View           : View;

#if defined(_WW3D_)
#if !defined(USE_INDIRECT_CONSTANT)
float4x4 ViewProjection
<
	string UIWidget = "None";
	string SasBindAddress = "Sas.Camera.WorldToProjection";
>;

float3 EyePosition
<
	string UIWidget = "None";
	string SasBindAddress = "Sas.Camera.Position";
>;
#endif // #if !defined(USE_INDIRECT_CONSTANT)

float4x4 GetViewProjection()
{
	return ViewProjection;
}

float3 GetEyePosition()
{
    return EyePosition;
}
#else
float4x4 Projection     : Projection;
float4x3 ViewI          : ViewInverse;

float4x4 GetViewProjection()
{
	return mul(View, Projection);
}

float3 GetEyePosition()
{
    return ViewI[3];
}
#endif

float Time : Time;

// ----------------------------------------------------------------------------
// Video texture animation. The following assumptions are made:
// - The original texture coordinates are already scaled to a subrectangle of the video texture (e.g [0, 0.25] for 4 frames per row)
// - FPS can be positive or negative, negative means anim is running backward
// ----------------------------------------------------------------------------
float2 CalculateVideoTextureOffset(float4 FPS_NumPerRow_LastFrame_FrameOffset)
{
	float fps = FPS_NumPerRow_LastFrame_FrameOffset.x;
	float numPerRow = FPS_NumPerRow_LastFrame_FrameOffset.y;
	float lastFrame = FPS_NumPerRow_LastFrame_FrameOffset.z;
	float frameOffset = FPS_NumPerRow_LastFrame_FrameOffset.w;
	
	float frameNumber = fmod(Time * fps + frameOffset, lastFrame);
	if (fps < 0)
		frameNumber = lastFrame + frameNumber; // Note frameNumber is negative when getting here.
	float2 uvOffset = float2(fmod(frameNumber, numPerRow), frameNumber / numPerRow);
	uvOffset -= frac(uvOffset); // Make this into an integer. More efficient here than performing the whole calculation with integers.
	uvOffset /= numPerRow;
	
	return uvOffset;
}


// ----------------------------------------------------------------------------
// SHADER: DEFAULT
// ----------------------------------------------------------------------------
struct VSOutput
{
	float4 Position : POSITION;
	float4 DiffuseColor_Opacity : COLOR0;
	float4 SpecularColor_Fog : COLOR1;
	float2 BaseTexCoord : TEXCOORD0;
	float2 SecondaryTexCoord : TEXCOORD1;
	float2 CloudTexCoord : TEXCOORD2;
	float2 ShroudTexCoord : TEXCOORD3;
	float4 ShadowMapTexCoord : TEXCOORD4;
	float3 MainLightDiffuseColor : TEXCOORD5;
	float3 MainLightSpecularColor : TEXCOORD6;
};

// ----------------------------------------------------------------------------
#if defined(EA_PLATFORM_PS3)
VSOutput VS(VSInputSkinningMultipleBones InSkin,
		float2 TexCoord0 : TEXCOORD0, float2 TexCoord1 : TEXCOORD1,
		float4 VertexColor: COLOR0,
		uniform int numJointsPerVertex,
		uniform int texCoordMapper_0,
		uniform int texCoordMapper_1,
		uniform bool applyHouseColor,
		uniform bool usePointLights)
{
	USE_DIRECTIONAL_LIGHT_INTERACTIVE(DirectionalLight, 0);
	
	VSOutput Out;
	
	float3 worldPosition = 0;
	float3 worldNormal = 0;

	CalculatePositionAndNormal(InSkin, numJointsPerVertex, worldPosition, worldNormal);

	Out.Position = mul(float4(worldPosition, 1), GetViewProjection());

	// Compute view direction in world space
	float3 worldEyeDir = normalize(GetEyePosition() - worldPosition);
	
#if defined(_3DSMAX_)
	// Default vertex color is 0 in Max, that's bad.
	VertexColor = 1.0;
#endif

	// Apply house color
	if (applyHouseColor)
	{
		VertexColor.xyz *= lerp(RecolorColor, float3(1.0,1.0,1.0),.25);
		
		if (HouseColorPulse)
		{
			VertexColor.xyz *= (sin(Time * 2) + 1.2);
		}
	}

	// Fade out edges.
	float boneOpacity = GetOpacity(InSkin, numJointsPerVertex);
	float viewingAngle = abs(dot(worldEyeDir, worldNormal));
	float fadeOut = smoothstep(0, EdgeFadeOut, viewingAngle) * boneOpacity;
	if (BlendMode == BlendMode_Additive)
	{
		VertexColor.xyz *= fadeOut;
	}
	else
	{
		VertexColor.a *= fadeOut;
	}

    // $Note (WSK) - diffuse light is not working yet, we simply want the opacity term for now
	float3 diffuseLight = 0;
	float3 diffuseColor = (ColorEmissive * EmissiveHDRMultipler + AmbientLightColor * ColorAmbient
		+ diffuseLight * ColorDiffuse) * VertexColor.xyz;
	
	Out.DiffuseColor_Opacity = float4(diffuseColor / 2, Opacity * OpacityOverride * VertexColor.w);

	Out.BaseTexCoord = TexCoord0;
	
	Out.ShroudTexCoord = CalculateShroudTexCoord(Shroud, worldPosition);

	return Out;
}

#else // EA_PLATFORM_WINDOWS || EA_PLATFORM_XENON

VSOutput VS(VSInputSkinningMultipleBones InSkin,
		float2 TexCoord0 : TEXCOORD0, float2 TexCoord1 : TEXCOORD1,
		float4 VertexColor: COLOR0,
		uniform int numJointsPerVertex,
		uniform int texCoordMapper_0,
		uniform int texCoordMapper_1,
		uniform bool applyHouseColor,
		uniform bool usePointLights)
{
	USE_DIRECTIONAL_LIGHT_INTERACTIVE(DirectionalLight, 0);
	
	VSOutput Out;
	
	float3 worldPosition = 0;
	float3 worldNormal = 0;

	CalculatePositionAndNormal(InSkin, numJointsPerVertex, worldPosition, worldNormal);

	ISOLATE Out.Position = mul(float4(worldPosition, 1), GetViewProjection());

	// Compute view direction in world space
	float3 worldEyeDir = normalize(GetEyePosition() - worldPosition);
	
#if defined(_3DSMAX_)
	// Default vertex color is 0 in Max, that's bad.
	VertexColor = 1.0;
#endif

	// Apply house color
	if (applyHouseColor)
	{
		VertexColor.xyz *= lerp(RecolorColor, float3(1.0,1.0,1.0),.25);
		
		if (HouseColorPulse)
		{
			VertexColor.xyz *= (sin(Time * 2) + 1.2);
		}
	}

	// Fade out edges.
	float boneOpacity = GetOpacity(InSkin, numJointsPerVertex);
	float viewingAngle = abs(dot(worldEyeDir, worldNormal));
	float fadeOut = smoothstep(0, EdgeFadeOut, viewingAngle) * boneOpacity;
	if (BlendMode == BlendMode_Additive)
	{
		VertexColor.xyz *= fadeOut;
	}
	else
	{
		VertexColor.a *= fadeOut;
	}

	// Compute light
	
	// Compute directional lights
	if (NumDirectionalLights > 0)
	{
		float3 halfEyeLightVector = normalize(DirectionalLight[0].Direction + worldEyeDir);

		float4 lighting = lit(dot(worldNormal, DirectionalLight[0].Direction),
			dot(worldNormal, halfEyeLightVector), Shininess);

		float3 lightColor = DirectionalLight[0].Color;
#if !SUPPORT_CLOUDS
		lightColor *= NoCloudMultiplier;
#endif

		float3 diffuseLight = lightColor * lighting.y;
		float3 specularLight = lightColor * lighting.z;
		
		Out.MainLightDiffuseColor = diffuseLight * ColorDiffuse * VertexColor.xyz / 2;
		Out.MainLightSpecularColor = specularLight * ColorSpecular / 2;
	}

	float3 diffuseLight = 0;
	float3 specularLight = 0;
	for (int i = 1; i < NumDirectionalLights; i++)
	{
		float3 halfEyeLightVector = normalize(DirectionalLight[i].Direction + worldEyeDir);

		float4 lighting = lit(dot(worldNormal, DirectionalLight[i].Direction),
			dot(worldNormal, halfEyeLightVector), Shininess);

		diffuseLight += DirectionalLight[i].Color * lighting.y;
		specularLight += DirectionalLight[i].Color * lighting.z;
	}

	// Compute point lights
	if (usePointLights)
	{
		for (int i = 0; i < NumPointLights; i++)
		{
			diffuseLight += CalculatePointLightDiffuse(PointLight[i], worldPosition, worldNormal);
		}
	}

	float3 diffuseColor = (ColorEmissive * EmissiveHDRMultipler + AmbientLightColor * ColorAmbient
		+ diffuseLight * ColorDiffuse) * VertexColor.xyz;
	
	Out.DiffuseColor_Opacity = float4(diffuseColor / 2, Opacity * OpacityOverride * VertexColor.w);
	Out.SpecularColor_Fog.xyz = specularLight * ColorSpecular / 2;

	// Set base texture coordinate	
	Out.BaseTexCoord = TexCoord0;
	if (texCoordMapper_0 == TexCoordMapper_ScaleMove)
	{
		// Scale with animated offset on texture coordinates 0
		Out.BaseTexCoord = Out.BaseTexCoord * TexCoordTransform_0.xy + Time * TexCoordTransform_0.zw;
	}
	else if (texCoordMapper_0 == TexCoordMapper_Video)
	{
		Out.BaseTexCoord += CalculateVideoTextureOffset(TextureAnimation_FPS_NumPerRow_LastFrame_FrameOffset_0);
	}

	Out.SecondaryTexCoord = TexCoord1;
	if (UseWorldCords)
 	{
 		Out.SecondaryTexCoord = worldPosition.xy;
 	}	
	if (texCoordMapper_1 == TexCoordMapper_ScaleMove)
	{
		// Scale with animated offset on texture coordinates 0
		Out.SecondaryTexCoord = Out.SecondaryTexCoord * TexCoordTransform_1.xy + Time * TexCoordTransform_1.zw;
	}
	
	// Calculate cloud layer coordinates
#if SUPPORT_CLOUDS
	Out.CloudTexCoord = CalculateCloudTexCoord(Cloud, worldPosition, Time);
#else
	Out.CloudTexCoord = float2( 1.0, 1.0 );
#endif
	
	// Calculate shroud texture coordinates
	Out.ShroudTexCoord = CalculateShroudTexCoord(Shroud, worldPosition);

	// Calculate shadow map texture coordinates	
	Out.ShadowMapTexCoord = CalculateShadowMapTexCoord(worldPosition);

	// Calculate fog
#if SUPPORT_FOG
	Out.SpecularColor_Fog.w = CalculateFog(Fog, worldPosition, GetEyePosition());
#else
	Out.SpecularColor_Fog.w = 1.0;
#endif

	return Out;
}
#endif

// ----------------------------------------------------------------------------
#if defined(EA_PLATFORM_PS3)
float4 PS(VSOutput In, uniform int numTextures, uniform int secondaryTextureBlendMode,
		uniform int fogMode, uniform bool hasShadow, float2 vPos : PIXELLOC ) COLORTARGET
{
	float4 color = In.DiffuseColor_Opacity;
	float3 specularColor = In.SpecularColor_Fog.xyz;

	// Lighting for ps3 is not working yet
	color.xyz = 1.0.xxx;

	if (numTextures >= 1)
	{
		float4 baseTextureColor = tex2D(SAMPLER(Texture_0), In.BaseTexCoord);
		baseTextureColor.xyz = GammaToLinear(baseTextureColor.xyz);
		color *= baseTextureColor;
	}

	if (numTextures >= 2)
	{
		float4 secondaryColor = tex2D(SAMPLER(Texture_1), In.SecondaryTexCoord);
		secondaryColor.xyz = GammaToLinear(secondaryColor.xyz);

		if (secondaryTextureBlendMode == SecTexBlend_Modulate)
		{
			color.xyz *= secondaryColor;
		}
		else if (secondaryTextureBlendMode == SecTexBlend_Modulate2X)
		{
			color.xyz *= secondaryColor.xyz;
			color.xyz += color.xyz;
		}
		else if (secondaryTextureBlendMode == SecTexBlend_AlphaBlend)
		{
			color.xyz = lerp(color.xyz, secondaryColor.xyz, color.a);
		}
		else if (secondaryTextureBlendMode == SecTexBlend_SpecularAlpha)
		{
			color.xyz += specularColor * color.a;
		}
	}

	color.xyz *= tex2D( SAMPLER(ShroudTexture), In.ShroudTexCoord).x;

 	return(color);
}

#else // EA_PLATFORM_WINDOWS || EA_PLATFORM_XENON

float4 PS(VSOutput In, uniform int numTextures, uniform int secondaryTextureBlendMode,
		uniform int fogMode, uniform bool hasShadow, float2 vPos : PIXELLOC ) COLORTARGET
{
	float4 color = In.DiffuseColor_Opacity;
	float3 specularColor = In.SpecularColor_Fog.xyz;
	float fogStrength = In.SpecularColor_Fog.w;

	float3 cloud = float3(1, 1, 1);

#if defined(_WW3D_) && !defined(_W3DVIEW_) && SUPPORT_CLOUDS
	cloud = GammaToLinear(tex2D(SAMPLER(CloudTexture), In.CloudTexCoord));
#endif

	if (hasShadow)
	{
		cloud *= shadow( SAMPLER(ShadowMap), In.ShadowMapTexCoord );
	}

	color.xyz += In.MainLightDiffuseColor * cloud;
	specularColor += In.MainLightSpecularColor * cloud;

	if (numTextures < 2 || secondaryTextureBlendMode != SecTexBlend_SpecularAlpha)
		color.xyz += specularColor.xyz;

	if (numTextures >= 1)
	{
		float4 baseTextureColor = tex2D(SAMPLER(Texture_0), In.BaseTexCoord);
		baseTextureColor.xyz = GammaToLinear(baseTextureColor.xyz);
		color *= baseTextureColor;
	}

	if (numTextures >= 2)
	{
		float4 secondaryColor = tex2D(SAMPLER(Texture_1), In.SecondaryTexCoord);
		secondaryColor.xyz = GammaToLinear(secondaryColor.xyz);

		if (secondaryTextureBlendMode == SecTexBlend_Modulate)
		{
			color.xyz *= secondaryColor;
		}
		else if (secondaryTextureBlendMode == SecTexBlend_Modulate2X)
		{
			color.xyz *= secondaryColor.xyz;
			color.xyz += color.xyz;
		}
		else if (secondaryTextureBlendMode == SecTexBlend_AlphaBlend)
		{
			color.xyz = lerp(color.xyz, secondaryColor.xyz, color.a);
		}
		else if (secondaryTextureBlendMode == SecTexBlend_SpecularAlpha)
		{
			color.xyz += specularColor * color.a;
		}
	}
	
	// Overbrighten	
	color.xyz += color.xyz;
	
#if SUPPORT_SSAO
	color.xyz *= ComputeSSAO(vPos);
#endif

	// Apply fog
#if SUPPORT_FOG
	if (fogMode == FogMode_Opaque)
	{
		color.xyz = lerp(Fog.Color, color.xyz, fogStrength);
	}
	else if (fogMode == FogMode_Additive)
	{
	 	// Fog used with additive blending just needs to reduce the additive influence, not blend towards the fog color
		color.xyz *= fogStrength;
	}
#endif

	// Apply shroud
	color.xyz *= tex2D( SAMPLER(ShroudTexture), In.ShroudTexCoord);
	
	return CorrectForFrameBufferGamma(color);
}
#endif

// ----------------------------------------------------------------------------
// SHADER: VS_Xenon
// ----------------------------------------------------------------------------
VSOutput VS_Xenon(VSInputSkinningMultipleBones InSkin,
		float2 TexCoord0 : TEXCOORD0, float2 TexCoord1 : TEXCOORD1,
		float4 VertexColor: COLOR0 )
{
	return VS(	InSkin, TexCoord0, TexCoord1, VertexColor, 
				min(NumJointsPerVertex, 2), min(TexCoordMapper_0, MaxTexCoordMapper_0),
				min(TexCoordMapper_1, MaxTexCoordMapper_1),
				HasRecolorColors && UseRecolorColors,
				true);
}

// ----------------------------------------------------------------------------
// SHADER: PS_Xenon
// ----------------------------------------------------------------------------
float4 PS_Xenon( VSOutput In, float2 vPos : PIXELLOC ) : COLOR
{
	return PS( In, min( NumTextures, 2 ),
			   SecondaryTextureBlendMode,
#if SUPPORT_FOG
			   (Fog.IsEnabled ? (BlendMode == BlendMode_Additive ? FogMode_Additive : FogMode_Opaque) : FogMode_Disabled),
#else // #if SUPPORT_FOG
			   (FogMode_Disabled),
#endif // #if SUPPORT_FOG
			   HasShadow, vPos);
}

// ----------------------------------------------------------------------------
// TECHNIQUE : DEFAULT
// ----------------------------------------------------------------------------
#define VS_NumJointsPerVertex(texCoordMapper0, texCoordMapper1, applyHouseColor) \
	compile VS_3_0 VS(0, texCoordMapper0, texCoordMapper1, applyHouseColor, true), \
	compile VS_3_0 VS(1, texCoordMapper0, texCoordMapper1, applyHouseColor, true), \
	compile VS_3_0 VS(2, texCoordMapper0, texCoordMapper1, applyHouseColor, true)

DEFINE_ARRAY_MULTIPLIER( VS_Multiplier_TexCoordMapper0 = 3 );

#define VS_TexCoordMapper0(texCoordMapper1, applyHouseColor) \
	VS_NumJointsPerVertex(TexCoordMapper_Direct, texCoordMapper1, applyHouseColor), \
	VS_NumJointsPerVertex(TexCoordMapper_ScaleMove, texCoordMapper1, applyHouseColor), \
	VS_NumJointsPerVertex(TexCoordMapper_Video, texCoordMapper1, applyHouseColor)

DEFINE_ARRAY_MULTIPLIER( VS_Multiplier_TexCoordMapper1 = VS_Multiplier_TexCoordMapper0 * 3 );

#define VS_TexCoordMapper1(applyHouseColor) \
	VS_TexCoordMapper0(TexCoordMapper_Direct, applyHouseColor), \
	VS_TexCoordMapper0(TexCoordMapper_ScaleMove, applyHouseColor)

DEFINE_ARRAY_MULTIPLIER( VS_Multiplier_ApplyHouseColor = VS_Multiplier_TexCoordMapper1 * 2 );

#define VS_ApplyHouseColor \
	VS_TexCoordMapper1(false), \
	VS_TexCoordMapper1(true)

DEFINE_ARRAY_MULTIPLIER( VS_Multiplier_Final = VS_Multiplier_ApplyHouseColor * 2 );

#if SUPPORTS_SHADER_ARRAYS
vertexshader VS_Array[VS_Multiplier_Final] =
{
	VS_ApplyHouseColor
};
#endif
	
#define PS_NumTextures(secondaryTextureBlendMode, fogMode, hasShadow ) \
	compile PS_3_0 PS(0, secondaryTextureBlendMode, fogMode, hasShadow ), \
	compile PS_3_0 PS(1, secondaryTextureBlendMode, fogMode, hasShadow ), \
	compile PS_3_0 PS(2, secondaryTextureBlendMode, fogMode, hasShadow )

DEFINE_ARRAY_MULTIPLIER( PS_Multiplier_SecondaryTextureBlendMode = 3 );

#define PS_SecondaryTextureBlendMode(fogMode, hasShadow ) \
	PS_NumTextures(SecTexBlend_Modulate, fogMode, hasShadow ), \
	PS_NumTextures(SecTexBlend_Modulate2X, fogMode, hasShadow ), \
	PS_NumTextures(SecTexBlend_AlphaBlend, fogMode, hasShadow ), \
	PS_NumTextures(SecTexBlend_SpecularAlpha, fogMode, hasShadow )

DEFINE_ARRAY_MULTIPLIER( PS_Multiplier_FogMode = PS_Multiplier_SecondaryTextureBlendMode * 4 );

#define PS_FogMode(hasShadow ) \
	PS_SecondaryTextureBlendMode(FogMode_Disabled, hasShadow ), \
	PS_SecondaryTextureBlendMode(FogMode_Opaque, hasShadow ), \
	PS_SecondaryTextureBlendMode(FogMode_Additive, hasShadow )

DEFINE_ARRAY_MULTIPLIER( PS_Multiplier_NumShadows = PS_Multiplier_FogMode * 3 );

#define PS_NumShadows \
	PS_FogMode(0), \
	PS_FogMode(1)

DEFINE_ARRAY_MULTIPLIER( PS_Multiplier_Final = PS_Multiplier_NumShadows * 2 );

#if SUPPORTS_SHADER_ARRAYS
pixelshader PS_Array[PS_Multiplier_Final] =
{
	PS_NumShadows
};
#endif

technique Default
{
	pass P0
	<
		USE_EXPRESSION_EVALUATOR("DefaultW3D")
	>
	{
		VertexShader = ARRAY_EXPRESSION_VS( VS_Array, min(NumJointsPerVertex, 2)
			+ min(TexCoordMapper_0, MaxTexCoordMapper_0) * VS_Multiplier_TexCoordMapper0
			+ min(TexCoordMapper_1, MaxTexCoordMapper_1) * VS_Multiplier_TexCoordMapper1
			+ (HasRecolorColors && UseRecolorColors) * VS_Multiplier_ApplyHouseColor,
			compile VS_VERSION VS_Xenon()
		);
		PixelShader = ARRAY_EXPRESSION_PS( PS_Array, min( NumTextures, 2 )
			+ SecondaryTextureBlendMode * PS_Multiplier_SecondaryTextureBlendMode
#if SUPPORT_FOG
			+ (Fog.IsEnabled ? (BlendMode == BlendMode_Additive ? FogMode_Additive : FogMode_Opaque) : FogMode_Disabled) * PS_Multiplier_FogMode
#else // #if SUPPORT_FOG
			+ (FogMode_Disabled) * PS_Multiplier_FogMode
#endif // #if SUPPORT_FOG
			+ HasShadow * PS_Multiplier_NumShadows,
			compile PS_VERSION PS_Xenon()
		);

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		AlphaFunc = GreaterEqual;
		AlphaRef = DEFAULT_ALPHATEST_THRESHOLD;
		
#if !EXPRESSION_EVALUATOR_ENABLED
		CullMode = ( CullingEnable ? D3DCULL_CW : D3DCULL_NONE );
		AlphaBlendEnable = ( BlendMode != BlendMode_Opaque || OpacityOverride < 0.99 );
		SrcBlend = ( BlendMode == BlendMode_Additive && OpacityOverride > 0.99 ? D3DBLEND_ONE : D3DBLEND_SRCALPHA );
		DestBlend = ( BlendMode == BlendMode_Additive ? D3DBLEND_ONE : D3DBLEND_INVSRCALPHA );

		ZWriteEnable = ( DepthWriteEnable );
		AlphaTestEnable = ( AlphaTestEnable );
#endif
	}  
}

#if ENABLE_LOD

// ----------------------------------------------------------------------------
float4 PS_M(VSOutput In, uniform int numTextures, uniform int secondaryTextureBlendMode,
		uniform int fogMode, uniform bool hasShadow ) COLORTARGET
{
	float4 color = In.DiffuseColor_Opacity;
	float3 specularColor = In.SpecularColor_Fog.xyz;
	float fogStrength = In.SpecularColor_Fog.w;

	float3 cloud = float3(1, 1, 1);

#if defined(_WW3D_) && !defined(_W3DVIEW_) && SUPPORT_CLOUDS
	cloud = tex2D( SAMPLER(CloudTexture), In.CloudTexCoord);
#endif

	if (hasShadow)
	{
		cloud *= shadow( SAMPLER(ShadowMap), In.ShadowMapTexCoord );
	}

	color.xyz += In.MainLightDiffuseColor * cloud;
	specularColor += In.MainLightSpecularColor * cloud;

	if (numTextures < 2 || secondaryTextureBlendMode != SecTexBlend_SpecularAlpha)
		color.xyz += specularColor.xyz;

	if (numTextures >= 1)
	{
		color *= tex2D( SAMPLER(Texture_0), In.BaseTexCoord);
	}

	if (numTextures >= 2)
	{
		float4 secondaryColor = tex2D( SAMPLER(Texture_1), In.SecondaryTexCoord);

		if (secondaryTextureBlendMode == SecTexBlend_Modulate)
		{
			color.xyz *= secondaryColor;
		}
		else if (secondaryTextureBlendMode == SecTexBlend_Modulate2X)
		{
			color.xyz *= secondaryColor.xyz;
			color.xyz += color.xyz;
		}
		else if (secondaryTextureBlendMode == SecTexBlend_AlphaBlend)
		{
			color.xyz = lerp(color.xyz, secondaryColor.xyz, color.a);
		}
		else if (secondaryTextureBlendMode == SecTexBlend_SpecularAlpha)
		{
			color.xyz += specularColor * color.a;
		}
	}
	
	// Overbrighten	
	color.xyz += color.xyz;

	// Apply fog
#if SUPPORT_FOG
	if (fogMode == FogMode_Opaque)
	{
		color.xyz = lerp(Fog.Color, color.xyz, fogStrength);
	}
	else if (fogMode == FogMode_Additive)
	{
	 	// Fog used with additive blending just needs to reduce the additive influence, not blend towards the fog color
		color.xyz *= fogStrength;
	}
#endif

	// Apply shroud
	color.xyz *= tex2D( SAMPLER(ShroudTexture), In.ShroudTexCoord);
	
	return color;
}

// ----------------------------------------------------------------------------
// TECHNIQUE : Default Medium LOD
// ----------------------------------------------------------------------------
#define VS_M_NumJointsPerVertex(texCoordMapper0, texCoordMapper1, applyHouseColor) \
	compile VS_2_0 VS(0, texCoordMapper0, texCoordMapper1, applyHouseColor, false), \
	compile VS_2_0 VS(1, texCoordMapper0, texCoordMapper1, applyHouseColor, false), \
	compile VS_2_0 VS(2, texCoordMapper0, texCoordMapper1, applyHouseColor, false)

DEFINE_ARRAY_MULTIPLIER( VS_M_Multiplier_TexCoordMapper0 = 3 );

#define VS_M_TexCoordMapper0(texCoordMapper1, applyHouseColor) \
	VS_M_NumJointsPerVertex(TexCoordMapper_Direct, texCoordMapper1, applyHouseColor), \
	VS_M_NumJointsPerVertex(TexCoordMapper_ScaleMove, texCoordMapper1, applyHouseColor), \
	VS_M_NumJointsPerVertex(TexCoordMapper_Video, texCoordMapper1, applyHouseColor)

DEFINE_ARRAY_MULTIPLIER( VS_M_Multiplier_TexCoordMapper1 = VS_M_Multiplier_TexCoordMapper0 * 3 );

#define VS_M_TexCoordMapper1(applyHouseColor) \
	VS_M_TexCoordMapper0(TexCoordMapper_Direct, applyHouseColor), \
	VS_M_TexCoordMapper0(TexCoordMapper_ScaleMove, applyHouseColor)

DEFINE_ARRAY_MULTIPLIER( VS_M_Multiplier_ApplyHouseColor = VS_M_Multiplier_TexCoordMapper1 * 2 );

#define VS_M_ApplyHouseColor \
	VS_M_TexCoordMapper1(false), \
	VS_M_TexCoordMapper1(true)

DEFINE_ARRAY_MULTIPLIER( VS_M_Multiplier_Final = VS_M_Multiplier_ApplyHouseColor * 2 );

#if SUPPORTS_SHADER_ARRAYS
vertexshader VS_M_Array[VS_M_Multiplier_Final] =
{
	VS_M_ApplyHouseColor
};
#endif
	
#define PS_M_NumTextures(secondaryTextureBlendMode, fogMode, hasShadow ) \
	compile PS_2_0 PS_M(0, secondaryTextureBlendMode, fogMode, hasShadow ), \
	compile PS_2_0 PS_M(1, secondaryTextureBlendMode, fogMode, hasShadow ), \
	compile PS_2_0 PS_M(2, secondaryTextureBlendMode, fogMode, hasShadow )

DEFINE_ARRAY_MULTIPLIER( PS_M_Multiplier_SecondaryTextureBlendMode = 3 );

#define PS_M_SecondaryTextureBlendMode(fogMode, hasShadow ) \
	PS_M_NumTextures(SecTexBlend_Modulate, fogMode, hasShadow ), \
	PS_M_NumTextures(SecTexBlend_Modulate2X, fogMode, hasShadow ), \
	PS_M_NumTextures(SecTexBlend_AlphaBlend, fogMode, hasShadow ), \
	PS_M_NumTextures(SecTexBlend_SpecularAlpha, fogMode, hasShadow )

DEFINE_ARRAY_MULTIPLIER( PS_M_Multiplier_FogMode = PS_M_Multiplier_SecondaryTextureBlendMode * 4 );

#define PS_M_FogMode(hasShadow ) \
	PS_M_SecondaryTextureBlendMode(FogMode_Disabled, hasShadow ), \
	PS_M_SecondaryTextureBlendMode(FogMode_Opaque, hasShadow ), \
	PS_M_SecondaryTextureBlendMode(FogMode_Additive, hasShadow )

DEFINE_ARRAY_MULTIPLIER( PS_M_Multiplier_NumShadows = PS_M_Multiplier_FogMode * 3 );

#define PS_M_NumShadows \
	PS_M_FogMode(0), \
	PS_M_FogMode(1)

DEFINE_ARRAY_MULTIPLIER( PS_M_Multiplier_Final = PS_M_Multiplier_NumShadows * 2 );

#if SUPPORTS_SHADER_ARRAYS
pixelshader PS_M_Array[PS_M_Multiplier_Final] =
{
	PS_M_NumShadows
};
#endif

technique _Default_M
{
	pass P0
	<
		USE_EXPRESSION_EVALUATOR("DefaultW3D")
	>
	{
		VertexShader = ARRAY_EXPRESSION_VS( VS_M_Array, min(NumJointsPerVertex, 2)
			+ min(TexCoordMapper_0, MaxTexCoordMapper_0) * VS_M_Multiplier_TexCoordMapper0
			+ min(TexCoordMapper_1, MaxTexCoordMapper_1) * VS_M_Multiplier_TexCoordMapper1
			+ (HasRecolorColors && UseRecolorColors) * VS_M_Multiplier_ApplyHouseColor,
			compile VS_VERSION VS_Xenon()
		);
		PixelShader = ARRAY_EXPRESSION_PS( PS_M_Array, min( NumTextures, 2 )
			+ SecondaryTextureBlendMode * PS_M_Multiplier_SecondaryTextureBlendMode
#if SUPPORT_FOG
			+ (Fog.IsEnabled ? (BlendMode == BlendMode_Additive ? FogMode_Additive : FogMode_Opaque) : FogMode_Disabled) * PS_M_Multiplier_FogMode
#else // #if SUPPORT_FOG
			+ (FogMode_Disabled) * PS_M_Multiplier_FogMode
#endif // #if SUPPORT_FOG
			+ HasShadow * PS_M_Multiplier_NumShadows,
			compile PS_VERSION PS_Xenon()
		);

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		AlphaFunc = GreaterEqual;
		AlphaRef = DEFAULT_ALPHATEST_THRESHOLD;
		
#if !EXPRESSION_EVALUATOR_ENABLED
		CullMode = ( CullingEnable ? D3DCULL_CW : D3DCULL_NONE );
		AlphaBlendEnable = ( BlendMode != BlendMode_Opaque || OpacityOverride < 0.99 );
		SrcBlend = ( BlendMode == BlendMode_Additive && OpacityOverride > 0.99 ? D3DBLEND_ONE : D3DBLEND_SRCALPHA );
		DestBlend = ( BlendMode == BlendMode_Additive ? D3DBLEND_ONE : D3DBLEND_INVSRCALPHA );

		ZWriteEnable = ( DepthWriteEnable );
		AlphaTestEnable = ( AlphaTestEnable );
#endif
	}  
}

// ----------------------------------------------------------------------------
// TECHNIQUE : Default Low LOD
// ----------------------------------------------------------------------------

technique _Default_L
{
	pass P0
		<
		USE_EXPRESSION_EVALUATOR("DefaultW3D")
		>
	{
		VertexShader = ARRAY_EXPRESSION_VS( VS_M_Array, min(NumJointsPerVertex, 2)
			+ min(TexCoordMapper_0, MaxTexCoordMapper_0) * VS_M_Multiplier_TexCoordMapper0
			+ min(TexCoordMapper_1, MaxTexCoordMapper_1) * VS_M_Multiplier_TexCoordMapper1
			+ (HasRecolorColors && UseRecolorColors) * VS_M_Multiplier_ApplyHouseColor,
			compile VS_VERSION VS_Xenon()
			);
		PixelShader = ARRAY_EXPRESSION_PS( PS_M_Array, min( NumTextures, 2 )
			+ SecondaryTextureBlendMode * PS_M_Multiplier_SecondaryTextureBlendMode
			+ FogMode_Disabled * PS_M_Multiplier_FogMode // Low LOD has fog disabled
			+ HasShadow * PS_M_Multiplier_NumShadows,
			compile PS_VERSION PS_Xenon()
			);

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		AlphaFunc = GreaterEqual;
		AlphaRef = DEFAULT_ALPHATEST_THRESHOLD;

#if !EXPRESSION_EVALUATOR_ENABLED
		CullMode = ( CullingEnable ? D3DCULL_CW : D3DCULL_NONE );
		AlphaBlendEnable = ( BlendMode != BlendMode_Opaque || OpacityOverride < 0.99 );
		SrcBlend = ( BlendMode == BlendMode_Additive && OpacityOverride > 0.99 ? D3DBLEND_ONE : D3DBLEND_SRCALPHA );
		DestBlend = ( BlendMode == BlendMode_Additive ? D3DBLEND_ONE : D3DBLEND_INVSRCALPHA );

		ZWriteEnable = ( DepthWriteEnable );
		AlphaTestEnable = ( AlphaTestEnable );
#endif
	}  
}

#endif // if ENABLE_LOD

// ----------------------------------------------------------------------------
// SHADER: ShadowMap
// ----------------------------------------------------------------------------
struct VSOutput_CreateShadowMap
{
	float4 Position : POSITION;
	float Opacity : COLOR0;
	float2 BaseTexCoord : TEXCOORD0;
	float Depth : TEXCOORD1;
};

// ----------------------------------------------------------------------------
VSOutput_CreateShadowMap CreateShadowMapVS(VSInputSkinningMultipleBones InSkin,
		float2 TexCoord0 : TEXCOORD0, float4 VertexColor: COLOR0,
		uniform int numJointsPerVertex, uniform bool blendModeAdditive)
{
	VSOutput_CreateShadowMap Out;
	
	float3 worldPosition = 0;
	float3 ignoredWorldNormal;
	CalculatePositionAndNormal(InSkin, numJointsPerVertex, worldPosition, ignoredWorldNormal);
	
	ISOLATE Out.Position = mul(float4(worldPosition, 1), GetViewProjection());
	
	Out.Opacity = Opacity * OpacityOverride * VertexColor.w;
	
	// Scale with animated offset on texture coordinates 0
	Out.BaseTexCoord = TexCoord0 * TexCoordTransform_0.xy + Time * TexCoordTransform_0.zw;
	Out.BaseTexCoord += CalculateVideoTextureOffset(TextureAnimation_FPS_NumPerRow_LastFrame_FrameOffset_0);
	
	Out.Depth = mul(float4(worldPosition, 1), View).z;

	// Don't render additive objects
	if (blendModeAdditive)
	{
		Out.Position = float4(1, 1, 1, 1);
	}
	
	return Out;
}

// ----------------------------------------------------------------------------
float4 CreateShadowMapPS(VSOutput_CreateShadowMap In, uniform int numTextures, uniform bool alphaTestEnable) COLORTARGET
{
	float opacity = In.Opacity;

	if (numTextures >= 1)
	{
		opacity *= tex2D( SAMPLER(Texture_0), In.BaseTexCoord).w;
	}
	
	if (alphaTestEnable)
	{
		// Simulate alpha testing for floating point render target
		clip(opacity - ((float)DEFAULT_ALPHATEST_THRESHOLD / 255));
	}

	return In.Depth;
}

// ----------------------------------------------------------------------------
// SHADER: CreateShadowMapVS_Xenon
// ----------------------------------------------------------------------------
VSOutput_CreateShadowMap CreateShadowMapVS_Xenon( VSInputSkinningMultipleBones InSkin,
		float2 TexCoord0 : TEXCOORD0, float4 VertexColor: COLOR0 )
{
	return CreateShadowMapVS( InSkin, TexCoord0, VertexColor, min(NumJointsPerVertex, 2), BlendMode == BlendMode_Additive );
}

// ----------------------------------------------------------------------------
// SHADER: CreateShadowMapPS_Xenon
// ----------------------------------------------------------------------------
float4 CreateShadowMapPS_Xenon( VSOutput_CreateShadowMap In ) : COLOR
{
	return CreateShadowMapPS( In, min(NumTextures, 1), AlphaTestEnable || BlendMode == BlendMode_Alpha );
}

// ----------------------------------------------------------------------------
// TECHNIQUE: _CreateShadowMap
// ----------------------------------------------------------------------------
#if CAST_SHADOWS

DEFINE_ARRAY_MULTIPLIER( VSCreateShadowMap_Multiplier_NumJointsPerVertex = 1 );

#define VSCreateShadowMap_NumJointsPerVertex(blendModeAdditive) \
	compile VS_2_0 CreateShadowMapVS(0, blendModeAdditive), \
	compile VS_2_0 CreateShadowMapVS(1, blendModeAdditive), \
	compile VS_2_0 CreateShadowMapVS(2, blendModeAdditive)

DEFINE_ARRAY_MULTIPLIER( VSCreateShadowMap_Multiplier_BlendModeAdditive = 3 * VSCreateShadowMap_Multiplier_NumJointsPerVertex );

#define VSCreateShadowMap_BlendModeAdditive \
	VSCreateShadowMap_NumJointsPerVertex(false), \
	VSCreateShadowMap_NumJointsPerVertex(true)

DEFINE_ARRAY_MULTIPLIER( VSCreateShadowMap_Multiplier_Final = 2 * VSCreateShadowMap_Multiplier_BlendModeAdditive );

#if SUPPORTS_SHADER_ARRAYS
vertexshader VSCreateShadowMap_Array[VSCreateShadowMap_Multiplier_Final] =
{
	VSCreateShadowMap_BlendModeAdditive
};
#endif

#define PSCreateShadowMap_NumTextures(alphaTestEnable) \
	compile PS_2_0 CreateShadowMapPS(0, alphaTestEnable), \
	compile PS_2_0 CreateShadowMapPS(1, alphaTestEnable)

DEFINE_ARRAY_MULTIPLIER( PSCreateShadowMap_Multiplier_AlphaTestEnable = 2 );

#define PSCreateShadowMap_AlphaTestEnable \
	PSCreateShadowMap_NumTextures(false), \
	PSCreateShadowMap_NumTextures(true)

DEFINE_ARRAY_MULTIPLIER( PSCreateShadowMap_Multiplier_Final = PSCreateShadowMap_Multiplier_AlphaTestEnable * 2 );

#if SUPPORTS_SHADER_ARRAYS
pixelshader PSCreateShadowMap_Array[PSCreateShadowMap_Multiplier_Final] =
{
	PSCreateShadowMap_AlphaTestEnable
};
#endif

technique _CreateShadowMap
{
	pass P0
	<
		USE_EXPRESSION_EVALUATOR("DefaultW3D_CreateShadowMap")
	>
	{
		VertexShader = ARRAY_EXPRESSION_VS( VSCreateShadowMap_Array,
			min(NumJointsPerVertex, 2)
			+ (BlendMode == BlendMode_Additive) * VSCreateShadowMap_Multiplier_BlendModeAdditive,
			compile VS_VERSION CreateShadowMapVS_Xenon()
		);
		
		PixelShader = ARRAY_EXPRESSION_PS( PSCreateShadowMap_Array,
			min(NumTextures, 1)
			+ (AlphaTestEnable || BlendMode == BlendMode_Alpha) * PSCreateShadowMap_Multiplier_AlphaTestEnable,
			compile PS_VERSION CreateShadowMapPS_Xenon()
		);

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		AlphaBlendEnable = false;
		AlphaTestEnable = false;
		
#if !EXPRESSION_EVALUATOR_ENABLED
		ZWriteEnable = ( DepthWriteEnable );
		CullMode = ( CullingEnable ? D3DCULL_CW : D3DCULL_NONE );
#endif
	}
}

#endif // if CAST_SHADOWS
