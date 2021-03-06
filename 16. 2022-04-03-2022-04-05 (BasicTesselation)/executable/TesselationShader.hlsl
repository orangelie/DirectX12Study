#ifndef NUM_DIR_LIGHTS
#define NUM_DIR_LIGHTS 3
#endif

#ifndef NUM_POINT_LIGHTS
#define NUM_POINT_LIGHTS 0
#endif

#ifndef NUM_SPOT_LIGHTS
#define NUM_SPOT_LIGHTS 0
#endif

#define MaxLights 16

struct Light
{
    float3 Strength;
    float FalloffStart; // 점광/점적광
    float3 Direction;   // 평행광/점적광
    float FalloffEnd;   // 점광/점적광
    float3 Position;    // 점광
    float SpotPower;    // 점적광
};

struct Material
{
    float4 DiffuseAlbedo; // 분산반사율: 빛이 매질을 통과할때 어떠한 빛은 흡수되고, 어떠한 빛은 분산되어 방출하지만, 이때 빛이 분산반사되는 크기
    float3 FresnelR0; // 프레넬방정식에서 사용하는 슐릭근사에서의 R0: 매질마다의 굴절률
    float Shininess; // (1 - Roughness)이며 거칠기의 반대: [0, 1]이며 0에 가까울수록 거칠고, 1에 가까울수록 매끈하다
};

float CalcAttenuation(float d, float falloffStart, float falloffEnd)
{
    // 선형 감쇠함수 (falloff End - d / falloffEnd - falloffStart)
    return saturate((falloffEnd - d) / (falloffEnd - falloffStart));
}

// 프레넬방정식에서 사용하는 슐릭근사(Schlick approximation)
float3 SchlickFresnel(float3 R0, float3 normal, float3 lightVec)
{
    // 슐릭근사: R(r) = R(0) x {(1 - R(0)) * (cos(O)^5)}
    // 람베르트 코사인법칙: cos(O) = max(L (dot) n, 0)
    // L: lightVec
    // n: normal


    float cosIncidentAngle = saturate(dot(normal, lightVec));

    float f0 = 1.0f - cosIncidentAngle;
    float3 reflectPercent = R0 + (1.0f - R0) * (f0 * f0 * f0 * f0 * f0);

    return reflectPercent;
}

float3 BlinnPhong(float3 lightStrength, float3 lightVec, float3 normal, float3 toEye, Material mat)
{
    const float m = mat.Shininess * 256.0f;
    float3 halfVec = normalize(toEye + lightVec);

    float roughnessFactor = (m + 8.0f) * pow(max(dot(halfVec, normal), 0.0f), m) / 8.0f;
    float3 fresnelFactor = SchlickFresnel(mat.FresnelR0, halfVec, lightVec);

    float3 specAlbedo = fresnelFactor * roughnessFactor;

    // LDR렌더링을 사용할것이기 때문에 반영반사율을 [0, 1]사이로 매핑
    specAlbedo = specAlbedo / (specAlbedo + 1.0f);

    return (mat.DiffuseAlbedo.rgb + specAlbedo) * lightStrength;
}

// 평행광 계산
float3 ComputeDirectionalLight(Light L, Material mat, float3 normal, float3 toEye)
{
    // 빛의 방향에 -1을 곱하면 빛벡터가 된다
    float3 lightVec = -L.Direction;

    // 람베르트 코사인법칙
    float ndotl = max(dot(lightVec, normal), 0.0f);
    float3 lightStrength = L.Strength * ndotl;

    return BlinnPhong(lightStrength, lightVec, normal, toEye, mat);
}

// 점광 계산
float3 ComputePointLight(Light L, Material mat, float3 pos, float3 normal, float3 toEye)
{
    // 뷰x투영행렬의 위치에서에서 빛의 위치방향으로 가는 벡터
    float3 lightVec = L.Position - pos;

    // 빛벡터의 길이
    float d = length(lightVec);

    // 맞는지 확인
    if (d > L.FalloffEnd)
        return 0.0f;

    // 빛벡터 일반화
    lightVec /= d;

    // 람베르트 코사인법칙
    float ndotl = max(dot(lightVec, normal), 0.0f);
    float3 lightStrength = L.Strength * ndotl;

    // 빛의세기에 선형감쇠함수의 결과값을 곱한다.
    float att = CalcAttenuation(d, L.FalloffStart, L.FalloffEnd);
    lightStrength *= att;

    return BlinnPhong(lightStrength, lightVec, normal, toEye, mat);
}

// 점적광 계산
float3 ComputeSpotLight(Light L, Material mat, float3 pos, float3 normal, float3 toEye)
{
    // 뷰x투영행렬의 위치에서에서 빛의 위치방향으로 가는 벡터
    float3 lightVec = L.Position - pos;

    // 빛벡터의 길이
    float d = length(lightVec);

    // 맞는지 확인
    if (d > L.FalloffEnd)
        return 0.0f;

    // 빛벡터 일반화
    lightVec /= d;

    // 람베르트 코사인법칙
    float ndotl = max(dot(lightVec, normal), 0.0f);
    float3 lightStrength = L.Strength * ndotl;

    // 빛의세기에 선형감쇠함수의 결과값을 곱한다.
    float att = CalcAttenuation(d, L.FalloffStart, L.FalloffEnd);
    lightStrength *= att;

    // 빛의세기에 max(-L (dot) d, 0)^s: s(L.SpotPower)를 조율함으로써 점적광원뿔의 크기를 변경할 수 있다.
    float spotFactor = pow(max(dot(-lightVec, L.Direction), 0.0f), L.SpotPower);
    lightStrength *= spotFactor;

    return BlinnPhong(lightStrength, lightVec, normal, toEye, mat);
}

