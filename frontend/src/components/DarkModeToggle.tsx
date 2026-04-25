import { Moon, Sun } from 'lucide-react'
import { useUIStore } from '../store/uiStore'

export default function DarkModeToggle() {
  const { darkMode, toggleDarkMode } = useUIStore()
  return (
    <button
      onClick={toggleDarkMode}
      className="p-2 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors"
      title={darkMode ? 'Modo claro' : 'Modo nocturno'}
    >
      {darkMode
        ? <Sun size={18} className="text-yellow-500" />
        : <Moon size={18} className="text-gray-600" />}
    </button>
  )
}
