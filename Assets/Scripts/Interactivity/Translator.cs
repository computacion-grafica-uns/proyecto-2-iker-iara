using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Translator : MonoBehaviour
{
    public float speed = 1f;
    public AnimationCurve curve;
    public Vector3 localDir = Vector3.right;

    public float t = 0f;
    public float dir = 1f;
    public Vector3 originalPos;

    void Start()
    {
        originalPos = transform.position;
    }

    void LateUpdate()
    {
        if (dir != 0f)
        {
            Vector3 worldDir = transform.right * localDir.x + transform.up * localDir.y + transform.forward * localDir.z;
            Vector3 targetPos = originalPos + worldDir;

            t = Mathf.Clamp01(t + dir * speed * Time.deltaTime);

            transform.position = Vector3.Lerp(originalPos, targetPos, curve.Evaluate(t));

            if ((dir > 0 && t >= (1f - Mathf.Epsilon)) || (dir < 0 && t <= Mathf.Epsilon))
            {
                dir = 0;
            }
        }
    }

    public void OnToggle()
    {
        if (dir != 0)
            dir -= dir;
        else
            dir = -Mathf.Sign(2f*t - 1);
    }
}
