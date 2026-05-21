using UnityEngine;
using UnityEditor;
using System;
using System.Linq;
using System.IO;

public class ShaderInspectorWindow : EditorWindow
{
    public static bool isOn = false;
    private const string SHADER_DEFINE_KEYWORD = "SHADER_INSPECTOR_ON";

    public static string selectedShaderPath;
    public static Material selectedMaterial;

    public static RenderTexture[] renderTextures;

    void OnEnable()
    {
        renderTextures = new RenderTexture[4];
        for (int i = 0; i < renderTextures.Length; i++)
        {
            renderTextures[i] = new RenderTexture(Screen.width, Screen.height, 24);
        }
    }

    void OnGUI()
    {
        GUILayout.Space(10);

        // ON/OFF Switch
        GUILayout.Label("Shader Inspector", EditorStyles.largeLabel);

        GUILayout.BeginHorizontal();

        GUI.enabled = ValidateTurnOn();
        if (GUILayout.Button("Turn On"))
            TurnOn();

        GUI.enabled = ValidateTurnOff();
        if (GUILayout.Button("Turn Off"))
            TurnOff();

        GUILayout.EndHorizontal();

        if (!isOn) return; // Chau chau

        // Main Content
        GUILayout.Space(10);

        if (selectedMaterial != null)
            GUILayout.Label($"Selected material: {selectedMaterial.name}");

        if (selectedShaderPath != null)
            GUILayout.Label($"Selected shader: {Path.GetFileName(selectedShaderPath)}" );

        var width  = 256;
        var height = renderTextures[0].height * width / renderTextures[0].width;

        GUILayout.BeginScrollView(Vector2.zero, false, true);
        GUILayout.Box(renderTextures[0], GUILayout.Width(width), GUILayout.Height(height));
        GUILayout.Box(renderTextures[1], GUILayout.Width(width), GUILayout.Height(height));
        GUILayout.Box(renderTextures[2], GUILayout.Width(width), GUILayout.Height(height));
        GUILayout.Box(renderTextures[3], GUILayout.Width(width), GUILayout.Height(height));
        GUILayout.EndScrollView();
    }

    void OnSelectionChange()
    {
        SelectionChange();
        Repaint();
    }

    void Update()
    {
        var cam = Camera.current;
        if (cam == null) return;

        var buffers = renderTextures.Select(rt => rt.colorBuffer).ToArray(); 
        
        cam.SetTargetBuffers(buffers, renderTextures[0].depthBuffer);
        cam.clearFlags = CameraClearFlags.SolidColor;
        cam.Render();

        Repaint(); 
    }

    static void SelectionChange()
    {
        if (!isOn) return; // Chau chau

        var selectionCount = Selection.transforms.Length;

        if (selectionCount > 0)
        {
            var selectedTransform = Selection.transforms[0];

            if (selectedTransform != null && selectedTransform.TryGetComponent<Renderer>(out var renderer)) {
                var material = renderer.sharedMaterial;
                
                SelectMaterial(material);
            }
            else
            {
                SelectMaterial(null);
            }
        }
        else
        {
            SelectMaterial(null);
        }
    }

    private static void SelectMaterial(Material material)
    {
        if (material != null)
        {
            material.EnableKeyword(SHADER_DEFINE_KEYWORD);
        }

        if (selectedMaterial != null)
        {
            selectedMaterial.DisableKeyword(SHADER_DEFINE_KEYWORD);
        }

        selectedMaterial = material;

        if (material == null)
        {
            selectedShaderPath = null;
            return;
        }

        var shaderGUID = material.shader.GetInstanceID();
        selectedShaderPath = AssetDatabase.GetAssetPath(shaderGUID);
        

    }

    #region Menu Items
    [MenuItem("Shader Inspector/Turn On", priority = 2)]
    static void TurnOn()
    {
        // Check if multiple render targets are supported
        if (!(SystemInfo.supportedRenderTargetCount > 1))
        {
            EditorUtility.DisplayDialog("Shader Inspector", "Multiple Render Targets are not supported on this platform.", "OK");
            return;
        }

        isOn = true;
        SelectionChange();
    }

    [MenuItem("Shader Inspector/Turn On", validate = true)]
    static bool ValidateTurnOn() => !isOn;

    [MenuItem("Shader Inspector/Turn Off", priority = 3)]
    static void TurnOff()
    {
        SelectMaterial(null);
        isOn = false;
    }

    [MenuItem("Shader Inspector/Turn Off", validate = true)]
    static bool ValidateTurnOff() => isOn;

    [MenuItem("Shader Inspector/Open", priority = 1)]
    static void ShowWindow()
    {
        GetWindow<ShaderInspectorWindow>("Shader Inspector");
    }
    #endregion
}
