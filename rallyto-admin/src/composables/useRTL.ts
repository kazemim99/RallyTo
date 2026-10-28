/**
 * useRTL: direction-aware helpers, ported from AsanRezerve's admin (`src/composables/useRTL.ts`).
 */
import { computed, type CSSProperties } from 'vue'
import { useLocaleStore } from '../stores/locale.store'
import { Direction } from '../types/locale.types'

export function useRTL() {
  const localeStore = useLocaleStore()

  const direction = computed(() => localeStore.direction)
  const isRTL = computed(() => direction.value === Direction.RTL)

  const side = (position: 'start' | 'end'): 'left' | 'right' =>
    (position === 'start') === isRTL.value ? 'right' : 'left'

  /** Text alignment for the start or end side. */
  function getTextAlign(position: 'start' | 'end' = 'start'): 'left' | 'right' {
    return side(position)
  }

  /** Float for the start or end side. */
  function getFloat(position: 'start' | 'end'): 'left' | 'right' {
    return side(position)
  }

  function getMarginStart(value: string): CSSProperties {
    return isRTL.value ? { marginRight: value } : { marginLeft: value }
  }

  function getMarginEnd(value: string): CSSProperties {
    return isRTL.value ? { marginLeft: value } : { marginRight: value }
  }

  function getPaddingStart(value: string): CSSProperties {
    return isRTL.value ? { paddingRight: value } : { paddingLeft: value }
  }

  function getPaddingEnd(value: string): CSSProperties {
    return isRTL.value ? { paddingLeft: value } : { paddingRight: value }
  }

  function getBorderStart(value: string): CSSProperties {
    return isRTL.value ? { borderRight: value } : { borderLeft: value }
  }

  function getBorderEnd(value: string): CSSProperties {
    return isRTL.value ? { borderLeft: value } : { borderRight: value }
  }

  function getPositionStart(value: string): CSSProperties {
    return isRTL.value ? { right: value } : { left: value }
  }

  function getPositionEnd(value: string): CSSProperties {
    return isRTL.value ? { left: value } : { right: value }
  }

  /** Flips a numeric value (a transform offset, a rotation) under RTL. */
  function flipValue(value: number): number {
    return isRTL.value ? -value : value
  }

  return {
    direction,
    isRTL,
    getTextAlign,
    getFloat,
    getMarginStart,
    getMarginEnd,
    getPaddingStart,
    getPaddingEnd,
    getBorderStart,
    getBorderEnd,
    getPositionStart,
    getPositionEnd,
    flipValue,
  }
}
