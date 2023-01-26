FROM nginx:1.23.1

ARG CONSUL_TEMPLATE_VERSION=0.30.0

# Set an environment variable for the location of the Consul
# cluster. By default, it tries to resolve to consul-client:8500
# which is the behavior if Consul is running as a container in the 
# same host and linked to this NGINX container (with the alias 
# consul, of course). But this environment variable can also be
# overridden as the container starts if we want to resolve to
# another address.

ENV CONSUL_URL consul-client:8500

# Download the specified version of Consul template
ADD https://releases.hashicorp.com/consul-template/${CONSUL_TEMPLATE_VERSION}/consul-template_${CONSUL_TEMPLATE_VERSION}_linux_amd64.zip /tmp

RUN apt-get update \
  && apt-get install -y --no-install-recommends dumb-init unzip \
  && unzip /tmp/consul-template_${CONSUL_TEMPLATE_VERSION}_linux_amd64.zip -d /usr/local/bin \
  && rm -rf /tmp/consul-template_${CONSUL_TEMPLATE_VERSION}_linux_amd64.zip

COPY consul-template-config.hcl ./consul-template-config.hcl
COPY nginx.ctmpl /usr/templates/nginx.ctmpl

EXPOSE 8085

STOPSIGNAL SIGQUIT

CMD ["dumb-init", "consul-template", "-config=consul-template-config.hcl"]