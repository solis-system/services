import fs from 'fs';
import path from 'path';
import yaml from 'js-yaml';
import dotenv from 'dotenv';
import winston from 'winston';

// Charger les variables d'environnement
dotenv.config();

const DOMAIN = process.env.DOMAIN;
const ENV = process.env.ENV || 'production';
const NETWORK_NAME = 'proxy-network';
const ENTRYPOINT_YML_PATH = 'custom.yml';
const OUTPUT_DIR = 'dist';  // Dossier de génération des fichiers

if (!DOMAIN) {
    throw new Error("The DOMAIN environment variable is not set.");
}

const SERVICE_KEYS = {
    required: ['image'],
    optional: ['title', 'description', 'icon', 'environment', 'volumes', 'labels', 'subdomain', 'internal_port', 'ports', 'command', 'depends_on', 'storage', 'dev_path', 'group']
};

// Configurer le logging
const logger = winston.createLogger({
    level: 'info',
    format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.printf(({ timestamp, level, message }) => `${timestamp} - ${level} - ${message}`)
    ),
    transports: [
        new winston.transports.Console()
    ]
});

class ConfigGenerator {
    constructor(ymlPath) {
        this.ymlPath = ymlPath;
        this.ymlData = this._readYamlFile();
        if (this.ymlData) {
            this.dockerCompose = {
                services: {},
                volumes: {},
                networks: {
                    [NETWORK_NAME]: {
                        external: true
                    }
                }
            };
            fs.mkdirSync(OUTPUT_DIR, { recursive: true });

            // Copier le fichier .env dans le dossier de sortie
            this.copyEnvFile();

            const dockerComposeYml = this.generateDockerCompose();
            this.writeFile(path.join(OUTPUT_DIR, 'docker-compose.yml'), dockerComposeYml);

            // Générer Caddyfile
            const caddyfileContent = this.generateCaddyfile();
            this.writeFile(path.join(OUTPUT_DIR, 'Caddyfile'), caddyfileContent);

            // Générer services.yml
            const servicesYml = this.generateServicesYml();
            this.writeFile(path.join(OUTPUT_DIR, 'homepage_services.yaml'), servicesYml);

            // Générer proxy.docker-compose.yml
            const proxyDockerComposeYml = this.generateProxyDockerCompose();
            this.writeFile(path.join(OUTPUT_DIR, 'proxy.docker-compose.yml'), proxyDockerComposeYml);

            logger.info("Files generated successfully!");
        }
    }

    _readYamlFile() {
        if (!fs.existsSync(this.ymlPath)) {
            logger.error(`File not found: ${this.ymlPath}`);
            return null;
        }
        try {
            const fileContent = fs.readFileSync(this.ymlPath, 'utf8');
            return yaml.load(fileContent);
        } catch (error) {
            logger.error(`Error parsing YAML file: ${this.ymlPath}\n${error}`);
            return null;
        }
    }

    writeFile(filepath, content) {
        fs.mkdirSync(path.dirname(filepath), { recursive: true });
        try {
            fs.writeFileSync(filepath, content);
            logger.info(`File written successfully: ${filepath}`);
        } catch (error) {
            logger.error(`Error writing file: ${filepath}\n${error}`);
        }
    }

    copyEnvFile() {
        const src = '.env';
        const dst = path.join(OUTPUT_DIR, '.env');
        try {
            fs.copyFileSync(src, dst);
            logger.info(`Copied .env file to ${dst}`);
        } catch (error) {
            logger.error(`Error copying .env file: ${src}\n${error}`);
        }
    }

    _getReverseProxyDetails(service) {
        const subdomain = service.subdomain || '';
        const internalPort = service.internal_port || 80;
        return [subdomain, internalPort];
    }

