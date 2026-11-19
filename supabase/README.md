# Live planning chat setup

The iOS client calls the `coach` Edge Function. The function validates a Supabase
user session and calls OpenAI's Responses API with structured output. It returns
only a Time / Activity table, with detailed activity descriptions and no prose.

## Activate

1. Create/select a Supabase project and enable anonymous sign-ins under Auth.
   Chat uses its own anonymous session stored in Keychain; the app's existing
   email sign-in is still local and is not used as proof of authentication.
2. Run `migrations/202611130001_coach_limits.sql` in the project's SQL editor.
3. Add `OPENAI_API_KEY` privately in Supabase Edge Function secrets. Set
   `OPENAI_MODEL` to a Responses / Structured Outputs compatible model available
   to your account (for example `gpt-4.1-mini`). Never add the OpenAI key to Xcode.
4. Deploy `functions/coach/index.ts` as the `coach` Edge Function. Disable the
   gateway's legacy JWT verification for this function: the handler verifies
   the bearer token itself with Supabase Auth before doing any paid work.
   With the Supabase CLI: `supabase functions deploy coach --project-ref PROJECT_REF --no-verify-jwt`.
5. Set the public project URL and publishable key in Xcode's Run scheme environment:
   `COACH_SUPABASE_URL` and `COACH_SUPABASE_PUBLIC_KEY`.
   For archived builds add the same public values as target Info properties
   `CoachSupabaseURL` and `CoachSupabasePublicKey`.
6. Run the app, open a planning bot, answer its questions, and request a change
   to a specific time. Verify both replies are tables and the second respects
   the conversation. Disconnect the network to verify the visible error and retry.

The backend limits all callers to 30 requests per anonymous session per UTC day
and 1,000 total per day, including failed provider requests. These are protective
service limits, not RevenueCat entitlement checks. Premium entitlement validation
and linking chat identities to real accounts remain separate work.

No hosted project, credentials, or deployment tools were supplied with this repo.
The iOS build can be checked locally; live requests need the activation steps above.

API reference: https://developers.openai.com/api/reference/resources/responses/methods/create
