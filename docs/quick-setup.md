# Quick Setup

> **Note:**
> This repository is meant to hold the shared infrastructure for the demo architecture.
> Starting up the entire system including the applications is not part of its role, but instructions are included here for simplicity.

## Prerequisites

**Warning:**
For the quick start to work, you must clone all the service repositories into the same directory as shown below

```bash
── microservices_march
    ├── messenger
    ├── notifier
    └── platform <-- you are here
```

For example:

```bash
mkdir microservices_march

cd microservices_march

git clone https://github.com/microservices-march/messenger.git
git clone https://github.com/microservices-march/notifier.git
git clone https://github.com/microservices-march/platform.git

cd platform
```

All the following commands assume that you have this directory structure. The quick start will not work if you deviate.
The name of the parent directory can be whatever you'd like.

## Starting the Demo Architecture

The following command will start all the services and shared infrastructure:

```bash
docker-compose -f docker-compose.full-demo.yml up --build --abort-on-container-exit
```

> **Note:**
> See that we set `--abort-on-container-exit`. This is because we need all services to be up and running, but docker-compose will happily start up just the services it can if you do not pass this flag. This can lead to confusing failures. By default, this will also make Docker output your container logs to your terminal, so you will have to open a new terminal window/tab to follow the rest of this guide.

At this point, all the services, their databases, and the shared infrastructure is up and running. However, we need to set up the database schemas and sample data for the services.

## Setup the Databases

Run the following commands to prepare the databases for the `messenger` and `notifier` applications.

You should only need to do this once, but you can do it again if you want to "reset" the data back to a clean state since these commands completely recreate the database.

### `messenger` Database Setup

```bash
# This script creates the database
docker-compose exec -e PGDATABASE=postgres messenger node scripts/create-db.mjs

# This script sets up the tables, constraints, and indexes
docker-compose exec messenger node scripts/create-schema.mjs

# This script writes seed data to the tables
docker-compose exec messenger node scripts/create-seed-data.mjs
```

### `notifier` Database Setup

```bash
# This script creates the database
docker-compose exec -e PGDATABASE=postgres notifier node scripts/create-db.mjs

# This script sets up the tables, constraints, and indexes
docker-compose exec notifier node scripts/create-schema.mjs

# This script writes seed data to the tables
docker-compose exec notifier node scripts/create-seed-data.mjs
```

## Verify the Deployment is Working

Start tailing the `notifier` logs to see notifications:

```bash
docker-compose logs -f notifier
```

Now you can create a conversation between two users and send some messages. You should see information about the notifications going out in the notifier logs.

```bash
# Create a conversation between user 1 and user 2
curl -d '{"participant_ids": [1, 2]}' -H "Content-Type: application/json" -X POST "http://localhost/conversations"

# User one sends a message to user two, user two gets notified
curl -d '{"content": "This is the first message"}' -H "User-Id: 1" -H "Content-Type: application/json" -X POST "http://localhost/conversations/1/messages"

# User two sends a message to user one, user one gets notified
curl -d '{"content": "This is the second message"}' -H "User-Id: 2" -H "Content-Type: application/json" -X POST "http://localhost/conversations/1/messages"

# See all the messages in the conversation
curl -X GET "http://localhost/conversations/1/messages"
```

Sample output:

```bash
{
  "messages": [
    {
      "id": "1",
      "content": "This is the first message",
      "user_id": "1",
      "channel_id": "1",
      "index": "1",
      "inserted_at": "2023-01-12T03:22:00.000Z",
      "username": "James Blanderphone"
    },
    {
      "id": "2",
      "content": "This is the second message",
      "user_id": "2",
      "channel_id": "1",
      "index": "2",
      "inserted_at": "2023-01-12T03:22:55.000Z",
      "username": "Normalavian Ropetoter"
    }
  ]
}
```

## Cleanup

Once you are done playing with this microservices demo architecture, run:

```bash
docker-compose -f docker-compose.full-demo.yml down
```

And optionally, to remove any potentially dangling images, run:

```bash
docker rmi $(docker images -f dangling=true -aq)
```
