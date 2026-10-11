import type { Segment } from '../types'

export type StatusInput = {
  cwd: string
  home?: string
  branch?: string
  model?: string
  contextPercent?: number
  fiveHourPercent?: number
  sevenDayPercent?: number
}

const BAR_CELLS = 10

export const colorFor = (pct: number): Segment['color'] =>
  pct >= 80 ? 'red' : pct >= 50 ? 'yellow' : 'green'

// $HOME becomes ~, then only the last 3 path segments are kept.
export const shortenCwd = (cwd: string, home?: string): string => {
  const tilded = home && cwd.startsWith(home) ? `~${cwd.slice(home.length)}` : cwd
  const parts = tilded.split('/')
  if (parts.length <= 3) return tilded
  const tail = parts.slice(-3).join('/')
  return tilded.startsWith('/') ? `/${tail}` : tail
}

export const contextBar = (pct: number): string => {
  const filled = Math.min(BAR_CELLS, Math.floor(pct / 10))
  return '█'.repeat(filled) + '░'.repeat(BAR_CELLS - filled)
}

export const buildSegments = (input: StatusInput): Segment[] => {
  const segments: Segment[] = []

  if (input.cwd) segments.push({ text: shortenCwd(input.cwd, input.home) })
  if (input.branch) segments.push({ text: input.branch })
  if (input.model) segments.push({ text: `🤖 ${input.model}`, color: 'cyan', isBold: true })

  if (input.contextPercent !== undefined) {
    const pct = Math.round(input.contextPercent)
    segments.push({ text: `ctx ${contextBar(pct)} ${pct}%`, color: colorFor(pct) })
  }
  if (input.fiveHourPercent !== undefined) {
    const pct = Math.round(input.fiveHourPercent)
    segments.push({ text: `5h ${pct}%`, color: colorFor(pct) })
  }
  if (input.sevenDayPercent !== undefined) {
    const pct = Math.round(input.sevenDayPercent)
    segments.push({ text: `7d ${pct}%`, color: colorFor(pct) })
  }

  return segments
}
