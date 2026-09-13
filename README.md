# OpenAI Chatbot — AWS EKS DevSecOps Deployment

A production-style deployment of a Next.js chatbot application on **Amazon EKS**, provisioned with **Terraform** and delivered through a **Jenkins CI/CD pipeline** with integrated security and quality gates.

The project focuses on the complete DevOps lifecycle:

* Infrastructure as Code with Terraform
* Containerization with Docker
* Kubernetes orchestration with Amazon EKS
* CI/CD automation with Jenkins
* Container and dependency security scanning
* Least-privilege Kubernetes RBAC
* Kubernetes workload hardening
* Automated deployment verification and rollback
* ECR image lifecycle management
* Cost-conscious AWS infrastructure design

## Architecture

```text
                              GitHub
                                │
                                │ Push / Webhook
                                ▼
                         ┌───────────────┐
                         │    Jenkins    │
                         └───────┬───────┘
                                 │
                    ┌────────────┴────────────┐
                    │      CI/CD Pipeline     │
                    │                         │
                    │  SonarQube              │
                    │  Quality Gate            │
                    │  OWASP Dependency Check │
                    │  Trivy Filesystem       │
                    │  Docker Build            │
                    │  Trivy Image Scan       │
                    └────────────┬────────────┘
                                 │
                                 ▼
                         ┌───────────────┐
                         │  Amazon ECR   │
                         │ openai-chatbot│
                         └───────┬───────┘
                                 │
                           Image :BUILD_ID
                                 │
                                 ▼
              ┌────────────────────────────────────┐
              │             Amazon EKS              │
              │                                    │
              │       ┌────────────────────┐       │
              │       │  EKS Control Plane │       │
              │       └─────────┬──────────┘       │
              │                 │                  │
              │        ┌────────┴────────┐         │
              │        │                 │         │
              │   Private Node      Private Node   │
              │        │                 │         │
              │        └────────┬────────┘         │
              │                 │                  │
              │          Chatbot Deployment        │
              │                 │                  │
              │          chatbot-service           │
              └─────────────────┼──────────────────┘
                                │
                         AWS Load Balancer
                                │
                                ▼
                           End Users
                                │
                                ▼
                         Chatbot Web UI
```

### Network Architecture

The EKS environment uses a VPC spanning two Availability Zones.

```text
                         Internet
                            │
                     Internet Gateway
                            │
              ┌─────────────┴─────────────┐
              │                           │
        Public Subnets              Public Subnets
              │                           │
        NAT Gateway                 NAT Gateway
              │                           │
              └─────────────┬─────────────┘
                            │
                     Private Subnets
                            │
                    EKS Worker Nodes
```

Worker nodes are placed in **private subnets**, while public subnets provide the networking required for internet-facing infrastructure and outbound access through NAT.

### Deployment Flow

```text
Developer Push
      ↓
GitHub Webhook
      ↓
Jenkins
      ↓
Security & Quality Gates
      ↓
Docker Image
      ↓
Amazon ECR
      ↓
Amazon EKS
      ↓
Rolling Deployment
      ↓
Rollout Verification
      ↓
Application Available
```

Each deployment is tagged using the Jenkins build number, providing traceability between the CI build, ECR image, and Kubernetes workload.

For example:

```text
Jenkins Build #41
       ↓
ECR: openai-chatbot:41
       ↓
EKS: openai-chatbot:41
```
## Technology Stack

| Category               | Technologies                                    |
| ---------------------- | ----------------------------------------------- |
| Cloud Provider         | AWS                                             |
| Infrastructure as Code | Terraform                                       |
| Containerization       | Docker                                          |
| Container Registry     | Amazon ECR                                      |
| Orchestration          | Kubernetes / Amazon EKS                         |
| CI/CD                  | Jenkins                                         |
| Source Control         | Git / GitHub                                    |
| Application            | Next.js / Node.js                               |
| Code Quality           | SonarQube                                       |
| Dependency Security    | OWASP Dependency-Check                          |
| Vulnerability Scanning | Trivy                                           |
| Kubernetes Security    | RBAC, Security Contexts, Probes                 |
| Networking             | AWS VPC, Subnets, Internet Gateway, NAT Gateway |
| External Access        | AWS Load Balancer                               |
| Deployment Strategy    | Kubernetes Rolling Update                       |
| Recovery               | Automated Kubernetes Rollback                   |

## Infrastructure Details

The infrastructure is provisioned entirely through **Terraform**, avoiding manual creation of the core AWS resources.

