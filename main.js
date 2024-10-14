import path from 'path'
import config from './config.js'
import logger from './functions/logger.js'
import * as template from './functions/template.js'
import * as files from './functions/file.js'

class ConfigGenerator {
  constructor(ymlPath) {
    if (!config.DOMAIN)
      throw new Error('The DOMAIN environment variable is not set.')

    this.ymlData = files.readYamlFile(ymlPath)
    if (!this.ymlData) logger.error('Error reading YAML file')

    this.servicesObject = Object.entries(this.ymlData.services || {})

    files.removeDir(config.OUTPUT_DIR)

    // Copier le fichier .env dans le dossier de sortie
    files.copyFile('.env', path.join(config.OUTPUT_DIR, '.env'))
    files.copyFile('Dockerfile-caddy', path.join(config.OUTPUT_DIR, 'Dockerfile-caddy'))

    const dockerComposeYml = this.generateDockerCompose()
    files.writeFile(config.OUTPUT_DIR, 'docker-compose.yml', dockerComposeYml)

    const devDockerComposeYml = this.generateDevDockerCompose()
    files.writeFile(config.OUTPUT_DIR, 'docker-compose.dev.yml', devDockerComposeYml)

    // Générer Caddyfile
    const caddyfileContent = this.generateCaddyfile()
    files.writeFile(config.OUTPUT_DIR, 'Caddyfile', caddyfileContent)

    // Générer services.yml
    const servicesYml = this.generateServicesYml()
    files.writeFile(config.OUTPUT_DIR, 'homepage_services.yaml', servicesYml)

    // Générer proxy.docker-compose.yml
    const proxyDockerComposeYml = this.generateProxyDockerCompose()
    files.writeFile(
      config.OUTPUT_DIR,
      'proxy.docker-compose.yml',
      proxyDockerComposeYml
    )

    logger.info('Files generated successfully!')
  }

  _getReverseProxyDetails(service) {
    const subdomain = service.subdomain || ''
    const internalPort = service.internal_port || 80
    return [subdomain, internalPort]
  }

  generateDockerCompose() {
    const dockerCompose = {
      services: {},
      volumes: {},
      networks: {
        [config.NETWORK_NAME]: {
          external: true,
        },
      },
    }

    for (const [serviceName, service] of this.servicesObject) {
      if (!config.SERVICE_KEYS.required.every((key) => key in service)) {
        logger.warn(`Service definition incomplete: ${serviceName}`)
        continue
      }

      const composeServiceItem = {
        container_name: serviceName,
        image: service.image,
        restart: 'always',
        networks: [config.NETWORK_NAME],
      }

      if (service.environment) {
        composeServiceItem.environment = service.environment.map(
          (varName) => varName + '=' + '${' + varName + '}'
        )
      }
      if (service.volumes) {
        composeServiceItem.volumes = service.volumes
      }
      if (service.labels) {
        composeServiceItem.labels = service.labels
      }
      if (service.ports) {
        composeServiceItem.ports = service.ports
      }
      if (service.command) {
        composeServiceItem.command = service.command
      }
      if (service.depends_on) {
        composeServiceItem.depends_on = service.depends_on
      }

      // Create storage volume
      if (service.storage) {
        const volumeName = `${serviceName}_data`
        if (service.storage === 'internal') {
          dockerCompose.volumes[volumeName] = {}
        } else {
          dockerCompose.volumes[volumeName] = { external: true }
        }
        composeServiceItem.volumes = [
          ...(composeServiceItem.volumes || []),
          `${volumeName}:/data`,
        ]
      }

      dockerCompose.services[serviceName] = composeServiceItem

      // Check for extra keys
      const extraKeys = Object.keys(service).filter(
        (key) =>
          !config.SERVICE_KEYS.required.includes(key) &&
          !config.SERVICE_KEYS.optional.includes(key)
      )
      if (extraKeys.length) {
        logger.warn(
          `Service '${serviceName}' has extra keys not being used: ${extraKeys}`
        )
      }
    }

    return files.yamlDump(dockerCompose)
  }

  generateDevDockerCompose() {
    const dockerCompose = {
      services: {},
    }

    for (const [serviceName, service] of this.servicesObject) {
      if (!service.dev_path) continue
      dockerCompose.services[serviceName] = {
        container_name: serviceName,
        build: {
          context: service.dev_path,
          dockerfile: 'Dockerfile-dev',
        },
        volumes: [`${service.dev_path}:/app`],
        ports: [`${service.internal_port}:${service.internal_port}`]
      }
    }
    return files.yamlDump(dockerCompose)
  }

  generateProxyDockerCompose() {
    const proxyDockerCompose = {
      services: {
        caddy: {
          container_name: 'caddy',
          image: 'caddy:2.8.4',
          volumes: [
            '/var/run/docker.sock:/var/run/docker.sock',
            './Caddyfile:/etc/caddy/Caddyfile',
          ],
          ports: ['80:80', '443:443', '443:443/udp', '5000:5000'],
          restart: 'always',
          networks: [config.NETWORK_NAME],
        },
      },
      networks: {
        [config.NETWORK_NAME]: {
          external: true,
        },
      },
    }
    return files.yamlDump(proxyDockerCompose)
  }

  generateCaddyfile() {
    const lines = []

    const caddy_config = template.caddy_header(config)
    lines.push(caddy_config)


    for (const [serviceName, service] of this.servicesObject) {
      if (!('subdomain' in service)) continue

      const [subdomain, internalPort] = this._getReverseProxyDetails(service)
      const url = subdomain ? subdomain + '.' + config.DOMAIN : config.DOMAIN
      const proxy_service = serviceName + ':' + internalPort
      const basic_auth = service.auth === 'basic'
      const caddy_service = template.caddy_service(
        url,
        proxy_service,
        basic_auth
      )
      lines.push(caddy_service)
    }

    return lines.join('\n')
  }

  generateServicesYml() {
    const servicesDict = {}
    for (const [serviceName, service] of Object.entries(
      this.ymlData.services || {}
    )) {
      const groupId = service.group
      const groupName = config.HOME_PAGE_GROUPS[groupId] || 'Ungrouped'
      let [subdomain] = this._getReverseProxyDetails(service)

      if (subdomain === '*') subdomain = 'app'

      const href = subdomain
        ? `http://${subdomain}.${config.DOMAIN}`
        : `http://${config.DOMAIN}`

      if (!servicesDict[groupName]) {
        servicesDict[groupName] = []
      }

      const serviceEntry = {
        href,
        container: serviceName,
        showStats: true,
      }

      if (service.description) {
        serviceEntry.description = service.description
      }
      if (service.icon) {
        serviceEntry.icon = service.icon
      }

      const serviceNameOrTitle = service.title || serviceName
      servicesDict[groupName].push({ [serviceNameOrTitle]: serviceEntry })
    }

    const groupedServices = []
    for (const [group, services] of Object.entries(servicesDict)) {
      groupedServices.push({ [group]: services })
    }
    return files.yamlDump(groupedServices)
  }
}

const generator = new ConfigGenerator(config.ENTRYPOINT_YML_PATH)
