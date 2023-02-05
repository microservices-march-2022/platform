# Manual Setup

> **Note:**
> This repository is meant to hold the shared infrastructure for the demo architecture.
> Starting up the entire system including the applications is not part of its role, but instructions are included here for simplicity.

## Prerequisites

Make sure you have this repo as well as the following additional repos checked out:

- [notifier](https://github.com/microservices-march/notifier)
- [messenger](https://github.com/microservices-march/messenger)

### Start the Shared Platform Infrastructure

From this repository, run:

```bash
docker-compose up -d
```

### Start the `messenger` Service

1. From the `messenger` repository, build the Docker image:

   ```bash
   # From ./app
   docker build -t messenger .
   ```

2. From the `messenger` repository, start the PostgreSQL database:

   ```bash
   docker-compose up -d
   ```

3. Start the `messenger` service in a container:

   ```bash
   docker run -d -p 4000:4000 --name messenger -e PGPASSWORD=postgres -e CREATE_DB_NAME=messenger -e PGHOST=messenger-db-1 -e AMQPHOST=rabbitmq -e AMQPPORT=5672 -e PORT=4000 --network mm_2023 messenger
   ```

4. SSH into the container to set up the PostgreSQL DB:

   ```bash
   docker exec -it messenger /bin/bash
   ```

5. Create the PostgreSQL DB:

   ```bash
   PGDATABASE=postgres node bin/create-db.mjs
   ```

6. Create the PostgreSQL DB tables:

   ```bash
   node bin/create-schema.mjs
   ```

7. Create some PostgreSQL DB seed data:

   ```bash
   node bin/create-seed-data.mjs
   ```

### Start the `notifier` Service

1. From the `notifier` repository, build the Docker image:

   ```bash
   docker build -t notifier .
   ```

2. From the `notifier` repository, start the PostgreSQL database:

   ```bash
   docker-compose up -d
   ```

3. Start the `notifier` service in a container:

   ```bash
   docker run -d -p 5000:5000 --name notifier -e PGPASSWORD=postgres -e CREATE_DB_NAME=notifier -e PGHOST=notifier-db-1 -e AMQPHOST=rabbitmq -e AMQPPORT=5672 -e PORT=5000 -e PGPORT=5433 --network mm_2023 notifier
   ```

4. SSH into the container to set up the PostgreSQL DB:

   ```bash
   docker exec -it notifier /bin/bash
   ```

5. Create the PostgreSQL DB:

   ```bash
   PGDATABASE=postgres node bin/create-db.mjs
   ```

6. Create the PostgreSQL DB tables:

   ```bash
   node bin/create-schema.mjs
   ```

7. Create some PostgreSQL DB seed data:

   ```bash
   node bin/create-seed-data.mjs
   ```

### Use the Service

Follow the instructions [here](https://github.com/microservices-march/messenger#using-the-service) to test out the service. You should see notification logs coming from the `notifier:1` container. You can see them easily by running `docker logs -f notifier`

## Cleanup

Once you are done playing with this microservices demo architecture, to remove all running and dangling containers, run:

```bash
docker stop messenger notifier && docker rm messenger notifier
```

Then, from each cloned repository, run:

```bash
docker-compose down
```

And optionally, to remove any potentially dangling images, run:

```bash
docker rmi $(docker images -f dangling=true -aq)
```
