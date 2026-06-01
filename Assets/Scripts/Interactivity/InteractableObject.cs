using System;
using UnityEngine;
using UnityEngine.Events;

[RequireComponent(typeof(Collider))]
public class InteractableObject : MonoBehaviour
{
    public InteractionEvent onInteraction;

    public void OnInteract()
    {
        onInteraction.Invoke();
    }
}

[Serializable]
public class InteractionEvent : UnityEvent {}