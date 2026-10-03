FROM ruby:3.4-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential libpq-dev && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN gem install sinatra puma pg rackup

COPY app.rb .

EXPOSE 4567
CMD ["ruby", "app.rb"]