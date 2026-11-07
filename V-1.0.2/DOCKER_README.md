# Aarkam AM CLI — Sovereign Fabric Management Container

[![Docker Pulls](https://img.shields.io/docker/pulls/aarkam/aarkam.am.svg)](https://hub.docker.com/r/aarkam/aarkam.am)
[![Docker Image Size](https://img.shields.io/docker/image-size/aarkam/aarkam.am/latest.svg)](https://hub.docker.com/r/aarkam/aarkam.am)
[![Version](https://img.shields.io/badge/version-v1.0.2-blue.svg)](https://github.com/aarkamio/Aarkam)
[![Architecture](https://img.shields.io/badge/arch-linux%2Fx64-orange.svg)](https://hub.docker.com/r/aarkam/aarkam.am)

Official container image for **Aarkam AM CLI** — the unified administrative tool and interactive REPL shell for the **Aarkam Sovereign Storage Fabric**. `am` manages cluster topology, certificates, node lifecycle, Raft consensus, and hardware diagnostics across **Rokka** and **Abodi** deployments.

---

## 1. Quick Start

### Pull the Image

```bash
docker pull aarkam/aarkam.am:latest
# or explicit version
docker pull aarkam/aarkam.am:v1.0.2
```

---

## 2. Usage Modes

### A. Interactive REPL Shell Mode

Drop directly into the high-productivity interactive shell with syntax highlighting, autocomplete, and live status context:

```bash
docker run --rm -it \
  -v aarkam_certs:/var/lib/aarkam \
  -v $(pwd):/workspace \
  -e ROKKA_COORDINATOR_URL="https://rokka-coordinator.aarkam:57774" \
  aarkam/aarkam.am
```

When started with no arguments in an interactive terminal, `am` launches the dynamic REPL shell:
```text
  ___   ___  ______ _   __  ___  ___  ___
 / _ \ / _ \ | ___ \ | / / / _ \ |  \/  |
/ /_\ / /_\ \| |_/ / |/ / / /_\ \| .  . |
|  _  |  _  ||    /|    \ |  _  || |\/| |
| | | | | | || |\ \| |\  \| | | || |  | |
\_| |_|_| |_/\_| \_\_| \_/\_| |_/\_|  |_/

Aarkam Fabric Management Interface [v1.0.2]
Connected to: https://rokka-coordinator.aarkam:57774 (Status: Healthy | Nodes: 3)

am> help
am> cluster status
am> node list
```

---

### B. One-Shot Command Execution Mode

Pass commands directly to `am` for automated scripts, CI/CD, or deployment orchestration:

```bash
# Print general help
docker run --rm aarkam/aarkam.am --help

# Generate a Zero-Trust Root CA and mTLS certificate bundle
docker run --rm \
  -v $(pwd)/security:/var/lib/aarkam \
  -e ROKKA_CLUSTER_CA_PASSWORD="YourStrongPassword123!" \
  aarkam/aarkam.am cert init-ca --output /var/lib/aarkam

# Query cluster health
docker run --rm \
  --network aarkam-net \
  -e ROKKA_COORDINATOR_URL="https://rokka-coordinator.aarkam:57774" \
  aarkam/aarkam.am cluster health

# Inspect bare-metal storage node diagnostics (Abodi)
docker run --rm \
  --network aarkam-net \
  aarkam/aarkam.am node inspect --node-id "abodi-node-01"
```

---

## 3. Storage Architecture Alignment

Aarkam Fabric consists of three core components:

| Component | Image | Function |
| :--- | :--- | :--- |
| **Aarkam AM CLI** | `aarkam/aarkam.am` | Admin CLI & Interactive REPL Control Plane |
| **Aarkam Rokka** | [`aarkam/aarkam.rokka`](https://hub.docker.com/r/aarkam/aarkam.rokka) | Raft Consensus, S3 Gateway & Cluster Coordinator |
| **Aarkam Abodi** | [`aarkam/aarkam.abodi`](https://hub.docker.com/r/aarkam/aarkam.abodi) | Bare-Metal Storage Node Daemon & Hardware Diagnostics |

---

## 4. Environment Variables

| Variable | Default | Purpose |
| :--- | :--- | :--- |
| `ROKKA_COORDINATOR_URL` | `https://rokka-coordinator.aarkam:57774` | Coordinator gRPC mTLS control plane endpoint |
| `ROKKA_CLUSTER_CA_PASSWORD` | *(None)* | Password for decrypting/encrypting mTLS cluster root CA |
| `DOTNET_CLI_TELEMETRY_OPTOUT` | `1` | Disables telemetry for hardened air-gapped environments |

---

## 5. Persistent Volumes

| Mount Path | Description | Recommended Usage |
| :--- | :--- | :--- |
| `/workspace` | Container default working directory | Mount host directory `$(pwd):/workspace` for outputs |
| `/var/lib/aarkam` | Cluster certificates & credentials | Mount persistent named volume `aarkam_certs:/var/lib/aarkam` |
| `/etc/aarkam` | Static cluster configuration | Mount configuration files `appsettings.json` |

---

## 6. Docker Compose Example

```yaml
version: '3.8'

services:
  am-cli:
    image: aarkam/aarkam.am:v1.0.2
    container_name: aarkam-cli
    stdin_open: true
    tty: true
    networks:
      - aarkam-cluster
    environment:
      - ROKKA_COORDINATOR_URL=https://rokka-coordinator.aarkam:57774
    volumes:
      - ./security:/var/lib/aarkam
      - ./:/workspace

networks:
  aarkam-cluster:
    external: true
```

---

## 7. Security and Support

- **Air-Gapped Ready**: Self-contained single-file Linux binary runs entirely offline.
- **Zero-Trust PKI**: Built-in support for ECDSA/P-384 and modern AES-GCM encrypted PKCS#12 bundles.
- **Documentation**: [https://github.com/aarkamio/Aarkam](https://github.com/aarkamio/Aarkam)
