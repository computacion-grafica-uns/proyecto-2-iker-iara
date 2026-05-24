using UnityEngine;
using UnityEditor;
using System;
using System.Linq;
using System.IO;

public class ShaderInspectorWindow : EditorWindow
{
    public Rect rtRect;
    public int selectedChannel = 0;

    void OnGUI()
    {
        var e = Event.current;

        GUILayout.Space(10);

        if (!ShaderInspector.isOn)
        {
            EditorGUILayout.HelpBox("Shader Inspector is currently turned off. Use the menu to turn it on.", MessageType.Info);
            return;
        }

        var channels    = Enumerable.Range(0, 8).Select(i => i).ToArray();
        var channelStrs = channels.Select(i => $"Channel {i}").ToArray();
        selectedChannel = EditorGUILayout.IntPopup("", selectedChannel, channelStrs, channels);

        this.titleContent = new GUIContent($"Shader Inspector ({selectedChannel})");

        // Texture display
        GUILayout.Space(10);

        var rt = ShaderInspector.renderTextures[selectedChannel];

        var width  = this.position.width;
        var height = this.position.height - 42;
        var rtAspect = rt.width / (float)rt.height;

        if (rtAspect < width / height)
            width = height * rtAspect;
        else
            height = width / rtAspect;

        if (e.type == EventType.Repaint)
            rtRect = GUILayoutUtility.GetRect(width, height);
        else
            GUILayoutUtility.GetRect(width, height);    // Get but ignore rect for non-repaint events to avoid layout issues

        GUI.DrawTexture(rtRect, rt, ScaleMode.ScaleAndCrop, false);
        GUI.DrawTexture(new Rect(rtRect.x + 10, rtRect.y + 10, 65, 65), ShaderInspector.sampleTexture, ScaleMode.ScaleToFit, false);

        // Print pixel data on click over texture 
        if (e.type == EventType.MouseDrag && e.button == 0 && rtRect.Contains(e.mousePosition))
        {
            var rectAspect = rtRect.width / rtRect.height;
            var mousePos = e.mousePosition - rtRect.position;
            var x = Mathf.RoundToInt(mousePos.x / rtRect.width * rt.width);
            var y = Mathf.RoundToInt((1 - mousePos.y / rtRect.height) * rt.height);

            if (rtAspect < rectAspect)
                y = Mathf.RoundToInt((1 - mousePos.y / rtRect.height) * rt.height / rectAspect + (rt.height - rt.height / rectAspect) / 2);

            Vector4 pixel = ShaderInspector.SampleAtPixel(selectedChannel, x, y);

            Debug.Log($"Channel {selectedChannel} at ({x}, {y}): {pixel}");
            
            e.Use();
        }
    }

    void OnEnable()
    {
        ShaderInspector.OnOffChanged += OnShaderInspectorToggled;
    }

    void OnDisable()
    {
        ShaderInspector.OnOffChanged -= OnShaderInspectorToggled;
    }

    private void OnShaderInspectorToggled(bool newState)
    {
        Repaint();
    }

    void Update()
    {
        if (ShaderInspector.isOn) Repaint();
    }

    #region Menu Items
    [MenuItem("Shader Inspector/Turn On", priority = 2)]
    static void TurnOn() => ShaderInspector.TurnOn();

    [MenuItem("Shader Inspector/Turn On", validate = true)]
    static bool ValidateTurnOn() => !ShaderInspector.isOn;

    [MenuItem("Shader Inspector/Turn Off", priority = 3)]
    static void TurnOff() => ShaderInspector.TurnOff();

    [MenuItem("Shader Inspector/Turn Off", validate = true)]
    static bool ValidateTurnOff() => ShaderInspector.isOn;

    [MenuItem("Shader Inspector/Open", priority = 1)]
    static void ShowWindow()
    {
        var window = CreateInstance<ShaderInspectorWindow>();
        window.titleContent = new GUIContent("Shader Inspector");
        window.Show();
    }
    #endregion
}
