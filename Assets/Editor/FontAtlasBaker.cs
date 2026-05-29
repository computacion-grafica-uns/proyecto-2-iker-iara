// FontAtlasBaker.cs — put in Editor/ folder
using UnityEngine;
using UnityEditor;

public class FontAtlasBaker : EditorWindow {
    string chars = " .:;+=xX$&龍漢語";
    Font font;
    int charH = 16;

    [MenuItem("Tools/Bake ASCII Font Atlas")]
    static void Open() => GetWindow<FontAtlasBaker>();

    void OnGUI() {
        font = EditorGUILayout.ObjectField("Font", font, typeof(Font), false) as Font;
        chars = EditorGUILayout.TextField("Characters", chars);
        charH = EditorGUILayout.IntField("Char height px", charH);
        if (GUILayout.Button("Bake")) Bake();
    }

    void Bake() {
        int n = chars.Length;
        var tex = new Texture2D(n * charH, charH, TextureFormat.R8, false);
        // ... render each char to a RenderTexture, copy to atlas column
        // (full implementation omitted for brevity — happy to expand)
        AssetDatabase.CreateAsset(tex, "Assets/ASCIIFontAtlas.asset");
    }
}