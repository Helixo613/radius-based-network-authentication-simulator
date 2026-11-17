.PHONY: help build build-backend buildf runs runf dev clean test test-integration test-integration-pg test-eap-acceptance-docker initdb killfs version lint ci setup-hooks build-macos

# Version info
VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo "develop")
BUILD_TIME ?= $(shell date -u '+%Y-%m-%dT%H:%M:%SZ')
GIT_COMMIT ?= $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
LDFLAGS := -s -w -X main.Version=$(VERSION) -X main.BuildTime=$(BUILD_TIME) -X main.GitCommit=$(GIT_COMMIT)

# Default target
help:
	@echo "ToughRADIUS v9 Makefile Commands"
	@echo "================================="
	@echo "Development:"
	@echo "  make runs       - Start backend service (supports SQLite)"
	@echo "  make runf       - Start frontend dev server"
	@echo "  make dev        - Start frontend and backend together"
	@echo "  make killfs     - Stop all frontend and backend services"
	@echo ""
	@echo "Build:"
	@echo "  make build      - Build full release (frontend + backend, recommended)"
	@echo "  make buildf     - Build frontend only"
	@echo "  make build-backend - Build backend only (assumes frontend is built)"
	@echo ""
	@echo "Quality:"
	@echo "  make test       - Run tests"
	@echo "  make test-eap-acceptance-docker - Run external EAP acceptance tests in a Linux container"
	@echo "  make lint       - Run lint"
	@echo "  make ci         - Run full CI checks (local)"
	@echo "  make setup-hooks - Install Git hooks"
	@echo ""
	@echo "Database:"
	@echo "  make initdb     - Initialize database (dangerous: deletes all data)"
	@echo ""
	@echo "Maintenance:"
	@echo "  make clean      - Clean build files"
	@echo ""

# Start backend service (dev mode, SQLite supported)
runs:
	@echo "🚀 Starting Radius Auth Simulator backend..."
	@echo "📝 Config file: toughradius.yml"
	@echo "🔧 SQLite support: enabled (CGO_ENABLED=0)"
	@echo ""
	CGO_ENABLED=0 go run main.go -c toughradius.yml

# Start frontend dev server
runf:
	@echo "🎨 Start frontend dev server..."
	@echo "📂 Working directory: web/"
	@echo "🌐 URL: http://localhost:3000/admin"
	@echo ""
	cd web && npm run dev

# Start frontend and backend (needs tmux or two terminals)
dev:
	@echo "⚠️  Run these in two separate terminals:"
	@echo "   Terminal 1: make runs"
	@echo "   Terminal 2: make runf"
	@echo ""
	@echo "Or run them in the background:"
	@echo "   make runs > /tmp/toughradius-backend.log 2>&1 &"
	@echo "   make runf > /tmp/toughradius-frontend.log 2>&1 &"

# Build production release (static, supports PostgreSQL and SQLite)
build: buildf
	@echo ""
	@echo "🔨 Building backend production release..."
	@echo "📦 Version: $(VERSION)"
	@echo "🕐 Build Time: $(BUILD_TIME)"
	@echo "📝 Git Commit: $(GIT_COMMIT)"
	@echo "⚠️  Static build (CGO_ENABLED=0)"
	@echo ""
	@echo "🔍 Checking frontend build..."
	@test -f web/dist/admin/index.html || (echo "❌ Error: web/dist/admin/index.html does not exist!" && exit 1)
	@test -d web/dist/admin/assets || (echo "❌ Error: web/dist/admin/assets directory does not exist!" && exit 1)
	@ASSET_COUNT=$$(find web/dist/admin/assets -type f 2>/dev/null | wc -l | tr -d ' '); \
	if [ "$$ASSET_COUNT" -lt 1 ]; then \
		echo "❌ Error: web/dist/admin/assets is empty!"; \
		exit 1; \
	fi; \
	echo "✅ Frontend check passed ($$ASSET_COUNT asset files)"
	@echo ""
	@mkdir -p release
	CGO_ENABLED=0 go build -ldflags "$(LDFLAGS)" -o release/toughradius main.go
	@echo ""
	@SIZE=$$(ls -lh release/toughradius | awk '{print $$5}'); \
	echo "✅ Build complete: release/toughradius ($$SIZE)"
	@echo "📁 Frontend embedded in binary"

