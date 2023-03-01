# Microservices March Demo Architecture Platform (WIP)

Shared infrastructure for the Microservices March demo architecture.

## Overview

The aim of this demo architecture is to set up a microservices architecture as manually as possible without involving something heavy like Kubernetes. Future iterations might have examples of more advanced setups.

## Running Only Shared Infrastructure

If you are working on one of the services, such as [messenger](https://github.com/microservices-march/messenger), that depends on a piece of shared infrastructure to function, you can run `docker-compose up` from this repository to provide that infrastructure. This does not set up the NGINX ingress.

## Setting Up the Demo Architecture

Starting up the entire system including the applications is not part of the role of this repository. However, instructions are included here for simplicity.

We provide two methods to set things up:

1. [Manual Setup](https://github.com/microservices-march/platform/blob/main/docs/manual-setup.md): Follow this guide if you want to manually go through most steps. Recommended for learning.
2. [Quick Setup](https://github.com/microservices-march/platform/blob/main/docs/quick-setup.md): Follow this guide if you want to get started quickly. Automates mosts steps covered in the Manual Setup guide.

## Components

### NGINX (Ingress)

NGINX is used in front of the entire archtecture to provide load balancing to all the services.
Currently only the `messenger` service accepts HTTP requests, so it simply routes to that.

### RabbitMQ (Message Queue)

Message queues are an important tool in microservices architectures to allow us to further decouple services from each other.

## Development

Read the [`CONTRIBUTING.md`](https://github.com/microservices-march/platform/blob/main/CONTRIBUTING.md) file for instructions on how to best contribute to this repository.

## License

[Apache License, Version 2.0](https://github.com/microservices-march/platform/blob/main/LICENSE)

&copy; [F5 Networks, Inc.](https://www.f5.com/) 2023
