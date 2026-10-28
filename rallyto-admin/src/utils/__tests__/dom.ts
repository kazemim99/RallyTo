import { DOMWrapper, flushPromises } from '@vue/test-utils'

/** DOM helpers for the screen tests. Modals, drawers and dropdowns render into document.body, outside the component. */

export const page$ = () => new DOMWrapper(document.body)

export const byTestId = (id: string) => page$().find(`[data-testid="${id}"]`)

/** The native field behind a test id, whether Ant Design put the id on the field itself or on its wrapper. */
export function fieldOf(id: string, tag: 'input' | 'textarea') {
  const found = byTestId(id)
  return found.element.tagName === tag.toUpperCase() ? found : found.find(tag)
}

export async function click(target: DOMWrapper<Element>) {
  await target.trigger('click')
  await flushPromises()
}

export async function type(id: string, value: string, tag: 'input' | 'textarea' = 'input') {
  await fieldOf(id, tag).setValue(value)
  await flushPromises()
}

/**
 * Opens the select under `id` and picks the option titled `title`. Every select keeps its own dropdown in the body
 * once opened, so the most recently created matching option is the one just opened.
 */
export async function choose(id: string, title: string) {
  await page$().find(`[data-testid="${id}"] .ant-select-selector`).trigger('mousedown')
  await flushPromises()
  const options = page$().findAll(`.ant-select-item-option[title="${title}"]`)
  if (options.length === 0) throw new Error(`No option titled "${title}" for ${id}.`)
  await click(options[options.length - 1]!)
}

/** Waits real time (the similar-name lookup is debounced with a real timer). */
export const wait = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms))