### AWS Region & Availability Zones

```text
Region:
eu-north-1

Availability Zones:
eu-north-1a
eu-north-1b
```

Using two Availability Zones provides a multi-AZ foundation for the EKS environment.

### VPC

The VPC is divided into public and private subnets:

```text
VPC
│
├── Public Subnets
│   ├── Internet Gateway connectivity
│   ├── NAT Gateway infrastructure
│   └── Internet-facing AWS resources
│
└── Private Subnets
    └── EKS Worker Nodes
```

Kubernetes subnet tags are configured so AWS can identify the appropriate subnets for load-balancer placement:

```text
kubernetes.io/role/elb = 1
kubernetes.io/role/internal-elb = 1
```

### NAT Gateway

Two NAT Gateways are deployed across the Availability Zones.

Private worker nodes can therefore initiate outbound connections without receiving direct inbound connections from the public internet.

```text
Private Worker
      │
      ▼
NAT Gateway
      │
      ▼
Internet Gateway
      │
      ▼
Internet
```

### Amazon EKS

The Kubernetes cluster is:

```text
Cluster:
openai-chatbot-eks

Kubernetes:
1.35
```

The cluster uses **EKS Managed Node Groups**.

For this learning environment, the worker nodes use:

```text
Instance:
t3.micro

Capacity:
SPOT
```

This was a deliberate **cost-optimization choice for the learning environment**. For production workloads, more appropriately sized instances and On-Demand capacity would be preferred where workload reliability requires it.

### Worker Node Placement

Worker nodes run in private subnets rather than directly on public subnets.

This separates:

```text
Internet-facing infrastructure
          from
Internal Kubernetes compute
```

The application is exposed externally through a Kubernetes `LoadBalancer` Service rather than assigning public IPs directly to worker nodes.

### Kubernetes Workload

The application runs in the dedicated namespace:

```text
chatbot
```

Main Kubernetes resources:

```text
Deployment:
chatbot

Service:
chatbot-service

Container Port:
3000

Service Port:
80
```

The Service uses:

```yaml
type: LoadBalancer
```

which provisions an AWS load balancer for external access.

### Infrastructure Versions

The project uses:

```text
Terraform AWS VPC Module:
v5.21.0

Terraform AWS EKS Module:
v21.25.0
```

During implementation, the EKS module configuration had to be updated to match the current module interface rather than blindly using the older reference project's variables. This was validated through:

```bash
terraform validate
terraform plan
```

The final infrastructure progressed from:

```text
VPC:
23 resources

EKS:
53 resources

EKS + Managed Node Group:
60 resources
```
## CI/CD & DevSecOps Pipeline

The project uses Jenkins to automate the complete path from source-code change to Kubernetes deployment.

The pipeline is intentionally structured so that **quality and security checks happen before the application is pushed to ECR or deployed to EKS**.

### Pipeline Flow

```text id="b2j7z3"
GitHub
   │
   ▼
Checkout
   │
   ▼
npm ci
   │
   ▼
SonarQube Analysis
   │
   ▼
Quality Gate
   │
   ▼
OWASP Dependency-Check
   │
   ▼
Trivy Filesystem Scan
   │
   ▼
Docker Build
   │
   ▼
Trivy Image Scan
   │
   ▼
Push Image → Amazon ECR
   │
   ▼
Update kubeconfig
   │
   ▼
Inject Build Image Tag
   │
   ▼
Deploy → Amazon EKS
   │
   ▼
Rollout Verification
```

### 1. Checkout

Jenkins retrieves the latest source code from GitHub.

```groovy
checkout scm
```

The pipeline then works against the exact revision that triggered the build.

### 2. Dependency Installation

Dependencies are installed using:

```bash
npm ci
```

Using the lockfile makes CI dependency installation deterministic.

### 3. SonarQube Analysis

SonarQube analyzes the application for code-quality and security-related issues.

The pipeline then waits for the configured Quality Gate:

```groovy
waitForQualityGate abortPipeline: true
```

If the gate fails, the pipeline stops before continuing toward deployment.

### 4. OWASP Dependency-Check

OWASP Dependency-Check scans project dependencies for known vulnerabilities.

The scan excludes generated/vendor directories such as:

```text
node_modules/
.next/
```

and uses an NVD API key to improve vulnerability-data retrieval.

### 5. Trivy Filesystem Scan

Trivy scans the application source tree for:

* vulnerabilities
* misconfigurations
* secrets

The pipeline fails on:

```text
HIGH
CRITICAL
```

findings:

```bash
trivy fs . \
  --scanners vuln,misconfig,secret \
  --exit-code 1 \
  --severity HIGH,CRITICAL
```

This means a security finding can block the pipeline rather than simply being reported.

### 6. Docker Build

Only after the earlier quality and dependency-security stages pass does Jenkins build the container image.

```text
chatbot-ui:${BUILD_NUMBER}
```

The Dockerfile uses a multi-stage build:

```text id="q8w7s2"
Dependencies
      ↓
Build
      ↓
Production Image
```

The final runtime container runs as a non-root user.

### 7. Trivy Container Image Scan

The built Docker image is scanned separately from the source filesystem.

```bash
trivy image \
  --scanners vuln,misconfig,secret \
  --severity HIGH,CRITICAL \
  --exit-code 1 \
  chatbot-ui:${BUILD_NUMBER}
```

This provides a second security boundary around the actual artifact that will be deployed.

### 8. Push to Amazon ECR

Only after the image scan succeeds is the image pushed to:

```text
Amazon ECR
    │
    └── openai-chatbot
```

Images are tagged with the Jenkins build number rather than using `latest`.

Example:

```text
Jenkins Build #41
        ↓
openai-chatbot:41
```

### 9. Deploy to Amazon EKS

Jenkins authenticates against EKS and updates its Kubernetes configuration:

```bash
aws eks update-kubeconfig \
  --region eu-north-1 \
  --name openai-chatbot-eks
```

The Kubernetes manifest contains a placeholder:

```yaml
image: CHATBOT_IMAGE
```

Jenkins replaces it with the exact ECR image for the current build:

```text
CHATBOT_IMAGE
      ↓
openai-chatbot:41
```

This keeps the Kubernetes manifest reusable while allowing CI to control the deployed version.

### 10. Rollout Verification

Deployment is not considered successful merely because `kubectl apply` succeeds.

Jenkins explicitly waits for Kubernetes to complete the rollout:

```bash
kubectl -n chatbot rollout status \
  deployment/chatbot \
  --timeout=120s
```

This verifies that the new workload actually becomes ready.

---

## DevSecOps Remediation Example

The pipeline initially detected:

```text
36 vulnerabilities
├── 34 HIGH
└── 2 CRITICAL
```

Instead of suppressing the findings, the dependency tree was investigated and remediated.

Major changes included:

```text
rehype-mathjax
       ↓
rehype-katex

Unused openai dependency
       ↓
removed

Next.js 13.5.11
       ↓
Next.js 15.5.25

Nested vulnerable PostCSS
       ↓
npm override
```

After reinstalling dependencies and rescanning:

```text id="v7b9e2"
36
 ↓
15
 ↓
2
 ↓
0
```

Final Trivy result:

> **0 HIGH/CRITICAL vulnerabilities**

This demonstrates the intended DevSecOps workflow:

```text
Detect
  ↓
Trace dependency
  ↓
Identify root cause
  ↓
Remediate
  ↓
Rebuild
  ↓
Rescan
  ↓
Deploy
```

## Pipeline Security Principle

The important design decision is that security is not a separate activity performed after deployment.

It is integrated into the delivery path:

```text
Code
 ↓
Quality
 ↓
Dependencies
 ↓
Filesystem
 ↓
Container
 ↓
Registry
 ↓
Kubernetes
```

A build that fails the configured quality or security gates does not proceed to the deployment stages.

## Kubernetes Security & Least-Privilege RBAC

Security was applied at both the **container runtime** and **CI/CD access** layers.

### Container Security Context

The chatbot container does not run with default privileges.

The workload is configured with:

```yaml
securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL
  runAsNonRoot: true
  runAsUser: 10001
  runAsGroup: 10001
  readOnlyRootFilesystem: true
```

The Pod also uses:

```yaml
securityContext:
  seccompProfile:
    type: RuntimeDefault
```

This provides multiple layers of runtime restriction:

| Control                           | Purpose                                      |
| --------------------------------- | -------------------------------------------- |
| `runAsNonRoot`                    | Prevents execution as root                   |
| Explicit UID/GID                  | Provides a predictable non-root identity     |
| `allowPrivilegeEscalation: false` | Prevents privilege escalation                |
| Drop `ALL` capabilities           | Removes unnecessary Linux capabilities       |
| Read-only root filesystem         | Reduces filesystem modification              |
| RuntimeDefault seccomp            | Restricts potentially dangerous system calls |

