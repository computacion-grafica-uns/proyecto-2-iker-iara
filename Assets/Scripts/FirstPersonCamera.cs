using UnityEngine;

[RequireComponent(typeof(Rigidbody))]
public class FirstPersonCamera : MonoBehaviour
{
    [Header("Movement")]
    public float walkSpeed = 5f;
    public float sprintSpeed = 8f;
    public float acceleration = 10f;
    public float jumpForce = 5f;
    public LayerMask groundMask;
    public float groundCheckDistance = 0.1f;

    [Header("Lookaround")]
    public float mouseXSense = 0.1f;
    public float mouseYSense = 0.1f;

    [Header("References")]
    public Transform cameraTransform; // assign child camera here if needed

    Rigidbody rb;
    Vector3 velocityInput;
    Vector3 currentVelocity;
    bool wantJump;

    void Awake()
    {
        rb = GetComponent<Rigidbody>();
        rb.constraints = RigidbodyConstraints.FreezeRotation;
    }

    void Update()
    {
        // Read input
        float h = Input.GetAxisRaw("Horizontal");
        float v = Input.GetAxisRaw("Vertical");

        float azimuth = Input.GetAxisRaw("Mouse X");
        float zenith = Input.GetAxisRaw("Mouse Y");

        bool toggleCursor = Input.GetKeyDown(KeyCode.Alpha0) || Input.GetKeyDown(KeyCode.Keypad0);

        bool sprint = Input.GetKey(KeyCode.LeftShift) || Input.GetKey(KeyCode.RightShift);
        wantJump = wantJump || Input.GetButtonDown("Jump");

        // Build input relative to camera forward (only horizontal plane)
        Vector3 camForward = cameraTransform ? cameraTransform.forward : transform.forward;
        camForward.y = 0f;
        camForward.Normalize();
        Vector3 camRight = cameraTransform ? cameraTransform.right : transform.right;
        camRight.y = 0f;
        camRight.Normalize();

        Vector3 inputDir = (camForward * v + camRight * h);
        if (inputDir.sqrMagnitude > 1f) inputDir.Normalize();

        float targetSpeed = sprint ? sprintSpeed : walkSpeed;
        velocityInput = inputDir * targetSpeed;

        AzimuthLookaround(azimuth * mouseXSense);
        ZenithLookaround(zenith * mouseYSense);

        Cursor.visible = (toggleCursor && !Cursor.visible) || (!toggleCursor && Cursor.visible);
    }

    void FixedUpdate()
    {
        // Smooth velocity on the horizontal plane
        Vector3 horizontalVel = rb.velocity;
        horizontalVel.y = 0f;

        Vector3 desiredVel = velocityInput;
        currentVelocity = Vector3.MoveTowards(horizontalVel, desiredVel, acceleration * Time.fixedDeltaTime);

        Vector3 velChange = currentVelocity - horizontalVel;
        rb.AddForce(velChange, ForceMode.VelocityChange);

        // Jump
        if (wantJump && IsGrounded())
        {
            // zero out any downward velocity before jump
            Vector3 v = rb.velocity;
            v.y = 0f;
            rb.velocity = v;
            rb.AddForce(Vector3.up * jumpForce, ForceMode.VelocityChange);
        }

        wantJump = false;
    }

    void AzimuthLookaround(float azimuthDelta)
    {
        transform.Rotate(new Vector3(0, azimuthDelta, 0));
    }

    void ZenithLookaround(float zenithDelta)
    {
        cameraTransform.Rotate(new Vector3(zenithDelta, 0, 0), Space.Self);
    }

    bool IsGrounded()
    {
        Vector3 origin = transform.position + Vector3.up * 0.01f;
        bool isGrounded = Physics.Raycast(origin, Vector3.down, groundCheckDistance + 0.01f);
        Debug.Log("IsGrounded: " + (isGrounded ? "true" : "false"));
        return true;//isGrounded;
    }
}
