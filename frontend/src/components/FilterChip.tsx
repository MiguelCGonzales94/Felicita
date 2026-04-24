interface FilterChipProps {
  label: string
  value: string | number
  active?: boolean
  count?: number
  onClick: () => void
  variant?: 'default' | 'success' | 'warning' | 'danger'
}

const VARIANTS = {
  default: 'border-gray-200 text-gray-700 hover:border-gray-300',
  success: 'border-success-600/30 text-success-900 hover:bg-success-50',
  warning: 'border-warning-600/30 text-warning-900 hover:bg-warning-50',
  danger:  'border-danger-600/30 text-danger-900 hover:bg-danger-50',
}

const VARIANTS_ACTIVE = {
  default: 'bg-brand-800 border-brand-800 text-white',
  success: 'bg-success-600 border-success-600 text-white',
  warning: 'bg-warning-600 border-warning-600 text-white',
  danger:  'bg-danger-600 border-danger-600 text-white',
}

export default function FilterChip({
  label, count, active, onClick, variant = 'default'
}: FilterChipProps) {
  const styles = active ? VARIANTS_ACTIVE[variant] : VARIANTS[variant]

  return (
    <button
      onClick={onClick}
      className={`inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full border text-xs font-semibold transition-colors ${styles}`}
    >
      {label}
      {count !== undefined && (
        <span className={`px-1.5 py-0 rounded-full text-[10px] ${
          active ? 'bg-white/20' : 'bg-gray-100 text-gray-600'
        }`}>
          {count}
        </span>
      )}
    </button>
  )
}
