import Link from "next/link"
import { APP_TITLE } from "@/lib/constants"
import { ThemeToggle } from "@/components/theme-toggle"
import { CommandPalette } from "@/components/command-palette"

/**
 * AppHeader — top navigation bar.
 * Snowflake brand: the white (reverse) logo on full-bleed Snowflake Blue,
 * with clear space around it. Logo file is the official one from the
 * Snowflake logo package (public/brand).
 */
export function AppHeader() {
  return (
    <header className="sticky top-0 z-40 w-full bg-[var(--brand-nav-bg)] text-[var(--brand-nav-fg)]">
      <div className="mx-auto flex h-14 w-full max-w-7xl items-center gap-4 px-4 sm:px-6 lg:px-8">
        <Link href="/" className="flex min-w-0 items-center gap-4">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="/brand/snowflake-logo-reverse-rgb.svg" alt="Snowflake" className="h-7 w-auto shrink-0" />
          <span className="h-6 w-px shrink-0 bg-white/60" aria-hidden />
          <span className="truncate font-heading text-sm font-black uppercase tracking-wide">{APP_TITLE}</span>
        </Link>
        <div className="ml-auto flex shrink-0 items-center gap-1.5">
          <CommandPalette />
          <span className="[&_button]:text-white [&_button:hover]:bg-white/15 [&_button:hover]:text-white">
            <ThemeToggle />
          </span>
        </div>
      </div>
    </header>
  )
}
