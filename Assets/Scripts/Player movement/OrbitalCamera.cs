using UnityEngine;

[RequireComponent(typeof(Camera))]
public class OrbitalCamera : MonoBehaviour
{
    [Header("Target")]
    public Transform defaultTarget;
    public Transform target;
    public Vector3 targetOffset = Vector3.zero;

    [Header("Distance")]
    public float distance = 5f;
    public float minDistance = 1f;
    public float maxDistance = 20f;
    public float zoomSpeed = 2f;

    [Header("Rotation")]
    public float orbitSpeed = 180f;
    public float yaw = 0f;
    public float pitch = 20f;
    public float minPitch = -20f;
    public float maxPitch = 80f;
    public bool invertY = false;

    [Header("Panning")]
    public float panSpeed = 0.5f;
    public bool allowPanning = true;

    [Header("Target Cycle")]
    public Transform[] targets = new Transform[0]; // drag objects here in the inspector
    int _targetIndex = 0;

    [Header("Selection")]
    public LayerMask selectableMask = ~0; // which layers can be selected
    public float doubleClickTime = 0.3f;  // max interval between clicks for a double-click
    public float maxSelectionDistance = 100f;

    Camera cam;

    // double-click tracking
    float lastClickTime = -1f;
    int clickCount = 0;

    void Awake()
    {
        cam = GetComponent<Camera>();
    }

    void LateUpdate()
    {
        HandleSelection();
        if (target == null) return;

        HandleZoom();
        HandleInput();
        UpdateTransform();
    }

    void HandleSelection()
    {
        if (Input.GetKeyDown(KeyCode.Escape))
        {
            target = defaultTarget;
            return;
        }

        if (Input.GetKeyDown(KeyCode.Alpha1) && targets.Length > 0)
        {
            _targetIndex = (_targetIndex + 1) % targets.Length;
            SetTarget(targets[_targetIndex]);
            return;
        }
        if (!Input.GetMouseButtonDown(0)) return; // left button down only

        float time = Time.unscaledTime;
        if (time - lastClickTime <= doubleClickTime)
        {
            clickCount++;
        }
        else
        {
            clickCount = 1;
        }
        lastClickTime = time;

        if (clickCount == 2)
        {
            // Perform raycast from camera through mouse
            Ray ray = cam.ScreenPointToRay(Input.mousePosition);
            if (Physics.Raycast(ray, out RaycastHit hit, maxSelectionDistance))
            {
                SetTarget(hit.transform);
            }
            clickCount = 0;
        }
    }

    public void SetTarget(Transform newTarget)
    {
        target = newTarget;
        targetOffset = Vector3.zero;

        // Optionally position the camera to keep the same relative angles/distance
        // Recompute yaw/pitch to focus on the new target center
        Vector3 dir = (transform.position - target.position).normalized;
        yaw = Mathf.Atan2(dir.x, dir.z) * Mathf.Rad2Deg;
        pitch = Mathf.Asin(dir.y) * Mathf.Rad2Deg;
    }

    void HandleZoom()
    {
        float scroll = Input.GetAxis("Mouse ScrollWheel");
        if (Mathf.Abs(scroll) > 0.0001f)
        {
            distance = Mathf.Clamp(distance - scroll * zoomSpeed * (distance * 0.1f), minDistance, maxDistance);
        }
    }

    void HandleInput()
    {
        Vector3 delta = new Vector3(Input.GetAxisRaw("Mouse X"), Input.GetAxisRaw("Mouse Y"), 0);
        bool rightDrag = Input.GetMouseButton(1);
        bool middleDrag = Input.GetMouseButton(2);
        bool leftDrag = Input.GetMouseButton(0);

        if (rightDrag || leftDrag)
        {
            float invert = invertY ? 1f : -1f;
            yaw += delta.x * (orbitSpeed / Screen.width) * 60f;
            pitch += delta.y * (orbitSpeed / Screen.height) * 60f * invert;
            pitch = Mathf.Clamp(pitch, minPitch, maxPitch);
        }

        if (allowPanning && (middleDrag || (leftDrag && (Input.GetKey(KeyCode.LeftAlt) || Input.GetKey(KeyCode.RightAlt)))))
        {
            Vector3 right = transform.right;
            Vector3 up = transform.up;
            float scale = panSpeed * (distance / 10f);
            Vector3 pan = (-right * delta.x / Screen.width + -up * delta.y / Screen.height) * scale * 60f;
            target.position += pan;
        }
    }

    void UpdateTransform()
    {
        Vector3 tgt = target.position + targetOffset;

        float radPitch = Mathf.Deg2Rad * pitch;
        float radYaw = Mathf.Deg2Rad * yaw;
        Vector3 dir = new Vector3(
            Mathf.Cos(radPitch) * Mathf.Sin(radYaw),
            Mathf.Sin(radPitch),
            Mathf.Cos(radPitch) * Mathf.Cos(radYaw)
        );

        Vector3 desiredPos = tgt + dir * distance;
        transform.position = desiredPos;
        transform.LookAt(tgt);
    }
}
