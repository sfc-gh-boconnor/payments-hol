import Link from "next/link"
import { ArrowDown, ArrowRight, Bot, Lightbulb, ShieldCheck, Sparkles, Workflow } from "lucide-react"
import { Card, CardContent } from "@/components/ui/card"

const GAINS = [
  { icon: Workflow, title: "Ship a real data product", text: "Go from raw Iceberg payments to tested, governed, self-refreshing data in an afternoon." },
  { icon: Sparkles, title: "Let AI do the heavy lifting", text: "Cortex Code writes the SQL, dbt and notebooks. You describe the outcome in plain English." },
  { icon: Bot, title: "Put agents to work", text: "Build agents and reports your RMs and ops teams can question themselves." },
  { icon: ShieldCheck, title: "Stay in control", text: "Masking, lineage and audit are built in, so nothing leaves the governance boundary." },
]

const PRODUCTS = [
  { name: "Payments operations", modules: "C1, DE1-DE3, OPS2", business: "Corporate", elsewhere: "card disputes, fraud alerts, faster-payments SLAs" },
  { name: "Client 360", modules: "DA0, DA1, OPS1, AI1-AI3", business: "Corporate and RM", elsewhere: "next best action, credit reviews, KYC refresh" },
  { name: "Retail banking", modules: "C0, data map", business: "Retail", elsewhere: "attrition, next best product, affordability, fraud" },
  { name: "Customer voice", modules: "DA2, OPS3", business: "Corporate and retail", elsewhere: "complaints handling, call notes, app reviews" },
  { name: "Branch network and catchment", modules: "DA3", business: "Retail", elsewhere: "ATM placement, mortgage branches, SME lending reach" },
  { name: "Trust and governance", modules: "GOV1-GOV3", business: "Every data product", elsewhere: "PII controls, audit evidence, AI model access" },
]

const HOW = [
  "Start with C0 to tour all the data, then C1 to explore one data product.",
  "Pick the pathway that matches your role. Each module stands alone.",
  "Paste the prompts, then press Check my work to confirm it worked.",
]

/** Home page welcome: the hook, what attendees get out of the lab, and how it works. */
export function Welcome() {
  return (
    <Card className="overflow-hidden">
      <div className="bg-[var(--sf-mid-blue)] px-6 py-8 text-white sm:px-8">
        <p className="font-heading text-xs font-extrabold uppercase tracking-widest text-[var(--sf-star-blue)]">Welcome</p>
        <h2 className="mt-2 max-w-3xl text-2xl sm:text-3xl">What if your bank&apos;s data could answer back?</h2>
        <p className="mt-3 max-w-2xl text-sm leading-relaxed text-white/90">
          In the next few hours you&apos;ll build what usually takes a team weeks: governed banking data products, live dashboards and AI agents that answer questions about clients, payments and branches, all on Snowflake and all with AI help.
        </p>
        <p className="mt-2 max-w-2xl text-sm leading-relaxed text-white/90">
          Everything runs in your own Snowflake account, on realistic corporate and retail banking data. All of it is synthetic, so experiment freely.
        </p>
      </div>
      <CardContent className="space-y-6 pt-6">
        <div>
          <h3 className="text-sm">What you&apos;ll get out of it</h3>
          <div className="mt-3 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
            {GAINS.map(({ icon: Icon, title, text }) => (
              <div key={title} className="rounded-lg border p-4">
                <Icon className="h-5 w-5 text-primary" aria-hidden />
                <div className="mt-2 text-sm font-semibold">{title}</div>
                <p className="mt-1 text-xs leading-relaxed text-muted-foreground">{text}</p>
              </div>
            ))}
          </div>
        </div>
        <div>
          <h3 className="text-sm">Data products you&apos;ll touch</h3>
          <p className="mt-1 text-xs text-muted-foreground">
            Payments is the worked example. Every pattern carries over to the others, and to your own.{" "}
            <Link href="/data" className="inline-flex items-center gap-1 font-semibold text-primary hover:underline">See the data map <ArrowRight className="h-3 w-3" aria-hidden /></Link>
          </p>
          <div className="mt-3 grid gap-3 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-6">
            {PRODUCTS.map((p) => (
              <div key={p.name} className="flex flex-col rounded-lg border border-t-4 border-t-primary p-4">
                <div className="text-sm font-semibold">{p.name}</div>
                <div className="mt-0.5 text-[11px] text-muted-foreground">{p.business} &middot; {p.modules}</div>
                <p className="mt-2 text-xs leading-relaxed"><span className="font-semibold">Also works for:</span> {p.elsewhere}</p>
              </div>
            ))}
          </div>
        </div>
        <div className="grid gap-6 lg:grid-cols-2">
          <div>
            <h3 className="text-sm">How it works</h3>
            <ol className="mt-3 list-decimal space-y-1.5 pl-5 text-sm marker:font-semibold marker:text-primary">
              {HOW.map((h) => <li key={h}>{h}</li>)}
            </ol>
          </div>
          <div className="rounded-lg border border-primary/30 bg-primary/5 p-4">
            <div className="flex items-center gap-2 text-sm font-semibold">
              <Lightbulb className="h-4 w-4 text-primary" aria-hidden /> Take it back to your team
            </div>
            <p className="mt-2 text-sm leading-relaxed">
              As you go, note the one problem in your own work this could solve: a report you rebuild every week, a question ops can&apos;t answer, a check that&apos;s still manual.
            </p>
            <p className="mt-2 text-sm leading-relaxed">
              Bring it to the wrap-up. We&apos;ll help you shape it into a first use case.
            </p>
          </div>
        </div>
        <p className="flex items-center gap-2 text-xs text-muted-foreground">
          <ArrowDown className="h-3.5 w-3.5" aria-hidden /> Choose your pathway below to get started.
        </p>
      </CardContent>
    </Card>
  )
}