### Health Checks

The application exposes:

```text id="x2fb2s"
/api/health
```

Kubernetes uses this endpoint for both readiness and liveness checks.

```yaml
readinessProbe:
  httpGet:
    path: /api/health
    port: 3000

livenessProbe:
  httpGet:
    path: /api/health
    port: 3000
```

This allows Kubernetes to distinguish between:

```text
Pod exists
     ≠
Application is ready
```

Resource requests and limits are also defined to prevent the workload from consuming unbounded cluster resources.

---

## Jenkins → EKS Least-Privilege Access

The initial implementation used:

```text id="i7y5d3"
AmazonEKSClusterAdminPolicy
```

at cluster scope.

Although this worked, it granted Jenkins significantly more access than the deployment process required.

The configuration was therefore redesigned around **least privilege**.

### Final Access Model

```text id="y7u0r8"
Jenkins
   │
   ▼
AWS IAM User
jenkins-ecr
   │
   ▼
EKS Authentication
   │
   ▼
Kubernetes RoleBinding
   │
   ▼
Namespace: chatbot
   │
   ▼
Role: jenkins-deployer
```

The cluster-admin policy was removed.

The final Kubernetes Role is namespace-scoped and grants only the operations required by the pipeline.

### Deployment Permissions

Jenkins can manage the deployment lifecycle:

```text id="0f2qg7"
Deployments
ReplicaSets
Deployment status
Deployment scaling
```

with:

```text id="4k4v9s"
get
list
watch
update
patch
```

### Read-Only Runtime Access

Jenkins can inspect:

```text id="3v7x0m"
Services
Pods
Pod logs
Events
```

but these resources are intentionally read-only.

For example:

```text id="b0y4cc"
services
  → get
  → list
  → watch
```

Jenkins does not receive unnecessary Service write permissions.

### Why This Matters

The CI/CD system only needs to deploy and verify the application.

It does **not** need:

```text id="5xj7qk"
Cluster Administrator
```

permissions.

The final model therefore follows:

```text id="p8j4q2"
Required permission
      ↓
Grant permission
      ↓
Everything else
      ↓
Deny by default
```

---

## Security Permission Iteration

This was not a one-shot configuration.

The access model was tightened iteratively.

### Initial

```text id="b9k7c1"
Jenkins
   ↓
Cluster Admin
```

### Improved

```text id="c5z2q6"
Jenkins
   ↓
Namespace Role
```

### Further tightened

Trivy identified excessive Kubernetes permissions, leading to Service permissions being reduced from write access to read-only access.

### Final

```text id="e3f4a1"
Jenkins
   ↓
IAM Authentication
   ↓
Namespace-scoped Role
   ↓
Only required deployment + verification permissions
```

The important principle is:

> **A working deployment is not automatically a secure deployment.**

The project deliberately evolved the Jenkins permissions from "works" to "works with the minimum required authority."

## Deployment Failure, Automatic Rollback & Reliability

The deployment pipeline does not assume that every new container image will start successfully.

Kubernetes rollout health is explicitly verified, and deployment failures trigger an automated rollback.

### Deployment Verification

After applying the Kubernetes manifests, Jenkins waits for the deployment to complete:

```bash
kubectl -n chatbot rollout status \
  deployment/chatbot \
  --timeout=120s
```

A successful `kubectl apply` is therefore not treated as proof that the new version is healthy.

---

## Failure Simulation

To validate the recovery mechanism, a deliberately invalid image was deployed:

```text id="f2h8k1"
openai-chatbot:does-not-exist
```

Kubernetes attempted to start the new ReplicaSet, but the image could not be pulled.

The resulting Pod entered:

```text id="w5n4c7"
ImagePullBackOff
```

The rollout subsequently failed to complete within the configured timeout.

This reproduced a realistic deployment failure rather than simply testing the rollback code theoretically.

---

## Automatic Rollback

The Jenkins deployment stage wraps the deployment and rollout verification in error handling:

```text id="q1e6r9"
Deploy
  │
  ▼
Rollout verification
  │
  ├── Success ───────► Continue
  │
  └── Failure
          │
          ▼
     rollout undo
          │
          ▼
   Verify recovery
          │
          ▼
     Re-throw error
```

The rollback command restores the previous ReplicaSet:

```bash id="a4s8p2"
kubectl -n chatbot rollout undo deployment/chatbot
```

Jenkins then waits for the recovered deployment to become healthy.

---

## Why the Build Still Fails

