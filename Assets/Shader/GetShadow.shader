Shader "Custom/GetShadow"
{
    Properties
    {
        _MainTex ("Base (RGB)", 2D) = "white" {}
        _Albedo("Albedo",Color) = (0.5,0.5,0.5,1)
        _DownScale("DownScale",Range(0,5)) = 1
        _WLIGHT("WLight",Range(0,10)) = 1
    }
    CGINCLUDE 
    #include "UnityCG.cginc"
    #define NUM_SAMPLES 20
    #define NUM_RINGS 10
    #define PI 3.141592653589793
    #define PI2 6.283185307179586
    
    uniform float4x4 _View2Screen;
    float4 _ShadowCameraPos;
    float4 shadowuv;
    float2 world2ShadowUV (float3 worldPos)
    {
        return ((shadowuv= mul(_View2Screen, worldPos - _ShadowCameraPos.xyz)).xy / shadowuv.w)*.5 + .5;
    } 

    sampler2D _ShadowMap;
    float4 _ShadowMap_TexelSize;
    float _DownScale, _WLIGHT;

    float rand_1to1(float x ) { 
    // -1 -1
        return frac(sin(x)*10000.0);
    }
    float rand_2to1(float2 uv ) { 
    // 0 - 1
        float a = 12.9898, b = 78.233, c = 43758.5453;
        float dt = dot( uv.xy, float2( a,b ) ), sn = fmod( dt, PI );
        return frac(sin(sn) * c);
    }
    float2 poissonDisk[NUM_SAMPLES];
    void poissonDiskSamples( float2 randomSeed ) 
    {
        float ANGLE_STEP = PI2 * float( NUM_RINGS ) / float( NUM_SAMPLES );
        float INV_NUM_SAMPLES = 1.0 / float( NUM_SAMPLES );

        float angle = rand_2to1( randomSeed ) * PI2;
        float radius = INV_NUM_SAMPLES;
        float radiusStep = radius;

        for( int i = 0; i < NUM_SAMPLES; i ++ ) 
        {
            poissonDisk[i] = float2( cos( angle ), sin( angle ) ) * pow( radius, 0.75 );
            radius += radiusStep;
            angle += ANGLE_STEP;
        }
    }

    float PCF (float curDepth, float2 coords)
    {
        poissonDiskSamples(coords);
        float filterSize = _ShadowMap_TexelSize.x * _DownScale;
        float visibility = 0.0;

        for (int i = 0; i < NUM_SAMPLES; i ++)
        {
            float2 sampleCoords = filterSize * poissonDisk[i] + coords.xy;
            float depth = tex2D(_ShadowMap, sampleCoords).x;
            
            if ( depth+0.01 > curDepth)
            {
                visibility += 1.0;
            }
        }
        visibility /= NUM_SAMPLES;
        return visibility;
    }

    float PCSS(float curDepth, float2 coords)
    {
        // STEP 1: avgblocker depth
        poissonDiskSamples(coords.xy);
        
        float blockerDepth = 0.0;
        float filterSize = _ShadowMap_TexelSize.x * _DownScale;
        int blockerNum = 0;

        for (int i = 0; i < NUM_SAMPLES; i ++)
        {
            float2 sampleCoords = filterSize * poissonDisk[i] + coords.xy;
            float depth = tex2D(_ShadowMap, sampleCoords).x ;
            
            if ( depth+0.05 < curDepth){
                blockerDepth += depth;
                blockerNum += 1;
            }
        }
        blockerDepth /= blockerNum; 

        //if(blockerDepth - curDepth > 0.01) return 1.0;
        // STEP 2: penumbra size
        float w = (curDepth - blockerDepth) *  _WLIGHT / blockerDepth;

        // STEP 3: filtering
        float filterRange = _ShadowMap_TexelSize.x * _DownScale * w *2;
        float visibility = 0.0;
        
        for (int i = 0; i < NUM_SAMPLES; i ++)
        {
            float2 sampleCoords = filterRange * poissonDisk[i] + coords.xy;
            float depth = tex2D(_ShadowMap, sampleCoords).x ;
            
            if ( depth+0.05 > curDepth){
                visibility += 1.0;
            }
        }

        visibility /= NUM_SAMPLES;
        return visibility;

    }
    float hardShadow (float curDepth, float2 coords)
    {
        float depth = tex2D(_ShadowMap, coords).x; 
        float visibility = curDepth > depth + 0.001 ? 0 : 1;
        return visibility;
    }

    struct VertexDataCalculate
    {
        float2 uv : TEXCOORD0;
        float4 vertex : SV_POSITION;
        float4 worldPos : TEXCOORD1; 
    };

    VertexDataCalculate VertexCalculate (float4 vertex : POSITION, float2 uv : TEXCOORD0)
    {
        VertexDataCalculate o;
        o.vertex = UnityObjectToClipPos(vertex);
        o.uv = uv;
        o.worldPos = mul(unity_ObjectToWorld, vertex);
        return o;
    }

    
    float4 _Albedo;
    float4x4 _ShadowCameraWorldToCameraMatrix;
    float _ShadowCameraFarPlane;
    float4 FragmentCalculate (VertexDataCalculate i) : SV_Target
    {     
        //float3 col = _Albedo * visibility;

        float4 worldPos = i.worldPos;
        float4 viewPos = mul(_ShadowCameraWorldToCameraMatrix,worldPos);

        float curDepth = -viewPos.z / _ShadowCameraFarPlane;
        float2 coords = world2ShadowUV(i.worldPos.xyz);

        //float visibility = hardShadow (curDepth, coords);
        //float visibility = PCF(curDepth, coords);
        float visibility = PCSS(curDepth, coords);

        float3 col = _Albedo.rgb * visibility;
        
        return float4(col, 1);
    }
    ENDCG

    SubShader
    {

        pass
        {
            Tags { "LightMode"="ForwardBase" }

            CGPROGRAM
            #pragma vertex VertexCalculate
            #pragma fragment FragmentCalculate
            ENDCG
        }

    }
    FallBack "Diffuse"
}

