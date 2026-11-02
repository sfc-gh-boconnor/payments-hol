"use client"

import { useQuery } from "@tanstack/react-query"
import { Users } from "lucide-react"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table"
import { EmptyState } from "@/components/empty-state"
import { Skeleton } from "@/components/ui/skeleton"
import { StatCard } from "@/components/stat-card"
import { formatRelative } from "@/lib/format"
import { cn } from "@/lib/utils"

type Row = { USER_NAME: string; MODULE_CODE: string; CHECK_ID: string; PASSED: boolean; CHECKED_AT: string }

export function FacilitatorBoard({ modules }: { modules: { code: string; checks: number }[] }) {
  const q = useQuery<{ rows: Row[] }>({
    queryKey: ["facilitator"],
    queryFn: async () => {
      const r = await fetch("/api/facilitator")
      if (!r.ok) throw new Error((await r.json()).error ?? "Failed")
      return r.json()
    },
    refetchInterval: 30_000,
  })

  const rows = q.data?.rows ?? []
  const users = [...new Set(rows.map((r) => r.USER_NAME))].sort()
  const cell = (u: string, code: string) => {
    const mine = rows.filter((r) => r.USER_NAME === u && r.MODULE_CODE === code)
    return { passed: mine.filter((r) => r.PASSED).length, tried: mine.length }
  }
  const lastSeen = (u: string) => rows.filter((r) => r.USER_NAME === u).map((r) => r.CHECKED_AT).sort().at(-1)
  const completedModules = users.flatMap((u) => modules.filter((m) => cell(u, m.code).passed === m.checks)).length

  if (q.isPending) return <Skeleton className="h-64" />
  if (q.isError) return <EmptyState variant="error" title="Could not load progress" description={q.error.message} />

  return (
    <div className="space-y-6">
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <StatCard label="Attendees active" value={users.length} icon={Users} />
        <StatCard label="Modules completed" value={completedModules} hint="All checks passing" />
        <StatCard label="Checks run" value={rows.length} hint="Latest result per check" />
      </div>
      <Card>
        <CardHeader>
          <CardTitle>Progress by attendee</CardTitle>
          <CardDescription>Passing checks per module. Refreshes every 30 seconds.</CardDescription>
        </CardHeader>
        <CardContent className="p-0">
          {users.length === 0 ? (
            <div className="p-6"><EmptyState title="No checks run yet" description="Results appear here as soon as attendees press Run checks." /></div>
          ) : (
            <Table bordered>
              <TableHeader>
                <TableRow>
                  <TableHead>Attendee</TableHead>
                  {modules.map((m) => <TableHead key={m.code} className="text-center">{m.code}</TableHead>)}
                  <TableHead>Last check</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {users.map((u) => (
                  <TableRow key={u}>
                    <TableCell className="font-medium">{u}</TableCell>
                    {modules.map((m) => {
                      const { passed, tried } = cell(u, m.code)
                      return (
                        <TableCell
                          key={m.code}
                          className={cn(
                            "text-center text-xs tabular-nums",
                            tried === 0 && "text-muted-foreground",
                            tried > 0 && passed === m.checks && "bg-success/15 font-semibold text-success",
                            tried > 0 && passed < m.checks && "bg-warning/15 text-warning",
                          )}
                        >
                          {tried === 0 ? "-" : `${passed}/${m.checks}`}
                        </TableCell>
                      )
                    })}
                    <TableCell className="text-xs text-muted-foreground">{formatRelative(lastSeen(u))}</TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>
    </div>
  )
}