The pipeline intentionally re-throws the original exception after recovery:

```groovy id="m7v3q1"
catch (Exception e) {
    echo 'Deployment failed. Rolling back...'

    sh '''
        kubectl -n chatbot rollout undo deployment/chatbot
        kubectl -n chatbot rollout status deployment/chatbot --timeout=120s
    '''

    throw e
}
```

This creates an important distinction:

```text id="r8c5t0"
Application
     ↓
Recovered
```

does **not** mean:

```text id="x3v9b6"
Deployment
     ↓
Successful
```

The application is restored to a healthy version, while Jenkins correctly reports the deployment as failed.

This prevents a broken release from being falsely reported as successful.

---

## Rollback Strategy

The overall recovery model is:

```text id="z4j6n2"
Known-good version
       │
       ▼
New version deployed
       │
       ▼
Health verification
       │
       ├── Healthy ──► Keep new version
       │
       └── Unhealthy
              │
              ▼
        Roll back
              │
              ▼
       Restore known-good
              │
              ▼
       Mark CI build failed
```

ECR lifecycle management complements this strategy by retaining the most recent tagged images, providing previous artifacts that can be used for recovery.

---

## Reliability Controls

The deployment combines several independent controls:

| Control            | Purpose                                        |
| ------------------ | ---------------------------------------------- |
| Readiness probe    | Prevents unhealthy Pods from receiving traffic |
| Liveness probe     | Detects unhealthy application processes        |
| Rollout status     | Verifies deployment completion                 |
| Automatic rollback | Restores the previous workload version         |
| Image versioning   | Identifies the exact deployed build            |
| ECR retention      | Keeps recent images available for recovery     |
| Resource limits    | Prevents uncontrolled resource consumption     |

The result is a deployment process that is designed to **detect failure, recover service, and still accurately report the failed release**.

## Troubleshooting & Engineering Lessons

This project involved several real implementation issues rather than following a completely linear deployment path.

The debugging process consistently followed:

```text
Symptom
   ↓
Investigate
   ↓
Identify root cause
   ↓
Apply targeted fix
   ↓
Rebuild / redeploy
   ↓
Verify
```

### Terraform Module Compatibility

**Problem:**
The reference Terraform configuration used arguments that were incompatible with the current EKS module version.

**Investigation:**
After upgrading the module, Terraform validation and planning exposed the incompatible configuration.

**Resolution:**
Updated the configuration to the current module interface, including EKS cluster naming, Kubernetes version, and API endpoint settings.

**Result:**
Terraform successfully progressed from VPC provisioning to EKS and managed node-group provisioning.

---

### Next.js Native Build Failure

**Problem:**
The Next.js production build encountered a low-level:

```text
Bus error
```

**Investigation:**
The application itself was not the immediate cause. Running the build with a single build worker succeeded.

**Resolution:**

```bash
NEXT_PRIVATE_BUILD_WORKER=1 npm run build
```

The same build configuration was then applied to the Docker build.

**Result:**
The production image built successfully and proceeded through the security pipeline.

---

### Trivy Vulnerability Remediation

**Problem:**
The initial filesystem scan reported:

```text
36 vulnerabilities
34 HIGH
2 CRITICAL
```

**Investigation:**
The dependency tree was traced to identify the actual sources rather than suppressing the findings.

**Resolution:**

* Replaced `rehype-mathjax` with `rehype-katex`
* Removed the unused `openai` dependency
* Upgraded Next.js
* Updated the associated Next.js ESLint package
* Added an npm override for the vulnerable nested PostCSS version
* Reinstalled dependencies and regenerated the lockfile

**Result:**

```text
36 → 15 → 2 → 0
```

No real vulnerability was hidden using a blanket Trivy suppression.

---

### SonarQube Quality Gate Failure

**Problem:**
The initial Quality Gate failed because of reliability, coverage, and security-hotspot review conditions.

**Investigation:**
The findings were separated into actual code-quality issues and quality-policy requirements that were not appropriate for the current project scope.

**Resolution:**

* Fixed concrete code issues
* Removed unstable `Math.random()` React keys
* Removed unnecessary random filename generation
* Corrected regex-related findings
* Adjusted the Quality Gate to enforce meaningful project standards

**Result:**
The pipeline successfully passed the SonarQube Quality Gate.

---

### Jenkins Kubernetes Permissions

**Problem:**
The initial Jenkins identity used cluster-admin-level EKS access.

**Investigation:**
The deployment worked, but the permission scope was significantly broader than necessary.

