import { atom, read, update } from 'claude-code'
import type { Engine, Register } from 'claude-code'

import type { Segment } from '../types'
import { buildSegments } from './format'

const line = atom({ plugin: 'statusline', key: 'line' } as const, [] as Segment[])

const refresh = async ($: Engine) => {
  try {
    const cwd = await $.session.cwd()
    const [model, usage, home, git] = await Promise.all([
      $.session.model(),
      $.session.usage(),
      $.env.get('HOME'),
      $.process.run(['git', '-C', cwd, 'rev-parse', '--abbrev-ref', 'HEAD']),
    ])
    const limit = (kind: string) => usage.rateLimits.find(r => r.kind === kind)?.percentUsed

    await update($, line, () =>
      buildSegments({
        cwd,
        home,
        branch: git.exitCode === 0 ? git.stdout.trim() : undefined,
        model,
        contextPercent: usage.context.percent,
        fiveHourPercent: limit('five_hour'),
        sevenDayPercent: limit('seven_day'),
      }),
    )
  } catch {
    // A failed refresh keeps the last line rather than breaking the hook chain.
  }
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await refresh($)
    return next(e)
  })

  on('session.measure', async ($, e, next) => {
    await refresh($)
    return next(e)
  })

  // The branch and cwd can move during a turn without any usage figure changing.
  on('turn.complete', async ($, e, next) => {
    const result = await next(e)
    await refresh($)
    return result
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const segments = await read($, line)

    if (e.props.hasSurvey || segments.length === 0) {
      return next(e)
    }

    const { Box, Text } = $.ui.resolve(e)

    return (
      <Box>
        {segments.map((segment, i) => (
          <Text key={i} color={segment.color} bold={segment.isBold}>
            {i === 0 ? '' : '  '}
            {segment.text}
          </Text>
        ))}
      </Box>
    )
  })
}
