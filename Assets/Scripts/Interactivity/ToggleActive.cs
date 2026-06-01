using UnityEngine;

public class ToggleActive : MonoBehaviour
{
    public void OnToggle()
    {
        gameObject.SetActive(!gameObject.activeSelf);
    }
}