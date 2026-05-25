export function normalizeSchoolTermCode(value: string): string {
  const trimmed = value.trim();
  const displayMatch = /^(\d{4}-\d{4})\s*学年\s*(\d+)\s*学期$/.exec(trimmed);
  if (displayMatch) {
    return `${displayMatch[1]}-${displayMatch[2]}`;
  }
  return trimmed;
}
