/**
 * UI state global — pub-sub minimal pentru flag-uri care trebuie partajate
 * intre componente fara context React (ex. Demo Panel din layout vs.
 * page.tsx care randeaza Constellation).
 */

type Listener<T> = (value: T) => void

class Flag<T> {
  private value: T
  private listeners = new Set<Listener<T>>()
  constructor(initial: T) {
    this.value = initial
  }
  get() {
    return this.value
  }
  set(next: T) {
    if (this.value === next) return
    this.value = next
    this.listeners.forEach((l) => l(next))
  }
  subscribe(l: Listener<T>) {
    this.listeners.add(l)
    return () => this.listeners.delete(l)
  }
}

export const constellationFlag = new Flag<boolean>(false)

export type Theme = 'dark' | 'light'

/** Citeste tema curenta din DOM (sau default dark) — safe pe server. */
export function getInitialTheme(): Theme {
  if (typeof document === 'undefined') return 'dark'
  const attr = document.documentElement.getAttribute('data-theme')
  return attr === 'light' ? 'light' : 'dark'
}

export const themeFlag = new Flag<Theme>('dark')

/** Aplica tema in DOM + persista in localStorage + notifica subscriberi. */
export function setTheme(t: Theme) {
  if (typeof document !== 'undefined') {
    document.documentElement.setAttribute('data-theme', t)
    try {
      localStorage.setItem('voltera:theme', t)
    } catch {
      /* ignora */
    }
  }
  themeFlag.set(t)
}
