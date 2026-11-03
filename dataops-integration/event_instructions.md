# {{vars.EVENT_NAME}}

---

## Welcome.

You will use **two windows** for this lab: the **Lab Companion** (your lab guide) and **Snowflake** (where you run the lab). Click each button below. They open in separate tabs: drag one into its own window so you can see both side by side.

### Your login: the same for both

<div class="mt-4 border-t border-gray-100">
  <dl class="divide-y space-y-2 divide-gray-100">
    <div class="px-4  grid grid-cols-4">
      <dt class="text-md/6 font-medium text-gray-900">Username</dt>
      <dd class="text-md/6 text-gray-700 col-span-3">{{vars.SNOWFLAKE_USER}}</dd>
    </div>
    <div class="px-4  grid grid-cols-4">
      <dt class="text-md/6 font-medium text-gray-900">Password</dt>
      <dd class="text-md/6 text-gray-700 col-span-3">{{vars.SNOWFLAKE_PASSWORD}}</dd>
    </div>
    <div class="px-4  grid grid-cols-4">
      <dt class="text-md/6 font-medium text-gray-900">Snowflake URL</dt>
      <dd class="text-md/6 text-gray-700 col-span-3"><a href="https://{{vars.DATAOPS_SNOWFLAKE_ACCOUNT}}.snowflakecomputing.com" target="snowflake" rel="noopener noreferrer">https://{{vars.DATAOPS_SNOWFLAKE_ACCOUNT}}.snowflakecomputing.com</a></dd>
    </div>
  </dl>
</div>

<div class="flex flex-wrap gap-6 my-6" style="display:flex;flex-wrap:wrap;gap:24px;margin:24px 0;">
<a href="{{vars.LAB_COMPANION_URL}}" target="lab_companion" rel="noopener noreferrer">
  <svg xmlns="http://www.w3.org/2000/svg" width="240" height="50">
    <rect x="0" y="0" width="240" height="50" rx="10" ry="10" fill="#11567f" />
    <text x="120" y="30" font-family="Arial, sans-serif" font-size="16" fill="white" text-anchor="middle">
        1. Open Lab Companion
    </text>
  </svg>
</a>
<a href="https://{{vars.DATAOPS_SNOWFLAKE_ACCOUNT}}.snowflakecomputing.com" target="snowflake" rel="noopener noreferrer">
  <svg xmlns="http://www.w3.org/2000/svg" width="240" height="50">
    <rect x="0" y="0" width="240" height="50" rx="10" ry="10" fill="#29b5e8" />
    <text x="120" y="30" font-family="Arial, sans-serif" font-size="16" fill="white" text-anchor="middle">
        2. Open Snowflake
    </text>
  </svg>
</a>
</div>

### Then

1. **Lab Companion:** sign in with the login above, choose your pathway and follow the steps. Press **Check my work** at the end of each module.
2. **Snowflake:** sign in with the same login, then switch to the role `HOL_PARTICIPANT` (your name, bottom left, then **Switch role**). Open the **payments-hol** Workspace (**Projects > Workspaces**) to run the lab SQL.
