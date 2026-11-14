__doc__ = """RealityKit scenes: entities, Python components, and systems that update them.

```python
import scenes
from scenes import Component, Entity, Scene, System, Vector3

class Spin(Component):
    speed = 2

class Spinner(System):
    def update(self, context):
        for entity in context.query(Spin):
            turn = entity.components[Spin].speed * context.delta_time
            entity.transform.rotation.yaw += turn

Spinner.register()

cube = Entity.box(Vector3(0.2, 0.2, 0.2), color="red")
cube.components.set(Spin())

Scene(cube)
```

RealityKit's own components, such as a camera, are in `scenes.components`."""
__all__ = [
    "CameraControl", "CameraControlValue", "Component", "Components", "Entity", "Quaternion", "Scene", "SceneContext",
    "System", "Transform", "Vector2", "Vector3", "Vector4",
]

from collections.abc import Iterator
from enum import StrEnum
from typing import TypeVar

import _scenes
from _scenes import Entity, Quaternion, Scene, SceneContext, Transform, Vector2, Vector3, Vector4

# Report the public module, not the private one they live in.
for _type in (Entity, Quaternion, Scene, SceneContext, Transform, Vector2, Vector3, Vector4):
    _type.__module__ = __name__
del _type


class CameraControl(StrEnum):
    """How a scene's camera follows gestures."""
    ORBIT = "orbit"
    PAN = "pan"
    TILT = "tilt"
    DOLLY = "dolly"


type CameraControlValue = CameraControl | str


def _declare(cls: type, declaration: str) -> None:
    # What Python adds to a native class, for its type stub.
    cls._interface = cls._interface.rstrip() + "\n\n    " + declaration


class Component:
    """Subclass to add data to entities; any attributes it has stay in Python.
    An instance belongs to one entity, and a cloned entity shares it."""

    _indices = {}
    _index = 0

    def __init_subclass__(cls, **kwargs):
        super().__init_subclass__(**kwargs)
        # By name, so a card that runs again keeps finding its entities.
        indices = Component._indices
        cls._index = indices.setdefault(_key(cls), len(indices) + 1)


# Unbound: RealityKit's components from `scenes.components` aren't `Component`s.
C = TypeVar("C")


# RealityKit's components that `scenes.components` binds, which register here.
_native_components: list = []


def _is_native(cls) -> bool:
    return isinstance(cls, type) and hasattr(cls, '_native')


class Components:
    """An entity's components, by class: Python ones, and RealityKit's from
    `scenes.components`."""

    def __init__(self, entity: Entity) -> None:
        self._entity = entity

    def set(self, component) -> None:
        """Adds it, replacing one of the same class."""
        if _is_native(type(component)):
            component._apply(self._entity)
            return
        if not isinstance(component, Component):
            raise TypeError(f"expected a Component, not {type(component).__name__}")
        self._entity._set_component(type(component)._index, component)

    def get(self, type: type[C]) -> C | None:
        if _is_native(type):
            return type._read(self._entity)
        return self._entity._component(type._index)

    def remove(self, type: type) -> None:
        if _is_native(type):
            type._remove(self._entity)
            return
        self._entity._remove_component(type._index)

    def __getitem__(self, type: type[C]) -> C:
        component = self.get(type)
        if component is None:
            raise KeyError(type.__name__)
        return component

    def __contains__(self, type: type) -> bool:
        return self.get(type) is not None

    def __iter__(self) -> Iterator:
        return iter(self._values())

    def __len__(self) -> int:
        return len(self._values())

    def _values(self) -> list:
        natives = [value for cls in _native_components if (value := cls._read(self._entity)) is not None]
        return list(self._entity._component_values()) + natives


Entity.components = property(Components, doc="The entity's Python components.")
_declare(Entity, "components: Components")


def _query(self, *components: type) -> Iterator[Entity]:
    """The scene's entities that have all of `components`: Python ones, and
    RealityKit's from `scenes.components`."""
    indices = [component._index for component in components if not _is_native(component)]
    natives = [component._native for component in components if _is_native(component)]
    return iter(self._query(indices, natives))


SceneContext.query = _query
_declare(SceneContext, "def query(self, *components: type) -> Iterator[Entity]: ...")


class System:
    """Subclass and `register()`. Like RealityKit's, it applies to every scene,
    with an instance per scene. `update` runs every frame on the main thread,
    so a slow one slows the view, and it can't be `async`. An exception is
    printed to the card that registered it, and it's unregistered."""

    def update(self, context: SceneContext) -> None:
        pass

    @classmethod
    def register(cls) -> None:
        """Registering a class of the same name replaces it, so a card can rerun."""
        instances = {}

        def step(context):
            try:
                system = instances.get(context._scene_id)
                if system is None:
                    system = instances[context._scene_id] = cls()
                system.update(context)
            except BaseException:
                cls.unregister()
                raise

        _scenes._register_system(_key(cls), step)

    @classmethod
    def unregister(cls) -> None:
        _scenes._unregister_system(_key(cls))


def _key(cls: type) -> str:
    return f"{cls.__module__}.{cls.__qualname__}"
