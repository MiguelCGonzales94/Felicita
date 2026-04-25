import { Outlet } from 'react-router-dom'
import Sidebar from './Sidebar'
import NotificacionesCampana from './NotificacionesCampana'
import DarkModeToggle from './DarkModeToggle'

export default function AppLayout() {
  return (

    <div className="flex min-h-screen bg-gray-100">
      <Sidebar />
      <main className="flex-1 min-w-0 overflow-x-hidden">
        <Outlet />
      </main>
    </div>
  )
}
