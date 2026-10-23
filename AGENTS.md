# AGENTS.md

Guidance for AI coding agents working in this repository.

## What this repo is

A GitOps-provisioned OpenShift demo with two independent AI agents (each its
own Gradio UI + OGX sidecar pod) that generate repo documentation for a
given GitHub repo — `doc-gen-agent` produces architecture documentation
with Mermaid C4 diagrams, and `openapi-gen-agent` produces an OpenAPI
specification for repos that look like HTTP API services. Both use a
model served by an external, configurable OpenAI-compatible endpoint (no
GPU or in-cluster model serving on this branch) and a shared GitHub MCP
server for code exploration. It is a simplified take on
[opendatahub-io/architecture-context](https://github.com/opendatahub-io/architecture-context).
The two agents are fully independent — separate pods, UIs, budgets, and
PRs; neither triggers the other.

The stack also includes an internal developer portal (`developer-hub/`) backed
by Red Hat Developer Hub (RHDH 1.10) with OIDC authentication via Red Hat
Build of Keycloak (`keycloak/`). RHDH shows all three AI components in its
software catalog and provides links to their live UIs.

> This is the `main` branch. The [`local-model`](../../tree/local-model)
> branch preserves the original design where the model is served
> in-cluster by vLLM on OpenShift AI (GPU required) — its own `AGENTS.md`
> documents that architecture's conventions. Don't port vLLM/RHOAI/GPU
> conventions from there back onto `main`.

Read [`README.md`](README.md) first for the full architecture diagram and
component breakdown before making changes.

## Repository layout

```
gitops/                 # ArgoCD App-of-Apps: bootstrap.sh is the entry point
  apps/                  # Child ArgoCD Application manifests (one per component)
github-mcp-server/       # FastMCP server exposing GitHub repo browsing as MCP tools
doc-gen-agent/           # OGX sidecar (agentic loop) + Gradio UI — architecture docs & diagrams
openapi-gen-agent/       # OGX sidecar (agentic loop) + Gradio UI — OpenAPI spec generation (independent)
ci-cd-pipeline/          # Tekton CI/CD pipeline resources
keycloak/                # Red Hat Build of Keycloak (RHBK) — OIDC identity provider for RHDH
developer-hub/           # Red Hat Developer Hub (RHDH 1.10) — internal developer portal
build-and-deploy-all.sh  # Non-GitOps quick-start for all components
```

Each deployable component is self-contained with a `k8s/` directory and a
`build-and-deploy.sh`. `doc-gen-agent` and `openapi-gen-agent` are two separate
agents — don't reintroduce cross-calls between them without the user explicitly
asking.

**`keycloak/`** installs the RHBK operator and a Keycloak instance in namespace
`keycloak`. The realm `platform` is created as a shell; users and the RHDH OIDC
client are provisioned by the `configure-rhdh` Job inside `developer-hub/`.

**`developer-hub/`** installs the RHDH operator and a Backstage instance in
namespace `rhdh`. Its structure follows the same sub-directory convention:

```
developer-hub/k8s/
  operator/       # OperatorGroup, Subscription (Manual fast-1.10), approve-installplan Job
  instance/       # ConfigMaps, Secrets, Backstage CR, ConsoleLink, RBAC
  catalog/        # all.yaml — Backstage entity definitions (also mirrored as rhdh-catalog-configmap.yaml)
  jobs/           # configure-rhdh.yaml — ArgoCD Sync hook (wave 18)
```

## Core conventions

- **GitOps is the source of truth for deployment.** Any new Kubernetes
  resource must live under a component's `k8s/` directory so ArgoCD picks
  it up. Don't hand-apply one-off resources without also committing the
  manifest.
- **ArgoCD Application `repoURL` fields contain a placeholder**
  (`https://github.com/YOUR_ORG/agentic-doc-generation.git`). Never
  hardcode a real URL in a manifest — `gitops/bootstrap.sh` substitutes it
  at bootstrap time via `sed`.
- **Sync-wave ordering matters.** Full wave order:
  - Wave 0: `github-mcp-server`
  - Wave 1: `doc-gen-agent`, `openapi-gen-agent` (concurrent, depend on wave-0 DNS)
  - Wave 2: `ci-cd-pipeline`
  - Wave 3: `keycloak` (RHBK must be ready before developer-hub's configure-rhdh Job)
  - Wave 4: `developer-hub`

  Preserve the `argocd.argoproj.io/sync-wave` annotations when adding resources.
- **ConfigMaps generated from files are not committed as inline YAML.**
  `ogx-stack-config` and `agent-knowledge` (per component) are created by
  each component's `build-and-deploy.sh` via
  `oc create configmap --from-file=...` to avoid YAML-in-YAML. Exception:
  `developer-hub/k8s/instance/rhdh-catalog-configmap.yaml` embeds catalog
  entities inline because they are simple Backstage YAML (no escaping issues);
  the canonical source is `developer-hub/k8s/catalog/all.yaml` — keep them in sync.
- **`doc-gen-agent` and `openapi-gen-agent` share the `cluster-config`
  ConfigMap and `external-model-credentials` Secret** (both in the
  `doc-gen-demo` namespace) — only `doc-gen-agent/k8s/cluster-config.yaml`
  is committed; `openapi-gen-agent`'s Deployment references the same
  ConfigMap name rather than duplicating it. Don't create a second
  `cluster-config.yaml` under `openapi-gen-agent/k8s/`.
- **Model identity must stay in sync across three files** when pointing
  at a different model or endpoint: `doc-gen-agent/k8s/cluster-config.yaml`
  (`model_base_url`, `model_name` — shared by both agents), and **each**
  agent's own `ogx/stack_run_config.yaml`. The endpoint's API key goes in
  the `external-model-credentials` Secret (created out-of-band, never committed).
- **`rhdh-secrets` in namespace `rhdh` is patched at runtime** by the
  `configure-rhdh` Sync Job — never commit real values there. ArgoCD
  `ignoreDifferences` on `/data` prevents drift loops. The Job runs at wave 18
  inside the `developer-hub` Application sync, after the Backstage CR is applied.
- **`keycloak-initial-admin` Secret** in namespace `keycloak` is created by
  the RHBK operator with the generated admin password. The `configure-rhdh`
  Job reads it (via a cross-namespace RoleBinding) to get an admin token for
  the Keycloak Admin API. Never commit or log this secret's contents.
- **RHDH operator uses Manual install plan** (`fast-1.10`, pinned to
  `rhdh-operator.v1.10.6`). The `approve-installplan` Job in
  `developer-hub/k8s/operator/` handles approval automatically. Don't change
  the channel or CSV without also updating the approve-installplan Job allowlist.
- **RHBK operator uses Automatic install plan** (`stable-v26`). No manual
  approval step is needed.

## Making changes

- **Python services** (`github-mcp-server/server.py`,
  `doc-gen-agent/agent.py`, `doc-gen-agent/app.py`,
  `openapi-gen-agent/agent.py`, `openapi-gen-agent/app.py`): run
  `python3 -m py_compile <file>` after edits; there is no test suite yet.
- **YAML manifests**: validate with
  `python3 -c "import yaml,sys; yaml.safe_load_all(open(sys.argv[1]))" <file>`
  (or run it across all files with glob) before committing — this repo has
  no CI yet, so this is the only automated check.
- **Shell scripts**: run `bash -n <script>` after edits.
- Keep container images non-root (UID 1001, `chmod g=u`) and set
  `resources.requests`/`limits` on every container, matching the existing
  Deployments.

## What NOT to do

- Don't call an LLM API directly from `agent.py`/`app.py` — inference
  must always go through the OGX sidecar's `remote::vllm`-protocol
  provider, configured to point at whatever external OpenAI-compatible
  endpoint `cluster-config.yaml` specifies. The sidecar is the only
  component that should talk to the model endpoint.
- Don't reintroduce an in-cluster model-serving dependency (RHOAI
  operator, KServe, vLLM `ServingRuntime`/`InferenceService`, GPU
  resource requests) on `main` — that design lives on the `local-model`
  branch. If a change needs it, it belongs on that branch instead.
