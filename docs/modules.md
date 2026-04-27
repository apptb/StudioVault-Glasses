# Module Implementation Map

This document defines where each active development module should be implemented across the repository. It also records API contracts and explicit data boundaries so clinical and patient data flows remain clear and auditable.

## Layer legend

- **iOS**: Swift app in `samples/CameraAccess/CameraAccess/`
- **Android**: Kotlin app in `samples/CameraAccessAndroid/app/src/main/java/com/meta/wearable/dat/externalsampleapps/cameraaccess/`
- **web**: Next.js UI routes/components in `agent/src/app/`
- **agent**: Server-side orchestration/API handlers in `agent/src/app/api/` and `agent/src/lib/`

## 1) Clinical query interface (AI-powered search)

### Owning layers

- **Primary owner**: `web` + `agent`
- **Client adapters**: `iOS` + `Android`

### Concrete implementation paths

- **Web UI**: `agent/src/app/modules/clinical-query/`
- **Agent domain package**: `agent/src/lib/modules/clinical-query/`
- **Agent API route**: `agent/src/app/api/agent/clinical-query/` (scaffolded)
- **iOS feature package**: `samples/CameraAccess/CameraAccess/Modules/ClinicalQuery/`
- **Android feature package**: `samples/CameraAccessAndroid/app/src/main/java/com/meta/wearable/dat/externalsampleapps/cameraaccess/features/clinicalquery/`

### API contracts

- `POST /api/agent/clinical-query/search`
  - Request: `{ query: string, patientContextId?: string, filters?: { dateRange?: ..., sourceTypes?: string[] }, correlationId: string }`
  - Response: `{ hits: ClinicalHit[], citations: Citation[], latencyMs: number, correlationId: string }`
- `POST /api/agent/clinical-query/summarize`
  - Request: `{ hitIds: string[], intent: 'diagnostic' | 'medication' | 'timeline', correlationId: string }`
  - Response: `{ summary: string, confidence?: number, citations: Citation[], correlationId: string }`

### Data boundaries

- Search query text and patient identifiers may cross from client -> agent API.
- Raw clinical documents stay in backend stores/services; clients receive redacted excerpts + references.
- Session transcripts live in existing agent chat/session storage and are linked by `correlationId`, not full PHI payload duplication.

## 2) Real-time monitoring dashboard

### Owning layers

- **Primary owner**: `web`
- **Data/stream owner**: `agent`
- **Edge collectors**: `iOS` + `Android`

### Concrete implementation paths

- **Web dashboard**: `agent/src/app/modules/realtime-monitoring/`
- **Agent domain package**: `agent/src/lib/modules/realtime-monitoring/`
- **Agent API route**: `agent/src/app/api/agent/realtime-monitoring/` (scaffolded)
- **iOS collector package**: `samples/CameraAccess/CameraAccess/Modules/RealtimeMonitoring/`
- **Android collector package**: `samples/CameraAccessAndroid/app/src/main/java/com/meta/wearable/dat/externalsampleapps/cameraaccess/features/realtimemonitoring/`

### API contracts

- `POST /api/agent/realtime-monitoring/events`
  - Request: `{ patientId: string, eventType: string, value: number | string | object, observedAt: string, deviceId: string }`
  - Response: `{ accepted: boolean, eventId: string }`
- `GET /api/agent/realtime-monitoring/stream?patientId=...`
  - Response: Server-sent events/WebSocket frames for normalized vitals, alerts, and device state.
- `POST /api/agent/realtime-monitoring/ack-alert`
  - Request: `{ alertId: string, actorId: string, note?: string }`
  - Response: `{ acknowledged: boolean, acknowledgedAt: string }`

### Data boundaries

- Device telemetry enters through mobile collectors, gets normalized in agent layer, and only then reaches web views.
- Web layer is read-mostly; alert acknowledgements are the only write path from dashboard clients.
- High-frequency raw sensor samples should be buffered/aggregated agent-side; dashboard consumes derived streams to reduce PHI surface area.

## 3) Document processing + metadata extraction

### Owning layers

- **Primary owner**: `agent`
- **Review/visibility**: `web`
- **Capture/upload entry points**: `iOS` + `Android`

### Concrete implementation paths

- **Agent processing package**: `agent/src/lib/modules/document-processing/`
- **Agent API route**: `agent/src/app/api/agent/document-processing/` (scaffolded)
- **Web review UI**: `agent/src/app/modules/document-processing/`
- **iOS upload package**: `samples/CameraAccess/CameraAccess/Modules/DocumentProcessing/`
- **Android upload package**: `samples/CameraAccessAndroid/app/src/main/java/com/meta/wearable/dat/externalsampleapps/cameraaccess/features/documentprocessing/`

