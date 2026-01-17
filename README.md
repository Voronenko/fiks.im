# fiks.im: A Simple Tool for Local App Debugging

Just as lvh.voronenko.net, but branding neutral ;)

# Introduction:
When it comes to developing and debugging applications locally, having a reliable and efficient tool is crucial. One such tool is the domain lvh.me, which acts as a local DNS resolver, 
redirecting all addresses to the localhost. I used it for a long time, but was always missing normal green seal https certificates for this domain. I used for a long time lvh.voronenko.net
which acts in the same way, but as number of mine clients started to use it too, question appeared - can it be more "neutral" ?

Thus I have registered fiks.im, which will valid at least until 2033.  You could be sure, that you will get all subdomains of this domain (except www which points to this repo) to localhost,
and fqdn will be neutral enough to be used by most of the teams.

Thus you will be able to use domains like app.fiks.im,  api.fiks.im , etc

## What is fiks.im?
fiks.im is a domain name that stands close to "we are fixing (smth)". Actually, if you know Albanian, perhaps there are chances it is written exactly in the same way (confirmation needed)
<https://www.translate.com/dictionary/albanian-english/fiksim-11484480>. Learn Albanian! :)

It is specifically designed to simplify mine local app debugging by resolving all domain addresses to the localhost IP address (127.0.0.1).
This means that any request made to a fiks.im subdomain will be automatically redirected to your local machine, allowing you to test and debug your application in a controlled environment.

My usual setup is based on a traefik, check https://github.com/Voronenko/traefik2-compose-template for details. In this repo I will publish basic traefik docker-compose, and green seal certificates,
that you are free to use. They will be updated regularly, to ensure that you always will get authorized https connection locally.

Benefits of using fiks.im:

1. Simplicity: With fiks.im, there is no need to modify your hosts file or set up complex DNS configurations. It provides a straightforward solution for redirecting all requests to your local development environment.

2. Easy setup: Using fiks.im is as simple as including the desired subdomain in your application's URL. If you want https, there is a need to take a look on fiks.im repo and configure
traefik once. For details of traefik configuration and few useful applications, please check out https://github.com/Voronenko/traefik2-compose-template for deeper knowledge and more examples.
This makes fiks.im an ideal tool for myself (and hopefully other developers) who want a quick and hassle-free debugging experience.

3. Versatility: fiks.im + traefik support both HTTP and HTTPS, allowing you to test and debug applications that require secure connections.
This flexibility ensures that you can replicate various scenarios and thoroughly test your app's functionality.

## How to use fiks.im:

1. Include the desired subdomain: To use fiks.im, simply include the desired subdomain as a prefix to your localhost address.
For example, if your app runs on localhost:3000, accessing it through myapp.fiks.im:3000 will redirect the request to your local development environment. If you would use traefik,
you will be able to wrap application behind usual http and https ports, and thus access your application just as https://myapp.fiks.im or http://myapp.fiks.im

2. Testing multiple subdomains: fiks.im allows you to test multiple subdomains simultaneously. For example, you can access subdomain1.fiks.im, subdomain2.fiks.im, and so on. 
This feature is particularly useful when testing multi-tenant applications or different sections of your app.

3. HTTPS support: Repeating, if your application requires HTTPS, fiks.im has got you covered. By using the subdomain with the HTTPS protocol, traefik and fiks.im will ensure that the request 
is redirected securely to your local environment.

Should you have any questions, feel free to contact

## Development meat


### Short notes

to run `docker-compose up -d`

once executed, on  http://traefik.fiks.im:8880/  you can find dashboard.

Take a look on example of

http://whoami.fiks.im:880 or http://whoami.fiks.im
and
https://whoami.fiks.im:8443 or  https://whoami.fiks.im

(depending on ports you have chosen)


Traefik serves only containers that share `traefik-public` docker network.

That introduces some isolation to the application into "public" and "private" parts when needed

for ideas to enable your service as https and http

### Update certs

```sh
make update-certs
```


### Integrating external services 


```yaml

version: '3.4'
services:
  whoami2:
    image: "containous/whoami"
#    container_name: "simple-service2"
    networks:
      - traefik-public
    labels:
      - "traefik.enable=true"
#      - "traefik.http.middlewares.whoami2-https.redirectscheme.scheme=https"
      - "traefik.http.routers.whoami2-http.entrypoints=web"
      - "traefik.http.routers.whoami2-http.rule=Host(`whoami2.fiks.im`)"
#      - "traefik.http.routers.whoami2-http.middlewares=whoami2-https@docker"
      - "traefik.http.routers.whoami2.entrypoints=websecure"
      - "traefik.http.routers.whoami2.rule=Host(`whoami2.fiks.im`)"
      - "traefik.http.routers.whoami2.tls=true"
      - "traefik.http.routers.whoami2.tls.certresolver=default"
networks:
  traefik-public:
    external: true
```


