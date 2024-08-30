import dotenv from 'dotenv'

dotenv.config()

export default {
  DOMAIN: process.env.DOMAIN,
  ENV: process.env.ENV || 'production',
  BASIC_AUTH: process.env.BASIC_AUTH,
  ADMIN_EMAIL: 'admin@solis-system.com',
  NETWORK_NAME: 'proxy-network',
  ENTRYPOINT_YML_PATH: 'manifest.yml',
  OUTPUT_DIR: 'dist',
  HOME_PAGE_GROUPS: {
    1: 'Lolapp',
    2: 'Outils',
    3: 'Data',
  },
  SERVICE_KEYS: {
    required: ['image'],
    optional: [
      'title',
      'description',
      'icon',
      'environment',
      'volumes',
      'labels',
      'subdomain',
      'internal_port',
      'ports',
      'command',
      'depends_on',
      'storage',
      'dev_path',
      'group',
      'auth',
      'env'
    ],
  },
}
