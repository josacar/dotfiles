import { readFile } from "node:fs/promises"
import os from "node:os"

export type CpuSample = {
  idle: number
  total: number
}

export type Memory = {
  total: number
  used: number
}

export function cpuSample(): CpuSample {
  let idle = 0
  let total = 0
  for (const cpu of os.cpus()) {
    idle += cpu.times.idle
    total += cpu.times.user + cpu.times.nice + cpu.times.sys + cpu.times.idle + cpu.times.irq
  }
  return { idle, total }
}

export function cpuUsage(previous: CpuSample, current: CpuSample) {
  const total = current.total - previous.total
  const idle = current.idle - previous.idle
  if (total <= 0) return undefined
  return Math.min(100, Math.max(0, (1 - idle / total) * 100))
}

export function formatBytes(bytes: number) {
  const units = ["B", "K", "M", "G", "T"]
  let value = bytes
  let unit = 0
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024
    unit++
  }
  return `${value.toFixed(value >= 100 || unit === 0 ? 0 : 1)}${units[unit]}`
}

export async function memory(): Promise<Memory> {
  const total = os.totalmem()
  const fallback = { total, used: total - os.freemem() }
  if (process.platform !== "linux") return fallback

  const info = await readFile("/proc/meminfo", "utf8").catch(() => undefined)
  if (!info) return fallback

  const values = new Map<string, number>()
  for (const line of info.split("\n")) {
    const match = /^(\w+):\s+(\d+)\s*kB$/.exec(line)
    if (match) values.set(match[1], Number(match[2]) * 1024)
  }

  const available = values.get("MemAvailable") ?? values.get("MemFree")
  if (!available) return fallback
  return { total, used: Math.max(0, total - available) }
}
