using UnityEngine;

[RequireComponent(typeof(CharacterController))]
public class FPCamera : MonoBehaviour
{
    [Header("Movement")]
    public float walkSpeed = 5f;
    public float sprintSpeed = 8f;
    public float acceleration = 10f;
    public float jumpForce = 5f;
    public float drag = 0.8f;
    public float gravity = 9.8f;

    [Header("Lookaround")]
    public float mouseXSense = 0.1f;
    public float mouseYSense = 0.1f;

    [Header("References")]
    public Transform cameraTransform;

    CharacterController cc;
    Vector3 velocity;
    bool wantJump;

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
        wantJump = wantJump || Input.GetButtonDown("Jump");

        // Look around
        AzimuthLookaround(azimuth * mouseXSense);
        ZenithLookaround(zenith * mouseYSense);

        Cursor.visible = (toggleCursor && !Cursor.visible) || (!toggleCursor && Cursor.visible);

        // Move
        float maxSpeed = sprint ? sprintSpeed : walkSpeed;
        Vector3 movementAccel = new(h, 0, v);

        Vector3 horizontalVelocity = new(velocity.x, 0, velocity.z);
        horizontalVelocity *= Mathf.Lerp(Mathf.Max(1 - drag * Time.deltaTime, 0), 1, movementAccel.sqrMagnitude);
        horizontalVelocity += acceleration * Time.deltaTime * movementAccel;

        if (horizontalVelocity.sqrMagnitude > maxSpeed*maxSpeed)
            horizontalVelocity = horizontalVelocity.normalized * maxSpeed;

        // Jump
        float verticalVelocity = velocity.y;

        if (cc.isGrounded)
        {
            if (wantJump)
                verticalVelocity = jumpForce;
        }
        else
        {
            verticalVelocity -= gravity * Time.deltaTime;
        }

        velocity = new(horizontalVelocity.x, verticalVelocity, horizontalVelocity.z);

        cc.Move((velocity.x * transform.right + velocity.y * transform.up + velocity.z * transform.forward) * Time.deltaTime);

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
}