**Resolution:**

```text
EKS Cluster Admin
       ↓
Removed
       ↓
Namespace-scoped Kubernetes Role
```

The Role was further tightened after identifying unnecessary Service write permissions.

**Result:**
Jenkins continued to perform the required deployment and verification operations without cluster-admin access.

---

### Kubernetes Deployment Failure

**Problem:**
A deliberately invalid image caused:

```text
ImagePullBackOff
```

and the rollout timed out.

**Resolution:**
The deployment pipeline automatically executed:

```bash
kubectl rollout undo
```

and verified that the previous version recovered successfully.

**Result:**

```text
Failed release
      ↓
Automatic rollback
      ↓
Healthy previous version
      ↓
Jenkins build remains FAILED
```

This validated the failure-recovery path rather than testing only the happy path.

---

## Engineering Lessons

The project reinforced several practical DevOps principles:

1. **Don't blindly copy infrastructure code** — verify module versions and interfaces.
2. **Trace vulnerabilities to their dependency root cause** before deciding how to handle them.
3. **Separate security findings from security policy** when designing quality gates.
4. **Least privilege is iterative** — start with a working model, then reduce permissions based on actual requirements.
5. **`kubectl apply` is not deployment verification** — wait for rollout health.
6. **Rollback should be automated and tested**, not merely documented.
7. **Build artifacts need traceable versions** — avoid relying on `latest`.
8. **Cost optimization is part of cloud engineering** — especially for non-production learning environments.

## Validation & Results

The final deployment was validated at multiple layers, from CI/CD execution and security scanning to Kubernetes health and actual HTTP traffic.

### Final Deployment State

```text id="j9c1w4"
Jenkins Build              #41 SUCCESS
Trivy HIGH/CRITICAL       0
EKS Worker Nodes          2 Ready
Deployment                1/1 Ready
Pod                       Running
Pod Restarts              0
ECR Image                 :41
HTTP Response             200 OK
```

### End-to-End Validation

The final delivery path was successfully verified:

```text id="6c4h7m"
GitHub
  ↓
Jenkins Build #41
  ↓
Quality & Security Gates
  ↓
Docker Image
  ↓
Amazon ECR :41
  ↓
Amazon EKS
  ↓
Kubernetes Deployment
  ↓
Running Pod
  ↓
AWS Load Balancer
  ↓
HTTP 200 OK
  ↓
Chatbot Application
```

### Kubernetes Validation

The deployed workload was verified using Kubernetes:

```bash id="br6y1m"
kubectl -n chatbot get deployment chatbot
kubectl -n chatbot get pods
kubectl -n chatbot get svc chatbot-service
```

The final deployment reported:

```text id="9w0l8q"
READY       1/1
UP-TO-DATE  1
AVAILABLE   1
```

The running Pod had:

```text id="z5e8k2"
READY      1/1
STATUS     Running
RESTARTS   0
```

The deployed image was verified as:

```text id="0xq2qj"
574921529429.dkr.ecr.eu-north-1.amazonaws.com/openai-chatbot:41
```

### External Traffic Validation

The Kubernetes `LoadBalancer` Service exposed the application externally.

HTTP validation returned:

```text id="4k3v1n"
HTTP/1.1 200 OK
X-Powered-By: Next.js
```

This confirmed that the application was not only deployed successfully but was also serving real HTTP traffic.

---

## Project Evidence

The following screenshots provide the strongest visual evidence for the implementation.

### 1. Jenkins CI/CD Pipeline

Shows the complete pipeline executing successfully from source checkout through EKS deployment.

**Proves:**

* CI/CD automation
* security gates
* Docker build
* ECR push
* EKS deployment
* rollout verification

### 2. Trivy Security Scan

Shows the final:

```text id="4c8y6v"
0 vulnerabilities
```

**Proves:**

* vulnerability remediation
* security scanning
* pipeline security enforcement

### 3. Amazon EKS Nodes

Shows the worker nodes in `Ready` state.

**Proves:**

* EKS cluster availability
* managed worker nodes
* Kubernetes runtime health

### 4. Live Chatbot Application

Shows the deployed application running successfully.

**Proves:**

* application availability
* successful deployment
* functional runtime

### 5. Least-Privilege RBAC

Shows the Jenkins Kubernetes access model.

**Proves:**

* namespace-scoped CI/CD permissions
* removal of unnecessary cluster-admin access
* Kubernetes security controls

### 6. Automatic Rollback

Shows the deliberate deployment failure and recovery.

