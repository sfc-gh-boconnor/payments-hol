# GOV3: AI governance with Cortex AI Gateway

| | |
|---|---|
| **Persona** | AI governance lead / platform team |
| **Time** | ~40 min |
| **Prerequisites** | C1 only. Uses the account's Cortex AI Gateway (`SNOWFLAKE`, created by Snowflake) |
| **Reference** | [`gov3.sql`](gov3.sql), [`gov3_gateway_calls.py`](gov3_gateway_calls.py) |

## Business question
> Our teams use coding agents, SDK apps and Snowflake agents. How do we control which models they can reach, see what every request did, and attribute AI spend to each person, without slowing the builders down?

## What you'll build
- Notebook `gov3_ai_gateway` that calls two model families through the gateway and reads back what it recorded
- A key pair on your own user, restricted to `HOL_PARTICIPANT` and expiring after a day
- A drafted model policy for the gateway (only an account administrator can apply it)
- A per-user, per-model view of AI usage from the gateway's traces

## One governed door for every AI client
Cortex AI Gateway (preview) gives every AI client in the organisation one endpoint. It speaks the industry-standard APIs (OpenAI Chat Completions and Responses, Anthropic Messages), so any client that lets you change its base URL can use it: coding agents, the OpenAI and Anthropic SDKs, agent frameworks. Inference stays inside the Snowflake perimeter, and every request is tied to the Snowflake user who sent it, so access control, traces and cost attribution come for free.
- **Access:** USAGE on the gateway lets a role send requests. It doesn't widen which models a user may reach: model access controls such as `CORTEX_MODELS_ALLOWLIST` still apply.
- **Specification:** which models the gateway exposes, and what it logs.
- **Observability:** traces and spans for every request, in an event table in your account.
- **Cost:** per-user attribution, budgets and per-user quotas.

## Steps
### Create the GOV3 notebook
Where: payments-hol Workspace > **+ > Notebook**
Name it `gov3_ai_gateway`, with the compute pool **NOTEBOOK_POOL** and the warehouse **BARCLAYS_WH**. Then open the notebook's settings (the **⋮** menu > **Notebook settings** > **External access**) and turn on **HOL_NOTEBOOK_ACCESS_INTEGRATION**. The notebook calls the gateway on this account's public endpoint, and Snowflake blocks outbound traffic from notebooks unless an integration allows it.
Expect: an empty notebook with a connected kernel and the external access integration enabled

### Inspect the gateway
Where: the Cortex Code sidebar, with `gov3_ai_gateway` open
```prompt
In the open notebook gov3_ai_gateway, add a markdown cell titled "GOV3: AI governance with Cortex AI Gateway", then a SQL cell named gateway that runs SHOW AI GATEWAYS and a SQL cell named gateway_spec that runs DESCRIBE AI GATEWAY SNOWFLAKE. Run them and explain the specification: which models it exposes, whether logging is on, and whether prompts and responses are captured.
```
Expect: one gateway, `SNOWFLAKE`, with its base URL. The specification exposes every model (`name: '*'`) and logs every request's metadata; prompts and responses are **not** captured unless an administrator turns payload capture on.

### Give yourself a short-lived key
```prompt
Add a Python cell named make_key that generates an RSA key pair in memory with the cryptography package and registers the public key on my own user with ALTER USER ADD KEY PAIR GOV3_GATEWAY_KEY PUBLIC_KEY = '<base64 DER public key>' ROLE_RESTRICTION = 'HOL_PARTICIPANT' DAYS_TO_EXPIRY = 1, using get_active_session(). Remove any existing GOV3_GATEWAY_KEY first (REMOVE KEY PAIR has no IF EXISTS, so wrap it in try/except). Keep the private key in a variable called key; never print or save it. Then run SHOW USER KEY PAIRS. Use vignettes/gov3_ai_gateway/gov3_gateway_calls.py in the Workspace as the reference.
```
Expect: `GOV3_GATEWAY_KEY` listed with role restriction `HOL_PARTICIPANT` and an expiry tomorrow. The gateway accepts the same tokens as other Snowflake REST APIs: OAuth, a key-pair JWT or a programmatic access token. A key that's tied to one role and expires in a day can only do what the lab role can, and only today.

