using UnityEngine;

// Base class for all cameras in the project.
// Owns the Update loop; subclasses implement input and movement.
public abstract class CameraController : MonoBehaviour
{
    protected Camera cam;

    protected virtual void Awake()
    {
        cam = GetComponent<Camera>();
    }

    void Update()
    {
        if (!cam.enabled) return;
        HandleInput();
        UpdateTransform();
    }

    // Read input and store it into fields (called before UpdateTransform).
    protected abstract void HandleInput();

    // Apply stored input to the camera's position/rotation.
    protected abstract void UpdateTransform();

    // SceneManager calls these to swap the active camera.
    public virtual void Activate()   { cam.enabled = true; }
    public virtual void Deactivate() { cam.enabled = false; }
}