### API contracts

- `POST /api/agent/document-processing/upload`
  - Request: multipart upload + `{ patientId: string, source: 'camera' | 'pdf' | 'fax', correlationId: string }`
  - Response: `{ documentId: string, status: 'queued' | 'processing' }`
- `POST /api/agent/document-processing/extract`
  - Request: `{ documentId: string, schemas: string[], correlationId: string }`
  - Response: `{ metadata: Record<string, unknown>, entities: ExtractedEntity[], version: string }`
- `GET /api/agent/document-processing/:documentId`
  - Response: `{ status: string, metadata?: ..., errors?: ProcessingError[] }`

### Data boundaries

- Binary files and OCR artifacts remain in agent-managed storage, never embedded in mobile/web local state beyond temporary upload buffers.
- Extracted metadata is the contract surface shared with downstream workflows.
- Any model-generated fields must include provenance (`sourceSpan`/`confidence`) before becoming workflow inputs.

## 4) Care coordination workflows

### Owning layers

- **Primary owner**: `agent`
- **Operational console**: `web`
- **Task interaction surfaces**: `iOS` + `Android`

### Concrete implementation paths

- **Agent workflow package**: `agent/src/lib/modules/care-coordination/`
- **Agent API route**: `agent/src/app/api/agent/care-coordination/` (scaffolded)
- **Web operations UI**: `agent/src/app/modules/care-coordination/`
- **iOS task package**: `samples/CameraAccess/CameraAccess/Modules/CareCoordination/`
- **Android task package**: `samples/CameraAccessAndroid/app/src/main/java/com/meta/wearable/dat/externalsampleapps/cameraaccess/features/carecoordination/`

### API contracts

- `POST /api/agent/care-coordination/workflows`
  - Request: `{ patientId: string, workflowType: string, triggerContext: object, initiatedBy: string }`
  - Response: `{ workflowId: string, state: 'created' | 'running' }`
- `POST /api/agent/care-coordination/workflows/:workflowId/tasks/:taskId/complete`
  - Request: `{ actorId: string, outcome: string, notes?: string }`
  - Response: `{ taskStatus: 'completed', workflowState: string }`
- `GET /api/agent/care-coordination/workflows/:workflowId`
  - Response: `{ workflow: WorkflowState, tasks: WorkflowTask[], auditLog: AuditEvent[] }`

### Data boundaries

- Workflow engine owns authoritative state transitions and audit history.
- Clients can propose actions (complete/reassign/escalate) but cannot mutate workflow state directly without server validation.
- Cross-module reads (monitoring alerts, extracted document metadata, query summaries) are pull-based through typed agent contracts.

## Scaffolded directories in this repository

The following directories are scaffolded and committed as starting points for implementation:

- `agent/src/app/modules/clinical-query/`
- `agent/src/app/modules/realtime-monitoring/`
- `agent/src/app/modules/document-processing/`
- `agent/src/app/modules/care-coordination/`
- `agent/src/lib/modules/clinical-query/`
- `agent/src/lib/modules/realtime-monitoring/`
- `agent/src/lib/modules/document-processing/`
- `agent/src/lib/modules/care-coordination/`
- `agent/src/app/api/agent/clinical-query/`
- `agent/src/app/api/agent/realtime-monitoring/`
- `agent/src/app/api/agent/document-processing/`
- `agent/src/app/api/agent/care-coordination/`
- `samples/CameraAccess/CameraAccess/Modules/ClinicalQuery/`
- `samples/CameraAccess/CameraAccess/Modules/RealtimeMonitoring/`
- `samples/CameraAccess/CameraAccess/Modules/DocumentProcessing/`
- `samples/CameraAccess/CameraAccess/Modules/CareCoordination/`
- `samples/CameraAccessAndroid/app/src/main/java/com/meta/wearable/dat/externalsampleapps/cameraaccess/features/clinicalquery/`
- `samples/CameraAccessAndroid/app/src/main/java/com/meta/wearable/dat/externalsampleapps/cameraaccess/features/realtimemonitoring/`
- `samples/CameraAccessAndroid/app/src/main/java/com/meta/wearable/dat/externalsampleapps/cameraaccess/features/documentprocessing/`
- `samples/CameraAccessAndroid/app/src/main/java/com/meta/wearable/dat/externalsampleapps/cameraaccess/features/carecoordination/`

Each scaffold currently includes a `.gitkeep` so the structure exists before implementation begins.
