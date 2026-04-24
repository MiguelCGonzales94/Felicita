import { ReactNode, useEffect } from 'react'
import { X } from 'lucide-react'

interface ModalProps {
  isOpen: boolean
  onClose: () => void
  title: string
  description?: string
  size?: 'sm' | 'md' | 'lg' | 'xl'
  children: ReactNode
  footer?: ReactNode
}

const SIZES = {
  sm: 'max-w-md',
  md: 'max-w-lg',
  lg: 'max-w-2xl',
  xl: 'max-w-4xl',
}

export default function Modal({
  isOpen, onClose, title, description, size = 'md', children, footer
}: ModalProps) {
  useEffect(() => {
    if (!isOpen) return
    const handleEsc = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose()
    }
    document.body.style.overflow = 'hidden'
    window.addEventListener('keydown', handleEsc)
    return () => {
      document.body.style.overflow = ''
      window.removeEventListener('keydown', handleEsc)
    }
  }, [isOpen, onClose])

  if (!isOpen) return null

  return (
    <div
      className="fixed inset-0 z-50 overflow-y-auto"
      onClick={onClose}
      role="dialog"
      aria-modal="true"
    >
      {/* Backdrop */}
      <div className="fixed inset-0 bg-slate-900/50 backdrop-blur-sm" />

      {/* Dialog */}
      <div className="flex min-h-full items-center justify-center p-4">
        <div
          className={`relative w-full ${SIZES[size]} bg-white rounded-xl shadow-xl transform transition-all`}
          onClick={(e) => e.stopPropagation()}
        >
          {/* Header */}
          <div className="flex items-start justify-between px-6 py-4 border-b border-gray-100">
            <div>
              <h2 className="font-heading font-bold text-gray-900 text-lg">{title}</h2>
              {description && (
                <p className="text-sm text-gray-500 mt-0.5">{description}</p>
              )}
            </div>
            <button
              onClick={onClose}
              className="p-1 hover:bg-gray-100 rounded-lg transition-colors text-gray-500"
              aria-label="Cerrar"
            >
              <X size={18} />
            </button>
          </div>

          {/* Body */}
          <div className="px-6 py-5 max-h-[70vh] overflow-y-auto">
            {children}
          </div>

          {/* Footer */}
          {footer && (
            <div className="px-6 py-4 border-t border-gray-100 bg-gray-50 rounded-b-xl flex items-center justify-end gap-2">
              {footer}
            </div>
          )}
        </div>
      </div>
    </div>
  )
}

// ── ConfirmDialog ────────────────────────────────────
interface ConfirmDialogProps {
  isOpen: boolean
  onClose: () => void
  onConfirm: () => void
  title: string
  message: string
  confirmText?: string
  cancelText?: string
  variant?: 'danger' | 'warning' | 'info'
  loading?: boolean
}

export function ConfirmDialog({
  isOpen, onClose, onConfirm, title, message,
  confirmText = 'Confirmar', cancelText = 'Cancelar',
  variant = 'danger', loading = false
}: ConfirmDialogProps) {
  const btnClass = {
    danger:  'bg-danger-600 hover:bg-danger-700 text-white',
    warning: 'bg-warning-600 hover:bg-warning-700 text-white',
    info:    'bg-brand-800 hover:bg-brand-900 text-white',
  }[variant]

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title={title}
      size="sm"
      footer={
        <>
          <button onClick={onClose} className="btn-secondary" disabled={loading}>
            {cancelText}
          </button>
          <button
            onClick={onConfirm}
            disabled={loading}
            className={`px-4 py-2 rounded-lg font-medium text-sm transition-colors disabled:opacity-50 ${btnClass}`}
          >
            {loading ? 'Procesando...' : confirmText}
          </button>
        </>
      }
    >
      <p className="text-sm text-gray-600 leading-relaxed">{message}</p>
    </Modal>
  )
}
