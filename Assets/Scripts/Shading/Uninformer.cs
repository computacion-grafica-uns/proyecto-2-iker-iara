using System.Linq;
using UnityEngine;

[ExecuteAlways]
public class Uninformer : MonoBehaviour
{
    public Color ambientTint = Color.black;
    public int maxLights = 8;

    void Update()
    {
        var allLights = FindObjectsOfType<LightCasera>();

        var count        = allLights.Length;
        var intensities  = allLights.Select(l => l.intensity);
        var colors       = allLights.Select(l => ColorToVector4(l.color));
        var positions    = allLights.Select(l => PositionToVector4(l.transform.position));
        var forwards     = allLights.Select(l => PositionToVector4(-l.transform.forward));
        var coneCosines  = allLights.Select(l => Mathf.Cos(Mathf.Deg2Rad * l.coneAngle / 2));
        var coneFalloffs = allLights.Select(l => l.coneFalloff);
        var attenuations = allLights.Select(l => l.attenuationPower);
        var types        = allLights.Select(l => (float)l.type);

        // Pad arrays to maxLights with default values
        intensities  =  intensities.Concat(Enumerable.Repeat(0f, maxLights - count)).Take(maxLights);
        colors       =       colors.Concat(Enumerable.Repeat(Vector4.zero, maxLights - count)).Take(maxLights);
        positions    =    positions.Concat(Enumerable.Repeat(Vector4.zero, maxLights - count)).Take(maxLights);
        forwards     =     forwards.Concat(Enumerable.Repeat(Vector4.zero, maxLights - count)).Take(maxLights);
        coneCosines  =  coneCosines.Concat(Enumerable.Repeat(0f, maxLights - count)).Take(maxLights);
        coneFalloffs = coneFalloffs.Concat(Enumerable.Repeat(0f, maxLights - count)).Take(maxLights);
        attenuations = attenuations.Concat(Enumerable.Repeat(2f, maxLights - count)).Take(maxLights);
        types        =        types.Concat(Enumerable.Repeat(0f, maxLights - count)).Take(maxLights);

        Shader.SetGlobalInt("_L_Count", count);
        Shader.SetGlobalFloatArray("_L_Intensity", intensities.ToArray());
        Shader.SetGlobalVectorArray("_L_Color", colors.ToArray());
        Shader.SetGlobalVectorArray("_L_Position", positions.ToArray());
        Shader.SetGlobalVectorArray("_L_Forward", forwards.ToArray());
        Shader.SetGlobalFloatArray("_L_ConeCosine", coneCosines.ToArray());
        Shader.SetGlobalFloatArray("_L_ConeFalloff", coneFalloffs.ToArray());
        Shader.SetGlobalFloatArray("_L_Attenuation", attenuations.ToArray());
        Shader.SetGlobalFloatArray("_L_Type", types.ToArray());
        Shader.SetGlobalVector("_k_a", ambientTint);
    }

    Vector4 ColorToVector4(Color c)
    {
        return new Vector4(c.r, c.g, c.b, c.a);
    }

    Vector4 PositionToVector4(Vector3 p)
    {
        return new Vector4(p.x, p.y, p.z, 1.0f);
    }
}