# Build backend only (no frontend rebuild; assumes it exists)
build-backend:
	@echo "🔨 Building backend only (skipping frontend)..."
	@echo "📦 Version: $(VERSION)"
	@echo "🕐 Build Time: $(BUILD_TIME)"
	@echo "📝 Git Commit: $(GIT_COMMIT)"
	@if [ ! -f web/dist/admin/index.html ]; then \
		echo "⚠️  Warning: frontend not built, building now..."; \
		$(MAKE) buildf; \
	fi
	@mkdir -p release
	CGO_ENABLED=0 go build -ldflags "$(LDFLAGS)" -o release/toughradius main.go
	@SIZE=$$(ls -lh release/toughradius | awk '{print $$5}'); \
	echo "✅ Build complete: release/toughradius ($$SIZE)"

# Build macOS binaries (Apple Silicon + Intel). Pure Go, no CGO, so this
# cross-compiles from Linux too. On a Mac with lipo, also emits a universal binary.
build-macos:
	@test -f web/dist/admin/index.html || $(MAKE) buildf
	@mkdir -p release
	CGO_ENABLED=0 GOOS=darwin GOARCH=arm64 go build -ldflags "$(LDFLAGS)" -o release/radius-simulator-darwin-arm64 main.go
	CGO_ENABLED=0 GOOS=darwin GOARCH=amd64 go build -ldflags "$(LDFLAGS)" -o release/radius-simulator-darwin-amd64 main.go
	CGO_ENABLED=0 GOOS=darwin GOARCH=arm64 go build -o release/radtest-darwin-arm64 ./cmd/radtest
	CGO_ENABLED=0 GOOS=darwin GOARCH=amd64 go build -o release/radtest-darwin-amd64 ./cmd/radtest
	@if command -v lipo >/dev/null 2>&1; then \
		lipo -create -output release/radius-simulator-darwin-universal release/radius-simulator-darwin-arm64 release/radius-simulator-darwin-amd64; \
		echo "Universal binary: release/radius-simulator-darwin-universal"; \
	fi

# Show version info
version:
	@echo "Version:    $(VERSION)"
	@echo "Build Time: $(BUILD_TIME)"
	@echo "Git Commit: $(GIT_COMMIT)"

