"use client"

import { useEffect, useRef } from "react"
import { Film } from "lucide-react"

/** A short muted, looping clip of the UI clicks for a step. Loads only when scrolled
 *  into view and plays while visible; clicking toggles play/pause. */
export function StepMedia({ file, caption }: { file: string; caption?: string }) {
  const ref = useRef<HTMLVideoElement>(null)

  useEffect(() => {
    const video = ref.current
    if (!video) return
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          if (!video.src) video.src = `/media/${file}`
          void video.play().catch(() => {}) // autoplay can be refused; the user can click
        } else {
          video.pause()
        }
      },
      { threshold: 0.4 },
    )
    observer.observe(video)
    return () => observer.disconnect()
  }, [file])

  return (
    <figure className="max-w-xl space-y-1">
      <video
        ref={ref}
        muted
        loop
        playsInline
        preload="none"
        onClick={(e) => (e.currentTarget.paused ? e.currentTarget.play() : e.currentTarget.pause())}
        className="w-full cursor-pointer rounded-md border bg-muted"
        aria-label={caption || "Clip showing where to click"}
      />
      <figcaption className="flex items-center gap-1 text-xs text-muted-foreground">
        <Film className="h-3 w-3" />
        {caption || "Where to click"} (click to pause)
      </figcaption>
    </figure>
  )
}
