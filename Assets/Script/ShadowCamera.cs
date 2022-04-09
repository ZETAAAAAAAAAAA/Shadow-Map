using UnityEngine;
using System.Collections;

public class ShadowCamera : PostEffectsBase {

	public Shader shader;
	private Material ShaowMaterial = null;
	private Camera cam;
	public Material material {  
		get {
			ShaowMaterial = CheckShaderAndCreateMaterial(shader, ShaowMaterial);
			return ShaowMaterial;
		}  
	}

	void OnEnable() {
		if (cam == null) cam = GetComponent<Camera>();
		GetComponent<Camera>().depthTextureMode |= DepthTextureMode.DepthNormals;
	}

	[ImageEffectOpaque]
	void OnRenderImage (RenderTexture src, RenderTexture des) {
		if (material != null) {
			RenderTexture shadowMap = RenderTexture.GetTemporary(src.width/2, src.height/2, 0, RenderTextureFormat.ARGBFloat);

			Graphics.Blit(src, shadowMap, ShaowMaterial);
			Shader.SetGlobalTexture("_ShadowMap",shadowMap);
			Shader.SetGlobalMatrix("_View2Screen", (cam.cameraToWorldMatrix * cam.projectionMatrix.inverse).inverse);
			Shader.SetGlobalVector("_ShadowCameraPos", cam.transform.position);
			Shader.SetGlobalFloat("_ShadowCameraFarPlane", cam.farClipPlane);
			Shader.SetGlobalMatrix("_ShadowCameraProjectionMatirx", cam.projectionMatrix);
			Shader.SetGlobalMatrix("_ShadowCameraWorldToCameraMatrix", cam.worldToCameraMatrix);
			Graphics.Blit(shadowMap, des);

		} else {
			Graphics.Blit(src, des);
		}
	}
}
