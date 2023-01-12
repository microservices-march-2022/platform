# Microservices March Demo Architecture Platform (WIP)

Shared infrastructure for the Microservices March demo architecture.


## Usage

The aim is to set things up as manually as possible without involving something heavy like Kubernetes. Future iterations might have examples of more advanced setups.

In this example we use `docker-compose` to allow you to easily get started. The configuration can be held in one file. We also provide instructions for setting things up mostly manually using docker and minimal compose files if you learn better that way.

<details>
  <summary>Quick Start</summary>

    ## Prerequisites

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

    git clone git@github.com:microservices-march/messenger.git
    git clone git@github.com:microservices-march/notifier.git
    git clone git@github.com:microservices-march/platform.git

    cd platform
    ```

    All the following commands assume that you have this directory structure.

    ## Starting the Demo Architecture
    The following command will start all the services and shared infrastructure:

    ```bash
    docker-compose -f docker-compose.full-demo.yml up --abort-on-container-exit
    ```
    > **Note**
    > See that we set `--abort-on-container-exit`. This is because we need all services to be up and running, but docker-compose will happily start up just the services it can if you do not pass this flag. This can lead to confusing failures.

    ## Set up the Databases
    Run the following commands to prepare the databases for the `messenger` and `notifier` applications.

    You should only need to do this once, but you can do it again if you want to "reset" the data back to a clean slate since these commands completely recreate the database.


    ## `messenger` DB Setup
    ```bash
    docker-compose exec -e PGDATABASE=postgres messenger node bin/create-db.mjs

    docker-compose exec messenger node bin/create-schema.mjs

    docker-compose exec messenger node bin/create-seed-data.mjs
    ```

    ## `notifier` DB Setup
    ```bash
    docker-compose exec -e PGDATABASE=postgres notifier node bin/create-db.mjs

    docker-compose exec notifier node bin/create-schema.mjs

    docker-compose exec notifier node bin/create-seed-data.mjs
    ```

    ## Verify it's Working
    Now start tailing the notifier logs to see notifications:
    ```bash
    docker-compose logs -f notifier
    ```

    Now you can create a conversation between two users and send some messages.  You should see information about the notifications going out in the notifier logs.

    ```bash
    # Create a conversation between user 1 and user 2
    curl -d '{"participant_ids": [1, 2]}' -H "Content-Type: application/json" -X POST http://localhost:80/conversations

    # User one sends a message to user two, user two gets notified
    curl -d '{"content": "This is the first message"}' -H "User-Id: 1" -H "Content-Type: application/json" -X POST 'http://localhost:80/conversations/1/messages'

    # User two sends a message to user one, user one gets notified
    curl -d '{"content": "This is the second message"}' -H "User-Id: 2" -H "Content-Type: application/json" -X POST 'http://localhost:80/conversations/1/messages'

    # See all the messages in the conversation
    curl -X GET http://localhost:80/conversations/1/messages

    # Sample output
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
</details>

<details>
  <summary>Manual Setup</summary>
    ## Prerequisites
    Make sure you have this repo as well as the following additional repos checked out:

    * [notifier](https://github.com/microservices-march/notifier)
    * [messenger](https://github.com/microservices-march/messenger)

    ### Start the Shared Platform Infrastructure

    From this repository, run:

    ```bash
    docker-compose up -d
    ```

    ### Start the `messenger` Service

    1. From the `messenger` repository, build the Docker image:

        ```bash
        docker build -t messenger .
        ```

    2. From the `messenger` repository, start the PostgreSQL database:

        ```bash
        docker-compose up -d
        ```

    3. Start the `messenger` service in a container:

        ```bash
        docker run -d -p 8083:8083 --name messenger -e PGPASSWORD=postgres -e CREATE_DB_NAME=messenger -e PGHOST=messenger-db-1 -e AMQPHOST=rabbitmq -e AMQPPORT=5672 -e PORT=8083 --network mm_2023 messenger
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
        docker run -d -p 8084:8084 --name notifier -e PGPASSWORD=postgres -e CREATE_DB_NAME=notifier -e PGHOST=notifier-db-1 -e AMQPHOST=rabbitmq -e AMQPPORT=5672 -e PORT=8084 -e PGPORT=5433 --network mm_2023 notifier
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

    Follow the instructions [here](https://github.com/microservices-march/messenger#using-the-service) to test out the service. You should see notification logs coming from the `notifier:1` container.  You can see them easily by running `docker logs -f notifier`

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

</details>


## RabbitMQ (Message Queue)

Message queues are an important tool in microservices architectures to allow us to further decouple services from each other.