    generateDockerCompose() {
        for (const [serviceName, service] of Object.entries(this.ymlData.services || {})) {
            if (!SERVICE_KEYS.required.every(key => key in service)) {
                logger.warn(`Service definition incomplete: ${serviceName}`);
                continue;
            }

            const composeServiceItem = {
                container_name: serviceName,
                image: service.image,
                restart: 'always',
                networks: [NETWORK_NAME]
            };

            if (service.environment) {
                composeServiceItem.environment = service.environment.map(varName => `${varName}=${process.env[varName]}`);
            }
            if (service.volumes) {
                composeServiceItem.volumes = service.volumes;
            }
            if (service.labels) {
                composeServiceItem.labels = service.labels;
            }
            if (service.ports) {
                composeServiceItem.ports = service.ports;
            }
            if (service.command) {
                composeServiceItem.command = service.command;
            }
            if (service.depends_on) {
                composeServiceItem.depends_on = service.depends_on;
            }

            // Create storage volume
            if (service.storage) {
                const volumeName = `${serviceName}_data`;
                if (service.storage === 'internal') {
                    this.dockerCompose.volumes[volumeName] = {};
                } else {
                    this.dockerCompose.volumes[volumeName] = { external: true };
                }
                composeServiceItem.volumes = [...(composeServiceItem.volumes || []), `${volumeName}:/data`];
            }

            // Add dev_path if ENV is 'development'
            if (ENV === 'development' && service.dev_path) {
                composeServiceItem.volumes = [...(composeServiceItem.volumes || []), `${service.dev_path}:/app`];
            }

            this.dockerCompose.services[serviceName] = composeServiceItem;

            // Check for extra keys
            const extraKeys = Object.keys(service).filter(key => !SERVICE_KEYS.required.includes(key) && !SERVICE_KEYS.optional.includes(key));
            if (extraKeys.length) {
                logger.warn(`Service '${serviceName}' has extra keys not being used: ${extraKeys}`);
            }
        }

        return yaml.dump(this.dockerCompose, { sortKeys: false });
    }

    generateProxyDockerCompose() {
        const proxyDockerCompose = {
            services: {
                caddy: {
                    container_name: 'caddy',
                    image: 'caddy:latest',
                    volumes: [
                        '/var/run/docker.sock:/var/run/docker.sock',
                        './Caddyfile:/etc/caddy/Caddyfile'
                    ],
                    ports: [
                        '80:80',
                        '443:443',
                        '443:443/udp',
                        '5000:5000'
                    ],
                    restart: 'always',
                    networks: [
                        NETWORK_NAME
                    ]
                }
            },
            networks: {
                [NETWORK_NAME]: {
                    external: true
                }
            }
        };
        return yaml.dump(proxyDockerCompose, { sortKeys: false });
    }

    generateCaddyfile() {
        const lines = [];
        const baseConfig = this.ymlData.caddy_base_config || '';
        if (baseConfig) {
            lines.push(baseConfig);
        }

        for (const [serviceName, service] of Object.entries(this.ymlData.services || {})) {
            const [subdomain, internalPort] = this._getReverseProxyDetails(service);
            if (subdomain) {
                lines.push(`${subdomain}.${DOMAIN} {`);
            } else {
                lines.push(`${DOMAIN} {`);
            }
            lines.push(`    reverse_proxy ${serviceName}:${internalPort}`);
            lines.push('}');
        }

        return lines.join('\n');
    }

    generateServicesYml() {
        const servicesDict = {};
        const groups = this.ymlData.groups || {};
        for (const [serviceName, service] of Object.entries(this.ymlData.services || {})) {
            const groupId = service.group;
            const groupName = groups[groupId] || 'Ungrouped';
            const [subdomain] = this._getReverseProxyDetails(service);
            const href = subdomain ? `http://${subdomain}.${DOMAIN}` : `http://${DOMAIN}`;

            if (!servicesDict[groupName]) {
                servicesDict[groupName] = [];
            }

            const serviceEntry = {
                href,
                container: serviceName,
                showStats: true
            };

            if (service.description) {
                serviceEntry.description = service.description;
            }
            if (service.icon) {
                serviceEntry.icon = service.icon;
            }

            const serviceNameOrTitle = service.title || serviceName;
            servicesDict[groupName].push({ [serviceNameOrTitle]: serviceEntry });
        }

        const groupedServices = [];
        for (const [group, services] of Object.entries(servicesDict)) {
            groupedServices.push({ [group]: services });
        }
        return yaml.dump(groupedServices, { sortKeys: false });
    }
}

const generator = new ConfigGenerator(ENTRYPOINT_YML_PATH);