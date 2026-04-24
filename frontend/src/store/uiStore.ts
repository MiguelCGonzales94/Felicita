import { create } from 'zustand'

interface UIState {
  sidebarCollapsed: boolean
  toggleSidebar: () => void
  setSidebarCollapsed: (v: boolean) => void
}

const STORAGE_KEY = 'felicita_sidebar_collapsed'

export const useUIStore = create<UIState>((set) => ({
  sidebarCollapsed: localStorage.getItem(STORAGE_KEY) === 'true',
  toggleSidebar: () => set((state) => {
    const next = !state.sidebarCollapsed
    localStorage.setItem(STORAGE_KEY, String(next))
    return { sidebarCollapsed: next }
  }),
  setSidebarCollapsed: (v) => {
    localStorage.setItem(STORAGE_KEY, String(v))
    set({ sidebarCollapsed: v })
  },
}))
