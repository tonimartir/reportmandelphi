# New Report Wizard Plan

## Goals

- Keep the wizard aligned with real `dbxconnections` entries instead of bypassing saved connections.
- For the `Reportman AI Agent` route, ask first whether the user wants a new connection or an existing one.
- For existing Agent connections, list only `dbxconnections` entries whose driver is `Reportman AI Agent`.
- For the direct route, when `Existing Connection` is selected, list only connections that match the selected family at least at the family level.
- For direct existing connections, show the resolved driver family in blue under the selected connection so the user can verify whether it is `DBExpress`, `FireDAC`, or `Zeos`.

## Flow

1. Route page:
   - `Reportman AI / DB Agent`
   - `Direct database connection`
2. Agent route:
   - Connection mode page: `Existing Connection` or `New Connection`
   - Existing mode lists only `Reportman AI Agent` entries from `dbxconnections`
   - New mode captures the new connection name
   - A dedicated schema page hosts the reusable `AILogin` and `AISchemaSelector` controls
   - Existing mode preloads and prioritizes schemas for the selected Agent connection `HubDatabaseId`
   - New mode uses the same schema page to discover the selected Hub database and persist the new Agent connection into `dbxconnections`
   - Finish page captures the optional prompt
3. Direct route:
   - Schema question
   - If the user chooses to use a schema, the same dedicated schema page is shown with `AILogin` and `AISchemaSelector`
   - Driver family and concrete driver
   - Connection mode page filtered by the selected family
   - Existing mode shows a blue family hint below the selected connection
   - New mode creates the connection and then edits parameters when applicable
   - Finish page captures the optional prompt

## Implementation notes

- Agent reports must use the selected `dbxconnections` alias when committing the connection to the report.
- Direct existing connection lists must stop using the unfiltered `GetConnectionNames(..., '')` call.
- Family detection should come from stored connection parameters, not from UI captions.
- The schema chosen in the wizard must be propagated into the initial design-chat context so the first AI prompt uses the selected schema immediately.