import yaml
import logging
import os
from dotenv import load_dotenv
import shutil

# Charger les variables d'environnement
load_dotenv()

DOMAIN = os.getenv('DOMAIN')
ENV = os.getenv('ENV', 'production')
NETWORK_NAME = 'proxy-network'
ENTRYPOINT_YML_PATH = 'custom.yml'
OUTPUT_DIR = 'dist'  # Dossier de génération des fichiers

if DOMAIN is None:
    raise RuntimeError("The DOMAIN environment variable is not set.")

SERVICE_KEYS = {
    'required': {'image'},
    'optional': {'title', 'description', 'icon', 'environment', 'volumes', 'labels', 'subdomain', 'internal_port', 'ports', 'command', 'depends_on', 'storage', 'dev_path', 'group'}
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
            os.makedirs(OUTPUT_DIR, exist_ok=True)

            # Copier le fichier .env dans le dossier de sortie
            self.copy_env_file()

            docker_compose_yml = self.generate_docker_compose()
            self.write_file(os.path.join(OUTPUT_DIR, 'docker-compose.yml'), docker_compose_yml)

            # Générer Caddyfile
            caddyfile_content = self.generate_caddyfile()
            self.write_file(os.path.join(OUTPUT_DIR, 'Caddyfile'), caddyfile_content)

            # Générer services.yml
            services_yml = self.generate_services_yml()
            self.write_file(os.path.join(OUTPUT_DIR, 'homepage_services.yaml'), services_yml)

            # Générer proxy.docker-compose.yml
            proxy_docker_compose_yml = self.generate_proxy_docker_compose()
            self.write_file(os.path.join(OUTPUT_DIR, 'proxy.docker-compose.yml'), proxy_docker_compose_yml)

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
        os.makedirs(os.path.dirname(filepath), exist_ok=True)
        try:
            with open(filepath, 'w') as file:
                file.write(content)
                logging.info(f"File written successfully: {filepath}")
        except IOError as exc:
            logging.error(f"Error writing file: {filepath}\n{exc}")

    def copy_env_file(self):
        src = '.env'
        dst = os.path.join(OUTPUT_DIR, '.env')
        try:
            shutil.copy(src, dst)
            logging.info(f"Copied .env file to {dst}")
        except IOError as exc:
            logging.error(f"Error copying .env file: {src}\n{exc}")

    def _get_reverse_proxy_details(self, service):
        subdomain = service.get('subdomain', '')
        internal_port = service.get('internal_port', 80)
        return subdomain, internal_port

    def generate_docker_compose(self):
        for service_name, service in self.yml_data.get('services', {}).items():
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

            # Add dev_path if ENV is 'development'
            if ENV == 'development' and 'dev_path' in service:
                compose_service_item['volumes'] = compose_service_item.get('volumes', []) + [f"{service['dev_path']}:/app"]

            self.docker_compose['services'][service_name] = compose_service_item

            # Check for extra keys
            extra_keys = set(service.keys()) - SERVICE_KEYS['required'] - SERVICE_KEYS['optional']
            if extra_keys:
                logging.warning(f"Service '{service_name}' has extra keys not being used: {extra_keys}")

        return yaml.dump(self.docker_compose, sort_keys=False)

    def generate_proxy_docker_compose(self):
        proxy_docker_compose = {
            'services': {
                'caddy': {
                    'container_name': 'caddy',
                    'image': 'caddy:latest',
                    'volumes': [
                        '/var/run/docker.sock:/var/run/docker.sock',
                        './Caddyfile:/etc/caddy/Caddyfile'
                    ],
                    'ports': [
                        '80:80',
                        '443:443',
                        '443:443/udp',
                        '5000:5000'
                    ],
                    'restart': 'always',
                    'networks': [
                        NETWORK_NAME
                    ]
                }
            },
            'networks': {
                NETWORK_NAME: {
                    'external': True
                }
            }
        }
        return yaml.dump(proxy_docker_compose, sort_keys=False)

    def generate_caddyfile(self):
        lines = []
        base_config = self.yml_data.get('caddy_base_config', '')
        if base_config:
            lines.append(base_config)

        for service_name, service in self.yml_data.get('services', {}).items():
            subdomain, internal_port = self._get_reverse_proxy_details(service)
            if subdomain:
                lines.append(f"{subdomain}.{DOMAIN} {{")
            else:
                lines.append(f"{DOMAIN} {{")
            lines.append(f"    reverse_proxy {service_name}:{internal_port}")
            lines.append("}")

        return "\n".join(lines)

    def generate_services_yml(self):
        services_dict = {}
        groups = self.yml_data.get('groups', {})
        for service_name, service in self.yml_data.get('services', {}).items():
            group_id = service.get('group')
            group_name = groups.get(group_id, 'Ungrouped')
            subdomain, _ = self._get_reverse_proxy_details(service)
            href = f"http://{subdomain}.{DOMAIN}" if subdomain else f"http://{DOMAIN}"

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
