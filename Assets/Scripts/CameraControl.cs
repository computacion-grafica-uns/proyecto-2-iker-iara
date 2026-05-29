// ASCIIPostProcess.cs — attach to your camera
using UnityEngine;

[ExecuteInEditMode, RequireComponent(typeof(Camera))]
public class CameraControl : MonoBehaviour {
    public Material asciMat;
    public Texture2D fontAtlas;   // your baked font texture
    [Range(4, 32)] public int cellSize = 8;

    void OnRenderImage(RenderTexture src, RenderTexture dst) {
        asciMat.SetTexture("_FontTex", fontAtlas);
        asciMat.SetFloat("_CellSize", cellSize);
        Graphics.Blit(src, dst, asciMat);
    }
}