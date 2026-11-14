__doc__ = """RealityKit's own components, set on entities next to Python ones.

```python
from scenes import *
from scenes.components import PerspectiveCameraComponent

camera = Entity("camera")
camera.components.set(PerspectiveCameraComponent(fov=40))
camera.transform.translation = Vector3(0, 0.2, 0.6)
camera.look_at(Vector3(0, 0, 0))

Scene(Entity.box(color="orange"), camera)
```

Read from an entity, a component is live: changing it changes the entity's.

```python
class Zoom(System):
    def update(self, context: SceneContext) -> None:
        for entity in context.query(PerspectiveCameraComponent):
            entity.components[PerspectiveCameraComponent].fov -= 5 * context.delta_time
```"""
__all__ = ["FieldOfViewOrientation", "FieldOfViewOrientationValue", "PerspectiveCameraComponent"]

from enum import StrEnum

import scenes
from _scenes import PerspectiveCameraComponent

PerspectiveCameraComponent.__module__ = __name__
# What `Components` and `context.query` tell native components by.
PerspectiveCameraComponent._native = "PerspectiveCameraComponent"
scenes._native_components.append(PerspectiveCameraComponent)


class FieldOfViewOrientation(StrEnum):
    """Which side of the view a camera's `fov` spans."""
    VERTICAL = "vertical"
    HORIZONTAL = "horizontal"


type FieldOfViewOrientationValue = FieldOfViewOrientation | str
