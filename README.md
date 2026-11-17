# Radius Based Network Authentication Simulator

A RADIUS (Remote Authentication Dial-In User Service) server and client toolkit for
simulating network authentication, authorization and accounting (AAA) — the flow a
Wi-Fi access point, VPN gateway or 802.1X switch performs against a RADIUS server.

It ships a full RADIUS server (RFC 2865/2866), EAP / 802.1X methods (EAP-TLS, PEAP,
TTLS, MSCHAPv2, MD5), RadSec (RADIUS over TLS), a web admin console, and `radtest`,
a command-line client that plays the role of a Network Access Server (NAS) so you can
simulate login, accounting start/stop and full session flows.

Runs on **Linux and macOS** (Apple Silicon and Intel). Pure Go, no CGO, embedded SQLite.

> Based on the open-source [ToughRADIUS](https://github.com/talkincode/toughradius)
> project (MIT License). Internal identifiers such as the `TOUGHRADIUS_*` environment
> variables and the `toughradius.yml` config filename are kept for compatibility.

## 🍎 macOS Quick Start

```bash
# Prerequisites (Homebrew)
brew install go node

git clone https://github.com/Helixo613/radius-network-auth-simulator.git
cd radius-network-auth-simulator

# Build frontend + macOS binaries (arm64 + amd64, universal if lipo is present)
make build-macos

# Run the server (Apple Silicon; use -darwin-amd64 on Intel Macs)
./release/radius-simulator-darwin-arm64
```

- Data directory on macOS defaults to `~/.radius-simulator` (Linux: `/var/toughradius`).
  Override with `system.workdir` in `toughradius.yml` or `TOUGHRADIUS_SYSTEM_WORKER_DIR`.
- Timezone follows the system clock (`system.location: Local`).
- Ports 1812/1813 (UDP), 2083 (RadSec) and 1816 (web) are unprivileged — no `sudo` needed.
  macOS may ask once to allow incoming connections; click **Allow**.
- Admin login: user `admin`, password in `~/.radius-simulator/private/admin-bootstrap-password`.
- Unsigned binaries downloaded from the internet may be quarantined by Gatekeeper; clear with
  `xattr -d com.apple.quarantine ./release/radius-simulator-darwin-*`.

### Simulate a client login

1. Load demo data (users `demo-alice`, `demo-bob`, ... with password `123456`, plus a
   local NAS `127.0.0.1` / secret `testing123`). Stop the server first, then:

```bash
go run ./cmd/demo-seed
```

2. Start the server again and send requests as the simulated NAS:

```bash
./release/radtest-darwin-arm64 auth -server 127.0.0.1 -secret testing123 -username demo-alice -password 123456   # Access-Accept
./release/radtest-darwin-arm64 auth -server 127.0.0.1 -secret testing123 -username demo-alice -password wrong    # Access-Reject
./release/radtest-darwin-arm64 flow -server 127.0.0.1 -secret testing123 -username demo-alice -password 123456
```

`flow` runs Access-Request, Accounting-Start and Accounting-Stop, simulating a full session.

## ✨ Core Features

### RADIUS Protocol Support

- 🔐 **Standard RADIUS** - Full support for RFC 2865/2866 authentication and accounting protocols
- 🔒 **RadSec** - TLS encrypted RADIUS over TCP (RFC 6614)
- 🌐 **Multi-Vendor Support** - Compatible with major network devices like Cisco, Mikrotik, Huawei, etc.
- ⚡ **High Performance** - Built with Go, supporting high concurrency processing

### EAP / 802.1X Authentication

A pluggable EAP handler registry covers both challenge and tunneled methods:

- 🪪 **EAP-MD5 / EAP-MSCHAPv2** - Challenge-based password methods (RFC 3748)
- 🔐 **EAP-TLS** - Certificate-based mutual authentication with TLS handshake, fragmentation reassembly, and certificate-to-identity mapping (RFC 5216)
- 🪟 **PEAPv0 / EAP-MSCHAPv2** - Server-certificate TLS tunnel carrying inner EAP-MSCHAPv2 with MPPE key derivation, for Windows / AD / legacy enterprise networks
- 🧩 **EAP-TTLS** - TLS tunnel carrying inner PAP / MS-CHAPv2, onboarding LDAP and legacy credential stores without a per-client certificate rollout (RFC 5281)

> ⚠️ **Compatibility note:** PEAP and EAP-MSCHAPv2 are *compatibility-first* methods. MS-CHAPv2-style exchanges carry an NTLMv1-like attack surface (see Microsoft guidance). Use them to serve legacy devices and AD users; prefer **EAP-TLS** for new deployments where you control the client certificate estate.

### Management Features

- 📊 **React Admin Interface** - Modern Web management dashboard
- 👥 **User Management** - Complete user account and profile management
- 📈 **Real-time Monitoring** - Online session monitoring and accounting record queries
- 🔍 **Log Auditing** - Detailed authentication and accounting logs

### Integration Capabilities

- **Multi-Database Support** - PostgreSQL, SQLite
- 🔌 **Flexible Extension** - Supports custom authentication and accounting logic
- 📡 **Multi-Vendor VSA** - Huawei, Mikrotik, Cisco, H3C, etc.

## 🚀 Quick Start

### Prerequisites

- Go 1.25+ (for building from source)
- PostgreSQL or SQLite
- Node.js 18+ (for frontend development)

### Installation

#### 1. Build from Source

```bash
# Clone repository
git clone https://github.com/Helixo613/radius-network-auth-simulator.git
cd radius-network-auth-simulator

# Build frontend
cd web
npm install
npm run build
cd ..

# Build backend
go build -o toughradius main.go
```

### Configuration

1. Copy the configuration template:

```bash
cp toughradius.yml toughradius.prod.yml
```

2. Edit `toughradius.prod.yml` configuration file:

```yaml
system:
  appid: RadiusAuthSimulator
  location: Local
  workdir: ./rundata

database:
  type: sqlite # or postgres
  name: toughradius.db
  # PostgreSQL configuration
  # host: localhost
  # port: 5432
  # user: toughradius
  # passwd: your_password

radiusd:
  enabled: true
  host: 0.0.0.0
  auth_port: 1812 # RADIUS authentication port
  acct_port: 1813 # RADIUS accounting port
  radsec_port: 2083 # RadSec port

web:
  host: 0.0.0.0
  port: 1816 # Web management interface port
```

### EAP Configuration

ToughRADIUS registers the following EAP handlers out of the box:

| Method | Kind | Notes |
| --- | --- | --- |
| `eap-md5` | Challenge | Default; password challenge (RFC 3748) |
| `eap-mschapv2` | Challenge | MS-CHAPv2 password challenge |
| `eap-tls` | Tunneled (certificate) | Certificate-based mutual authentication (RFC 5216) |
| `eap-peap` | Tunneled | PEAPv0 with inner EAP-MSCHAPv2 (Windows / AD) |
| `eap-ttls` | Tunneled | Inner PAP / MS-CHAPv2 (RFC 5281) |

Fine-tune authentication behavior via system configuration (`sys_config`):

- `radius.EapMethod`: Preferred EAP method offered on EAP-Identity (default `eap-md5`).
- `radius.EapEnabledHandlers`: Allow-list of enabled handlers, comma-separated, e.g. `eap-md5,eap-mschapv2,eap-tls`. Use `*` to enable all registered handlers.

This lets you disable unauthorized EAP methods without interrupting the service.

> ⚠️ MS-CHAPv2-based methods (`eap-mschapv2`, `eap-peap`, and TTLS inner MS-CHAPv2) are compatibility-oriented and carry an NTLMv1-like attack surface. Prefer `eap-tls` for new deployments where you control client certificates.

### Running

```bash
# Initialize database
./toughradius -initdb -c toughradius.prod.yml

# Start service
./toughradius -c toughradius.prod.yml
```

Access Web Management Interface: <http://localhost:1816>

Bootstrap Admin Account:

- Username: `admin`
- Password: generated on first start and written to `{workdir}/private/admin-bootstrap-password` (mode 0600). It is never `toughradius`.

Set `TOUGHRADIUS_ADMIN_PASSWORD` before the first start if you want to choose the initial password yourself. Lost passwords can be reset with `cmd/reset-password`. Upgrades that still have the historical default password rotate it automatically and log the replacement once.

For any deployment exposed beyond a local development host, also set `web.secret` / `TOUGHRADIUS_WEB_SECRET` to a long random value before starting the service; it signs management API JWTs.
Production mode (`system.debug=false` or `logger.mode=production`) refuses to start when the built-in placeholder or an empty JWT secret is still configured.

## 📖 Documentation

- 📚 **[Bilingual Handbook (mdbook)](https://www.toughradius.net/)** - CN/EN documentation site (source in [`docs-site/`](docs-site/)) consolidating the overview, security policy, RFC reference, and more; built, link-checked, and deployed to GitHub Pages by CI
- [Roadmap](docs/roadmap.md) - Milestones and the EAP suite delivery plan (EAP-TLS / PEAP / TTLS, with TLS 1.3, TEAP, EAP-PWD tracked)
- [Feature Checklist](docs/feature-checklist.md) / [English](docs/feature-checklist.en.md) - Product scope baseline for aligning future development with feature IDs and avoiding uncontrolled direction changes
- [Overview](docs-site/src/en/overview.md) / [Concepts & Terminology](docs-site/src/en/concepts.md) - Current architecture, service model, and AAA concepts
- [Admin UI Manual](docs-site/src/en/admin-manual.md) - React Admin management interface, pages, roles, and workflows
- [Operations Guide](docs-site/src/en/ops-guide.md) - Production configuration, environment variables, SQLite/PostgreSQL storage, backup, and runtime operations
- [Documentation Map](docs-site/src/en/documentation-map.md) / [中文](docs-site/src/zh/documentation-map.md) - Canonical map for handbook chapters and repository documents

## 🏗️ Project Structure

```text
toughradius/
├── cmd/             # Application entry points
├── internal/        # Private application code
│   ├── adminapi/   # Admin API (New version)
│   ├── radiusd/    # RADIUS service core
│   ├── domain/     # Data models
│   └── webserver/  # Web server
├── pkg/            # Public libraries
├── web/            # React Admin frontend
└── docs/           # Documentation
```

## 🔧 Development

### Backend Development

```bash
# Run tests
go test ./...

# Run benchmark tests
go test -bench=. ./internal/radiusd/

# Start development mode
go run main.go -c toughradius.yml
```

### Frontend Development

```bash
cd web
npm install
npm run dev       # Development server
npm run build     # Production build
npm run lint      # Code linting
```

## 🤝 Contribution

We welcome contributions in various forms, including but not limited to:

- 🐛 Submitting Bug reports and feature requests
- 📝 Improving documentation
- 💻 Submitting code patches and new features
- 🌍 Helping with translation

## 📜 License

This project is licensed under the [MIT License](LICENSE).

### Third-Party Resources

The RADIUS dictionary files in the `share/` directory are derived from the [FreeRADIUS](https://freeradius.org/) project and are licensed under the [Creative Commons Attribution 4.0 International License (CC BY 4.0)](share/LICENSE).

## 🔗 Related Links

- [Official Website](https://www.toughradius.net/)
- [Online Documentation](https://github.com/talkincode/toughradius/wiki)
- [RadSec RFC 6614](https://tools.ietf.org/html/rfc6614)
- [RADIUS RFC 2865](https://tools.ietf.org/html/rfc2865)
- [EAP RFC 3748](https://tools.ietf.org/html/rfc3748)
- [EAP-TLS RFC 5216](https://tools.ietf.org/html/rfc5216)
- [EAP-TTLS RFC 5281](https://tools.ietf.org/html/rfc5281)
- [Mikrotik RADIUS Configuration](https://wiki.mikrotik.com/wiki/Manual:RADIUS_Client)

## 💎 Sponsors

Thanks to [JetBrains](https://jb.gg/OpenSourceSupport) for supporting this project!

![JetBrains Logo](https://resources.jetbrains.com/storage/products/company/brand/logos/jb_beam.svg)
