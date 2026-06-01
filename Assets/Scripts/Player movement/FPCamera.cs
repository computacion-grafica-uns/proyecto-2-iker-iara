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
    public float interactionDist = 1f;

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
        bool jump = Input.GetButtonDown("Jump");

        // Look around
        AzimuthLookaround(azimuth * mouseXSense);
        ZenithLookaround(zenith * mouseYSense);

        Cursor.visible = (toggleCursor && !Cursor.visible) || (!toggleCursor && Cursor.visible);

        // Move
        Move(h, v, sprint, jump);

        bool interact = Input.GetButtonDown("Fire1");

        if (interact)
        {        
            if (Physics.Raycast(cameraTransform.position, cameraTransform.forward, out RaycastHit hit, interactionDist))
            {
                if (hit.transform.TryGetComponent<InteractableObject>(out var interactable))
                    interactable.OnInteract();
                
                Debug.DrawRay(cameraTransform.position, cameraTransform.forward * hit.distance, Color.yellow);
                Debug.Log("Did Hit");
            }
        }
    }

    private void Move(float h, float v, bool sprint, bool jump)
    {
        float maxSpeed = sprint ? sprintSpeed : walkSpeed;
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
        cameraTransform.Rotate(new Vector3(zenithDelta, 0, 0), Space.Self);
    }
}
