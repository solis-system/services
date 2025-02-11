export const caddy_header = (config) => `
{
    email ${config.ADMIN_EMAIL}
    log {
        output stdout
        format console
    }
}

jscanify.${config.DOMAIN} {
    reverse_proxy lola-france.fr:5173
    encode gzip
}

beta.${config.DOMAIN} {
    reverse_proxy localhost:8090
    encode gzip
}

telescope.${config.DOMAIN} {

    @telescope {
        path /telescope*
        path /vendor*
    }
    route @telescope {

        reverse_proxy api:8000
        encode gzip
    }
    @telescope_root {
        not path /telescope*
        not path /vendor*
    }
    redir @telescope_root /telescope
}


`
export const caddy_footer = (config) => `
api-minio.${config.DOMAIN} {
    reverse_proxy minio:9000 {
            header_up Host {host}
            header_up X-Real-IP {remote}
            header_up X-Forwarded-Port {port}
    }
    encode gzip
}
`

export const caddy_service = (url, proxy_service, basic_auth = false, config) =>
  `${url} {
    encode gzip
    reverse_proxy ${proxy_service}
    tls {
      dns cloudflare ${config.CLOUDFLARE_API_TOKEN}
    }
}`

    // ${basic_auth ? 'import auth' : ''}
//     (auth) {
//     basic_auth {
//         admin ${config.BASIC_AUTH}
//     }
// }