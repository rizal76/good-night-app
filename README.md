# Good night app

This project uses Ruby on Rails, PostgreSQL, and Redis, fully containerized with Docker.

## Getting Started

### Prerequisites
- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/)

### Setup & Run

Copy `.env.example` to `.env` and edit if needed.

0. All docker have to run with `./docker-compose-run.sh`, so we have to make it executable
   ```sh
   chmod +x docker-compose-run.sh
   ```

1. **Build containers:**
   ```sh
   docker-compose build
   ```

2. **Set up the database:**
   (Runs database migrations and seeds)
   ```sh
   ./docker-compose-run.sh api bin/rails db:migrate
   ./docker-compose-run.sh api bin/rails db:setup
   ```

3. **Seed sample data:**
   (Creates sample users, sleep records, and follow relationships)
   ```sh
   ./docker-compose-run.sh api bin/rails db:seed
   ```

4. **Start the full stack:**
   ```sh
   ./docker-compose-run.sh up
   ```
   Rails API will be available at http://localhost:3000

5. **Stop services:** Press Ctrl-C or run
   ```sh
   ./docker-compose-run.sh down
   ```

### Useful Commands
- Rails Console:
  ```sh
  ./docker-compose-run.sh api bin/rails console
  ```
- Run database migrations manually:
  ```sh
  ./docker-compose-run.sh api bin/rails db:migrate
  ```
- Seed sample data:
  ```sh
  ./docker-compose-run.sh api bin/rails db:seed
  ```
- Run rubocop
  ```sh
  ./docker-compose-run.sh api bundle exec rubocop -f github
  ```

## Stack
- Ruby on Rails (API-only)
- PostgreSQL (Database)
- Redis (Cache/Jobs)
- Docker Compose (orchestrates containers)

---

**No Ruby, Node, or DB setup required on your host!**

This project is set up as a Rails API-only app (no HTML, just JSON endpoints). Frontend should be developed separately if needed.
