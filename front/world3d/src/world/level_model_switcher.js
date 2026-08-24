export function switchLevelModel(scene, currentObject, nextObject) {
  if (currentObject) {
    scene.remove(currentObject);
    currentObject.traverse((child) => {
      child.geometry?.dispose();
      const materials = Array.isArray(child.material) ? child.material : [child.material];
      for (const material of materials) {
        if (!material) continue;
        for (const value of Object.values(material)) value?.isTexture && value.dispose();
        material.dispose?.();
      }
    });
  }
  scene.add(nextObject);
  return nextObject;
}
