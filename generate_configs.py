import yaml
import logging
import os
from dotenv import load_dotenv

load_dotenv()

DOMAIN = os.getenv('DOMAIN')
NETWORK_NAME = 'proxy-network'
HOMEPAGE_SERVICE_PATH='config/homepage/services.yaml'
ENTRYPOINT_YML_PATH='custom.yml'

if DOMAIN is None:
    raise RuntimeError("The DOMAIN environment variable is not set.")

SERVICE_KEYS = {
    'required': {'image'},
    'optional': {'title', 'description', 'icon', 'environment', 'volumes', 'labels', 'reverse_proxy', 'ports', 'command', 'depends_on', 'storage'}
}

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

class ConfigGenerator:
    def __init__(self, yml_path):
        self.yml_path = yml_path
        self.yml_data = self._read_yaml_file()
        if self.yml_data:
            self.docker_compose = {
                'services': {},
                'volumes': {},
                'networks': {
                    NETWORK_NAME: {
                        'external': True
                    }
                }
            }
            docker_compose_yml = self.generate_docker_compose()
            self.write_file('docker-compose.yml', docker_compose_yml)

            # Générer Caddyfile
            caddyfile_content = self.generate_caddyfile()
            self.write_file('Caddyfile', caddyfile_content)

            # Générer services.yml
            services_yml = self.generate_services_yml()
            self.write_file(HOMEPAGE_SERVICE_PATH, services_yml)

            logging.info("Files generated successfully!")

    def _read_yaml_file(self):
        if not os.path.exists(self.yml_path):
            logging.error(f"File not found: {self.yml_path}")
            return None
        try:
            with open(self.yml_path, 'r') as file:
                return yaml.safe_load(file)
        except yaml.YAMLError as exc:
            logging.error(f"Error parsing YAML file: {self.yml_path}\n{exc}")
            return None

    def write_file(self, filepath, content):
        try:
            with open(filepath, 'w') as file:
                file.write(content)
                logging.info(f"File written successfully: {filepath}")
        except IOError as exc:
            logging.error(f"Error writing file: {filepath}\n{exc}")

    def _get_reverse_proxy_details(self, reverse_proxy, service_name):
        subdomain = service_name
        port = 80
        if isinstance(reverse_proxy, dict):
            subdomain = reverse_proxy.get('subdomain', subdomain)
            port = reverse_proxy.get('port', port)
        return subdomain, port

    def generate_docker_compose(self):
        for group_name, services in self.yml_data.get('services', {}).items():
            for service_name, service in services.items():
                if not SERVICE_KEYS['required'].issubset(service):
                    logging.warning(f"Service definition incomplete: {service_name}")
                    continue

                compose_service_item = {
                    'container_name': service_name,
                    'image': service['image'],
                    'restart': 'always',
                    'networks': [NETWORK_NAME]
                }

                if 'environment' in service:
                    compose_service_item['environment'] = [f"{var}=${{{var}}}" for var in service['environment']]
                if 'volumes' in service:
                    compose_service_item['volumes'] = service['volumes']
                if 'labels' in service:
                    compose_service_item['labels'] = service['labels']
                if 'ports' in service:
                    compose_service_item['ports'] = service['ports']
                if 'command' in service:
                    compose_service_item['command'] = service['command']
                if 'depends_on' in service:
                    compose_service_item['depends_on'] = service['depends_on']

                # Create storage volume
                if 'storage' in service:
                    volume_name = f"{service_name}_data"
                    if service['storage'] == 'internal':
                        self.docker_compose['volumes'][volume_name] = {}
                    else:
                        self.docker_compose['volumes'][volume_name] = {'external': True}
                    compose_service_item['volumes'] = compose_service_item.get('volumes', []) + [f"{volume_name}:/data"]

                self.docker_compose['services'][service_name] = compose_service_item

                # Check for extra keys
                extra_keys = set(service.keys()) - SERVICE_KEYS['required'] - SERVICE_KEYS['optional']
                if extra_keys:
                    logging.warning(f"Service '{service_name}' has extra keys not being used: {extra_keys}")

        return yaml.dump(self.docker_compose, sort_keys=False)

    def generate_caddyfile(self):
        lines = []
        base_config = self.yml_data.get('caddy_base_config', '')
        if base_config:
            lines.append(base_config)

        for group_name, services in self.yml_data.get('services', {}).items():
            for service_name, service in services.items():
                if 'reverse_proxy' in service:
                    reverse_proxy = service['reverse_proxy']
                    subdomain, port = self._get_reverse_proxy_details(reverse_proxy, service_name)
                    if subdomain:
                        lines.append(f"{subdomain}.{DOMAIN} {{")
                    else:
                        lines.append(f"{DOMAIN} {{")
                    lines.append(f"    reverse_proxy {service_name}:{port}")
                    lines.append("}")

        return "\n".join(lines)

    def generate_services_yml(self):
        services_dict = {}
        for group_name, services in self.yml_data.get('services', {}).items():
            for service_name, service in services.items():
                if 'reverse_proxy' in service:
                    reverse_proxy = service['reverse_proxy']
                    subdomain, _ = self._get_reverse_proxy_details(reverse_proxy, service_name)
                    href = f"http://{subdomain}.{DOMAIN}" if subdomain else f"http://{DOMAIN}"
                else:
                    href = "#"

                if group_name not in services_dict:
                    services_dict[group_name] = []

                service_entry = {
                    'href': href,
                    'container': service_name,
                    'showStats': True
                }

                if 'description' in service:
                    service_entry['description'] = service['description']
                if 'icon' in service:
                    service_entry['icon'] = service['icon']

                service_name_or_title = service.get('title', service_name)
                services_dict[group_name].append({service_name_or_title: service_entry})

        grouped_services = []
        for group, services in services_dict.items():
            grouped_services.append({group: services})
        return yaml.dump(grouped_services, sort_keys=False)

if __name__ == "__main__":
    generator = ConfigGenerator(ENTRYPOINT_YML_PATH)
