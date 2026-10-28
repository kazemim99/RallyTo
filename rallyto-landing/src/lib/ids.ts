let next = 0

/** A page-unique id for SVG definitions (gradients), stable from build to build. */
export function uniqueId(prefix: string): string {
  next += 1
  return `${prefix}-${next}`
}