## Local Service Mapping (fiksim CLI)

`fiksim` is a CLI utility included in this repository to easily map local services (running on your host machine) to Traefik domains. It automatically handles HTTP and HTTPS routing.

### Usage

Ensure the script is executable:
```bash
chmod +x fiksim
```

#### Commands

*   **List active mappings:**
    ```bash
    ./fiksim list
    ```

*   **Add a mapping:**
    Maps a fiks.im domain to a local port.
    ```bash
    ./fiksim add <fqdn> <port>
    ```
    *Example:*
    ```bash
    ./fiksim add myapp.fiks.im 3000
    ```
    This will make `http://myapp.fiks.im` and `https://myapp.fiks.im` available via Traefik, proxying traffic to `http://host.docker.internal:3000`.

*   **Remove a mapping:**
    ```bash
    ./fiksim del <fqdn>
    ```
    *Example:*
    ```bash
    ./fiksim del myapp.fiks.im
    ```

## Traefik Inspection CLI (traefik_cli.py)

`traefik_cli.py` is a Python utility to inspect active Traefik routers and map them to their backend Docker containers.

### Usage

Ensure the script is executable:
```bash
chmod +x traefikctl.py
```

Run the script:
```bash
./traefikctl.py
```

### Output
The script prints a table compatible with wide terminal windows:
*   **HOST**: The domain rule.
*   **ENDPOINT**: The Traefik router/service name.
*   **CONTAINER NAME**: The resolved Docker container name.
*   **CONTAINER ID**: The Docker container ID.
*   **CPORT**: The internal service port.

External services mapped via `fiksim` will show as "External/Host".

## Traffic Mirror Generator (fiks-mirror)

`fiks-mirror` is a CLI utility to generate and manage docker-compose files for traffic mirroring. It creates mirror containers that forward copies of traffic to your services for debugging and inspection.

### Usage

Ensure the script is executable:
```bash
chmod +x fiks-mirror
```

#### Commands

*   **Add mirror** (interactive or direct):
    ```bash
    ./fiks-mirror add                    # Interactive selection
    ./fiks-mirror add <service> <network>  # Direct creation
    ./fiks-mirror                        # Same as 'add' (backward compat)
    ./fiks-mirror <service> <network>    # Same as 'add' (backward compat)
    ```
    *Example:*
    ```bash
    ./fiks-mirror add whoami traefik-public
    ```

*   **List mirrors** (show created mirrors with status):
    ```bash
    ./fiks-mirror list
    ```

*   **Start mirror**:
    ```bash
    ./fiks-mirror start <name>
    ```
    *Example:*
    ```bash
    ./fiks-mirror start whoami
    ```

*   **Stop mirror**:
    ```bash
    ./fiks-mirror stop <name>
    ```

*   **Delete mirror** (stop, remove volumes, delete directory):
    ```bash
    ./fiks-mirror del <name>
    ```

*   **List available services** (show Traefik services):
    ```bash
    ./fiks-mirror --list
    ```

*   **Help**:
    ```bash
    ./fiks-mirror --help
    ```

### How It Works

1. `fiks-mirror add` queries the Traefik API to discover all registered services
2. It correlates services with Docker containers to find compose paths, networks, and ports
3. You select a service (via fzf or CLI argument) and its network
4. It generates a `mirrors/<service>/docker-compose.yml` file with a trafficmirror container
5. Use `./fiks-mirror start <name>` to start the mirror
6. The mirror container forwards traffic copies to the original service using the [trafficmirror](https://github.com/rb3ckers/trafficmirror) tool

### Mirror Lifecycle

```bash
# Create a new mirror
./fiks-mirror add whoami traefik-public

# Start the mirror
./fiks-mirror start whoami

# Check mirror status
./fiks-mirror list

# Stop the mirror (keeps configuration)
./fiks-mirror stop whoami

# Delete the mirror (removes everything)
./fiks-mirror del whoami
```

### Environment Variables

The generated docker-compose file supports environment variable overrides:

| Variable | Default | Description |
|----------|---------|-------------|
| `<SERVICE>_LISTEN_PORT` | 8080 | Port mirror listens on |
| `<SERVICE>_TARGET_HOST` | (container name) | Host to forward traffic to |
| `<SERVICE>_TARGET_PORT` | (detected) | Port of original service |
| `<SERVICE>_DOMAIN` | `<service>.fiks.im` | Domain for mirror |

**Example Override**:
```bash
export WHOAMI_LISTEN_PORT=9090
export WHOAMI_DOMAIN=mirror.example.com
docker-compose up
```

### Management Interface

The trafficmirror image exposes a management interface for dynamic reconfiguration:

**Port**: `5<TARGET_PORT>` → mapped to container port 1234

For a service on port 3000, access management at:
```
http://localhost:53000
```

This allows you to change target configuration without restarting the container.
