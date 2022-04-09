Shader "Custom/ShadowMap"
{
    Properties
    {
        _MainTex ("Base (RGB)", 2D) = "white" {}
    }
    CGINCLUDE 
    #include "UnityCG.cginc"
    
    struct VertexDataCalculate
    {
        float2 uv : TEXCOORD0;
        float4 vertex : SV_POSITION;
    };

    VertexDataCalculate VertexCalculate (float4 vertex : POSITION, float2 uv : TEXCOORD0)
    {
        VertexDataCalculate o;
        o.vertex = UnityObjectToClipPos(vertex);
        o.uv = uv;
        return o;
    }

    sampler2D _CameraDepthTexture;
    float4 FragmentCalculate (VertexDataCalculate i) : SV_Target{     
        float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv);
        depth = Linear01Depth(depth);
        return float4(depth.xxx,1);
    }
    ENDCG

    SubShader
    {
		Cull Off ZWrite Off ZTest Always
        pass
        {
            CGPROGRAM
            #pragma vertex VertexCalculate
            #pragma fragment FragmentCalculate
            ENDCG
        }

    }
    FallBack "Diffuse"
}
