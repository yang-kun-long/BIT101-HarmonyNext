function errorMessage(error: Object): string {
  if (error instanceof Error) {
    return error.message;
  }
  return String(error);
}

export async function guardAsyncStorage<T>(
  operation: string,
  action: () => Promise<T>,
): Promise<T> {
  try {
    return await action();
  } catch (error) {
    throw new Error(`${operation} failed: ${errorMessage(error as Object)}`);
  }
}

export async function guardAsyncStorageOrDefault<T>(
  operation: string,
  action: () => Promise<T>,
  fallback: T,
): Promise<T> {
  try {
    return await action();
  } catch (error) {
    const _ = `${operation} failed: ${errorMessage(error as Object)}`;
    return fallback;
  }
}
