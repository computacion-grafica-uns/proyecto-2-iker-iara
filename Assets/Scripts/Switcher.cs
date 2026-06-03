using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Switcher : MonoBehaviour
{
    public GameObject[] objectsToSwitch;

    void Start()
    {
        foreach (GameObject obj in objectsToSwitch)
        {
            obj.SetActive(false);
        }

        if (objectsToSwitch.Length > 0)
        {
            objectsToSwitch[0].SetActive(true);
        }
    }

    void Update()
    {
        for (int i = 0; i < objectsToSwitch.Length; i++)
        {
            if (Input.GetKeyDown(KeyCode.Alpha1 + i) || Input.GetKeyDown(KeyCode.Keypad1 + i))
            {
                for (int j = 0; j < objectsToSwitch.Length; j++)
                {
                    objectsToSwitch[j].SetActive(j == i);
                }
            }
        }
    }
}