### Call two model families through the gateway
```prompt
Add a Python cell named gateway_calls that builds a key-pair JWT from key (issuer ACCOUNT.USER.SHA256:<public key fingerprint>, subject ACCOUNT.USER, 50 minute expiry, signed RS256 with cryptography) and calls the gateway at https://<org>-<account>.snowflakecomputing.com/api/v2/aigateways/snowflake, with underscores in the host replaced by hyphens. Send the header X-Snowflake-Authorization-Token-Type: KEYPAIR_JWT and the conversation header x-snowflake-ai-gateway-conversation-id: gov3-lab. Make two calls with urllib: openai-gpt-5 on /v1/chat/completions asking "In two sentences, why might a CHAPS payment be returned, and what should the operations team check first?", and claude-sonnet-4-5 on /v1/messages asking the same about a delayed SEPA payment. Print each answer and its token usage. Use gov3_gateway_calls.py as the reference.
```
Expect: two answers, one from each model family, each with its token counts. Same endpoint, same credential, two API formats: the gateway routes each request to the right model. Any client that can change its base URL (a coding agent, the OpenAI SDK, an agent framework) could make these calls.

### See what the gateway recorded
```prompt
Add a SQL cell named my_traces over TABLE(AGENT_TRACE_TABLE('SNOWFLAKE')) for the last hour: one row per trace with the start time, user (resource_attributes:"user"), model (record_attributes:"gen_ai.request.model"), conversation id (record_attributes:"gen_ai.conversation.id"), input and output tokens (record_attributes:"gen_ai.usage.input_tokens" and "gen_ai.usage.output_tokens"), duration in milliseconds, and status (http.status_code below 400 is success). Run it and explain the difference between a conversation, a trace and a span.
```
Expect: your two calls, tagged with your user, the model, the `gov3-lab` conversation and their tokens and duration. You see only your own traces: a role with **MONITOR** on the gateway sees everyone's. The same data is charted in Snowsight under **AI & ML > AI Gateway > Observability**.
Check: gov3_traces

### Draft a tighter model policy
```prompt
Add a markdown cell explaining the gateway specification, then a code cell (don't run it) with the ALTER AI GATEWAY SNOWFLAKE FROM SPECIFICATION statement an account administrator would run to expose only claude-sonnet-4-5, claude-haiku-4-5 and openai-gpt-5, keep logging on, turn on prompt and response capture, and exclude users tagged BARCLAYS_HOL.GOVERNANCE.PAYLOAD_CAPTURE_EXEMPT from capture. Explain why FROM SPECIFICATION replaces the whole specification, why captured prompts make the trace table sensitive, and how CORTEX_MODELS_ALLOWLIST differs from the gateway's model list.
```
Expect: a reviewed specification change, not applied: attendees aren't account administrators, which is the point. The gateway list controls what this door exposes; `CORTEX_MODELS_ALLOWLIST` controls which models anyone in the account can use at all. Capturing prompts helps audit and evaluation but puts customer data into the trace table, so restrict who can read it, and exempt sensitive users.

### See who is using which model
```prompt
Add a SQL cell named usage_by_model over TABLE(AGENT_TRACE_TABLE('SNOWFLAKE')) for the last day: requests, input tokens and output tokens per user and model, plus the failure count. Then add a markdown cell explaining where an AI governance lead gets authoritative credits (SNOWFLAKE.ACCOUNT_USAGE.AI_GATEWAY_USAGE_HISTORY, which lags), and the controls they can apply: budgets, per-user quotas, and revoking USAGE on the gateway from a role.
```
Expect: your usage by model. Traces show what happened per request; credits come from `AI_GATEWAY_USAGE_HISTORY`, and per-user quotas or a budget stop spend before it surprises you.

## Business Ontology: one vocabulary for every agent (concept)
Governing the door is half the story; the other half is making sure every AI client means the same thing by the same words. **Business Ontology** (private preview) is a business-wide vocabulary: terms such as **Client**, **Payment**, **SLA breach**, **Churn risk**, **Branch** and **Catchment** are defined once, related to each other (a Payment belongs to a Client; an SLA breach is a Payment that missed its scheme's target), and linked to the Snowflake objects that implement them, such as the semantic views this lab builds: `SV_CLIENT_360` (DA1), `SV_PAYMENTS_AUDIT` (GOV2) and `SV_BRANCH_NETWORK` (DA3). Agents and Cortex Sense ground their answers in those definitions, so "churn risk" means the same in the payments agent, the branch advisor and a coding agent behind the gateway. It's enabled per account during the preview, so this lab describes it rather than building it.

## Check your work
`gov3_traces` passes once the gateway has recorded at least two of your requests today. Remove your key when you're done: `ALTER USER REMOVE KEY PAIR GOV3_GATEWAY_KEY` (it expires tomorrow anyway).

## Barclayflake note
One endpoint, one identity, one trace table for every AI client means the AI governance lead can answer "who used which model, on what, at what cost" from Snowflake alone, and change the policy in one place.
