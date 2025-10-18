# syntax=docker/dockerfile:1

ARG RUBY_VERSION=3.3.9
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

WORKDIR /app

# Install ALL packages upfront
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    curl libjemalloc2 libvips postgresql-client \
    build-essential git libpq-dev libyaml-dev pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# ✅ USER ARGS + ENV
ARG USER_ID=1000
ARG GROUP_ID=1000
ENV RAILS_ENV="development" \
    BUNDLE_PATH="/usr/local/bundle"

# ✅ CREATE USER IN BASE
RUN groupadd --system --gid ${GROUP_ID} rails && \
    useradd rails --uid ${USER_ID} --gid ${GROUP_ID} --create-home --shell /bin/bash && \
    chown -R rails:rails /app /usr/local/bundle

FROM base AS build

# ✅ SWITCH USER IMMEDIATELY
USER ${USER_ID}:${GROUP_ID}

# Install gems as rails user
COPY --chown=rails:rails Gemfile Gemfile.lock ./
RUN bundle config set frozen 'false' && \
    bundle install && \
    bundle exec bootsnap precompile --gemfile

# Copy app as rails user
COPY --chown=rails:rails . .

RUN bundle exec bootsnap precompile app/ lib/

# Final stage
FROM base

# Copy EVERYTHING as rails user
COPY --from=build --chown=rails:rails "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build --chown=rails:rails /app /app

# Runtime dirs (already owned by COPY --chown)
USER ${USER_ID}:${GROUP_ID}

ENTRYPOINT ["/app/bin/docker-entrypoint"]
EXPOSE 3000
CMD ["./bin/rails", "server"]