# Build frontend production bundle
buildf:
	@echo "🎨 Build frontend production bundle..."
	@if [ ! -d web/node_modules ]; then \
		echo "📦 Install frontend dependencies..."; \
		cd web && npm ci; \
	fi
	@echo "🔍 Running TypeScript type check..."
	@cd web && npm run type-check
	@echo "🏗️  Compiling frontend assets..."
	@cd web && npm run build
	@echo ""
	@ASSET_COUNT=$$(find web/dist/admin/assets -type f 2>/dev/null | wc -l | tr -d ' '); \
	echo "✅ Frontend build complete: web/dist/admin/ ($$ASSET_COUNT asset files)"
	@ls -lh web/dist/admin/index.html web/dist/admin/assets/*.js 2>/dev/null | head -5

# Initialize database (dangerous)
initdb:
	@echo "⚠️  Warning: this drops and recreates all database tables!"
	@read -p "Continue?(yes/no): " confirm && [ "$$confirm" = "yes" ] || (echo "Cancelled"; exit 1)
	@echo "🗄️  Initializing database..."
	CGO_ENABLED=0 go run main.go -initdb -c toughradius.yml

# Run tests
test:
	@echo "🧪 Run tests..."
	CGO_ENABLED=0 go test ./...

# Run integration tests
test-integration:
	@echo "🧪 Run integration tests..."
	CGO_ENABLED=0 go test -v ./internal/radiusd/... -run TestRadiusIntegration

# Run integration tests against containerized PostgreSQL / OpenLDAP (real external dependencies)
# Starts the services in docker-compose.test.yml, runs the //go:build integration suite, then cleans up.
test-integration-pg:
	@echo "🐘 Starting PostgreSQL / OpenLDAP test containers and running integration tests..."
	@set -e; \
	COMPOSE="docker compose -p toughradius-it -f docker-compose.test.yml"; \
	cleanup() { echo "🧹 Clean up test containers..."; $$COMPOSE down -v >/dev/null 2>&1 || true; }; \
	trap cleanup EXIT; \
	$$COMPOSE up -d; \
	echo "⏳ Waiting for service health checks..."; \
	for i in $$(seq 1 30); do \
		unhealthy=$$($$COMPOSE ps --format '{{.Health}}' 2>/dev/null | grep -vc '^healthy$$' || true); \
		[ "$$unhealthy" = "0" ] && break; \
		sleep 2; \
	done; \
	if [ "$$unhealthy" != "0" ]; then \
		$$COMPOSE ps; \
		echo "Not all test dependencies are healthy"; \
		exit 1; \
	fi; \
	TEST_DATABASE_HOST=127.0.0.1 \
	TEST_DATABASE_PORT=15432 \
	TEST_DATABASE_USER=toughradius \
	TEST_DATABASE_PASSWORD=toughradius \
	TEST_DATABASE_NAME=postgres \
	TEST_LDAP_URL=ldap://127.0.0.1:1389 \
	TEST_LDAP_BASE_DN=dc=example,dc=org \
	TEST_LDAP_USER_FILTER='(cn=%s)' \
	TEST_LDAP_BIND_DN_TEMPLATE='cn=%s,ou=users,dc=example,dc=org' \
	TEST_LDAP_ADMIN_DN=cn=admin,dc=example,dc=org \
	TEST_LDAP_ADMIN_PASSWORD=adminpassword \
	TEST_LDAP_USER=alice \
	TEST_LDAP_PASSWORD=alice-password \
	INTEGRATION_REQUIRED=1 \
	CGO_ENABLED=0 go test -tags=integration -count=1 -v ./test/integration/...

# Run external eapol_test EAP acceptance tests in a Linux container; useful to reproduce CI on macOS.
# This target does not update docs/reports; local JSON, logs and reports go to build/eap-acceptance/.
test-eap-acceptance-docker:
	@echo "🔐 Running external EAP acceptance tests in a Linux container..."
	@set -e; \
	COMPOSE="docker compose -p toughradius-it -f docker-compose.test.yml"; \
	NETWORK="toughradius-it_default"; \
	cleanup() { echo "🧹 Clean up test containers..."; $$COMPOSE down -v >/dev/null 2>&1 || true; }; \
	trap cleanup EXIT; \
	$$COMPOSE up -d; \
	echo "⏳ Waiting for Postgres health check..."; \
	for i in $$(seq 1 30); do \
		status=$$($$COMPOSE ps --format '{{.Health}}' 2>/dev/null || true); \
		[ "$$status" = "healthy" ] && break; \
		sleep 2; \
	done; \
	mkdir -p build/eap-acceptance; \
	test_status=0; \
	docker run --rm \
		--network "$$NETWORK" \
		-v "$$(pwd):/workspace" \
		-w /workspace \
		-e TEST_DATABASE_HOST=postgres \
		-e TEST_DATABASE_PORT=5432 \
		-e TEST_DATABASE_USER=toughradius \
		-e TEST_DATABASE_PASSWORD=toughradius \
		-e TEST_DATABASE_NAME=postgres \
		-e INTEGRATION_REQUIRED=1 \
		-e EAP_ACCEPTANCE_REQUIRED=1 \
		-e EAP_ACCEPTANCE_RESULT_JSON=/workspace/build/eap-acceptance/eap-acceptance.json \
		-e CGO_ENABLED=0 \
		-e GOCACHE=/tmp/go-build \
		golang:1.26-bookworm \
		bash -c 'set -o pipefail; apt-get update && apt-get install -y --no-install-recommends eapoltest ca-certificates && mkdir -p build/eap-acceptance && go test -tags="integration eap_accept" -count=1 -run TestEAPExternalAcceptance -v ./test/integration/... 2>&1 | tee build/eap-acceptance/go-test.log' || test_status=$$?; \
	if [ -f build/eap-acceptance/eap-acceptance.json ]; then \
		go run ./scripts/eap_acceptance_report.go \
			-input build/eap-acceptance/eap-acceptance.json \
			-report-dir build/eap-acceptance/reports \
			-docs-site-src build/eap-acceptance/docs-site \
			-date "$$(date -u +%F)" \
			-retention 3; \
	fi; \
	echo "✅ EAP Acceptance output: build/eap-acceptance/"; \
	exit $$test_status

# Lint
lint:
	@echo "🔍 Run lint..."
	@echo ""
	@echo "📝 Checking code formatting..."
	@UNFORMATTED=$$(gofmt -l . 2>/dev/null | grep -v vendor || true); \
	if [ -n "$$UNFORMATTED" ]; then \
		echo "❌ The following files need formatting:"; \
		echo "$$UNFORMATTED"; \
		echo "Run 'go fmt ./...' to fix"; \
		exit 1; \
	fi
	@echo "✅ Code formatting OK"
	@echo ""
	@echo "🔎 Running go vet..."
	@CGO_ENABLED=0 go vet ./...
	@echo "✅ go vet OK"
	@echo ""
	@if command -v golangci-lint > /dev/null 2>&1; then \
		echo "🔍 Running golangci-lint..."; \
		golangci-lint run --timeout=5m || true; \
	else \
		echo "💡 Tip: Install golangci-lint for more thorough checks:"; \
		echo "   brew install golangci-lint"; \
	fi
	@echo ""
	@echo "✅ Lint checks completed"

# Local CI checks (mirrors GitHub Actions)
ci: lint test build
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "✅ All CI checks passed!"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Install Git hooks
setup-hooks:
	@echo "🔧 Setting up Git hooks..."
	@chmod +x .githooks/pre-commit .githooks/pre-push
	@git config core.hooksPath .githooks
	@echo "✅ Git hooks installed!"
	@echo ""
	@echo "📋 Installed hooks:"
	@echo "   • pre-commit: format check, go vet, quick build"
	@echo "   • pre-push:   full tests, lint, build check"
	@echo ""
	@echo "💡 To disable hooks temporarily:"
	@echo "   git commit --no-verify"
	@echo "   git push --no-verify"

# Clean build files
clean:
	@echo "🧹 Clean build files..."
	rm -rf release/
	rm -rf web/dist/
	rm -f /tmp/toughradius-test
	@echo "✅ Clean complete"

# Install frontend dependencies
install-frontend:
	@echo "📦 Install frontend dependencies..."
	cd web && npm install

# Check code formatting
fmt:
	@echo "📝 Formatting Go code..."
	go fmt ./...
	@echo "📝 Formatting frontend code..."
	cd web && npm run format || echo "Tip: add a format script to package.json to format frontend code"

# View backend logs
logs:
	@tail -f /tmp/toughradius.log

# View frontend logs
logsf:
	@tail -f /tmp/frontend.log

# Stop all frontend and backend services
killfs:
	@echo "🛑 Stop all frontend and backend services..."
	@pkill -f "go run main.go" 2>/dev/null || true
	@pkill -f "toughradius" 2>/dev/null || true
	@pkill -f "vite" 2>/dev/null || true
	@pkill -f "npm run dev" 2>/dev/null || true
	@echo "✅ All services stopped"

# Restart backend service
restart-backend: killfs
	@echo "🔄 Restart backend service..."
	@make runs

# Quick start (frontend and backend in background)
quick-start: killfs
	@echo "🚀 Quick-starting frontend and backend (background)..."
	@make runs > /tmp/toughradius-backend.log 2>&1 &
	@sleep 3
	@make runf > /tmp/toughradius-frontend.log 2>&1 &
	@sleep 2
	@echo ""
	@echo "✅ Services started!"
	@echo "📊 Backend: http://localhost:1816"
	@echo "🎨 Frontend: http://localhost:3000/admin"
	@echo "📝 Backend log: tail -f /tmp/toughradius-backend.log"
	@echo "📝 Frontend log: tail -f /tmp/toughradius-frontend.log"
	@echo ""
	@echo "🛑 Stop services: make killfs"
