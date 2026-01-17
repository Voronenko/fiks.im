#!/usr/bin/env python3

import urllib.request
import json
import subprocess
import sys
import re
import os

# Configuration
TRAEFIK_API_URL = "http://localhost:880/api"


def fetch_json(url):
    """Fetch JSON data from a URL."""
    try:
        req = urllib.request.Request(url)
        with urllib.request.urlopen(req) as response:
            if response.status == 200:
                return json.loads(response.read().decode())
    except urllib.error.URLError as e:
        sys.stderr.write(f"Error fetching {url}: {e}\n")
    except Exception as e:
        sys.stderr.write(f"Unexpected error fetching {url}: {e}\n")
    return []


def get_docker_containers():
    """Build a mapping of IP addresses to Container Name/ID and compose info."""
    try:
        # Get all running container IDs
        cmd = ["docker", "ps", "-q"]
        output = subprocess.check_output(cmd).decode().strip()
        if not output:
            return {}
        ids = output.split()

        # Inspect them to get IPs and Names
        cmd_inspect = ["docker", "inspect"] + ids
        inspect_output = subprocess.check_output(cmd_inspect).decode()
        data = json.loads(inspect_output)

        ip_map = {}
        for container in data:
            name = container.get("Name", "").lstrip("/")
            cid = container.get("Id", "")[:12]

            # Extract docker-compose labels
            labels = container.get("Config", {}).get("Labels", {})
            compose_project = labels.get("com.docker.compose.project.working_dir", "")
            compose_service = labels.get("com.docker.compose.service", "")

            # Replace $HOME with ~ in the compose path
            if compose_project:
                home = os.path.expanduser("~")
                if compose_project.startswith(home):
                    compose_project = "~" + compose_project[len(home):]

            container_info = {
                "name": name,
                "id": cid,
                "compose_path": compose_project if compose_project else None,
                "compose_service": compose_service if compose_service else None,
            }

            # Check network settings
            networks = container.get("NetworkSettings", {}).get("Networks", {})
            for net_name, net_conf in networks.items():
                ip = net_conf.get("IPAddress")
                if ip:
                    ip_map[ip] = container_info

            # Additional logic for host mode if needed
            if container.get("HostConfig", {}).get("NetworkMode") == "host":
                # In host mode, IP might not be listed under Networks the same way
                pass

        return ip_map
    except Exception as e:
        sys.stderr.write(f"Error inspecting docker containers: {e}\n")
        return {}


def main():
    # 1. Fetch Traefik Data
    routers_url = f"{TRAEFIK_API_URL}/http/routers"
    services_url = f"{TRAEFIK_API_URL}/http/services"

    routers = fetch_json(routers_url)
    services = fetch_json(services_url)

    if not routers:
        print("No routers found or failed to fetch from Traefik API.")
        return

    # Map Service Name -> Service Data
    service_map = {s.get("name"): s for s in services}

    # 2. Fetch Docker Data
    docker_map = get_docker_containers()

    # 3. Process and Print
    # Header format
    header = f"{'HOST':<45} {'ENDPOINT':<40} {'CONTAINER NAME':<30} {'CONTAINER ID':<15} {'CPORT':<25} {'COMPOSE PATH':<40} {'COMPOSE SERVICE':<20}"
    print(header)
    print("-" * len(header))

    for router in routers:
        if router.get("status") != "enabled":
            continue

        name = router.get("name", "")
        rule = router.get("rule", "")
        service_name = router.get("service", "")

        # Extract Host from Rule
        hosts = []
        if "Host(" in rule:
            matches = re.findall(r"Host\(`([^`]+)`\)", rule)
            hosts.extend(matches)

        display_host = ", ".join(hosts) if hosts else rule

        if len(display_host) > 43:
            display_host = display_host[:40] + "..."

        # Resolve Service
        service = service_map.get(service_name)
        if not service:
            # Try appending provider suffix
            provider = router.get("provider")
            if provider:
                alt_name = f"{service_name}@{provider}"
                service = service_map.get(alt_name)

        target_preview = "-"
        container_info = "N/A"
        container_id = "-"
        compose_path = "-"
        compose_service = "-"

        if service:
            lb = service.get("loadBalancer", {})
            servers = lb.get("servers", [])

            if servers:
                # Just take the first server for brevity list
                url = servers[0].get("url", "")

                # Extract IP/Port
                if "://" in url:
                    try:
                        target = url.split("://")[1]
                        parts = target.split(":")
                        ip = parts[0]
                        port = parts[1] if len(parts) > 1 else ""

                        target_preview = port

                        if "host.docker.internal" in ip:
                            container_info = "External/Host"
                            container_id = "-"
                        elif ip in docker_map:
                            info = docker_map[ip]
                            container_info = info["name"]
                            container_id = info["id"]
                            compose_path = info.get("compose_path") or "-"
                            compose_service = info.get("compose_service") or "-"
                        else:
                            container_info = "Unknown/External"
                            container_id = "-"
                    except IndexError:
                        pass
                    except Exception:
                        pass

        print(
            f"{display_host:<45} {name:<40} {container_info:<30} {container_id:<15} {target_preview:<25} {compose_path:<40} {compose_service:<20}"
        )


if __name__ == "__main__":
    main()
