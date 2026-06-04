using UnityEngine;

[RequireComponent(typeof(CharacterController))]
public class FPCamera : MonoBehaviour
{
    [Header("Movement")]
    public float walkSpeed = 5f;
    public float sprintSpeed = 8f;
    public float crouchSpeed = 0.5f;
    public float acceleration = 10f;
    public float jumpForce = 5f;
    public float drag = 0.8f;
    public float gravity = 9.8f;
    public float crouchHeight = 0.5f;
    public float crouchTransitionSpeed = 5f;

    [Header("Lookaround")]
    public float mouseXSense = 0.1f;
    public float mouseYSense = 0.1f;
    public float normalFOV = 60f;
    public float zoomFOV = 30f;
    public float interactionDist = 1f;
    public float maxZenith = 90f;
    public float minZenith = -90f;
    public float height = 1.8f;

    [Header("References")]
    public Camera cam;

    CharacterController cc;
    Vector3 velocity;
    float zoomT = 0f;
    float crouchT = 0f;

    void Awake()
    {
        cc = GetComponent<CharacterController>();
    }

    void LateUpdate()
    {
        // Read input
        float h = Input.GetAxisRaw("Horizontal");
        float v = Input.GetAxisRaw("Vertical");

        float azimuth = Input.GetAxisRaw("Mouse X");
        float zenith = Input.GetAxisRaw("Mouse Y");

        bool toggleCursor = Input.GetKeyDown(KeyCode.Alpha0) || Input.GetKeyDown(KeyCode.Keypad0);

        bool sprint = Input.GetKey(KeyCode.LeftShift) || Input.GetKey(KeyCode.RightShift);
        bool crouch = Input.GetKey(KeyCode.LeftControl) || Input.GetKey(KeyCode.RightControl);
        bool interact = Input.GetButtonDown("Fire1");
        bool zoom = Input.GetMouseButton(1);
        bool jump = Input.GetButtonDown("Jump");

        // Look around
        AzimuthLookaround(azimuth * mouseXSense);
        ZenithLookaround(zenith * mouseYSense);

        Cursor.visible = (toggleCursor && !Cursor.visible) || (!toggleCursor && Cursor.visible);
        Cursor.lockState = Cursor.visible ? CursorLockMode.None : CursorLockMode.Locked;

        // Crouch
        if (crouch)
        {
            h *= 0.5f;
            v *= 0.5f;
            crouchT = Mathf.Min(crouchT + Time.deltaTime * 5, 1f);
        }
        else
        {
            crouchT = Mathf.Max(crouchT - Time.deltaTime * 5, 0f);
        }

        float crouchingHeight = Mathf.Lerp(1, crouchHeight, Mathf.SmoothStep(0, 1, crouchT));
        cam.transform.localPosition = new Vector3(cam.transform.localPosition.x, height * crouchingHeight - 1f, cam.transform.localPosition.z);

        // Move
        Move(h, v, sprint, jump);

        if (interact)
        {        
            if (Physics.Raycast(cam.transform.position, cam.transform.forward, out RaycastHit hit, interactionDist))
            {
                if (hit.transform.TryGetComponent<InteractableObject>(out var interactable))
                    interactable.OnInteract();
            }
        }

        // Zoom
        if (zoom)
            zoomT = Mathf.Min(zoomT + Time.deltaTime * 5, 1f);
        else
            zoomT = Mathf.Max(zoomT - Time.deltaTime * 5, 0f);

        cam.fieldOfView = Mathf.Lerp(normalFOV, zoomFOV, Mathf.SmoothStep(0, 1, zoomT));
    }

    private void Move(float h, float v, bool sprint, bool jump)
    {
        float maxSpeed = Mathf.Lerp(sprint ? sprintSpeed : walkSpeed, crouchSpeed, crouchT);
        Vector3 movementAccel = new(h, 0, v);

        Vector3 horizontalVelocity = new(velocity.x, 0, velocity.z);
        horizontalVelocity *= Mathf.Lerp(Mathf.Max(1 - drag * Time.deltaTime, 0), 1, movementAccel.sqrMagnitude);
        horizontalVelocity += acceleration * Time.deltaTime * movementAccel;

        if (horizontalVelocity.sqrMagnitude > maxSpeed * maxSpeed)
            horizontalVelocity = horizontalVelocity.normalized * maxSpeed;

        float verticalVelocity = velocity.y;

        if (cc.isGrounded)
        {
            if (jump)
                verticalVelocity = jumpForce;
        }
        else
        {
            verticalVelocity -= gravity * Time.deltaTime;
        }

        velocity = new(horizontalVelocity.x, verticalVelocity, horizontalVelocity.z);

        cc.Move((velocity.x * transform.right + velocity.y * transform.up + velocity.z * transform.forward) * Time.deltaTime);
    }

    void AzimuthLookaround(float azimuthDelta)
    {
        transform.Rotate(new Vector3(0, azimuthDelta, 0));
    }

    void ZenithLookaround(float zenithDelta)
    {
        cam.transform.Rotate(new Vector3(zenithDelta, 0, 0), Space.Self);
    }
}
