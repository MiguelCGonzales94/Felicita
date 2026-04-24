import { create } from 'zustand'
import type { Empresa } from '../types/empresa'

interface EmpresaActivaState {
  empresaActiva: Empresa | null
  setEmpresaActiva: (empresa: Empresa | null) => void
  clearEmpresaActiva: () => void
}

export const useEmpresaActivaStore = create<EmpresaActivaState>((set) => ({
  empresaActiva: null,
  setEmpresaActiva: (empresa) => set({ empresaActiva: empresa }),
  clearEmpresaActiva: () => set({ empresaActiva: null }),
}))
