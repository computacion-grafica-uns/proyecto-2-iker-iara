using UnityEngine;

public class LightCasera : MonoBehaviour
{
    public LightType type;
    public Color color;
    public float intensity;
    public float coneAngle;
    public float coneFalloff;
    public float attenuationPower = 2;
}

public enum LightType
{
    Point,
    Directional,
    Spot
}