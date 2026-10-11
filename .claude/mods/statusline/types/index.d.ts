export type Segment = {
  text: string
  color?: 'green' | 'yellow' | 'red' | 'cyan'
  isBold?: boolean
}

declare module 'claude-code' {
  interface PluginState {
    statusline: { line: Segment[] }
  }
}
