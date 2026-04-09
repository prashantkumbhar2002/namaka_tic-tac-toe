.PHONY: dev build test deploy clean

dev:
	docker compose up --build

build:
	cd backend && go build -buildmode=plugin -trimpath -o ./backend.so .
	cd frontend && npm run build

test:
	cd backend && go test ./... -v
	cd frontend && npx vitest run

deploy:
	@echo "Deploy steps: see README.md"

clean:
	docker compose down -v
	rm -f backend/backend.so
	rm -rf frontend/dist
