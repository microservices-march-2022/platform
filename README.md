# Microservices March Demo Architecture Platform (WIP)

Shared infrastructure for the Microservices March demo architecture.

## Usage

The aim is to set things up as manually as possible without involving something heavy like Kubernetes. Future iterations might have examples of more advanced setups.

## Running just shared infrastructure

If you are running some subset of the services manually, just run `docker-compose up` from this repository to start up the message queue. This does not set up the NGINX load balancer.

## Setting up the whole demo architecture.

Starting up the entire system including the applications is not part of the role of this repository. However, instructions are included here for simplicity.

We provide two methods to set things up:

1. [Quick Setup](docs/quick-setup.md): Based on `docker-compose`. Use this one if you just want to get started quickly.
1. [Manual Setup](docs/manual-setup.md): Uses some `docker-compose` but mostly raw docker commands. Use this if you want go through what the quick start does for you automatically for learning.

## NGINX (Load Balancer)

NGINX is used in front of the entire archtecture to provide load balancing to all the services.
Currently only the `messenger` service accepts HTTP requests, so it simply routes to that.

## RabbitMQ (Message Queue)

Message queues are an important tool in microservices architectures to allow us to further decouple services from each other.
