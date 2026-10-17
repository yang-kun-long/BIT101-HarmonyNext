const listeners: Set<() => void> = new Set();

export function observeUserRelations(listener: () => void): () => void {
  listeners.add(listener);
  return () => { listeners.delete(listener); };
}

export function notifyUserRelationsChanged(): void {
  for (const listener of listeners) listener();
}