float4 ComputeLighting(Light gLights[MaxLights], Material mat,
    float3 pos, float3 normal, float3 toEye,
    float3 shadowFactor)
{
    float3 result = 0.0f;

    int i = 0;

#if (NUM_DIR_LIGHTS > 0)
    for (i = 0; i < NUM_DIR_LIGHTS; ++i)
    {
        result += shadowFactor[i] * ComputeDirectionalLight(gLights[i], mat, normal, toEye);
    }
#endif

#if (NUM_POINT_LIGHTS > 0)
    for (i = NUM_DIR_LIGHTS; i < NUM_DIR_LIGHTS + NUM_POINT_LIGHTS; ++i)
    {
        result += ComputePointLight(gLights[i], mat, pos, normal, toEye);
    }
#endif

#if (NUM_SPOT_LIGHTS > 0)
    for (i = NUM_DIR_LIGHTS + NUM_POINT_LIGHTS; i < NUM_DIR_LIGHTS + NUM_POINT_LIGHTS + NUM_SPOT_LIGHTS; ++i)
    {
        result += ComputeSpotLight(gLights[i], mat, pos, normal, toEye);
    }
#endif 

    return float4(result, 0.0f);
}


Texture2D gTextures : register(t0);

SamplerState gsamPointWrap        : register(s0);
SamplerState gsamPointClamp       : register(s1);
SamplerState gsamLinearWrap       : register(s2);
SamplerState gsamLinearClamp      : register(s3);
SamplerState gsamAnisotropicWrap  : register(s4);
SamplerState gsamAnisotropicClamp : register(s5);

cbuffer cbPerObject : register(b0)
{
    float4x4 gWorld;
    float4x4 gTexTransform;
};

cbuffer cbPass : register(b1)
{
    float4x4 gView;
    float4x4 gInvView;
    float4x4 gProj;
    float4x4 gInvProj;
    float4x4 gViewProj;
    float4x4 gInvViewProj;
    float3 gEyePosW;
    float cbPerObjectPad1;
    float2 gRenderTargetSize;
    float2 gInvRenderTargetSize;
    float gNearZ;
    float gFarZ;
    float gTotalTime;
    float gDeltaTime;
    float4 gAmbientLight;
    float4 gFogColor;
    float gFogStart;
    float gFogRange;
    float2 cbPerObjectPad2;

    Light gLights[MaxLights];
};

cbuffer cbMaterial : register(b2)
{
    float4 gDiffuseAlbedo;
    float3 gFresnelR0;
    float  gRoughness;
    float4x4 gMatTransform;
};

struct VertexIn {
    float3 PosL    : POSITION;
};

struct VertexOut {
    float3 PosW    : POSITION;
};

VertexOut VS(VertexIn vin)
{
    VertexOut vout = (VertexOut)0.0f;

    vout.PosW = vin.PosL;

    return vout;
}

struct PatchTess {
    float PatchTess[4] : SV_TessFactor;
    float InsidePatchTess[2] : SV_InsideTessFactor;
};

PatchTess ConstantHS(InputPatch<VertexOut, 4> iPatch, uint primID : SV_PrimitiveID) {
    PatchTess result;
    
    float3 centerL = 0.25f * (iPatch[0].PosW + iPatch[1].PosW + iPatch[2].PosW + iPatch[3].PosW);
    float3 centerW = mul(float4(centerL, 1.0f), gWorld).xyz;

    float d = distance(gEyePosW, centerL);
    const float d0 = 20.0f;
    const float d1 = 100.0f;

    const float tess = 64.0f * saturate((d1 - d) / (d1 - d0));

    result.PatchTess[0] = tess;
    result.PatchTess[1] = tess;
    result.PatchTess[2] = tess;
    result.PatchTess[3] = tess;

    result.InsidePatchTess[0] = tess;
    result.InsidePatchTess[1] = tess;

    return result;
}

struct HullOut {
    float3 PosL : POSITION;
};

[domain("quad")]
[partitioning("integer")]
[outputtopology("triangle_cw")]
[outputcontrolpoints(4)]
[patchconstantfunc("ConstantHS")]
[maxtessfactor(64.0f)]
HullOut HS(InputPatch<VertexOut, 4> iPatch, uint i : SV_OutputControlPointID, uint primID : SV_PrimitiveID) {
    HullOut result;
    
    result.PosL = iPatch[i].PosW;

    return result;
}

struct DomainOut
{
    float4 PosH : SV_POSITION;
};

[domain("quad")]
DomainOut DS(PatchTess patchTess, float2 uv : SV_DomainLocation, const OutputPatch<HullOut, 4> quad)
{
    DomainOut dout;

    float3 v1 = lerp(quad[0].PosL, quad[1].PosL, uv.x);
    float3 v2 = lerp(quad[2].PosL, quad[3].PosL, uv.x);
    float3 p = lerp(v1, v2, uv.y);

    p.y = 0.3f * (p.z * sin(p.x) + p.x * cos(p.z));

    float4 posW = mul(float4(p, 1.0f), gWorld);
    dout.PosH = mul(posW, gViewProj);

    return dout;
}

float4 PS(DomainOut dout) : SV_Target{
    return float4(1.0f, 1.0f, 1.0f, 1.0f);
}