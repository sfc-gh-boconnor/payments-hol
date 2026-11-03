# {{vars.EVENT_NAME}}

---

## Welcome.

Open **both** of these. Each one opens in its own tab: drag one into a separate window so you can see the guide and Snowflake side by side.

1. **Lab Companion** - your lab guide. Choose your pathway, follow the steps and press **Check my work** at the end of each module.
2. **Snowflake** - where you run the lab. Log in with the details below, then switch to the role `HOL_PARTICIPANT`.

<a href="{{vars.LAB_COMPANION_URL}}" target="lab_companion" rel="noopener noreferrer">
  <svg xmlns="http://www.w3.org/2000/svg" width="220" height="50">
    <rect x="0" y="0" width="220" height="50" rx="10" ry="10" fill="#11567f" />
    <text x="110" y="30" font-family="Arial, sans-serif" font-size="16" fill="white" text-anchor="middle">
        1. Open Lab Companion
    </text>
  </svg>
</a>
<a href="https://{{vars.DATAOPS_SNOWFLAKE_ACCOUNT}}.snowflakecomputing.com" target="snowflake" rel="noopener noreferrer">
  <svg xmlns="http://www.w3.org/2000/svg" width="220" height="50">
    <rect x="0" y="0" width="220" height="50" rx="10" ry="10" fill="#29b5e8" />
    <text x="110" y="30" font-family="Arial, sans-serif" font-size="16" fill="white" text-anchor="middle">
        2. Open Snowflake
    </text>
  </svg>
</a>

Sign in to the Lab Companion with the same Snowflake username and password.

<br>

## Snowflake Account Details

### Your temporary Snowflake account

<div class="mt-6 border-t border-gray-100">
  <dl class="divide-y space-y-2 divide-gray-100">
    <div class="px-4  grid grid-cols-4">
      <dt class="text-md/6 font-medium text-gray-900">URL</dt>
      <dd class="text-md/6 text-gray-700 col-span-3"><a href="https://{{vars.DATAOPS_SNOWFLAKE_ACCOUNT}}.snowflakecomputing.com" target="_blank" rel="noopener noreferrer">https://{{vars.DATAOPS_SNOWFLAKE_ACCOUNT}}.snowflakecomputing.com</a></dd>
    </div>
    <div class="px-4  grid grid-cols-4">
      <dt class="text-md/6 font-medium text-gray-900">Username</dt>
      <dd class="text-md/6 text-gray-700 col-span-3">{{vars.SNOWFLAKE_USER}}</dd>
    </div>
    <div class="px-4  grid grid-cols-4">
      <dt class="text-md/6 font-medium text-gray-900">Password</dt>
      <dd class="text-md/6 text-gray-700 col-span-3">{{vars.SNOWFLAKE_PASSWORD}}</dd>
    </div>
  </dl>
</div>
