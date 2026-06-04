using UnityEngine;
using UnityEditor;
using System.Linq;
using System;
using Unity.VisualScripting;


public static class ShaderInspector
{
    public const int CHANNEL_COUNT = 8;
    public const int SAMPLE_SIZE = 17;
    public const int RENDER_TARGET_WIDTH = 1280;
    public const int RENDER_TARGET_HEIGHT = 1280;
    public const int DEPTHBUFFER_SIZE = 24;
    public const string SHADER_KEYWORD = "SHADER_INSPECTOR_ON";

    public static bool isOn = false;
    public static Texture2D sampleTexture;
    public static RenderTexture[] renderTextures;
    public static event Action<bool> OnOffChanged;

    private static Camera cam;

    static void Update()
    {
        if (!isOn) return;

        Render();
    }

    static void Render()
    {
        // Track scene camera
        var scene = SceneView.lastActiveSceneView;
        if (scene == null) return;

        var sceneCam = scene.camera;
        if (sceneCam == null || cam == null) return;

        cam.transform.SetPositionAndRotation(sceneCam.transform.position, sceneCam.transform.rotation);
        cam.fieldOfView = sceneCam.fieldOfView;
        cam.nearClipPlane = sceneCam.nearClipPlane;
        cam.farClipPlane = sceneCam.farClipPlane;

        // Render to all targets
        var buffers = renderTextures.Select(rt => rt.colorBuffer).ToArray();

        cam.SetTargetBuffers(buffers, renderTextures[0].depthBuffer);
        cam.clearFlags = CameraClearFlags.SolidColor;
        cam.Render();
    }

    public static Vector4 SampleAtPixel(int channel, int x, int y)
    {
        RenderTexture prevRT = RenderTexture.active;
        RenderTexture.active = renderTextures[channel];

        var sampleRect = new Rect(x - SAMPLE_SIZE / 2, y - SAMPLE_SIZE / 2, SAMPLE_SIZE, SAMPLE_SIZE);

        sampleTexture.ReadPixels(sampleRect, 0, 0);
        sampleTexture.Apply();

        RenderTexture.active = prevRT;

        Color pixelColor = sampleTexture.GetPixel(SAMPLE_SIZE / 2, SAMPLE_SIZE / 2);

        // Draw crosshair
        for (int i = 0; i < SAMPLE_SIZE; i++)
        {
            sampleTexture.SetPixel(i, SAMPLE_SIZE / 2, Color.red);
            sampleTexture.SetPixel(SAMPLE_SIZE / 2, i, Color.red);
        }

        sampleTexture.SetPixel(SAMPLE_SIZE / 2, SAMPLE_SIZE / 2, pixelColor);
        sampleTexture.Apply();

        return pixelColor;
    }

    static void SetupRenderTargets()
    {
        renderTextures = new RenderTexture[CHANNEL_COUNT];

        for (int i = 0; i < CHANNEL_COUNT; i++)
        {
            renderTextures[i] = new RenderTexture(RENDER_TARGET_WIDTH, RENDER_TARGET_HEIGHT, DEPTHBUFFER_SIZE, RenderTextureFormat.ARGBFloat)
            {
                filterMode = FilterMode.Point,
            };
        }

        sampleTexture = new Texture2D(SAMPLE_SIZE, SAMPLE_SIZE, TextureFormat.RGBAFloat, false)
        {
            filterMode = FilterMode.Point,
        };
    }

    static void DisposeRenderTargets()
    {
        if (renderTextures != null)
        {
            foreach (var rt in renderTextures)
            {
                if (rt != null)
                {
                    rt.Release();
                    UnityEngine.Object.DestroyImmediate(rt);
                }
            }
        }

        renderTextures = null;
        UnityEngine.Object.DestroyImmediate(sampleTexture);
    }

    public static void TurnOn()
    {
        // TODO: Check if the system supports _all_ required render targets
        if (SystemInfo.supportedRenderTargetCount < 2)
        {
            EditorUtility.DisplayDialog("Shader Inspector", "Multiple Render Targets are not supported on this platform.", "OK");
            return;
        }

        var cameraObj = new GameObject("ShaderInspector_Camera")
        {
            hideFlags = HideFlags.HideAndDontSave
        };
        cam = cameraObj.AddComponent<Camera>();

        SetupRenderTargets();
        Shader.EnableKeyword(SHADER_KEYWORD);
        EditorApplication.update += Update;
        EditorApplication.playModeStateChanged += HandlePlayModeChange;
        AssemblyReloadEvents.beforeAssemblyReload += TurnOff;

        OnOffChanged?.Invoke(true);
        isOn = true;
    }

    public static void TurnOff()
    {
        OnOffChanged?.Invoke(false);
        isOn = false;

        UnityEngine.Object.DestroyImmediate(cam.gameObject);
        cam = null;

        DisposeRenderTargets();
        Shader.DisableKeyword(SHADER_KEYWORD);
        EditorApplication.update -= Update;
        EditorApplication.playModeStateChanged -= HandlePlayModeChange;
        AssemblyReloadEvents.beforeAssemblyReload -= TurnOff;
    }

    static void HandlePlayModeChange(PlayModeStateChange state)
    {
        TurnOff();
    } 
}