# Self-Hosted GitLab

This repo documents my work setting up a local GitLab instance with CI/CD runners using Docker.

I am doing this as part of my DevOps journey. Each doc in the `docs/` folder covers a specific thing I built, why it works the way it does, and how to run it yourself.

## What is in here

- `docker-compose.yml` — spins up GitLab and two runners (Python and Node)
- `runners/register.sh` — handles runner registration automatically on startup
- `scripts/bootstrap-tokens.sh` — calls the GitLab API to generate runner tokens, no manual UI clicks needed
- `.gitlab-ci.yml` — a sample CI pipeline with jobs tagged to specific runners
- `docs/` — setup guides with context on what each piece does and why

## How to run it

You need Docker Desktop and at least 4GB of free RAM.

```bash
# 1. Copy the env template and fill in your root password
cp .env

# 2. Start GitLab
docker compose up -d gitlab

# 3. Wait for GitLab to boot (takes 3 to 5 minutes), then run the bootstrap script
./scripts/bootstrap-tokens.sh

# 4. Start the runners
docker compose up -d runner-python runner-node
```

GitLab will be available at `http://localhost`. Log in with username `root` and the password you set.

## Docs

- [Setting up a local GitLab server](docs/setup-gitlab.md)
- [Automated multi-runner setup](docs/automated-runners.md)
