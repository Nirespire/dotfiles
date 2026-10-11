import { describe, expect, test } from 'claude-code/testing'

import { buildSegments, colorFor, contextBar, shortenCwd } from './format'

describe('shortenCwd', () => {
  test('tildes $HOME and keeps short paths whole', () => {
    expect(shortenCwd('/Users/me/code/dotfiles', '/Users/me')).toBe('~/code/dotfiles')
  })

  test('keeps the last 3 segments of a deeper path', () => {
    expect(shortenCwd('/Users/me/code/dotfiles/.claude', '/Users/me')).toBe('code/dotfiles/.claude')
  })

  test('keeps a leading slash outside $HOME', () => {
    expect(shortenCwd('/opt/homebrew/Cellar/jq', '/Users/me')).toBe('/homebrew/Cellar/jq')
  })
})

describe('context bar and thresholds', () => {
  test('fills one cell per 10% and caps at 10', () => {
    expect(contextBar(0)).toBe('░░░░░░░░░░')
    expect(contextBar(47)).toBe('████░░░░░░')
    expect(contextBar(100)).toBe('██████████')
    expect(contextBar(130)).toBe('██████████')
  })

  test('colors at 50 and 80', () => {
    expect(colorFor(49)).toBe('green')
    expect(colorFor(50)).toBe('yellow')
    expect(colorFor(79)).toBe('yellow')
    expect(colorFor(80)).toBe('red')
  })
})

describe('buildSegments', () => {
  test('omits what is unknown', () => {
    expect(buildSegments({ cwd: '/Users/me', home: '/Users/me' })).toEqual([{ text: '~' }])
  })

  test('renders every segment in order', () => {
    const texts = buildSegments({
      cwd: '/Users/me/code/x',
      home: '/Users/me',
      branch: 'main',
      model: 'Opus',
      contextPercent: 42.4,
      fiveHourPercent: 85,
      sevenDayPercent: 10,
    }).map(s => s.text)

    expect(texts).toEqual(['~/code/x', 'main', '🤖 Opus', 'ctx ████░░░░░░ 42%', '5h 85%', '7d 10%'])
  })
})
