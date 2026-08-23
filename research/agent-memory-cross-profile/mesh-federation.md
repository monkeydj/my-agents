# AgentMemory Mesh Federation Research

**Status:** IN PROGRESS

**Research Question:** How does agentmemory's mesh federation work? Can it sync memories between different agentmemory nodes running on different machines or for different profiles?

---

## 1. Federation Architecture — Push/Pull Over Authenticated HTTPS, Bearer Tokens

### Overview
AgentMemory's mesh federation enables peer-to-peer synchronization between separate agentmemory instances. The mesh syncs data between separate agentmemory instances via the `memory_mesh_sync` function and `mesh/*` routes. Peers are registered with a name and URL via `POST /agentmemory/mesh/peers` [Source: agentmemory docs](https://www.agent-memory.dev/docs/sharing).

### Peer Registration & Security
The system implements strict security measures to prevent Server-Side Request Forgery (SSRF) and unauthorized local network scanning:

- **SSRF Protection**: Peer URLs must use `http` or `https` protocols and cannot contain embedded credentials [Source: DeepWiki](https://deepwiki.com/rohitg00/agentmemory/5.3-mesh-networking-and-data-portability).
- **Private IP Blocking**: The system blocks loopback addresses (`127.0.0.1`, `::1`), private ranges (`10.x`, `192.168.x`, `172.16.x`), and link-local addresses [Source: DeepWiki](https://deepwiki.com/rohitg00/agentmemory/5.3-mesh-networking-and-data-portability).
- **Authentication**: All mesh endpoints require an `AGENTMEMORY_SECRET` to be configured for `timingSafeCompare` validation. Both peers must have the secret set [Source: DeepWiki](https://deepwiki.com/rohitg00/agentmemory/5.3-mesh-networking-and-data-portability).

### Synchronization Modes
The mesh synchronization uses the `mem::mesh-sync` function supporting three modes [Source: DeepWiki](https://deepwiki.com/rohitg00/agentmemory/5.3-mesh-networking-and-data-portability):

1. **Push** — Send local changes to the peer
2. **Pull** — Fetch changes from the peer
3. **Both** — Bidirectional sync (push then pull)

### REST API Endpoints
The REST API binds to `127.0.0.1` by default on port `3111` with 130 endpoints. Protected endpoints require `Authorization: Bearer <secret>` when `AGENTMEMORY_SECRET` is set, and mesh sync endpoints require `AGENTMEMORY_SECRET` on both peers [Source: GitHub](https://github.com/rohitg00/agentmemory).

---

## 2. Sync Scope — Full Memory Graph or Filtered by Project/AgentId?

### Shared Scopes
The mesh synchronizes core primitives including [Source: DeepWiki](https://deepwiki.com/rohitg00/agentmemory/5.3-mesh-networking-and-data-portability):
- `memories`
- `actions`
- `semantic`
- `procedural`
- `relations`
- `graphNodes`
- `graphEdges`

### Delta Sync
The system uses a `lastSyncAt` timestamp to only fetch items created or updated since the last successful synchronization [Source: DeepWiki](https://deepwiki.com/rohitg00/agentmemory/5.3-mesh-networking-and-data-portability).

---

## 3. Conflict Resolution — Duplicate Detection, Superseded Versions, Audit Trail

### Last-Write-Wins (LWW)
Conflicts are resolved using **Last-Write-Wins (LWW)** strategy. The system compares the `updatedAt` (or `createdAt`) timestamp of the incoming item with the existing local record. The local record is only overwritten if the incoming timestamp is strictly newer [Source: DeepWiki](https://deepwiki.com/rohitg00/agentmemory/5.3-mesh-networking-and-data-portability).

### Origin Tracking / Provenance
As of version `0.9.29`, each record carries an `Origin` block with channel values: `user`, `agent`, `tool`, `import`, or `shared` to track data lineage [Source: DeepWiki](https://deepwiki.com/rohitg00/agentmemory/5.3-mesh-networking-and-data-portability). The `importOrigin` helper ensures all imported data is tagged with `channel: "import"` unless a more specific origin is already present [Source: DeepWiki](https://deepwiki.com/rohitg00/agentmemory/5.3-mesh-networking-and-data-portability).

---

## 4. Multi-Machine Deployment — Docker Mode, Single-Process, State on Disk as JSON

### Single Process Architecture
AgentMemory runs as a single Node process with zero external services. State lives on disk as JSON. `agentmemory stop` flushes indexes before exit, in Docker mode too [Source: agent-memory.dev](https://www.agent-memory.dev/).

### Docker Deployment
Docker mode is supported for deployment. The system is designed for self-hosted setups with local Docker configurations [Source: DeepWiki](https://deepwiki.com/rohitg00/agentmemory/11.2-local-docker-and-self-hosted-setup).

---

## 5. Security Model — No Silent Syncs, Explicit Registration, Token Auth

### Explicit Peer Registration
Peers must be explicitly registered via `POST /agentmemory/mesh/peers` with a name and URL. There are no silent or automatic syncs [Source: agentmemory docs](https://www.agent-memory.dev/docs/sharing).

### Bearer Token Authentication
All protected endpoints require `Authorization: Bearer <secret>` when `AGENTMEMORY_SECRET` is configured. Mesh sync endpoints specifically require `AGENTMEMORY_SECRET` on both peers [Source: GitHub](https://github.com/rohitg00/agentmemory).

### SSRF & Network Protection
- Private IP blocking prevents internal network scanning
- URL validation prevents SSRF attacks
- No embedded credentials allowed in peer URLs [Source: DeepWiki](https://deepwiki.com/rohitg00/agentmemory/5.3-mesh-networking-and-data-portability)

---

**Status:** COMPLETE