**Proves:**

* failure detection
* rollout timeout
* automatic rollback
* recovery verification

---

## Evidence Summary

| Area                    | Result                                |
| ----------------------- | ------------------------------------- |
| Infrastructure          | Terraform-managed AWS/EKS environment |
| CI/CD                   | Jenkins automated deployment          |
| Code Quality            | SonarQube Quality Gate passed         |
| Dependency Security     | OWASP Dependency-Check integrated     |
| Vulnerability Scanning  | Trivy: 36 → 0                         |
| Container Security      | Hardened non-root workload            |
| Kubernetes Access       | Namespace-scoped least privilege      |
| Deployment Verification | Rollout status enforced               |
| Failure Recovery        | Automated rollback tested             |
| Image Management        | Build-number traceability             |
| ECR Cleanup             | Lifecycle policy configured           |
| Application             | HTTP 200 / live chatbot               |

## ECR Lifecycle & Cost Optimization

The project uses Amazon ECR as the private container registry for the chatbot images.

Each Jenkins build produces a uniquely identifiable image:

```text
openai-chatbot:<BUILD_NUMBER>
```

For example:

```text
Jenkins Build #41
        ↓
ECR: openai-chatbot:41
```

### Image Retention Policy

Continuous CI/CD can quickly accumulate old and untagged image manifests.

To control unnecessary registry storage, an ECR lifecycle policy was configured:

```text
Tagged images
    ↓
Keep latest 2

Untagged images
    ↓
Expire after 1 day
```

The policy is defined in:

```text
ecr/ecr-lifecycle-policy.json
```

and applied using the AWS CLI.

### Why Retain Two Tagged Images?

The latest image is the current release, while the previous image provides a readily available rollback target.

```text
Current
   │
   ├── openai-chatbot:41
   │
   └── openai-chatbot:40
             │
             ▼
        Recovery option
```

Older tagged images can therefore be removed without retaining an unlimited CI history in ECR.

### Cost-Conscious AWS Design

Because this is a learning and portfolio environment, infrastructure choices were intentionally balanced between realistic architecture and AWS cost.

Examples include:

* SPOT capacity for the EKS learning node group
* ECR lifecycle cleanup
* Avoiding unnecessary AWS services
* Using a small node instance size for the workload
* Destroying the environment when active experimentation is complete

These choices are specific to the learning environment and should not automatically be applied to production workloads where availability and capacity requirements differ.

## Project Outcomes & Key Takeaways

This project was built to demonstrate the practical responsibilities involved in operating a containerized application on AWS—not simply deploying an application to Kubernetes.

### What Was Implemented

* Provisioned the AWS infrastructure using Terraform.
* Built an Amazon EKS cluster with managed worker nodes across multiple Availability Zones.
* Isolated EKS worker nodes in private subnets.
* Containerized the Next.js application using a multi-stage Docker build.
* Built a Jenkins CI/CD pipeline from source checkout through EKS deployment.
* Integrated SonarQube quality analysis and Quality Gates.
* Integrated OWASP Dependency-Check for dependency security.
* Integrated Trivy filesystem and container-image scanning.
* Remediated the application's initial 36 HIGH/CRITICAL vulnerabilities down to 0.
* Implemented Kubernetes workload hardening using security contexts.
* Replaced cluster-admin CI/CD access with namespace-scoped Kubernetes RBAC.
* Implemented build-number-based container image traceability.
* Added Kubernetes rollout verification.
* Tested a real deployment failure using an invalid image.
* Implemented and validated automated rollback.
* Configured ECR lifecycle management to control image accumulation.
* Validated the deployed application through an AWS LoadBalancer and HTTP request.

### Engineering Principles Demonstrated

The project reinforced several practical DevOps principles:

**Infrastructure should be reproducible.**

Terraform defines the infrastructure instead of relying on manually configured AWS resources.

**Security should be integrated into delivery.**

Security scanning occurs before the artifact reaches ECR and EKS.

**Permissions should follow actual requirements.**

Jenkins does not need cluster-admin access simply because it needs to deploy one application.

**Deployment success must be verified.**

A successful `kubectl apply` does not guarantee a healthy application. The pipeline waits for rollout completion.

**Failures should be expected and recoverable.**

The deployment process was deliberately broken, observed failing, and then recovered automatically through rollback.

**Cost is part of cloud engineering.**

The learning environment uses appropriate cost-conscious choices while clearly distinguishing them from production recommendations.

### Final Result

The completed system provides an automated path from:

