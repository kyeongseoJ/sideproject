export function placeObject(object, transform = {}) {
  const { position, rotation, scale } = transform;

  if (position) {
    object.position.set(position.x ?? 0, position.y ?? 0, position.z ?? 0);
  }
  if (rotation) {
    object.rotation.set(rotation.x ?? 0, rotation.y ?? 0, rotation.z ?? 0);
  }
  if (scale) {
    object.scale.set(scale.x ?? 1, scale.y ?? 1, scale.z ?? 1);
  }

  return object;
}
