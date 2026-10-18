// Use the complete term's course keys so switching weeks never changes colors.
const COURSE_PALETTE: string[] = [
  '#4F46E5', '#059669', '#D97706', '#DC2626', '#0891B2', '#7C3AED',
  '#4D7C0F', '#DB2777', '#0284C7', '#A21CAF', '#0F766E', '#475569',
];

export function buildCourseColorMap(courseKeys: string[]): Record<string, string> {
  const keys: string[] = [];
  for (const key of courseKeys) {
    if (keys.indexOf(key) < 0) keys.push(key);
  }
  keys.sort();
  const colors: Record<string, string> = {};
  const used: number[] = [];
  for (const key of keys) {
    let hash = 2166136261 >>> 0;
    for (let i = 0; i < key.length; i++) {
      hash = Math.imul(hash ^ key.charCodeAt(i), 16777619) >>> 0;
    }
    let index = hash % COURSE_PALETTE.length;
    // Resolve palette collisions so a small timetable has distinct colors.
    if (used.length < COURSE_PALETTE.length) {
      while (used.indexOf(index) >= 0) index = (index + 1) % COURSE_PALETTE.length;
      used.push(index);
    }
    colors[key] = COURSE_PALETTE[index];
  }
  return colors;
}
