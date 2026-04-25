import { create } from 'zustand'

interface UIState {
  sidebarCollapsed: boolean
  toggleSidebar: () => void
  darkMode: boolean
  toggleDarkMode: () => void
  setDarkMode: (v: boolean) => void
}

export const useUIStore = create<UIState>((set) => ({
  sidebarCollapsed: false,
  toggleSidebar: () => set((state) => ({ sidebarCollapsed: !state.sidebarCollapsed })),
  darkMode: localStorage.getItem('felicita_dark') === 'true',
  toggleDarkMode: () => set((state) => {
    const next = !state.darkMode
    localStorage.setItem('felicita_dark', String(next))
    document.documentElement.classList.toggle('dark', next)
    return { darkMode: next }
  }),
  setDarkMode: (v) => {
    localStorage.setItem('felicita_dark', String(v))
    document.documentElement.classList.toggle('dark', v)
    set({ darkMode: v })
  },
}))

// Inicializar dark mode al cargar
if (localStorage.getItem('felicita_dark') === 'true') {
  document.documentElement.classList.add('dark')
}
