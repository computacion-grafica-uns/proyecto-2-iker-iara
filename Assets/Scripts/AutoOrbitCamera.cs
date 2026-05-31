using UnityEngine;

public class AutoOrbitCamera : MonoBehaviour
{
    [Header("Targets")]
    public Transform[] targets;

    [Header("Orbit")]
    public float distance    = 1f;
    public float orbitSpeed  = 45f;   // degrees per second
    public float pitch       = 20f;   // fixed vertical angle

    [Header("Transition")]
    public float transitionSpeed = 5f; // how fast the camera moves to a new target

    int        _index;
    float      _yaw;
    Vector3    _currentLookTarget;
    bool       _initialized;

    void Start()
    {
        if (targets == null || targets.Length == 0) return;

        _index             = 0;
        _yaw               = 0f;
        _currentLookTarget = targets[_index].position;
        _initialized       = true;

        SnapToTarget();
    }

    void LateUpdate()
    {
        if (!_initialized || targets.Length == 0) return;

        if (Input.GetKeyDown(KeyCode.Alpha1))
            NextTarget();

        _yaw += orbitSpeed * Time.deltaTime;

        Transform tgt = targets[_index];

        // Smoothly slide the look target position (handles moving objects too)
        _currentLookTarget = Vector3.Lerp(_currentLookTarget, tgt.position, transitionSpeed * Time.deltaTime);

        float radPitch = Mathf.Deg2Rad * pitch;
        float radYaw   = Mathf.Deg2Rad * _yaw;

        Vector3 offset = new Vector3(
            Mathf.Cos(radPitch) * Mathf.Sin(radYaw),
            Mathf.Sin(radPitch),
            Mathf.Cos(radPitch) * Mathf.Cos(radYaw)
        ) * distance;

        transform.position = _currentLookTarget + offset;
        transform.LookAt(_currentLookTarget);
    }

    void NextTarget()
    {
        _index = (_index + 1) % targets.Length;
    }

    // Place the camera instantly at the current target with no lerp
    void SnapToTarget()
    {
        if (targets.Length == 0) return;

        _currentLookTarget = targets[_index].position;

        float radPitch = Mathf.Deg2Rad * pitch;
        float radYaw   = Mathf.Deg2Rad * _yaw;

        Vector3 offset = new Vector3(
            Mathf.Cos(radPitch) * Mathf.Sin(radYaw),
            Mathf.Sin(radPitch),
            Mathf.Cos(radPitch) * Mathf.Cos(radYaw)
        ) * distance;

        transform.position = _currentLookTarget + offset;
        transform.LookAt(_currentLookTarget);
    }
}