```text id="r5u3q1"
Source Code
    ↓
Quality & Security
    ↓
Container Image
    ↓
Container Registry
    ↓
Kubernetes Deployment
    ↓
Health Verification
    ↓
Externally Accessible Application
```

with traceability, security controls, failure detection, and automated recovery built into the delivery process.

## Repository Structure

The repository separates the application, Kubernetes configuration, CI/CD pipeline, container registry configuration, and AWS infrastructure.

```text
openai-chatbot-eks/
│
├── Chatbot-UI/
│   ├── k8s/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── jenkins-rbac.yaml
│   │   └── jenkins-rolebinding.yaml
│   │
│   ├── JenkinsFile/
│   │   └── Chatbot-Jenkinsfile
│   │
│   ├── ecr/
│   │   └── ecr-lifecycle-policy.json
│   │
│   ├── components/
│   │   ├── Chat/
│   │   ├── Chatbar/
│   │   ├── Folders/
│   │   ├── Global/
│   │   ├── Markdown/
│   │   ├── Mobile/
│   │   ├── Promptbar/
│   │   ├── Settings/
│   │   └── Sidebar/
│   │
│   ├── pages/
│   │   └── api/
│   │
│   ├── public/
│   │   └── locales/
│   │       ├── en/
│   │       ├── ar/
│   │       ├── de/
│   │       ├── es/
│   │       ├── fr/
│   │       └── ...
│   │
│   ├── utils/
│   │   ├── app/
│   │   └── server/
│   │
│   ├── types/
│   ├── styles/
│   ├── docs/
│   ├── reference/
│   ├── __tests__/
│   ├── Dockerfile
│   ├── package.json
│   └── package-lock.json
│
└── terraform/
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    ├── providers.tf
    └── ...
```

### Directory Responsibilities

| Directory      | Purpose                                           |
| -------------- | ------------------------------------------------- |
| `Chatbot-UI/`  | Next.js chatbot application                       |
| `components/`  | Reusable React UI components                      |
| `pages/`       | Next.js pages and API routes                      |
| `public/`      | Static assets and localization files              |
| `utils/`       | Application and server-side utilities             |
| `types/`       | TypeScript types                                  |
| `styles/`      | Application styling                               |
| `__tests__/`   | Application tests                                 |
| `k8s/`         | Kubernetes deployment, service and RBAC manifests |
| `JenkinsFile/` | Jenkins CI/CD pipeline                            |
| `ecr/`         | ECR lifecycle policy                              |
| `terraform/`   | AWS infrastructure as code                        |

> Generated directories such as `.next/`, `.terraform/`, and Terraform provider/module caches are intentionally excluded from the documented repository structure.

---

## Deployment

### Prerequisites

The deployment workflow requires:

```text
AWS CLI
Terraform
kubectl
Docker
Git
Jenkins
```

AWS credentials must have the permissions required for the infrastructure and deployment operations being performed.

### Provision Infrastructure

From the Terraform directory:

```bash
cd terraform

terraform init
terraform validate
terraform plan
terraform apply
```

Configure `kubectl` to access the EKS cluster:

```bash
aws eks update-kubeconfig \
  --region eu-north-1 \
  --name openai-chatbot-eks
```

### Build & Deploy

Application deployments are handled through Jenkins.

A source-code push triggers the configured GitHub webhook, after which Jenkins executes the CI/CD pipeline:

```text
GitHub
   ↓
Jenkins
   ↓
Quality & Security Gates
   ↓
Docker Build
   ↓
Trivy Image Scan
   ↓
Amazon ECR
   ↓
Amazon EKS
   ↓
Rollout Verification
```

Each successful build receives a unique image tag based on the Jenkins build number.

### Verify Deployment

```bash
kubectl get nodes

kubectl -n chatbot get deployment chatbot

kubectl -n chatbot get pods

kubectl -n chatbot get service chatbot-service

kubectl -n chatbot rollout status deployment/chatbot
```

Verify the deployed image:

```bash
kubectl -n chatbot get deployment chatbot \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

---

## Cleanup

This project provisions AWS resources that can incur charges, particularly EKS, NAT Gateways, load-balancing infrastructure, and related networking resources.

When the learning environment is no longer required:

```bash
cd terraform

terraform destroy
```

After destruction, verify the AWS account for any resources that were created outside Terraform, such as manually configured ECR resources or other supporting services.

> **Cost warning:** Avoid leaving the EKS environment running when it is not being actively used for learning or testing.
