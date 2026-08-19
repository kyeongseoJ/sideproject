export function switchLevelModel(scene, currentObject, nextObject) {
  if (currentObject) {
    scene.remove(currentObject);
  }
  scene.add(nextObject);
  return nextObject;
}
