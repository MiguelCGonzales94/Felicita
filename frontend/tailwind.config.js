/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      fontFamily: {
        heading: ['Manrope', 'system-ui', 'sans-serif'],
        sans:    ['Inter', 'system-ui', 'sans-serif'],
        mono:    ['JetBrains Mono', 'ui-monospace', 'monospace'],
      },
      colors: {
        brand: {
          50:  '#EFF6FF', 100: '#DBEAFE', 200: '#BFDBFE',
          500: '#3B82F6', 600: '#2563EB', 700: '#1D4ED8',
          800: '#1E40AF', 900: '#1E3A8A',
        },
        sidebar: {
          DEFAULT: '#0F172A', hover: '#1E293B', active: '#1E40AF',
          border: '#1E293B', text: '#CBD5E1', muted: '#64748B',
        },
        success: { 50: '#ECFDF5', 600: '#059669', 700: '#047857', 900: '#065F46' },
        warning: { 50: '#FFFBEB', 600: '#D97706', 700: '#B45309', 900: '#92400E' },
        danger:  { 50: '#FEF2F2', 600: '#DC2626', 700: '#B91C1C', 900: '#991B1B' },
      },
      boxShadow: {
        'card': '0 1px 2px 0 rgb(0 0 0 / 0.04)',
        'card-hover': '0 4px 6px -1px rgb(0 0 0 / 0.08)',
      },
    }
  },
  plugins: []
}
