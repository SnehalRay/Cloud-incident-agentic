import type { ReactNode } from 'react'

interface HudFrameProps {
  title: string
  /** Right-aligned status/controls slot in the title bar. */
  accessory?: ReactNode
  /** Accent color for the title bar underline + label. */
  tone?: 'accent' | 'info' | 'active' | 'danger'
  className?: string
  bodyClassName?: string
  children: ReactNode
}

const toneText: Record<string, string> = {
  accent: 'text-accent',
  info: 'text-info',
  active: 'text-active',
  danger: 'text-danger',
}
const toneBorder: Record<string, string> = {
  accent: 'border-accent/40',
  info: 'border-info/40',
  active: 'border-active/40',
  danger: 'border-danger/40',
}

export default function HudFrame({
  title,
  accessory,
  tone = 'info',
  className = '',
  bodyClassName = '',
  children,
}: HudFrameProps) {
  return (
    <section
      className={`relative flex min-h-0 flex-col border bg-panel/80 ${toneBorder[tone]} chamfer ${className}`}
    >
      <header
        className={`flex items-center justify-between gap-2 border-b ${toneBorder[tone]} bg-void/60 px-3 py-2`}
      >
        <div className="flex items-center gap-2">
          <span className={`text-[11px] leading-none ${toneText[tone]}`}>◆</span>
          <h2 className={`title text-[11px] ${toneText[tone]} text-glow`}>{title}</h2>
        </div>
        {accessory}
      </header>
      <div className={`min-h-0 flex-1 ${bodyClassName}`}>{children}</div>
    </section>
  )
}
