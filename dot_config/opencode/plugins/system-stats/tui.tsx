import { Plugin } from "@opencode/plugin/tui"
import { cpuSample, cpuUsage, formatBytes, memory, type Memory } from "./stats"

const DEFAULT_INTERVAL = 2_000

type Theme = {
  text: {
    base: string
    muted: string
    feedback: {
      warning: { base: string }
      error: { base: string }
    }
  }
}

type TextNode = {
  content: string
  fg?: string
  isDestroyed?: boolean
  requestRender: () => void
}

function color(theme: Theme, value: number | undefined) {
  if (value === undefined) return theme.text.muted
  if (value >= 95) return theme.text.feedback.error.base
  if (value >= 85) return theme.text.feedback.warning.base
  return theme.text.base
}

export default Plugin.define({
  id: "system-stats",
  setup(context) {
    const requested = Number(context.options?.interval ?? DEFAULT_INTERVAL)
    const interval = Number.isFinite(requested) ? Math.min(60_000, Math.max(500, requested)) : DEFAULT_INTERVAL

    const nodes = { cpu: new Set<TextNode>(), mem: new Set<TextNode>() }
    let cpu: number | undefined
    let mem: Memory | undefined
    let previous = cpuSample()

    const paint = () => {
      for (const node of nodes.cpu) {
        if (node.isDestroyed) {
          nodes.cpu.delete(node)
          continue
        }
        node.content = cpu === undefined ? "--%" : `${Math.round(cpu)}%`
        node.fg = color(context.theme, cpu)
        node.requestRender()
      }
      for (const node of nodes.mem) {
        if (node.isDestroyed) {
          nodes.mem.delete(node)
          continue
        }
        node.content = mem ? `${formatBytes(mem.used)}/${formatBytes(mem.total)}` : "--"
        node.fg = color(context.theme, mem && mem.total > 0 ? (mem.used / mem.total) * 100 : undefined)
        node.requestRender()
      }
    }

    const sample = () => {
      const current = cpuSample()
      cpu = cpuUsage(previous, current)
      previous = current
      paint()
      void memory()
        .then((value) => {
          mem = value
          paint()
        })
        .catch(() => {})
    }

    const bind = (slot: "cpu" | "mem") => (node?: TextNode) => {
      if (!node) return
      nodes[slot].add(node)
      paint()
    }

    const render = () => (
      <box flexDirection="row" flexShrink={0}>
        <text fg={context.theme.text.muted}>CPU </text>
        <text ref={bind("cpu")} fg={context.theme.text.muted} />
        <text fg={context.theme.text.muted}> RAM </text>
        <text ref={bind("mem")} fg={context.theme.text.muted} />
      </box>
    )

    const first = setTimeout(sample, 500)
    const timer = setInterval(sample, interval)
    const disposers = [
      context.ui.slot({ append: "home.footer.status", render }),
      context.ui.slot({ append: "prompt.footer.status", render }),
    ]

    return () => {
      clearTimeout(first)
      clearInterval(timer)
      for (const dispose of disposers) dispose()
    }
  },
})
